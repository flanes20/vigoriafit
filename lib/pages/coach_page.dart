import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/coach.dart';
import '../services/store.dart';

class _Msg {
  final String text;
  final bool fromUser;
  const _Msg(this.text, this.fromUser);
}

/// Coach de vida saludable: un chat donde el usuario pregunta y la IA responde
/// usando su perfil y datos reales.
class CoachTab extends StatefulWidget {
  const CoachTab({super.key});

  @override
  State<CoachTab> createState() => _CoachTabState();
}

class _CoachTabState extends State<CoachTab> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [
    const _Msg(
      '¡Hola! 💪 Soy tu coach. Pregúntame lo que quieras sobre entrenamiento, '
      'comida, suplementos o hábitos. Estoy para ayudarte a lograr tu objetivo.',
      false,
    ),
  ];

  static const _suggestions = [
    '¿Qué como hoy?',
    '¿Qué suplemento me sirve?',
    '¿Cuánta proteína necesito?',
    '¿Qué rutina hago hoy?',
    'No tengo ganas de entrenar',
  ];

  bool _typing = false;

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _typing) return;
    setState(() {
      _msgs.add(_Msg(q, true));
      _ctrl.clear();
      _typing = true;
    });
    _scrollDown();

    final answer = await Coach.reply(q);
    if (!mounted) return;
    setState(() {
      _typing = false;
      _msgs.add(_Msg(answer, false));
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escucha AppStore para refrescar los colores si el usuario cambia de
    // tema en Ajustes mientras esta pestaña sigue montada de fondo.
    return ListenableBuilder(
      listenable: AppStore.instance,
      builder: (context, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.brand, AppColors.brandDark]),
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Coach IA',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    Text('Tu asistente de vida saludable',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              itemCount: _msgs.length + (_typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= _msgs.length) return _typingBubble();
                return _bubble(_msgs[i]);
              },
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _suggestions
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(s,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.ink)),
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: AppColors.line),
                          ),
                          onPressed: () => _send(s),
                        ),
                      ))
                  .toList(),
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final align = m.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = m.fromUser ? AppColors.brand : AppColors.surface;
    final textColor = m.fromUser ? Colors.white : AppColors.ink;
    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.fromUser ? 16 : 4),
            bottomRight: Radius.circular(m.fromUser ? 4 : 16),
          ),
          border: m.fromUser ? null : Border.all(color: AppColors.line),
        ),
        child: Text(m.text,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.35)),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.brand),
            ),
            const SizedBox(width: 10),
            Text('escribiendo…',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: AppColors.bg,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Pregúntale a tu coach…',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(color: AppColors.line),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.brand,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: () => _send(_ctrl.text),
            ),
          ),
        ],
      ),
    );
  }
}
