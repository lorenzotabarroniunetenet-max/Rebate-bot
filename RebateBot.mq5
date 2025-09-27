//+------------------------------------------------------------------+
//|                                                    RebateBot.mq5 |
//|                                  Copyright 2024, Lorenzo Tabarroni |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lorenzo Tabarroni"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>

input double LotSize = 0.01;              // Lot size per trade
input int MaxTradesPerDay = 180;          // Maximum trades per day
input int MinutesBetwenTrades = 8;        // Minutes between trades
input double MaxSpreadPips = 0.8;         // Maximum spread in pips
input double StopLossPips = 8.0;          // Stop loss in pips
input double TakeProfitPips = 12.0;       // Take profit in pips
input int MagicNumber = 12345;            // Magic number for trades
input string InpTradingSymbol = "EURUSD"; // Trading symbol (renamed to avoid conflicts)
input int RSI_Period = 14;                // RSI period for trend analysis
input int MA_Fast = 10;                   // Fast moving average period
input int MA_Slow = 20;                   // Slow moving average period
input double RSI_Oversold = 30;           // RSI oversold level
input double RSI_Overbought = 70;         // RSI overbought level
input bool UseBreakoutStrategy = true;    // Use breakout strategy
input int BreakoutPeriod = 20;            // Period for breakout calculation
input int BB_Period = 20;                 // Bollinger Bands period
input double BB_Deviation = 2.0;          // Bollinger Bands deviation
input int MACD_Fast = 12;                 // MACD fast EMA
input int MACD_Slow = 26;                 // MACD slow EMA
input int MACD_Signal = 9;                // MACD signal line
input bool UseVolumeFilter = true;        // Use volume analysis
input double MinVolumeMultiplier = 1.2;   // Minimum volume vs average
input bool UseSupportResistance = true;   // Use S/R levels
input int SR_LookbackPeriod = 50;         // S/R lookback period
input double RiskPerTrade = 1.0;          // Risk per trade in %
input bool UseTrailingStop = true;        // Use trailing stop
input double TrailingStopPips = 5.0;      // Trailing stop distance

