const { test, before, after, beforeEach } = require('node:test');
const { readFileSync } = require('node:fs');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, getDocs, collection, updateDoc, deleteDoc, serverTimestamp, Timestamp, writeBatch, query, where } = require('firebase/firestore');
let env;
const basic = () => ({name:'Alice',goal:3,level:0,daysPerWeek:3,hasGym:false,onboarded:false,createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
const health = () => ({age:25,heightCm:170,weightKg:70,targetWeightKg:70,conditions:[0],allergies:[1],updatedAt:serverTimestamp()});
const db = (uid, claims) => uid ? env.authenticatedContext(uid, claims).firestore() : env.unauthenticatedContext().firestore();
before(async () => { env = await initializeTestEnvironment({projectId:'demo-vigoriafit',firestore:{host:'127.0.0.1',port:8080,rules:readFileSync('firestore.rules','utf8')}}); });
after(async () => { await env?.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });
async function createUser(uid='alice') {
  const client = db(uid); const batch = writeBatch(client);
  batch.set(doc(client,`users/${uid}`),basic());
  batch.set(doc(client,`users/${uid}/private/health_profile`),health());
  await assertSucceeds(batch.commit());
}
async function createGroup() {
  const client = db('trainer',{trainer:true}); const batch = writeBatch(client);
  batch.set(doc(client,'groups/g1'), {trainerId:'trainer',trainerName:'Trainer',code:'123456',createdAt:serverTimestamp(),assignedWorkoutId:null,assignedWorkoutTitle:null});
  batch.set(doc(client,'groupInvites/123456'), {groupId:'g1',trainerId:'trainer',createdAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
}
async function join(uid='alice',code='123456') {
  return setDoc(doc(db(uid),`groups/g1/members/${uid}`), {name:uid,joinedAt:serverTimestamp(),inviteCode:code});
}
test('owner creates and reads both profile documents', async()=>{
  await createUser();
  await assertSucceeds(getDoc(doc(db('alice'),'users/alice')));
  await assertSucceeds(getDoc(doc(db('alice'),'users/alice/private/health_profile')));
});
test('anonymous and other users cannot read, write, delete or list private data',async()=>{
  await createUser();
  for(const uid of [null,'bob']) {
    const client=db(uid);
    for(const path of ['users/alice','users/alice/private/health_profile']) {
      await assertFails(getDoc(doc(client,path)));
      await assertFails(setDoc(doc(client,path),path.endsWith('health_profile')?health():basic()));
      await assertFails(deleteDoc(doc(client,path)));
    }
    await assertFails(getDocs(collection(client,'users')));
    await assertFails(getDocs(collection(client,'users/alice/private')));
  }
});
test('trainer role grants no access to student health profile',async()=>{
  await createUser(); await createGroup(); await join();
  await assertFails(getDoc(doc(db('trainer',{trainer:true}),'users/alice/private/health_profile')));
});
test('cannot self-assign roles or pollute schema on create and update',async()=>{
  await assertFails(setDoc(doc(db('alice'),'users/alice'),{...basic(),roles:['trainer']}));
  await createUser();
  await assertFails(updateDoc(doc(db('alice'),'users/alice'),{trainer:true,updatedAt:serverTimestamp()}));
  await assertFails(setDoc(doc(db('alice'),'users/alice/private/anything'),health()));
});
test('validate types, ranges, size and immutable timestamps on updates',async()=>{
  await createUser();
  for(const patch of [{name:'a'.repeat(121)},{goal:99},{level:'beginner'},{daysPerWeek:0},{createdAt:Timestamp.fromMillis(1)}]) {
    await assertFails(updateDoc(doc(db('alice'),'users/alice'),{...patch,updatedAt:serverTimestamp()}));
  }
  for(const patch of [{age:10},{weightKg:-1},{allergies:['wrong']},{conditions:Array(10).fill(0)},{heightCm:'170'}]) {
    await assertFails(updateDoc(doc(db('alice'),'users/alice/private/health_profile'),{...patch,updatedAt:serverTimestamp()}));
  }
  await assertFails(setDoc(doc(db('alice'),'users/alice'),{name:'missing required fields'}));
  await assertSucceeds(updateDoc(doc(db('alice'),'users/alice'),{name:'New name',updatedAt:serverTimestamp()}));
});
test('orphan health documents cannot be created',async()=>{
  await assertFails(setDoc(doc(db('alice'),'users/alice/private/health_profile'),health()));
});
test('ordinary user cannot create a trainer group or impersonate its owner',async()=>{
  const data={trainerId:'alice',trainerName:'Fake',code:'123456',createdAt:serverTimestamp(),assignedWorkoutId:null,assignedWorkoutTitle:null};
  await assertFails(setDoc(doc(db('alice'),'groups/g1'),data));
  await assertFails(setDoc(doc(db('trainer',{trainer:true}),'groups/g1'),data));
});
test('invitation lookup allows join without exposing group/member listings',async()=>{
  await createGroup();
  await assertSucceeds(getDoc(doc(db('alice'),'groupInvites/123456')));
  await assertFails(getDocs(collection(db('alice'),'groupInvites')));
  await assertFails(getDoc(doc(db('alice'),'groups/g1')));
  await assertFails(join('bob','999999'));
  await assertSucceeds(join());
  await assertSucceeds(getDoc(doc(db('alice'),'groups/g1')));
  await assertFails(getDocs(collection(db('alice'),'groups/g1/members')));
  await assertSucceeds(getDocs(collection(db('trainer',{trainer:true}),'groups/g1/members')));
});
test('only group trainer assigns routine; ownership cannot change',async()=>{
  await createGroup(); await join();
  const patch={assignedWorkoutId:'w1',assignedWorkoutTitle:'Routine',assignedAt:serverTimestamp()};
  await assertFails(updateDoc(doc(db('alice'),'groups/g1'),patch));
  await assertFails(updateDoc(doc(db('other',{trainer:true}),'groups/g1'),patch));
  await assertSucceeds(updateDoc(doc(db('trainer',{trainer:true}),'groups/g1'),patch));
  await assertFails(updateDoc(doc(db('trainer',{trainer:true}),'groups/g1'),{trainerId:'alice',assignedAt:serverTimestamp()}));
});
test('completion ownership and leaving a group enforce access',async()=>{
  await createGroup(); await join();
  const completion={userId:'alice',userName:'Alice',workoutId:'w1',workoutTitle:'Routine',completedAt:serverTimestamp()};
  await assertFails(setDoc(doc(db('bob'),'groups/g1/completions/c1'),completion));
  await assertFails(setDoc(doc(db('alice'),'groups/g1/completions/c1'),{...completion,userId:'bob'}));
  await assertSucceeds(setDoc(doc(db('alice'),'groups/g1/completions/c1'),completion));
  await assertSucceeds(getDocs(query(collection(db('trainer',{trainer:true}),'groups/g1/completions'),where('completedAt','>',Timestamp.fromMillis(0)))));
  await assertSucceeds(deleteDoc(doc(db('alice'),'groups/g1/members/alice')));
  await assertFails(getDoc(doc(db('alice'),'groups/g1')));
});
