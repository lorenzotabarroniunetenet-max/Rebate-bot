//+------------------------------------------------------------------+
//|                                                    RebateBot.mq5 |
//|                                  Copyright 2024, Lorenzo Tabarroni |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lorenzo Tabarroni"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>

input double LotSize = 0.01;
input int MaxTradesPerDay = 180;
input int MinutesBetwenTrades = 8;
input double MaxSpreadPips = 0.8;
input double StopLossPips = 8.0;
input double TakeProfitPips = 12.0;
input int MagicNumber = 12345;
input string TradingPair = "EURUSD";
input int RSI_Period = 14;
input int MA_Fast = 10;
input int MA_Slow = 20;
input double RSI_Oversold = 30;
input double RSI_Overbought = 70;
input bool UseBreakoutStrategy = true;
input int BreakoutPeriod = 20;
input int BB_Period = 20;
input double BB_Deviation = 2.0;
input int MACD_Fast = 12;
input int MACD_Slow = 26;
input int MACD_Signal = 9;
input bool UseVolumeFilter = true;
input double MinVolumeMultiplier = 1.2;
input bool UseSupportResistance = true;
input int SR_LookbackPeriod = 50;
input double RiskPerTrade = 1.0;
input bool UseTrailingStop = true;
input double TrailingStopPips = 5.0;

int rsiHandle, maFastHandle, maSlowHandle, bbHandle, macdHandle, volumeHandle;
double rsiBuffer[], maFastBuffer[], maSlowBuffer[], bbUpperBuffer[], bbMiddleBuffer[], bbLowerBuffer[];
double macdMainBuffer[], macdSignalBuffer[], volumeBuffer[];
double supportResistanceLevels[10];
int supportResistanceCount = 0;
int tradesCountToday = 0;
datetime lastTradeTime = 0;

int OnInit()
{
   Print("RebateBot EA initialized");
   Print("Lot size: ", LotSize);
   
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
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(maFastBuffer, true);
   ArraySetAsSeries(maSlowBuffer, true);
   ArraySetAsSeries(bbUpperBuffer, true);
   ArraySetAsSeries(bbMiddleBuffer, true);
   ArraySetAsSeries(bbLowerBuffer, true);
   ArraySetAsSeries(macdMainBuffer, true);
   ArraySetAsSeries(macdSignalBuffer, true);
   ArraySetAsSeries(volumeBuffer, true);
   
   tradesCountToday = CountTodayTrades();
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   IndicatorRelease(rsiHandle);
   IndicatorRelease(maFastHandle);
   IndicatorRelease(maSlowHandle);
   IndicatorRelease(bbHandle);
   IndicatorRelease(macdHandle);
   IndicatorRelease(volumeHandle);
}

void OnTick()
{
   if(!UpdateIndicators())
      return;
   
   if(!CanTrade())
      return;
   
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > MaxSpreadPips * 10)
   {
      return;
   }
   
   int signal = GetAdvancedTradingSignal();
   
   if(signal > 0 && PassesQualityFilters(signal))
   {
      ExecuteAdvancedTrade(ORDER_TYPE_BUY, signal);
   }
   else if(signal < 0 && PassesQualityFilters(signal))
   {
      ExecuteAdvancedTrade(ORDER_TYPE_SELL, MathAbs(signal));
   }
}

bool UpdateIndicators()
{
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) < 3 ||
      CopyBuffer(maFastHandle, 0, 0, 3, maFastBuffer) < 3 ||
      CopyBuffer(maSlowHandle, 0, 0, 3, maSlowBuffer) < 3 ||
      CopyBuffer(bbHandle, 1, 0, 3, bbUpperBuffer) < 3 ||
      CopyBuffer(bbHandle, 0, 0, 3, bbMiddleBuffer) < 3 ||
      CopyBuffer(bbHandle, 2, 0, 3, bbLowerBuffer) < 3 ||
      CopyBuffer(macdHandle, 0, 0, 3, macdMainBuffer) < 3 ||
      CopyBuffer(macdHandle, 1, 0, 3, macdSignalBuffer) < 3 ||
      CopyBuffer(volumeHandle, 0, 0, 3, volumeBuffer) < 3)
   {
      return false;
   }
   return true;
}

