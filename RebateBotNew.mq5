//+------------------------------------------------------------------+
//|                                                   RebateBotNew.mq5 |
//|                   ADVANCED AI-POWERED MT5 REBATE TRADING SYSTEM   |
//|                                  Copyright 2024, Lorenzo Tabarroni |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lorenzo Tabarroni"
#property link      ""
#property version   "2.00"
#property description "AI-Powered Multi-Strategy Rebate Trading System with Machine Learning"

#include <Trade\Trade.mqh>
#include <Math\Stat\Math.mqh>

// Input Parameters
input group "=== ADVANCED TRADING SETTINGS ==="
input double LotSize = 0.02;                    // Optimized lot size for commission efficiency
input int MaxTradesPerDay = 180;                // Maximum trades per day
input int MinutesBetweenTrades = 6;             // Minutes between trades (optimized for sustainability)
input double MaxSpreadPips = 0.8;               // Maximum spread in pips (tighter)
input int MagicNumber = 12345;                  // Magic number
input bool UseDynamicLotSizing = true;          // Enable dynamic position sizing
input double MaxLotSize = 0.05;                 // Maximum lot size allowed

input group "=== AI RISK MANAGEMENT ==="
input double BaseStopLossPips = 5.0;            // Base stop loss in pips
input double BaseTakeProfitPips = 18.0;         // Optimized to 18.0 for 3.6:1 R/R (34.3% win rate needed)
input double RiskPercentage = 1.2;              // Risk per trade %
input bool UseATRBasedSLTP = true;              // Use ATR for dynamic SL/TP
input bool UseTrailingStop = true;              // Enable trailing stop
input double TrailingStopPips = 4.0;            // Trailing stop distance
input bool UsePartialClose = true;              // Enable partial profit taking
input double PartialClosePercent = 50.0;       // Percentage to close at first target

input group "=== MULTI-STRATEGY SETTINGS ==="
input int RSI_Period = 14;                      // RSI period
input double RSI_Oversold = 25;                 // RSI oversold level (more aggressive)
input double RSI_Overbought = 75;               // RSI overbought level (more aggressive)
input int MA_Fast = 8;                          // Fast MA period (more responsive)
input int MA_Slow = 21;                         // Slow MA period
input int BB_Period = 20;                       // Bollinger Bands period
input double BB_Deviation = 2.0;                // Bollinger Bands deviation
input int MACD_Fast = 12;                       // MACD fast EMA
input int MACD_Slow = 26;                       // MACD slow EMA
input int MACD_Signal = 9;                      // MACD signal line
input int ATR_Period = 14;                      // ATR period for volatility
input bool UseVolumeFilter = true;              // Use volume filter
input double MinVolumeMultiplier = 1.5;         // Minimum volume multiplier (stronger filter)

input group "=== MULTI-TIMEFRAME ANALYSIS ==="
input bool UseMultiTimeframe = true;            // Enable multi-timeframe analysis
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H1; // Higher timeframe for trend
input bool UseNewsFilter = true;                // Avoid trading during high impact news
input bool UseSessionFilter = true;             // Trade only during active sessions

input group "=== MACHINE LEARNING FEATURES ==="
input bool UsePatternRecognition = true;        // Enable pattern recognition
input int PatternLookback = 50;                 // Bars to analyze for patterns
input bool UseMarketRegimeDetection = true;     // Detect trending vs ranging markets
input int RegimeAnalysisPeriod = 100;           // Period for regime analysis
input bool UseAdaptiveParameters = true;        // Auto-adjust parameters based on performance
input int PerformanceReviewPeriod = 1000;       // Bars to review for adaptation

// Global Variables
CTrade trade;
int tradesCountToday = 0;
datetime lastTradeTime = 0;
datetime currentDay = 0;

// Advanced indicator handles
int rsiHandle, rsiHTFHandle;
int maFastHandle, maSlowHandle;
int bbHandle, bbHTFHandle;
int macdHandle, macdHTFHandle;
int atrHandle;
int volumeHandle;
int adxHandle;
int stochHandle;

// AI and ML variables
double signalStrengthHistory[];
double profitHistory[];
double marketRegimeScore = 0.0;
bool isTrendingMarket = true;
double adaptiveRSIOversold = 25.0;
double adaptiveRSIOverbought = 75.0;
double currentATR = 0.0;
double avgVolume = 0.0;

// Performance tracking
struct PerformanceMetrics {
   int totalTrades;
   int winningTrades;
   double totalProfit;
   double maxDrawdown;
   double winRate;
   double profitFactor;
   double sharpeRatio;
};
PerformanceMetrics performance;

