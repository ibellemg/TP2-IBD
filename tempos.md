| Forma | Descricao | Linhas | Media (5 exec.) | Desvio | Min | Max | CV | vs. forma a |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Q1a | Sem indice (varredura da tabela) | 2250 | 29.2 ms | 1.2 ms | 28.5 ms | 31.2 ms | 4.0% | 1.00x |
| Q1b | Com indice composto em (cargo, carga_horaria) | 2250 | 29.4 ms | 0.9 ms | 28.8 ms | 31.0 ms | 3.2% | 1.01x |
| Q1c | Com indice de cobertura em (cargo, carga_horaria, nome, cpf): nao precisa ler a tabela | 2250 | 29.7 ms | 3.7 ms | 27.8 ms | 36.3 ms | 12.5% | 1.02x |
| Q2a | BETWEEN sem indice | 1054 | 78.2 ms | 9.8 ms | 69.5 ms | 94.7 ms | 12.5% | 1.00x |
| Q2b | BETWEEN com indice em (turno, data) | 1054 | 18.9 ms | 1.3 ms | 17.6 ms | 21.1 ms | 7.1% | 0.24x |
| Q2c | YEAR()/MONTH() com o mesmo indice (funcao na coluna impede o uso do intervalo) | 1054 | 32.8 ms | 0.1 ms | 32.7 ms | 33.0 ms | 0.4% | 0.42x |
| Q3a | JOIN explicito | 46053 | 769.0 ms | 60.0 ms | 719.0 ms | 865.4 ms | 7.8% | 1.00x |
| Q3b | Juncao no WHERE, com a ordem das relacoes invertida no FROM | 46053 | 718.9 ms | 9.2 ms | 712.3 ms | 734.6 ms | 1.3% | 0.93x |
| Q3c | Subconsulta IN no WHERE e subconsulta escalar para o nome da unidade | 46053 | 726.4 ms | 13.6 ms | 709.8 ms | 743.6 ms | 1.9% | 0.94x |
| Q4a | JOIN (ordem escolhida pelo otimizador) | 193787 | 3217.2 ms | 655.4 ms | 2871.0 ms | 4387.4 ms | 20.4% | 1.00x |
| Q4b | STRAIGHT_JOIN forcando a ordem do FROM (prescricao primeiro) | 193787 | 3760.6 ms | 122.7 ms | 3583.8 ms | 3927.5 ms | 3.3% | 1.17x |
| Q4c | Tabela derivada que filtra os remedios de tarja Preta antes da juncao | 193787 | 2992.0 ms | 87.2 ms | 2923.9 ms | 3136.9 ms | 2.9% | 0.93x |
| Q5a | JOIN sem indice auxiliar | 1285 | 915.6 ms | 34.6 ms | 883.4 ms | 957.9 ms | 3.8% | 1.00x |
| Q5b | JOIN com indice em atendimento (tipo, diagnostico) | 1285 | 300.6 ms | 432.1 ms | 69.9 ms | 1072.5 ms | 143.7% | 0.33x |
| Q5c | STRAIGHT_JOIN forcando comecar por paciente (ordem do FROM invertida) | 1285 | 1750.8 ms | 967.4 ms | 1273.1 ms | 3480.3 ms | 55.3% | 1.91x |
| Q6a | JOINs encadeados | 17890 | 1241.2 ms | 39.0 ms | 1213.9 ms | 1302.6 ms | 3.1% | 1.00x |
| Q6b | Subconsultas escalares correlacionadas no SELECT | 17890 | 1282.2 ms | 42.2 ms | 1255.7 ms | 1354.2 ms | 3.3% | 1.03x |
| Q6c | JOINs encadeados com indice em atendimento (tipo, diagnostico) | 17890 | 582.7 ms | 276.8 ms | 393.4 ms | 1072.4 ms | 47.5% | 0.47x |
| Q7a | JOIN com DISTINCT | 22388 | 992.1 ms | 98.3 ms | 926.3 ms | 1162.4 ms | 9.9% | 1.00x |
| Q7b | Subconsulta com EXISTS | 22388 | 758.1 ms | 27.7 ms | 737.2 ms | 802.0 ms | 3.7% | 0.76x |
| Q7c | Subconsulta com IN | 22388 | 781.0 ms | 33.2 ms | 746.3 ms | 829.7 ms | 4.3% | 0.79x |
| Q8a | JOINs sem indice auxiliar | 7665 | 277.0 ms | 144.3 ms | 188.4 ms | 526.8 ms | 52.1% | 1.00x |
| Q8b | JOINs com indice em plantao (turno, data) | 7665 | 190.7 ms | 3.6 ms | 187.8 ms | 196.6 ms | 1.9% | 0.69x |
| Q8c | STRAIGHT_JOIN forcando a ordem unidade -> plantao -> escalado_em -> profissional | 7665 | 188.8 ms | 1.2 ms | 187.1 ms | 190.1 ms | 0.6% | 0.68x |
| Q9a | JOIN das tres relacoes e depois GROUP BY | 11 | 6518.3 ms | 101.4 ms | 6464.8 ms | 6699.4 ms | 1.6% | 1.00x |
| Q9b | Agrega primeiro numa tabela derivada e so depois junta com unidade | 11 | 763.6 ms | 1.7 ms | 761.7 ms | 765.6 ms | 0.2% | 0.12x |
| Q9c | Subconsulta correlacionada que conta os atendimentos de cada unidade | 11 | 674.0 ms | 0.7 ms | 673.3 ms | 675.1 ms | 0.1% | 0.10x |
| Q10a | JOIN das tres relacoes | 10 | 5062.6 ms | 211.2 ms | 4963.4 ms | 5440.3 ms | 4.2% | 1.00x |
| Q10b | Subconsulta IN no lugar da juncao com atendimento | 10 | 4989.0 ms | 14.3 ms | 4970.0 ms | 5004.6 ms | 0.3% | 0.99x |
| Q10c | JOIN das tres relacoes com indice em atendimento (tipo) | 10 | 8966.7 ms | 709.2 ms | 8596.4 ms | 10229.3 ms | 7.9% | 1.77x |