bool CanTrade()
{
   if(tradesCountToday >= MaxTradesPerDay)
   {
      return false;
   }
   
   if(TimeCurrent() - lastTradeTime < MinutesBetwenTrades * 60)
   {
      return false;
   }
   
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   if(!TimeToStruct(currentTime, timeStruct))
      return false;
   int hour = timeStruct.hour;
   
   if(hour >= 8 && hour <= 10)
   {
      if(currentTime - lastTradeTime < 15 * 60)
         return false;
   }
   
   if(timeStruct.day_of_week == 0 || timeStruct.day_of_week == 6)
   {
      return false;
   }
   
   return true;
}

int GetAdvancedTradingSignal()
{
   int signal = 0;
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
   
   if(rsiBuffer[0] < RSI_Oversold && rsiBuffer[1] >= RSI_Oversold)
   {
      signal += 1;
      if(DetectBullishDivergence())
         signal += 3;
   }
   
   if(rsiBuffer[0] > RSI_Overbought && rsiBuffer[1] <= RSI_Overbought)
   {
      signal -= 1;
      if(DetectBearishDivergence())
         signal -= 3;
   }
   
   if(maFastBuffer[0] > maSlowBuffer[0] && maFastBuffer[1] <= maSlowBuffer[1])
   {
      signal += 1;
   }
   else if(maFastBuffer[0] < maSlowBuffer[0] && maFastBuffer[1] >= maSlowBuffer[1])
   {
      signal -= 1;
   }
   
   if(macdMainBuffer[0] > macdSignalBuffer[0] && macdMainBuffer[1] <= macdSignalBuffer[1])
   {
      signal += 1;
   }
   else if(macdMainBuffer[0] < macdSignalBuffer[0] && macdMainBuffer[1] >= macdSignalBuffer[1])
   {
      signal -= 1;
   }
   
   if(currentPrice <= bbLowerBuffer[0])
   {
      signal += 1;
   }
   else if(currentPrice >= bbUpperBuffer[0])
   {
      signal -= 1;
   }
   
   if(UseVolumeFilter)
   {
      double avgVolume = (volumeBuffer[1] + volumeBuffer[2]) / 2;
      if(volumeBuffer[0] > avgVolume * MinVolumeMultiplier)
      {
         if(signal > 0) signal += 1;
         if(signal < 0) signal -= 1;
      }
   }
   
   if(UseSupportResistance)
   {
      UpdateSupportResistanceLevels();
      for(int i = 0; i < supportResistanceCount; i++)
      {
         if(MathAbs(currentPrice - supportResistanceLevels[i]) < 10 * _Point)
         {
            if(currentPrice < supportResistanceLevels[i])
               signal += 1;
            else
               signal -= 1;
         }
      }
   }
   
   int htfSignal = GetHigherTimeframeSignal();
   signal += htfSignal;
   
   return signal;
}

bool DetectBullishDivergence()
{
   double currentLow = iLow(_Symbol, PERIOD_M5, 0);
   double prevLow = iLow(_Symbol, PERIOD_M5, 5);
   
   if(currentLow < prevLow && rsiBuffer[0] > rsiBuffer[5])
      return true;
   
   return false;
}

bool DetectBearishDivergence()
{
   double currentHigh = iHigh(_Symbol, PERIOD_M5, 0);
   double prevHigh = iHigh(_Symbol, PERIOD_M5, 5);
   
   if(currentHigh > prevHigh && rsiBuffer[0] < rsiBuffer[5])
      return true;
   
   return false;
}

