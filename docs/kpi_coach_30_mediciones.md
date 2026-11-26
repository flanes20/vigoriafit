# KPI Coach IA — Planilla de 30 Mediciones

**Fecha:** 25–26 de noviembre de 2026  
**Dispositivo:** ZTE Z2357N (Android 13, físico)  
**Red:** WiFi doméstica  
**Modelo:** `gemini-3.5-flash-lite` (Firebase AI Logic)  
**Método:** `Stopwatch` instrumentado en `CoachService.send()` — log `[KPI_COACH] XXXms | OK`

---

| # | Tiempo (ms) | Tiempo (s) | Estado |
|:---:|---:|---:|:---:|
| 1 | 1 961 | 1,96 | OK |
| 2 | 6 582 | 6,58 | OK |
| 3 | 4 313 | 4,31 | OK |
| 4 | 2 682 | 2,68 | OK |
| 5 | 4 344 | 4,34 | OK |
| 6 | 4 481 | 4,48 | OK |
| 7 | 1 875 | 1,88 | OK |
| 8 | 3 208 | 3,21 | OK |
| 9 | 1 547 | 1,55 | OK |
| 10 | 1 393 | 1,39 | OK |
| 11 | 2 185 | 2,19 | OK |
| 12 | 2 755 | 2,76 | OK |
| 13 | 2 054 | 2,05 | OK |
| 14 | 3 353 | 3,35 | OK |
| 15 | 3 630 | 3,63 | OK |
| 16 | 5 518 | 5,52 | OK |
| 17 | 3 521 | 3,52 | OK |
| 18 | 3 829 | 3,83 | OK |
| 19 | 4 151 | 4,15 | OK |
| 20 | 3 722 | 3,72 | OK |
| 21 | 4 087 | 4,09 | OK |
| 22 | 3 749 | 3,75 | OK |
| 23 | 4 569 | 4,57 | OK |
| 24 | 3 932 | 3,93 | OK |
| 25 | 14 540 | 14,54 | OK |
| 26 | 3 916 | 3,92 | OK |
| 27 | 3 237 | 3,24 | OK |
| 28 | 9 463 | 9,46 | OK |
| 29 | 4 229 | 4,23 | OK |
| 30 | 3 619 | 3,62 | OK |

---

## Resumen estadístico

| Métrica | Valor (ms) | Valor (s) |
|---|---:|---:|
| Muestra (n) | 30 | — |
| Mínimo | 1 393 | 1,39 |
| Promedio | 4 082 | 4,08 |
| Mediana (p50) | 3 760 | 3,76 |
| Percentil 95 (p95) | 8.167 | 8,17 |
| Máximo | 14 540 | 14,54 |
| Tasa de éxito | 100 % | — |
| SLA (p95 ≤ 10 s) | ✅ Cumple (margen 1,83 s) | — |

> **Método p95:** PERCENTIL.INC — índice = 0,95 × (30−1) = 27,55. Interpola entre posición 28 (6.582 ms) y posición 29 (9.463 ms): 6.582 + 0,55 × (9.463 − 6.582) = **8.167 ms**.  
> Nearest-rank (ceil) daría 9.463 ms (pos. 29). Ambos métodos cumplen el SLA ≤ 10 s.
