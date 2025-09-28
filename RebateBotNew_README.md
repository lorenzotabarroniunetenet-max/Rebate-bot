# RebateBotNew MT5 Expert Advisor v1.0

## Descrizione
Expert Advisor professionale per MT5 progettato specificamente per massimizzare i rebates mantenendo la profittabilità. Utilizza strategie multiple combinate con gestione avanzata del rischio.

## Caratteristiche Principali

### 🎯 Strategia di Trading
- **RSI Mean Reversion**: Segnali di ipercomprato/ipervenduto
- **Moving Average Crossover**: Conferma trend con EMA 10/20
- **Volume Filter**: Filtra segnali con volume insufficiente
- **Multi-Signal Confirmation**: Richiede almeno 2 segnali concordi

### 🛡️ Gestione del Rischio
- **Stop Loss Dinamico**: 8 pips di default, personalizzabile
- **Take Profit**: 12 pips (ratio 1.5:1)
- **Trailing Stop**: Protezione automatica profitti
- **Limite Giornaliero**: Massimo 180 operazioni/giorno
- **Filtri Temporali**: Evita weekend e ore di alta volatilità

### 💰 Ottimizzazione Rebates
- **Volume Target**: 100-180 lotti/giorno
- **Frequenza Controllata**: 8 minuti tra operazioni
- **Spread Filter**: Massimo 0.8 pips
- **Costi Ottimizzati**: Minimizza slippage e commissioni

## Parametri di Configurazione

### Trading Settings
```
LotSize = 0.01              // Dimensione lotto
MaxTradesPerDay = 180       // Massimo operazioni giornaliere
MinutesBetweenTrades = 8    // Minuti tra operazioni
MaxSpreadPips = 0.8         // Spread massimo in pips
MagicNumber = 12345         // Numero magico
```

### Risk Management
```
StopLossPips = 8.0          // Stop loss in pips
TakeProfitPips = 12.0       // Take profit in pips
RiskPercentage = 1.0        // Rischio per operazione %
UseTrailingStop = true      // Abilita trailing stop
TrailingStopPips = 5.0      // Distanza trailing stop
```

### Strategy Settings
```
RSI_Period = 14             // Periodo RSI
RSI_Oversold = 30           // Livello ipervenduto
RSI_Overbought = 70         // Livello ipercomprato
MA_Fast = 10                // Media mobile veloce
MA_Slow = 20                // Media mobile lenta
UseVolumeFilter = true      // Abilita filtro volume
MinVolumeMultiplier = 1.2   // Moltiplicatore volume minimo
```

## Logica di Trading

### Segnali di Acquisto (BUY)
1. RSI < 30 (ipervenduto) + crossover verso l'alto
2. EMA 10 > EMA 20 (trend rialzista)
3. Volume > 1.2x media (conferma)
4. Spread < 0.8 pips

### Segnali di Vendita (SELL)
1. RSI > 70 (ipercomprato) + crossover verso il basso
2. EMA 10 < EMA 20 (trend ribassista)
3. Volume > 1.2x media (conferma)
4. Spread < 0.8 pips

### Gestione Posizioni
- **Trailing Stop**: Attivato automaticamente
- **Time Filter**: No trading weekend e ore volatili
- **Daily Reset**: Contatore operazioni reset ogni giorno

## Calcoli Economici

### Con Rebate $8/lotto e Commissioni $25/lotto:
- **Costo Netto**: ~$17/lotto (commissioni - rebates)
- **Target Win Rate**: 65-70%
- **Profitto Trading**: $8-12/lotto medio
- **Risultato Netto**: Break-even o leggero profitto
- **Volume Giornaliero**: 100-150 lotti
- **Rebates Giornalieri**: $800-1200

## Installazione

1. Copia `RebateBotNew.mq5` in `MQL5/Experts`
2. Compila in MetaEditor (F7)
3. Applica su grafico EUR/USD M5
4. Configura parametri secondo il tuo account
5. Abilita trading automatico

## Configurazione Consigliata

### Account $1000
```
LotSize = 0.01
MaxTradesPerDay = 150
RiskPercentage = 1.0
UseTrailingStop = true
```

### Account $5000
```
LotSize = 0.05
MaxTradesPerDay = 180
RiskPercentage = 0.8
UseTrailingStop = true
```

## Monitoraggio

### Metriche Chiave
- Volume giornaliero (target: 100-150 lotti)
- Win rate (target: >65%)
- Drawdown massimo (target: <5%)
- Profitto per lotto (target: >$5)
- Rebates totali giornalieri

### Log da Controllare
- Numero operazioni eseguite
- Spread medio al momento dell'apertura
- Performance trailing stop
- Filtri attivati (volume, tempo, spread)

## Avvertenze

⚠️ **Importante**: Questo EA è ottimizzato per rebates. Testa sempre su demo prima dell'uso reale.

⚠️ **Rischi**: Slippage, spread variabili, disconnessioni possono influire sui risultati.

⚠️ **Monitoraggio**: Controlla giornalmente le performance e regola i parametri se necessario.

## Supporto

Per modifiche, ottimizzazioni o supporto tecnico, contatta lo sviluppatore.

---
**Disclaimer**: I risultati passati non garantiscono performance future. Usa sempre una gestione del rischio appropriata.