void UpdateSupportResistanceLevels()
{
   supportResistanceCount = 0;
   
   for(int i = 2; i < SR_LookbackPeriod - 2; i++)
   {
      double high = iHigh(_Symbol, PERIOD_M5, i);
      double low = iLow(_Symbol, PERIOD_M5, i);
      
      if(high > iHigh(_Symbol, PERIOD_M5, i-1) && high > iHigh(_Symbol, PERIOD_M5, i-2) &&
         high > iHigh(_Symbol, PERIOD_M5, i+1) && high > iHigh(_Symbol, PERIOD_M5, i+2))
      {
         if(supportResistanceCount < 5)
         {
            supportResistanceLevels[supportResistanceCount] = high;
            supportResistanceCount++;
         }
      }
      
      if(low < iLow(_Symbol, PERIOD_M5, i-1) && low < iLow(_Symbol, PERIOD_M5, i-2) &&
         low < iLow(_Symbol, PERIOD_M5, i+1) && low < iLow(_Symbol, PERIOD_M5, i+2))
      {
         if(supportResistanceCount < 5)
         {
            supportResistanceLevels[supportResistanceCount] = low;
            supportResistanceCount++;
         }
      }
   }
}

int GetHigherTimeframeSignal()
{
   int h1_ma_fast_handle = iMA(_Symbol, PERIOD_H1, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   int h1_ma_slow_handle = iMA(_Symbol, PERIOD_H1, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   
   if(h1_ma_fast_handle == INVALID_HANDLE || h1_ma_slow_handle == INVALID_HANDLE)
      return 0;
   
   double h1_fast[2], h1_slow[2];
   if(CopyBuffer(h1_ma_fast_handle, 0, 0, 2, h1_fast) < 2 ||
      CopyBuffer(h1_ma_slow_handle, 0, 0, 2, h1_slow) < 2)
   {
      IndicatorRelease(h1_ma_fast_handle);
      IndicatorRelease(h1_ma_slow_handle);
      return 0;
   }
   
   int signal = 0;
   if(h1_fast[0] > h1_slow[0])
      signal = 1;
   else if(h1_fast[0] < h1_slow[0])
      signal = -1;
   
   IndicatorRelease(h1_ma_fast_handle);
   IndicatorRelease(h1_ma_slow_handle);
   
   return signal;
}

bool PassesQualityFilters(int signal)
{
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   if(!TimeToStruct(currentTime, timeStruct))
      return false;
   int hour = timeStruct.hour;
   
   if(hour >= 22 || hour <= 2)
      return false;
   
   double atr = CalculateATR();
   double avgATR = CalculateAverageATR();
   if(atr > avgATR * 2.0)
      return false;
   
   double bbWidth = bbUpperBuffer[0] - bbLowerBuffer[0];
   double avgBBWidth = CalculateAverageBBWidth();
   if(bbWidth < avgBBWidth * 0.5)
      return false;
   
   return true;
}

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

double CalculateAverageBBWidth()
{
   double sum = 0;
   double upperBuffer[21];
   double lowerBuffer[21];
   
   if(CopyBuffer(bbHandle, 1, 0, 21, upperBuffer) < 21 ||
      CopyBuffer(bbHandle, 2, 0, 21, lowerBuffer) < 21)
      return (bbUpperBuffer[0] - bbLowerBuffer[0]);
   
   for(int i = 1; i <= 20; i++)
   {
      sum += (upperBuffer[i] - lowerBuffer[i]);
   }
   return sum / 20;
}

void ExecuteAdvancedTrade(ENUM_ORDER_TYPE orderType, int signalStrength)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp;
   
   double atr = CalculateATR();
   double dynamicSL = MathMax(StopLossPips * _Point * 10, atr * 1.5);
   double dynamicTP = dynamicSL * 1.5;
   
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

int CountTodayTrades()
{
   int count = 0;
   datetime startOfDay = TimeCurrent() - (TimeCurrent() % 86400);
   
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

void OnTrade()
{
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
            
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            
            if(profit > 50 && volume >= LotSize)
            {
               double closeVolume = volume / 2;
               ClosePartialPosition(ticket, closeVolume);
            }
            
            if(TimeCurrent() - openTime > 3600)
            {
               ClosePosition(ticket);
            }
            
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