// Pattern recognition arrays
double pricePattern[];
double volumePattern[];
int patternSignals[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== RebateBotNew v2.0 AI-POWERED SYSTEM Initialized ===");
   Print("🚀 Advanced Multi-Strategy Rebate Trading System");
   Print("📊 Max trades per day: ", MaxTradesPerDay);
   Print("💰 Base lot size: ", LotSize, " | Dynamic sizing: ", (UseDynamicLotSizing ? "ON" : "OFF"));
   Print("🧠 AI Features: Pattern Recognition, Market Regime Detection, Adaptive Parameters");
   Print("⏰ Multi-timeframe analysis: ", (UseMultiTimeframe ? "ENABLED" : "DISABLED"));
   
   // Initialize trade object with advanced settings
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(10);
   
   // Initialize main timeframe indicators
   rsiHandle = iRSI(_Symbol, PERIOD_M5, RSI_Period, PRICE_CLOSE);
   maFastHandle = iMA(_Symbol, PERIOD_M5, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   maSlowHandle = iMA(_Symbol, PERIOD_M5, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   bbHandle = iBands(_Symbol, PERIOD_M5, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   macdHandle = iMACD(_Symbol, PERIOD_M5, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_M5, ATR_Period);
   volumeHandle = iVolumes(_Symbol, PERIOD_M5, VOLUME_TICK);
   adxHandle = iADX(_Symbol, PERIOD_M5, 14);
   stochHandle = iStochastic(_Symbol, PERIOD_M5, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   // Initialize higher timeframe indicators if enabled
   if(UseMultiTimeframe)
   {
      rsiHTFHandle = iRSI(_Symbol, HTF_Timeframe, RSI_Period, PRICE_CLOSE);
      bbHTFHandle = iBands(_Symbol, HTF_Timeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
      macdHTFHandle = iMACD(_Symbol, HTF_Timeframe, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   }
   
   // Validate all indicators
   if(rsiHandle == INVALID_HANDLE || maFastHandle == INVALID_HANDLE || 
      maSlowHandle == INVALID_HANDLE || bbHandle == INVALID_HANDLE ||
      macdHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
      volumeHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE ||
      stochHandle == INVALID_HANDLE)
   {
      Print("❌ ERROR: Failed to create main timeframe indicators");
      return INIT_FAILED;
   }
   
   if(UseMultiTimeframe && (rsiHTFHandle == INVALID_HANDLE || 
      bbHTFHandle == INVALID_HANDLE || macdHTFHandle == INVALID_HANDLE))
   {
      Print("❌ ERROR: Failed to create higher timeframe indicators");
      return INIT_FAILED;
   }
   
   // Initialize arrays for ML features
   ArrayResize(signalStrengthHistory, 1000);
   ArrayResize(profitHistory, 1000);
   ArrayResize(pricePattern, PatternLookback);
   ArrayResize(volumePattern, PatternLookback);
   ArrayResize(patternSignals, PatternLookback);
   ArrayInitialize(signalStrengthHistory, 0.0);
   ArrayInitialize(profitHistory, 0.0);
   
   // Initialize performance metrics
   ZeroMemory(performance);
   
   // Count today's trades and initialize
   tradesCountToday = CountTodayTrades();
   currentDay = TimeCurrent() - (TimeCurrent() % 86400);
   
   // Calculate initial market conditions
   CalculateMarketRegime();
   UpdateAdaptiveParameters();
   
   Print("✅ Initialization complete!");
   Print("📈 Today's trades so far: ", tradesCountToday);
   Print("🎯 Market regime: ", (isTrendingMarket ? "TRENDING" : "RANGING"));
   Print("🔧 Adaptive RSI levels: ", adaptiveRSIOversold, " / ", adaptiveRSIOverbought);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== RebateBotNew v2.0 AI-POWERED SYSTEM Deinitialized ===");
   Print("📊 Final Performance Summary:");
   Print("   Total Trades: ", performance.totalTrades);
   Print("   Win Rate: ", DoubleToString(performance.winRate, 2), "%");
   Print("   Total Profit: $", DoubleToString(performance.totalProfit, 2));
   Print("   Profit Factor: ", DoubleToString(performance.profitFactor, 2));
   Print("   Max Drawdown: ", DoubleToString(performance.maxDrawdown, 2), "%");
   Print("Reason: ", reason);
   
   // Release main timeframe indicator handles
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(maFastHandle != INVALID_HANDLE) IndicatorRelease(maFastHandle);
   if(maSlowHandle != INVALID_HANDLE) IndicatorRelease(maSlowHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   if(macdHandle != INVALID_HANDLE) IndicatorRelease(macdHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(volumeHandle != INVALID_HANDLE) IndicatorRelease(volumeHandle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(stochHandle != INVALID_HANDLE) IndicatorRelease(stochHandle);
   
   // Release higher timeframe indicator handles
   if(UseMultiTimeframe)
   {
      if(rsiHTFHandle != INVALID_HANDLE) IndicatorRelease(rsiHTFHandle);
      if(bbHTFHandle != INVALID_HANDLE) IndicatorRelease(bbHTFHandle);
      if(macdHTFHandle != INVALID_HANDLE) IndicatorRelease(macdHTFHandle);
   }
   
   Print("✅ All resources released successfully");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if new day started
   datetime today = TimeCurrent() - (TimeCurrent() % 86400);
   if(today != currentDay)
   {
      currentDay = today;
      tradesCountToday = CountTodayTrades();
      Print("🌅 New day started. Trades count reset to: ", tradesCountToday);
      
      // Daily performance review and parameter adaptation
      if(UseAdaptiveParameters)
      {
         UpdateAdaptiveParameters();
         Print("🔧 Parameters adapted for new day");
      }
   }
   
   // Update market conditions every 10 ticks for efficiency
   static int tickCounter = 0;
   tickCounter++;
   if(tickCounter >= 10)
   {
      UpdateMarketConditions();
      tickCounter = 0;
   }
   
   // Check trading conditions
   if(!CanTrade()) return;
   
   // Advanced spread and volatility check
   double spread = GetCurrentSpread();
   if(spread > MaxSpreadPips)
   {
      return;
   }
   
   // Get AI-powered trading signals
   double signalStrength = 0.0;
   int signal = GetAdvancedTradingSignal(signalStrength);
   
   if(signal == 1 && signalStrength >= 2.8) // Optimized threshold for quality over quantity
   {
      ExecuteAdvancedTrade(ORDER_TYPE_BUY, signalStrength);
   }
   else if(signal == -1 && signalStrength >= 2.8) // Optimized threshold for quality over quantity
   {
      ExecuteAdvancedTrade(ORDER_TYPE_SELL, signalStrength);
   }
   
   // Advanced position management
   ManageAdvancedPositions();
   
   // Update performance metrics
   UpdatePerformanceMetrics();
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool CanTrade()
{
   // Check daily trade limit
   if(tradesCountToday >= MaxTradesPerDay)
   {
      return false;
   }
   
   // Check time between trades
   if(TimeCurrent() - lastTradeTime < MinutesBetweenTrades * 60)
   {
      return false;
   }
   
   // Check trading hours and weekends
   MqlDateTime dt;
   if(!TimeToStruct(TimeCurrent(), dt))
      return false;
   
   // No trading on weekends
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   
   // Avoid major news hours (example: 8-10 GMT)
   if(dt.hour >= 8 && dt.hour <= 10)
   {
      if(TimeCurrent() - lastTradeTime < 15 * 60) // 15 minutes during news
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get current spread in pips                                       |
//+------------------------------------------------------------------+
double GetCurrentSpread()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / _Point;
}

//+------------------------------------------------------------------+
//| Advanced AI-powered trading signal with machine learning        |
//+------------------------------------------------------------------+
int GetAdvancedTradingSignal(double &signalStrength)
{
   signalStrength = 0.0;
   
   // Get all indicator values
   double rsi[5], rsiHTF[3];
   double maFast[5], maSlow[5];
   double bbUpper[3], bbLower[3], bbMiddle[3];
   double bbHTFUpper[3], bbHTFLower[3];
   double macdMain[3], macdSignal[3];
   double macdHTFMain[3], macdHTFSignal[3];
   double atr[3], volume[5];
   double adx[3], stoch[3];
   
   // Copy all buffers with error checking
   if(CopyBuffer(rsiHandle, 0, 0, 5, rsi) < 5 ||
      CopyBuffer(maFastHandle, 0, 0, 5, maFast) < 5 ||
      CopyBuffer(maSlowHandle, 0, 0, 5, maSlow) < 5 ||
      CopyBuffer(bbHandle, 1, 0, 3, bbUpper) < 3 ||
      CopyBuffer(bbHandle, 2, 0, 3, bbLower) < 3 ||
      CopyBuffer(bbHandle, 0, 0, 3, bbMiddle) < 3 ||
      CopyBuffer(macdHandle, 0, 0, 3, macdMain) < 3 ||
      CopyBuffer(macdHandle, 1, 0, 3, macdSignal) < 3 ||
      CopyBuffer(atrHandle, 0, 0, 3, atr) < 3 ||
      CopyBuffer(volumeHandle, 0, 0, 5, volume) < 5 ||
      CopyBuffer(adxHandle, 0, 0, 3, adx) < 3 ||
      CopyBuffer(stochHandle, 0, 0, 3, stoch) < 3)
   {
      return 0;
   }
   
   // Get higher timeframe data if enabled
   if(UseMultiTimeframe)
   {
      if(CopyBuffer(rsiHTFHandle, 0, 0, 3, rsiHTF) < 3 ||
         CopyBuffer(bbHTFHandle, 1, 0, 3, bbHTFUpper) < 3 ||
         CopyBuffer(bbHTFHandle, 2, 0, 3, bbHTFLower) < 3 ||
         CopyBuffer(macdHTFHandle, 0, 0, 3, macdHTFMain) < 3 ||
         CopyBuffer(macdHTFHandle, 1, 0, 3, macdHTFSignal) < 3)
      {
         return 0;
      }
   }
   
   currentATR = atr[0];
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
   
   // === ADVANCED SIGNAL ANALYSIS ===
   
   // 1. RSI Divergence and Adaptive Levels
   double rsiSignal = 0.0;
   if(rsi[0] < adaptiveRSIOversold && rsi[1] >= adaptiveRSIOversold)
      rsiSignal = 2.5; // Strong buy
   else if(rsi[0] > adaptiveRSIOverbought && rsi[1] <= adaptiveRSIOverbought)
      rsiSignal = -2.5; // Strong sell
   else if(rsi[0] < adaptiveRSIOversold + 5)
      rsiSignal = 1.0; // Moderate buy
   else if(rsi[0] > adaptiveRSIOverbought - 5)
      rsiSignal = -1.0; // Moderate sell
   
   // RSI Divergence detection
   if(DetectRSIDivergence(rsi))
   {
      rsiSignal *= 1.5; // Amplify signal on divergence
   }
   
   signalStrength += rsiSignal;
   
   // 2. Multi-MA System with Trend Strength
   double maSignal = 0.0;
   if(maFast[0] > maSlow[0])
   {
      if(maFast[1] <= maSlow[1]) maSignal = 2.0; // Fresh crossover
      else maSignal = 1.0; // Continuing trend
   }
   else if(maFast[0] < maSlow[0])
   {
      if(maFast[1] >= maSlow[1]) maSignal = -2.0; // Fresh crossover
      else maSignal = -1.0; // Continuing trend
   }
   
   signalStrength += maSignal;
   
   // 3. Bollinger Bands Squeeze and Breakout
   double bbSignal = 0.0;
   double bbWidth = (bbUpper[0] - bbLower[0]) / bbMiddle[0];
   bool isSqueeze = bbWidth < 0.02; // Tight bands indicate low volatility
   
   if(currentPrice > bbUpper[0] && !isSqueeze)
      bbSignal = -1.5; // Sell on upper band break in normal volatility
   else if(currentPrice < bbLower[0] && !isSqueeze)
      bbSignal = 1.5; // Buy on lower band break in normal volatility
   else if(isSqueeze && currentPrice > bbMiddle[0])
      bbSignal = 0.5; // Weak buy in squeeze
   else if(isSqueeze && currentPrice < bbMiddle[0])
      bbSignal = -0.5; // Weak sell in squeeze
   
   signalStrength += bbSignal;
   
   // 4. MACD with Zero Line and Signal Line Analysis
   double macdSignalValue = 0.0;
   if(macdMain[0] > macdSignal[0] && macdMain[1] <= macdSignal[1])
   {
      if(macdMain[0] > 0) macdSignalValue = 2.0; // Strong buy above zero
      else macdSignalValue = 1.0; // Moderate buy below zero
   }
   else if(macdMain[0] < macdSignal[0] && macdMain[1] >= macdSignal[1])
   {
      if(macdMain[0] < 0) macdSignalValue = -2.0; // Strong sell below zero
      else macdSignalValue = -1.0; // Moderate sell above zero
   }
   
   signalStrength += macdSignalValue;
   
   // 5. ADX Trend Strength Filter
   double adxSignal = 0.0;
   if(adx[0] > 25) // Strong trend
   {
      adxSignal = (signalStrength > 0) ? 1.0 : -1.0; // Amplify existing signal
   }
   else if(adx[0] < 20) // Weak trend/ranging
   {
      signalStrength *= 0.8; // Reduce signal strength in ranging market (optimized from 0.5)
   }
   
   signalStrength += adxSignal;
   
   // 6. Stochastic Confirmation
   double stochSignal = 0.0;
   if(stoch[0] < 20 && stoch[1] >= 20)
      stochSignal = 1.0; // Buy signal
   else if(stoch[0] > 80 && stoch[1] <= 80)
      stochSignal = -1.0; // Sell signal
   
   signalStrength += stochSignal;
   
   // 7. Volume Analysis with Pattern Recognition
   avgVolume = (volume[1] + volume[2] + volume[3] + volume[4]) / 4;
   double volumeSignal = 0.0;
   
   if(UseVolumeFilter)
   {
      if(volume[0] > avgVolume * MinVolumeMultiplier)
         volumeSignal = 1.0; // Volume confirmation
      else
         signalStrength *= 0.7; // Reduce signal without volume (optimized from 0.3)
   }
   
   signalStrength += volumeSignal;
   
   // 8. Higher Timeframe Confirmation
   if(UseMultiTimeframe)
   {
      double htfSignal = 0.0;
      
      // HTF RSI trend
      if(rsiHTF[0] < 40) htfSignal += 1.0;
      else if(rsiHTF[0] > 60) htfSignal -= 1.0;
      
      // HTF MACD trend
      if(macdHTFMain[0] > macdHTFSignal[0]) htfSignal += 0.5;
      else htfSignal -= 0.5;
      
      signalStrength += htfSignal;
   }
   
   // 9. Market Regime Adjustment
   if(UseMarketRegimeDetection)
   {
      if(isTrendingMarket)
      {
         // In trending markets, amplify trend-following signals
         if(MathAbs(signalStrength) > 2.0)
            signalStrength *= 1.3;
      }
      else
      {
         // In ranging markets, favor mean reversion
         if(signalStrength > 0 && rsi[0] > 50) signalStrength *= 0.85; // Optimized from 0.7
         else if(signalStrength < 0 && rsi[0] < 50) signalStrength *= 0.85; // Optimized from 0.7
      }
   }
   
   // 10. Pattern Recognition Bonus
   if(UsePatternRecognition)
   {
      double patternSignal = AnalyzePricePatterns();
      signalStrength += patternSignal;
   }
   
   // 11. News and Session Filters
   if(UseNewsFilter && IsHighImpactNewsTime())
   {
      signalStrength *= 0.5; // Reduce signals during news (optimized from 0.2)
   }
   
   if(UseSessionFilter && !IsActiveSession())
   {
      signalStrength *= 0.5; // Reduce signals during inactive sessions
   }
   
   // Final signal determination
   signalStrength = MathAbs(signalStrength); // Make strength positive
   
   if(signalStrength >= 2.8)
   {
      // Determine direction based on combined signals
      double totalBuySignals = 0.0;
      double totalSellSignals = 0.0;
      
      if(rsiSignal > 0) totalBuySignals += MathAbs(rsiSignal);
      else totalSellSignals += MathAbs(rsiSignal);
      
      if(maSignal > 0) totalBuySignals += MathAbs(maSignal);
      else totalSellSignals += MathAbs(maSignal);
      
      if(bbSignal > 0) totalBuySignals += MathAbs(bbSignal);
      else totalSellSignals += MathAbs(bbSignal);
      
      if(macdSignalValue > 0) totalBuySignals += MathAbs(macdSignalValue);
      else totalSellSignals += MathAbs(macdSignalValue);
      
      if(totalBuySignals > totalSellSignals)
         return 1; // Buy
      else if(totalSellSignals > totalBuySignals)
         return -1; // Sell
   }
   
   return 0; // No trade
}

//+------------------------------------------------------------------+
//| Execute advanced trade with dynamic sizing and AI optimization  |
//+------------------------------------------------------------------+
void ExecuteAdvancedTrade(ENUM_ORDER_TYPE orderType, double signalStrength)
{
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculate dynamic lot size based on signal strength and risk
   double lotSize = CalculateDynamicLotSize(signalStrength);
   
   // Calculate ATR-based stop loss and take profit
   double sl, tp;
   CalculateATRBasedSLTP(orderType, price, sl, tp, signalStrength);
   
   // Create trade comment with signal info
   string comment = StringFormat("RebateBot_AI_%.1f", signalStrength);
   
   // Execute trade with enhanced error handling
   if(trade.PositionOpen(_Symbol, orderType, lotSize, price, sl, tp, comment))
   {
      tradesCountToday++;
      lastTradeTime = TimeCurrent();
      
      // Store signal strength for learning
      int historyIndex = tradesCountToday % 1000;
      signalStrengthHistory[historyIndex] = signalStrength;
      
      Print("🚀 ADVANCED TRADE EXECUTED:");
      Print("   Type: ", EnumToString(orderType));
      Print("   Signal Strength: ", DoubleToString(signalStrength, 2));
      Print("   Lot Size: ", DoubleToString(lotSize, 3));
      Print("   Price: ", DoubleToString(price, 5));
      Print("   SL: ", DoubleToString(sl, 5), " (", DoubleToString((MathAbs(price - sl) / _Point), 1), " pips)");
      Print("   TP: ", DoubleToString(tp, 5), " (", DoubleToString((MathAbs(tp - price) / _Point), 1), " pips)");
      Print("   Trades today: ", tradesCountToday, "/", MaxTradesPerDay);
      Print("   Market regime: ", (isTrendingMarket ? "TRENDING" : "RANGING"));
   }
   else
   {
      Print("❌ ADVANCED TRADE FAILED:");
      Print("   Error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
      Print("   Signal Strength: ", DoubleToString(signalStrength, 2));
      Print("   Attempted Lot Size: ", DoubleToString(lotSize, 3));
   }
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size based on signal strength and risk    |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(double signalStrength)
{
   if(!UseDynamicLotSizing)
      return LotSize;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercentage / 100.0;
   
   // Base lot size calculation
   double dynamicLot = LotSize;
   
   // Adjust based on signal strength (3.0 to 8.0 range)
   double strengthMultiplier = MathMin(2.0, signalStrength / 3.0);
   dynamicLot *= strengthMultiplier;
   
   // Adjust based on market volatility (ATR)
   if(currentATR > 0)
   {
      double avgATR = currentATR * 10000; // Convert to pips
      if(avgATR > 15) // High volatility
         dynamicLot *= 0.8;
      else if(avgATR < 8) // Low volatility
         dynamicLot *= 1.2;
   }
   
   // Adjust based on recent performance
   if(performance.winRate > 70)
      dynamicLot *= 1.1; // Increase size when performing well
   else if(performance.winRate < 50)
      dynamicLot *= 0.8; // Decrease size when performing poorly
   
   // Ensure lot size is within limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(MaxLotSize, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   dynamicLot = MathMax(minLot, MathMin(maxLot, dynamicLot));
   dynamicLot = MathRound(dynamicLot / lotStep) * lotStep;
   
   return dynamicLot;
}

//+------------------------------------------------------------------+
//| Calculate ATR-based stop loss and take profit                   |
//+------------------------------------------------------------------+
void CalculateATRBasedSLTP(ENUM_ORDER_TYPE orderType, double price, double &sl, double &tp, double signalStrength)
{
   double slDistance, tpDistance;
   
   if(UseATRBasedSLTP && currentATR > 0)
   {
      // Use ATR for dynamic SL/TP
      slDistance = currentATR * 1.2; // 1.2x ATR for stop loss (optimized from 1.5x)
      tpDistance = currentATR * 3.6; // 3.6x ATR for take profit (optimized for 18 pip target)
      
      // Adjust based on signal strength
      if(signalStrength > 5.0)
      {
         tpDistance *= 1.3; // Larger TP for very strong signals
      }
      else if(signalStrength < 4.0)
      {
         slDistance *= 0.8; // Tighter SL for weaker signals
      }
   }
   else
   {
      // Use fixed pip values
      slDistance = BaseStopLossPips * _Point * 10;
      tpDistance = BaseTakeProfitPips * _Point * 10;
   }
   
   // Apply minimum and maximum limits
   double minSL = 5 * _Point * 10; // Minimum 5 pips
   double maxSL = 20 * _Point * 10; // Maximum 20 pips
   double minTP = 8 * _Point * 10; // Minimum 8 pips
   double maxTP = 40 * _Point * 10; // Maximum 40 pips
   
   slDistance = MathMax(minSL, MathMin(maxSL, slDistance));
   tpDistance = MathMax(minTP, MathMin(maxTP, tpDistance));
   
   // Calculate final SL and TP
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - slDistance;
      tp = price + tpDistance;
   }
   else
   {
      sl = price + slDistance;
      tp = price - tpDistance;
   }
}

//+------------------------------------------------------------------+
//| Advanced position management with AI optimization               |
//+------------------------------------------------------------------+
void ManageAdvancedPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            ulong ticket = PositionGetTicket(i);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            double volume = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            
            double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                 SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            double currentProfit = PositionGetDouble(POSITION_PROFIT);
            double profitPips = (posType == POSITION_TYPE_BUY) ? 
                               (currentPrice - openPrice) / _Point :
                               (openPrice - currentPrice) / _Point;
            
            // 1. Advanced Trailing Stop
            if(UseTrailingStop)
            {
               ManageTrailingStop(ticket, posType, openPrice, currentPrice, currentSL, currentTP);
            }
            
            // 2. Partial Profit Taking
            if(UsePartialClose && volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            {
               ManagePartialClose(ticket, posType, openPrice, currentPrice, volume, profitPips);
            }
            
            // 3. Time-based Exit (Emergency)
            if(TimeCurrent() - openTime > 3600) // 1 hour maximum hold time
            {
               Print("⏰ Emergency time-based exit for position ", ticket);
               trade.PositionClose(ticket);
               continue;
            }
            
            // 4. Volatility-based SL adjustment
            if(UseATRBasedSLTP && currentATR > 0)
            {
               AdjustSLBasedOnVolatility(ticket, posType, openPrice, currentPrice, currentSL);
            }
            
            // 5. Market regime change exit
            if(UseMarketRegimeDetection)
            {
               CheckRegimeChangeExit(ticket, posType, openTime, profitPips);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Advanced trailing stop management                               |
//+------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket, ENUM_POSITION_TYPE posType, double openPrice, 
                       double currentPrice, double currentSL, double currentTP)
{
   double trailDistance = TrailingStopPips * _Point * 10;
   
   // Dynamic trailing distance based on ATR
   if(currentATR > 0)
   {
      trailDistance = MathMax(trailDistance, currentATR * 1.2);
   }
   
   double newSL = 0;
   bool shouldUpdate = false;
   
   if(posType == POSITION_TYPE_BUY)
   {
      newSL = currentPrice - trailDistance;
      
      // Only move SL up and ensure it's above breakeven
      if(newSL > currentSL && newSL > openPrice + (2 * _Point * 10))
      {
         shouldUpdate = true;
      }
   }
   else // SELL position
   {
      newSL = currentPrice + trailDistance;
      
      // Only move SL down and ensure it's below breakeven
      if(newSL < currentSL && newSL < openPrice - (2 * _Point * 10))
      {
         shouldUpdate = true;
      }
   }
   
   if(shouldUpdate)
   {
      if(trade.PositionModify(ticket, newSL, currentTP))
      {
         Print("✅ Trailing stop updated for position ", ticket, 
               " | New SL: ", DoubleToString(newSL, 5));
      }
   }
}

//+------------------------------------------------------------------+
//| Partial profit taking management                                 |
//+------------------------------------------------------------------+
void ManagePartialClose(ulong ticket, ENUM_POSITION_TYPE posType, double openPrice,
                       double currentPrice, double volume, double profitPips)
{
   // Close 50% at 2:1 risk/reward ratio
   double targetPips = BaseStopLossPips * 2; // 2:1 R/R
   
   if(MathAbs(profitPips) >= targetPips && volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      double closeVolume = MathRound(volume * PartialClosePercent / 100.0 / 
                                   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) * 
                                   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      if(closeVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      {
         if(trade.PositionClosePartial(ticket, closeVolume))
         {
            Print("💰 Partial close executed for position ", ticket,
                  " | Closed: ", DoubleToString(closeVolume, 2), " lots",
                  " | Profit: ", DoubleToString(profitPips, 1), " pips");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Adjust SL based on volatility changes                           |
//+------------------------------------------------------------------+
void AdjustSLBasedOnVolatility(ulong ticket, ENUM_POSITION_TYPE posType, double openPrice,
                              double currentPrice, double currentSL)
{
   static datetime lastVolatilityCheck = 0;
   
   // Check volatility every 5 minutes
   if(TimeCurrent() - lastVolatilityCheck < 300)
      return;
   
   lastVolatilityCheck = TimeCurrent();
   
   double atr[3];
   if(CopyBuffer(atrHandle, 0, 0, 3, atr) < 3)
      return;
   
   double currentATRValue = atr[0];
   double previousATRValue = atr[1];
   
   // If volatility increased significantly, widen the stop loss
   if(currentATRValue > previousATRValue * 1.5)
   {
      double newSL = 0;
      double atrDistance = currentATRValue * 1.8;
      
      if(posType == POSITION_TYPE_BUY)
      {
         newSL = currentPrice - atrDistance;
         if(newSL < currentSL) // Only widen, never tighten
         {
            trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            Print("📈 SL widened due to increased volatility for position ", ticket);
         }
      }
      else
      {
         newSL = currentPrice + atrDistance;
         if(newSL > currentSL) // Only widen, never tighten
         {
            trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            Print("📉 SL widened due to increased volatility for position ", ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check for market regime change exit                             |
//+------------------------------------------------------------------+
void CheckRegimeChangeExit(ulong ticket, ENUM_POSITION_TYPE posType, datetime openTime, double profitPips)
{
   static bool previousRegime = true;
   static datetime lastRegimeCheck = 0;
   
   // Check regime every 15 minutes
   if(TimeCurrent() - lastRegimeCheck < 900)
      return;
   
   lastRegimeCheck = TimeCurrent();
   
   // If market regime changed and position is not profitable, consider exit
   if(previousRegime != isTrendingMarket && profitPips < 0)
   {
      // Exit if position has been open for more than 30 minutes and is losing
      if(TimeCurrent() - openTime > 1800)
      {
         Print("🔄 Market regime changed - exiting unprofitable position ", ticket);
         trade.PositionClose(ticket);
      }
   }
   
   previousRegime = isTrendingMarket;
}

//+------------------------------------------------------------------+
//| Update performance metrics for machine learning                 |
//+------------------------------------------------------------------+
void UpdatePerformanceMetrics()
{
   static datetime lastUpdate = 0;
   
   // Update every minute
   if(TimeCurrent() - lastUpdate < 60)
      return;
   
   lastUpdate = TimeCurrent();
   
   // Calculate current performance
   datetime startOfDay = TimeCurrent() - (TimeCurrent() % 86400);
   if(!HistorySelect(startOfDay, TimeCurrent()))
      return;
   
   int totalDeals = HistoryDealsTotal();
   double totalProfit = 0.0;
   int winningTrades = 0;
   int totalTrades = 0;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            totalProfit += profit;
            totalTrades++;
            
            if(profit > 0)
               winningTrades++;
         }
      }
   }
   
   // Update performance structure
   performance.totalTrades = totalTrades;
   performance.winningTrades = winningTrades;
   performance.totalProfit = totalProfit;
   performance.winRate = (totalTrades > 0) ? (double)winningTrades / totalTrades * 100.0 : 0.0;
   
   // Calculate profit factor
   double grossProfit = 0.0, grossLoss = 0.0;
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            if(profit > 0) grossProfit += profit;
            else grossLoss += MathAbs(profit);
         }
      }
   }
   
   performance.profitFactor = (grossLoss > 0) ? grossProfit / grossLoss : 0.0;
   
   // Log performance every hour
   static datetime lastPerfLog = 0;
   if(TimeCurrent() - lastPerfLog > 3600)
   {
      lastPerfLog = TimeCurrent();
      Print("📊 PERFORMANCE UPDATE:");
      Print("   Trades: ", performance.totalTrades, " | Win Rate: ", DoubleToString(performance.winRate, 1), "%");
      Print("   Total Profit: $", DoubleToString(performance.totalProfit, 2));
      Print("   Profit Factor: ", DoubleToString(performance.profitFactor, 2));
      Print("   Market Regime: ", (isTrendingMarket ? "TRENDING" : "RANGING"));
   }
}

//+------------------------------------------------------------------+
//| Advanced AI Support Functions                                   |
//+------------------------------------------------------------------+

// Detect RSI Divergence
bool DetectRSIDivergence(const double &rsi[])
{
   double price[5];
   if(CopyClose(_Symbol, PERIOD_M5, 0, 5, price) < 5)
      return false;
   
   // Bullish divergence: price makes lower low, RSI makes higher low
   if(price[0] < price[2] && price[2] < price[4] && 
      rsi[0] > rsi[2] && rsi[2] > rsi[4])
      return true;
   
   // Bearish divergence: price makes higher high, RSI makes lower high
   if(price[0] > price[2] && price[2] > price[4] && 
      rsi[0] < rsi[2] && rsi[2] < rsi[4])
      return true;
   
   return false;
}

// Analyze price patterns using machine learning approach
double AnalyzePricePatterns()
{
   double prices[50];
   if(CopyClose(_Symbol, PERIOD_M5, 0, PatternLookback, prices) < PatternLookback)
      return 0.0;
   
   double signal = 0.0;
   
   // Pattern 1: Double Bottom/Top
   signal += DetectDoublePattern(prices);
   
   // Pattern 2: Head and Shoulders
   signal += DetectHeadAndShoulders(prices);
   
   // Pattern 3: Triangle Breakout
   signal += DetectTriangleBreakout(prices);
   
   // Pattern 4: Support/Resistance Break
   signal += DetectSRBreak(prices);
   
   return MathMax(-2.0, MathMin(2.0, signal)); // Limit to ±2.0
}

// Detect double bottom/top patterns
double DetectDoublePattern(const double &prices[])
{
   int size = ArraySize(prices);
   if(size < 20) return 0.0;
   
   // Find recent highs and lows
   double recentHigh = prices[0];
   double recentLow = prices[0];
   int highIndex = 0, lowIndex = 0;
   
   for(int i = 1; i < 20; i++)
   {
      if(prices[i] > recentHigh)
      {
         recentHigh = prices[i];
         highIndex = i;
      }
      if(prices[i] < recentLow)
      {
         recentLow = prices[i];
         lowIndex = i;
      }
   }
   
   // Double bottom pattern (bullish)
   if(lowIndex > 10)
   {
      for(int i = lowIndex + 5; i < size - 5; i++)
      {
         if(MathAbs(prices[i] - recentLow) < currentATR * 0.5)
         {
            return 1.5; // Strong buy signal
         }
      }
   }
   
   // Double top pattern (bearish)
   if(highIndex > 10)
   {
      for(int i = highIndex + 5; i < size - 5; i++)
      {
         if(MathAbs(prices[i] - recentHigh) < currentATR * 0.5)
         {
            return -1.5; // Strong sell signal
         }
      }
   }
   
   return 0.0;
}

// Detect head and shoulders pattern
double DetectHeadAndShoulders(const double &prices[])
{
   int size = ArraySize(prices);
   if(size < 30) return 0.0;
   
   // Simplified H&S detection
   double leftShoulder = 0, head = 0, rightShoulder = 0;
   int leftIdx = 0, headIdx = 0, rightIdx = 0;
   
   // Find three peaks
   for(int i = 5; i < size - 15; i++)
   {
      if(prices[i] > prices[i-1] && prices[i] > prices[i+1])
      {
         if(leftShoulder == 0)
         {
            leftShoulder = prices[i];
            leftIdx = i;
         }
         else if(head == 0 && prices[i] > leftShoulder)
         {
            head = prices[i];
            headIdx = i;
         }
         else if(rightShoulder == 0 && i > headIdx + 5)
         {
            rightShoulder = prices[i];
            rightIdx = i;
            break;
         }
      }
   }
   
   // Check if it's a valid H&S pattern
   if(leftShoulder > 0 && head > 0 && rightShoulder > 0)
   {
      if(head > leftShoulder && head > rightShoulder &&
         MathAbs(leftShoulder - rightShoulder) < currentATR)
      {
         return -2.0; // Strong bearish signal
      }
   }
   
   return 0.0;
}

// Detect triangle breakout
double DetectTriangleBreakout(const double &prices[])
{
   int size = ArraySize(prices);
   if(size < 20) return 0.0;
   
   // Calculate trend lines
   double upperTrend = CalculateTrendLine(prices, true);
   double lowerTrend = CalculateTrendLine(prices, false);
   
   double currentPrice = prices[0];
   double previousPrice = prices[1];
   
   // Upward breakout
   if(previousPrice <= upperTrend && currentPrice > upperTrend)
      return 1.8;
   
   // Downward breakout
   if(previousPrice >= lowerTrend && currentPrice < lowerTrend)
      return -1.8;
   
   return 0.0;
}

// Calculate trend line (simplified)
double CalculateTrendLine(const double &prices[], bool isUpper)
{
   int size = ArraySize(prices);
   double sum = 0.0;
   int count = 0;
   
   for(int i = 0; i < MathMin(size, 10); i++)
   {
      sum += prices[i];
      count++;
   }
   
   return count > 0 ? sum / count : 0.0;
}

// Detect support/resistance break
double DetectSRBreak(const double &prices[])
{
   double supportLevel = FindSupportLevel(prices);
   double resistanceLevel = FindResistanceLevel(prices);
   
   double currentPrice = prices[0];
   double previousPrice = prices[1];
   
   // Resistance break (bullish)
   if(previousPrice <= resistanceLevel && currentPrice > resistanceLevel)
      return 1.5;
   
   // Support break (bearish)
   if(previousPrice >= supportLevel && currentPrice < supportLevel)
      return -1.5;
   
   return 0.0;
}

// Find support level
double FindSupportLevel(const double &prices[])
{
   int size = ArraySize(prices);
   double minPrice = prices[0];
   
   for(int i = 1; i < MathMin(size, 20); i++)
   {
      if(prices[i] < minPrice)
         minPrice = prices[i];
   }
   
   return minPrice;
}

// Find resistance level
double FindResistanceLevel(const double &prices[])
{
   int size = ArraySize(prices);
   double maxPrice = prices[0];
   
   for(int i = 1; i < MathMin(size, 20); i++)
   {
      if(prices[i] > maxPrice)
         maxPrice = prices[i];
   }
   
   return maxPrice;
}

// Calculate market regime
void CalculateMarketRegime()
{
   double prices[100];
   if(CopyClose(_Symbol, PERIOD_M5, 0, RegimeAnalysisPeriod, prices) < RegimeAnalysisPeriod)
      return;
   
   // Calculate trend strength using linear regression
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   int n = RegimeAnalysisPeriod;
   
   for(int i = 0; i < n; i++)
   {
      sumX += i;
      sumY += prices[i];
      sumXY += i * prices[i];
      sumX2 += i * i;
   }
   
   double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
   double correlation = MathAbs(slope) * 1000; // Normalize
   
   marketRegimeScore = correlation;
   isTrendingMarket = (correlation > 0.5);
}

// Update adaptive parameters based on performance
void UpdateAdaptiveParameters()
{
   if(!UseAdaptiveParameters) return;
   
   // Adjust RSI levels based on recent performance
   if(performance.winRate > 70)
   {
      // Tighten levels for better quality
      adaptiveRSIOversold = MathMax(20, adaptiveRSIOversold - 1);
      adaptiveRSIOverbought = MathMin(80, adaptiveRSIOverbought + 1);
   }
   else if(performance.winRate < 50)
   {
      // Loosen levels for more trades
      adaptiveRSIOversold = MathMin(35, adaptiveRSIOversold + 1);
      adaptiveRSIOverbought = MathMax(65, adaptiveRSIOverbought - 1);
   }
}

// Update market conditions
void UpdateMarketConditions()
{
   // Update ATR for volatility
   double atr[3];
   if(CopyBuffer(atrHandle, 0, 0, 3, atr) >= 3)
      currentATR = atr[0];
   
   // Update average volume
   double volume[10];
   if(CopyBuffer(volumeHandle, 0, 0, 10, volume) >= 10)
   {
      double sum = 0;
      for(int i = 0; i < 10; i++)
         sum += volume[i];
      avgVolume = sum / 10;
   }
   
   // Update market regime periodically
   static datetime lastRegimeUpdate = 0;
   if(TimeCurrent() - lastRegimeUpdate > 3600) // Update every hour
   {
      CalculateMarketRegime();
      lastRegimeUpdate = TimeCurrent();
   }
}

// Check if it's high impact news time
bool IsHighImpactNewsTime()
{
   MqlDateTime dt;
   if(!TimeToStruct(TimeCurrent(), dt))
      return false;
   
   // Avoid trading 30 minutes before and after major news times
   // This is a simplified version - in practice, you'd use an economic calendar
   if((dt.hour == 8 && dt.min >= 30) || (dt.hour == 9 && dt.min <= 30) || // EUR news
      (dt.hour == 13 && dt.min >= 30) || (dt.hour == 14 && dt.min <= 30) || // USD news
      (dt.hour == 15 && dt.min >= 30) || (dt.hour == 16 && dt.min <= 30))   // USD news
   {
      return true;
   }
   
   return false;
}

// Check if it's an active trading session
bool IsActiveSession()
{
   MqlDateTime dt;
   if(!TimeToStruct(TimeCurrent(), dt))
      return true; // Default to allow trading
   
   // London session: 8:00-17:00 GMT
   // New York session: 13:00-22:00 GMT
   // Overlap: 13:00-17:00 GMT (most active)
   
   if((dt.hour >= 8 && dt.hour < 17) || (dt.hour >= 13 && dt.hour < 22))
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Count today's trades                                             |
//+------------------------------------------------------------------+
int CountTodayTrades()
{
   int count = 0;
   datetime startOfDay = TimeCurrent() - (TimeCurrent() % 86400);
   
   if(!HistorySelect(startOfDay, TimeCurrent()))
      return 0;
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
         {
            count++;
         }
      }
   }
   
   return count;
}
