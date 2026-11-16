# Comparativo busca gulosa × A*

100 instâncias por tamanho, semente 20261117, horizonte de 2 dias (120 slots de 15 min), α = 1, β = 0,5. Valores: média ± desvio-padrão.

| Tarefas | Custo gulosa | Custo A* | Gulosa acima do ótimo | Excesso médio da gulosa | Tempo gulosa (ms) | Tempo A* (ms) | Pior tempo A* (ms) | Nós expandidos A* |
|---|---|---|---|---|---|---|---|---|
| 5 | 4.0 ± 2.9 | 2.4 ± 1.3 | 80/100 | 89.4% | 0.015 ± 0.036 | 0.06 ± 0.07 | 0.40 | 36 ± 14 |
| 8 | 7.8 ± 5.7 | 3.9 ± 3.2 | 97/100 | 124.3% | 0.009 ± 0.008 | 0.23 ± 0.21 | 1.30 | 220 ± 181 |
| 10 | 12.8 ± 15.0 | 5.4 ± 10.9 | 98/100 | 187.8% | 0.015 ± 0.017 | 0.92 ± 0.98 | 5.85 | 733 ± 749 |
| 12 | 17.8 ± 19.3 | 7.5 ± 12.5 | 99/100 | 200.2% | 0.023 ± 0.008 | 4.08 ± 6.31 | 42.87 | 2189 ± 3032 |

Excesso médio da gulosa: (custo guloso − custo A*) / custo A*, calculado só nas instâncias em que a gulosa ficou acima do ótimo (100% quando o ótimo é zero).
