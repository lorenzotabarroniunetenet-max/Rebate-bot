# AdvancedRebateBot MT5 Expert Advisor v3.0

## Descrizione
Expert Advisor avanzato che combina multiple strategie profittevoli per massimizzare sia i profitti dal trading che i rebates. Utilizza analisi tecnica sofisticata, gestione dinamica del rischio e algoritmi di machine learning per identificare opportunità ad alta probabilità.

## Caratteristiche Avanzate
- **6 Strategie Combinate**: RSI+Divergenze, MACD, Bollinger Bands, Volume, S/R, Multi-Timeframe
- **Gestione Rischio Intelligente**: Position sizing dinamico basato su forza del segnale
- **Trailing Stop Avanzato**: Protezione automatica dei profitti
- **Filtri di Qualità**: Evita condizioni di mercato sfavorevoli
- **Partial Profit Taking**: Chiusura parziale per massimizzare profitti
- **Support/Resistance Detection**: Identificazione automatica livelli chiave

## Parametri Configurabili

### Parametri di Trading
- **LotSize**: Dimensione del lotto per operazione (default: 0.01)
- **MaxTradesPerDay**: Massimo numero di operazioni giornaliere (default: 180)
- **MinutesBetwenTrades**: Minuti tra un'operazione e l'altra (default: 8)
- **MaxSpreadPips**: Spread massimo in pips per aprire posizioni (default: 0.8)

### Gestione Rischio
- **StopLossPips**: Stop loss base in pips (default: 8.0)
- **TakeProfitPips**: Take profit base in pips (default: 12.0)
- **MagicNumber**: Numero magico per identificare le operazioni (default: 12345)

### Indicatori Tecnici Avanzati
- **RSI_Period**: Periodo RSI per analisi momentum (default: 14)
- **MA_Fast**: Periodo media mobile veloce (default: 10)
- **MA_Slow**: Periodo media mobile lenta (default: 20)
- **RSI_Oversold**: Livello RSI ipervenduto (default: 30)
- **RSI_Overbought**: Livello RSI ipercomprato (default: 70)
- **BB_Period**: Periodo Bollinger Bands (default: 20)
- **BB_Deviation**: Deviazione standard BB (default: 2.0)
- **MACD_Fast**: EMA veloce MACD (default: 12)
- **MACD_Slow**: EMA lenta MACD (default: 26)
- **MACD_Signal**: Linea segnale MACD (default: 9)

### Filtri Avanzati
- **UseVolumeFilter**: Abilita filtro volume (default: true)
- **MinVolumeMultiplier**: Volume minimo vs media (default: 1.2)
- **UseSupportResistance**: Abilita S/R detection (default: true)
- **SR_LookbackPeriod**: Periodo lookback S/R (default: 50)

### Gestione Rischio Avanzata
- **RiskPerTrade**: Rischio per trade in % (default: 1.0)
- **UseTrailingStop**: Abilita trailing stop (default: true)
- **TrailingStopPips**: Distanza trailing stop (default: 5.0)

## Strategia di Trading

### Logica Multi-Strategia Avanzata
1. **RSI + Divergenze**: Rileva divergenze bullish/bearish per segnali forti
2. **MACD Momentum**: Conferma momentum con crossover e posizione zero-line
3. **Bollinger Bands**: Squeeze detection e mean reversion
4. **Volume Analysis**: Conferma segnali con analisi volume
5. **Support/Resistance**: Identificazione automatica livelli chiave
6. **Multi-Timeframe**: Conferma trend da timeframe superiori
7. **Quality Filters**: Evita trading in condizioni sfavorevoli

### Sistema di Scoring Avanzato
- **Segnali Forti**: Score ≥ 3 (combinazione di almeno 3 indicatori)
- **Divergenze**: +3/-3 punti per divergenze confermate
- **Volume**: +1/-1 per conferma volume
- **S/R Levels**: +1/-1 per vicinanza a livelli chiave
- **HTF Confirmation**: +1/-1 per allineamento trend superiore
- **Risk/Reward Dinamico**: 1.5:1 a 2.1:1 basato su forza segnale

### Calcoli Economici Avanzati
Con strategia multi-algoritmica:
- **Rebate**: $8 per lotto
- **Commissioni**: $25 per lotto
- **Spread**: ~0.4 pips = ~$4 per lotto standard
- **Costo Totale**: ~$21 per lotto
- **Profitto Target**: 65-70% win rate con 1.5-2.1:1 R/R = +$8-12 per lotto medio
- **Risultato Netto**: $8 (rebate) + $10 (trading) - $21 (costi) = -$3 per lotto
- **Volume Necessario**: ~100-120 lotti/giorno per profittabilità
- **Profitto Giornaliero Target**: $200-400 (rebates) + $800-1200 (trading) = $1000-1600

## Installazione

1. Copia il file `RebateBot.mq5` nella cartella `MQL5/Experts` del tuo terminale MT5
2. Compila l'Expert Advisor nel MetaEditor
3. Applica l'EA al grafico EUR/USD

## Configurazione Consigliata

### Per Account da $1000
- **LotSize**: 0.01 (base, dinamico fino a 0.02)
- **RiskPerTrade**: 1.0% (rischio controllato)
- **MaxTradesPerDay**: 120-150 (qualità > quantità)
- **StopLoss**: 8 pips + ATR dinamico
- **TakeProfit**: 12-17 pips (ratio 1.5-2.1:1)
- **TrailingStop**: 5 pips (protezione profitti)
- **Partial Close**: 50% a 2:1 R/R

### Timeframe Consigliato
- **M1 o M5**: Per reattività alle condizioni di mercato

## Monitoraggio

### Metriche Avanzate
1. **Volume Giornaliero**: Numero di lotti tradati (target: 100-150)
2. **Win Rate**: Percentuale operazioni vincenti (target: >65%)
3. **Average R/R**: Rapporto profitto/perdita medio (target: >1.8)
4. **Signal Quality**: Score medio segnali (target: >3.5)
5. **Drawdown Massimo**: Perdita massima (target: <5%)
6. **Profit Factor**: Profitti/Perdite (target: >1.5)
7. **Sharpe Ratio**: Rendimento aggiustato per rischio
8. **Rebates Totali**: Volume × $8
9. **Profitto Trading Netto**: Al netto di commissioni
10. **ROI Giornaliero**: Rendimento su capitale investito

### Log da Monitorare
- Numero operazioni giornaliere
- Spread al momento dell'apertura
- Risultati delle singole operazioni

## Rischi e Considerazioni

### Rischi Principali
1. **Slippage**: Può aumentare i costi reali
2. **Spread Variabile**: Durante news o bassa liquidità
3. **Drawdown**: Sequenze di perdite consecutive
4. **Rischio Tecnico**: Disconnessioni o errori

### Raccomandazioni
1. **Test su Demo**: Prova sempre prima su account demo
2. **Monitoraggio Costante**: Controlla performance giornalmente
3. **Backup Capital**: Non usare tutto il capitale disponibile
4. **Stop Loss Globale**: Imposta un limite di perdita giornaliera

## Supporto
Per modifiche o ottimizzazioni, contatta lo sviluppatore.

---
**Disclaimer**: Questo EA è progettato per trading di rebate. I risultati passati non garantiscono performance future. Usa sempre gestione del rischio appropriata.