datetime lastTradeTime = 0;
int tradesCountToday = 0;
datetime currentDay = 0;
int rsiHandle;
int maFastHandle;
int maSlowHandle;
int bbHandle;
int macdHandle;
int volumeHandle;
double rsiBuffer[];
double maFastBuffer[];
double maSlowBuffer[];
double bbUpperBuffer[];
double bbLowerBuffer[];
double bbMiddleBuffer[];
double macdMainBuffer[];
double macdSignalBuffer[];
double volumeBuffer[];
double supportLevels[];
double resistanceLevels[];
int supportResistanceCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("RebateBot v2.0 initialized - Profitable Volume Strategy");
   Print("Max trades per day: ", MaxTradesPerDay);
   Print("Lot size: ", LotSize);
   
   // Initialize indicators
   rsiHandle = iRSI(_Symbol, PERIOD_M5, RSI_Period, PRICE_CLOSE);
   maFastHandle = iMA(_Symbol, PERIOD_M5, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   maSlowHandle = iMA(_Symbol, PERIOD_M5, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   bbHandle = iBands(_Symbol, PERIOD_M5, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   macdHandle = iMACD(_Symbol, PERIOD_M5, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   volumeHandle = iVolumes(_Symbol, PERIOD_M5, VOLUME_TICK);
   
   if(rsiHandle == INVALID_HANDLE || maFastHandle == INVALID_HANDLE || maSlowHandle == INVALID_HANDLE ||
      bbHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE || volumeHandle == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return(INIT_FAILED);
   }
   
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(maFastBuffer, true);
   ArraySetAsSeries(maSlowBuffer, true);
   ArraySetAsSeries(bbUpperBuffer, true);
   ArraySetAsSeries(bbLowerBuffer, true);
   ArraySetAsSeries(bbMiddleBuffer, true);
   ArraySetAsSeries(macdMainBuffer, true);
   ArraySetAsSeries(macdSignalBuffer, true);
   ArraySetAsSeries(volumeBuffer, true);
   ArrayResize(supportLevels, 10);
   ArrayResize(resistanceLevels, 10);
   
   currentDay = TimeCurrent() - (TimeCurrent() % 86400);
   tradesCountToday = CountTodayTrades();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("ProfitableRebateBot stopped. Trades today: ", tradesCountToday);
   
   // Release indicator handles
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(maFastHandle != INVALID_HANDLE)
      IndicatorRelease(maFastHandle);
   if(maSlowHandle != INVALID_HANDLE)
      IndicatorRelease(maSlowHandle);
   if(bbHandle != INVALID_HANDLE)
      IndicatorRelease(bbHandle);
   if(macdHandle != INVALID_HANDLE)
      IndicatorRelease(macdHandle);
   if(volumeHandle != INVALID_HANDLE)
      IndicatorRelease(volumeHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if it's a new day
   datetime newDay = TimeCurrent() - (TimeCurrent() % 86400);
   if(newDay != currentDay)
   {
      currentDay = newDay;
      tradesCountToday = 0;
      Print("New day started. Trade counter reset.");
   }
   
   // Check if we can trade
   if(!CanTrade())
      return;
   
   // Get current spread
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > MaxSpreadPips * 10) // Convert to points
   {
      return; // Skip if spread too high
   }
   
   // Update indicators
   if(!UpdateIndicators())
      return;
   
   // Update support/resistance levels
   if(UseSupportResistance)
      UpdateSupportResistance();
   
   // Execute advanced profitable strategy
   ExecuteAdvancedStrategy();
}

//+------------------------------------------------------------------+
//| Check if we can trade                                            |
//+------------------------------------------------------------------+
bool CanTrade()
{
   // Check daily trade limit
   if(tradesCountToday >= MaxTradesPerDay)
   {
      return false;
   }
   
   // Check time between trades
   if(TimeCurrent() - lastTradeTime < MinutesBetwenTrades * 60)
   {
      return false;
   }
   
   // Avoid trading during high impact news (simplified check)
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   if(!TimeToStruct(currentTime, timeStruct))
      return false;
   int hour = timeStruct.hour;
   
   if(hour >= 8 && hour <= 10) // London open volatility
   {
      if(currentTime - lastTradeTime < 15 * 60) // 15 min spacing during volatile hours
         return false;
   }
   
   // Check market hours (avoid weekends)
   if(timeStruct.day_of_week == 0 || timeStruct.day_of_week == 6)
   {
      return false;
   }
   
   // Check if we have open positions (limit to 1 at a time)
   if(PositionsTotal() > 0)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Update indicator values                                          |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) < 3)
      return false;
   if(CopyBuffer(maFastHandle, 0, 0, 3, maFastBuffer) < 3)
      return false;
   if(CopyBuffer(maSlowHandle, 0, 0, 3, maSlowBuffer) < 3)
      return false;
   if(CopyBuffer(bbHandle, 1, 0, 3, bbUpperBuffer) < 3)
      return false;
   if(CopyBuffer(bbHandle, 2, 0, 3, bbLowerBuffer) < 3)
      return false;
   if(CopyBuffer(bbHandle, 0, 0, 3, bbMiddleBuffer) < 3)
      return false;
   if(CopyBuffer(macdHandle, 0, 0, 3, macdMainBuffer) < 3)
      return false;
   if(CopyBuffer(macdHandle, 1, 0, 3, macdSignalBuffer) < 3)
      return false;
   if(CopyBuffer(volumeHandle, 0, 0, 10, volumeBuffer) < 10)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Execute advanced profitable strategy                             |
//+------------------------------------------------------------------+
void ExecuteAdvancedStrategy()
{
   // Get comprehensive signal from multiple advanced strategies
   int signal = GetAdvancedTradingSignal();
   
   if(signal == 0)
      return; // No signal
   
   // Additional filters for high-probability trades
   if(!PassesQualityFilters(signal))
      return;
   
   ENUM_ORDER_TYPE orderType = (signal > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   ExecuteAdvancedTrade(orderType, signal);
}

//+------------------------------------------------------------------+
//| Get advanced trading signal from multiple strategies             |
//+------------------------------------------------------------------+
int GetAdvancedTradingSignal()
{
   int signal = 0;
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
   
   // Strategy 1: Enhanced RSI with divergence detection
   if(rsiBuffer[0] < RSI_Oversold && rsiBuffer[1] >= RSI_Oversold)
   {
      if(DetectBullishDivergence())
         signal += 3; // Very strong buy
      else
         signal += 2; // Strong buy
   }
   else if(rsiBuffer[0] > RSI_Overbought && rsiBuffer[1] <= RSI_Overbought)
   {
      if(DetectBearishDivergence())
         signal -= 3; // Very strong sell
      else
         signal -= 2; // Strong sell
   }
   
   // Strategy 2: MACD momentum confirmation
   if(macdMainBuffer[0] > macdSignalBuffer[0] && macdMainBuffer[1] <= macdSignalBuffer[1])
   {
      if(macdMainBuffer[0] > 0)
         signal += 2; // Strong bullish momentum
      else
         signal += 1; // Weak bullish momentum
   }
   else if(macdMainBuffer[0] < macdSignalBuffer[0] && macdMainBuffer[1] >= macdSignalBuffer[1])
   {
      if(macdMainBuffer[0] < 0)
         signal -= 2; // Strong bearish momentum
      else
         signal -= 1; // Weak bearish momentum
   }
   
   // Strategy 3: Bollinger Bands squeeze and expansion
   double bbWidth = bbUpperBuffer[0] - bbLowerBuffer[0];
   double bbWidthPrev = bbUpperBuffer[1] - bbLowerBuffer[1];
   
   if(currentPrice <= bbLowerBuffer[0] && currentPrice > bbLowerBuffer[1])
   {
      signal += 2; // Bounce from lower band
   }
   else if(currentPrice >= bbUpperBuffer[0] && currentPrice < bbUpperBuffer[1])
   {
      signal -= 2; // Rejection from upper band
   }
   
   // Strategy 4: Volume confirmation
   if(UseVolumeFilter)
   {
      double avgVolume = CalculateAverageVolume();
      if(volumeBuffer[0] > avgVolume * MinVolumeMultiplier)
      {
         if(signal > 0) signal += 1; // Volume confirms bullish signal
         if(signal < 0) signal -= 1; // Volume confirms bearish signal
      }
   }
   
   // Strategy 5: Support/Resistance levels
   if(UseSupportResistance)
   {
      if(IsNearSupport(currentPrice))
         signal += 1; // Near support, potential bounce
      else if(IsNearResistance(currentPrice))
         signal -= 1; // Near resistance, potential rejection
   }
   
   // Strategy 6: Multi-timeframe confirmation
   int htfSignal = GetHigherTimeframeSignal();
   if(htfSignal != 0)
   {
      if((signal > 0 && htfSignal > 0) || (signal < 0 && htfSignal < 0))
         signal += (htfSignal > 0) ? 1 : -1; // HTF confirmation
   }
   
   // Only trade if signal is strong enough (absolute value >= 3)
   if(MathAbs(signal) >= 3)
      return signal;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Detect bullish divergence                                        |
//+------------------------------------------------------------------+
bool DetectBullishDivergence()
{
   // Simple divergence: price makes lower low, RSI makes higher low
   double currentLow = iLow(_Symbol, PERIOD_M5, 0);
   double prevLow = iLow(_Symbol, PERIOD_M5, 5);
   
   if(currentLow < prevLow && rsiBuffer[0] > rsiBuffer[5])
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect bearish divergence                                        |
//+------------------------------------------------------------------+
bool DetectBearishDivergence()
{
   // Simple divergence: price makes higher high, RSI makes lower high
   double currentHigh = iHigh(_Symbol, PERIOD_M5, 0);
   double prevHigh = iHigh(_Symbol, PERIOD_M5, 5);
   
   if(currentHigh > prevHigh && rsiBuffer[0] < rsiBuffer[5])
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate average volume                                         |
//+------------------------------------------------------------------+
double CalculateAverageVolume()
{
   double sum = 0;
   for(int i = 1; i < 10; i++)
   {
      sum += volumeBuffer[i];
   }
   return sum / 9;
}

//+------------------------------------------------------------------+
//| Update support and resistance levels                            |
//+------------------------------------------------------------------+
void UpdateSupportResistance()
{
   supportResistanceCount = 0;
   
   // Find pivot highs and lows
   for(int i = 2; i < SR_LookbackPeriod - 2; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      
      // Check for pivot high (resistance)
      if(high > iHigh(_Symbol, PERIOD_M5, i-1) && high > iHigh(_Symbol, PERIOD_M5, i-2) &&
         high > iHigh(_Symbol, PERIOD_M5, i+1) && high > iHigh(_Symbol, PERIOD_M5, i+2))
      {
         if(supportResistanceCount < 5)
         {
            resistanceLevels[supportResistanceCount] = high;
            supportResistanceCount++;
         }
      }
      
      // Check for pivot low (support)
      if(low < iLow(_Symbol, PERIOD_M5, i-1) && low < iLow(_Symbol, PERIOD_M5, i-2) &&
         low < iLow(_Symbol, PERIOD_M5, i+1) && low < iLow(_Symbol, PERIOD_M5, i+2))
      {
         if(supportResistanceCount < 5)
         {
            supportLevels[supportResistanceCount] = low;
            supportResistanceCount++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if price is near support                                  |
//+------------------------------------------------------------------+
bool IsNearSupport(double price)
{
   double tolerance = 10 * _Point; // 1 pip tolerance
   
   for(int i = 0; i < supportResistanceCount; i++)
   {
      if(MathAbs(price - supportLevels[i]) <= tolerance)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if price is near resistance                               |
//+------------------------------------------------------------------+
bool IsNearResistance(double price)
{
   double tolerance = 10 * _Point; // 1 pip tolerance
   
   for(int i = 0; i < supportResistanceCount; i++)
   {
      if(MathAbs(price - resistanceLevels[i]) <= tolerance)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get higher timeframe signal                                     |
//+------------------------------------------------------------------+
int GetHigherTimeframeSignal()
{
   // Get H1 trend direction using handles
   int h1_ma_fast_handle = iMA(_Symbol, PERIOD_H1, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   int h1_ma_slow_handle = iMA(_Symbol, PERIOD_H1, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   
   if(h1_ma_fast_handle == INVALID_HANDLE || h1_ma_slow_handle == INVALID_HANDLE)
      return 0;
   
   double h1_fast_buffer[1];
   double h1_slow_buffer[1];
   
   if(CopyBuffer(h1_ma_fast_handle, 0, 0, 1, h1_fast_buffer) < 1 ||
      CopyBuffer(h1_ma_slow_handle, 0, 0, 1, h1_slow_buffer) < 1)
   {
      IndicatorRelease(h1_ma_fast_handle);
      IndicatorRelease(h1_ma_slow_handle);
      return 0;
   }
   
   IndicatorRelease(h1_ma_fast_handle);
   IndicatorRelease(h1_ma_slow_handle);
   
   if(h1_fast_buffer[0] > h1_slow_buffer[0])
      return 1; // Bullish HTF trend
   else if(h1_fast_buffer[0] < h1_slow_buffer[0])
      return -1; // Bearish HTF trend
   
   return 0;
}

//+------------------------------------------------------------------+
//| Check if trade passes quality filters                           |
//+------------------------------------------------------------------+
bool PassesQualityFilters(int signal)
{
   // Filter 1: Avoid trading during low liquidity hours
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   if(!TimeToStruct(currentTime, timeStruct))
      return false;
   int hour = timeStruct.hour;
   
   if(hour >= 22 || hour <= 2) // Avoid Asian session low liquidity
      return false;
   
   // Filter 2: Check volatility is not too high
   double atr = CalculateATR();
   double avgATR = CalculateAverageATR();
   if(atr > avgATR * 2.0) // Avoid extremely volatile conditions
      return false;
   
   // Filter 3: Ensure we're not in a ranging market
   double bbWidth = bbUpperBuffer[0] - bbLowerBuffer[0];
   double avgBBWidth = CalculateAverageBBWidth();
   if(bbWidth < avgBBWidth * 0.5) // Avoid tight ranges
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate average ATR                                           |
//+------------------------------------------------------------------+
double CalculateAverageATR()
{
   double sum = 0;
   for(int i = 1; i <= 20; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      double prevClose = iClose(_Symbol, PERIOD_M5, i + 1);
      
      double tr1 = high - low;
      double tr2 = MathAbs(high - prevClose);
      double tr3 = MathAbs(low - prevClose);
      
      sum += MathMax(tr1, MathMax(tr2, tr3));
   }
   return sum / 20;
}

//+------------------------------------------------------------------+
//| Calculate average Bollinger Bands width                         |
//+------------------------------------------------------------------+
double CalculateAverageBBWidth()
{
   double sum = 0;
   double upperBuffer[21];
   double lowerBuffer[21];
   
   if(CopyBuffer(bbHandle, 1, 0, 21, upperBuffer) < 21 ||
      CopyBuffer(bbHandle, 2, 0, 21, lowerBuffer) < 21)
      return (bbUpperBuffer[0] - bbLowerBuffer[0]); // Fallback to current width
   
   for(int i = 1; i <= 20; i++)
   {
      sum += (upperBuffer[i] - lowerBuffer[i]);
   }
   return sum / 20;
}

//+------------------------------------------------------------------+
//| Execute advanced trade with dynamic risk management             |
//+------------------------------------------------------------------+
void ExecuteAdvancedTrade(ENUM_ORDER_TYPE orderType, int signalStrength)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp;
   
   // Dynamic SL/TP based on volatility
   double atr = CalculateATR();
   double dynamicSL = MathMax(StopLossPips * _Point * 10, atr * 1.5);
   double dynamicTP = dynamicSL * 1.5; // 1.5:1 risk reward ratio
   
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - dynamicSL;
      tp = price + dynamicTP;
   }
   else
   {
      sl = price + dynamicSL;
      tp = price - dynamicTP;
   }
   
   // Prepare trade request
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.magic = MagicNumber;
   request.comment = "ProfitableRebateBot";
   
   // Send trade
   bool orderResult = OrderSend(request, result);
   if(orderResult)
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         tradesCountToday++;
         lastTradeTime = TimeCurrent();
         
         Print("Profitable trade executed: ", EnumToString(orderType), 
               " Lot: ", LotSize, 
               " Price: ", price,
               " SL: ", sl,
               " TP: ", tp,
               " Trades today: ", tradesCountToday);
      }
      else
      {
         Print("Trade failed: ", result.retcode, " - ", result.comment);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Average True Range for volatility                     |
//+------------------------------------------------------------------+
double CalculateATR()
{
   double atr = 0;
   int period = 14;
   
   for(int i = 1; i <= period; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      double prevClose = iClose(_Symbol, PERIOD_M5, i + 1);
      
      double tr1 = high - low;
      double tr2 = MathAbs(high - prevClose);
      double tr3 = MathAbs(low - prevClose);
      
      atr += MathMax(tr1, MathMax(tr2, tr3));
   }
   
   return atr / period;
}

//+------------------------------------------------------------------+
//| Count today's trades                                             |
//+------------------------------------------------------------------+
int CountTodayTrades()
{
   int count = 0;
   datetime startOfDay = TimeCurrent() - (TimeCurrent() % 86400);
   
   // Count from history
   HistorySelect(startOfDay, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber)
      {
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Advanced position management
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            
            // Implement trailing stop
            if(UseTrailingStop)
            {
               double trailDistance = TrailingStopPips * _Point * 10;
               double newSL = 0;
               
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  newSL = currentPrice - trailDistance;
                  if(newSL > currentSL && newSL > openPrice)
                  {
                     ModifyPosition(ticket, newSL, currentTP);
                  }
               }
               else
               {
                  newSL = currentPrice + trailDistance;
                  if(newSL < currentSL && newSL < openPrice)
                  {
                     ModifyPosition(ticket, newSL, currentTP);
                  }
               }
            }
            
            // Partial profit taking for strong moves
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            
            if(profit > 50 && volume >= LotSize) // If profit > $50 and we can split
            {
               // Close half position at 2:1 R/R
               double closeVolume = volume / 2;
               ClosePartialPosition(ticket, closeVolume);
            }
            
            // Emergency close for old positions
            if(TimeCurrent() - openTime > 3600) // 1 hour max
            {
               ClosePosition(ticket);
            }
            
            // Close losing positions during high volatility
            double atr = CalculateATR();
            double avgATR = CalculateAverageATR();
            if(atr > avgATR * 2.5 && profit < -20)
            {
               ClosePosition(ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modify position SL/TP                                           |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double sl, double tp)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = sl;
   request.tp = tp;
   
   bool modifyResult = OrderSend(request, result);
   if(modifyResult)
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         Print("Position modified: Ticket=", ticket, " New SL=", sl);
      }
   }
}

//+------------------------------------------------------------------+
//| Close partial position                                          |
//+------------------------------------------------------------------+
void ClosePartialPosition(ulong ticket, double volume)
{
   if(!PositionSelectByTicket(ticket))
      return;
      
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.volume = volume;
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.magic = MagicNumber;
   request.comment = "Partial Close";
   
   bool closeResult = OrderSend(request, result);
   if(!closeResult)
   {
      Print("Failed to close partial position: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Close position completely                                       |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return;
      
   MqlTradeRequest request;
   MqlTradeResult result;
   
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = PositionGetString(POSITION_SYMBOL);
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.magic = MagicNumber;
   request.comment = "Force Close";
   
   bool closeResult = OrderSend(request, result);
   if(!closeResult)
   {
      Print("Failed to close position: ", result.retcode);
   }
}
