//+------------------------------------------------------------------+
//|                                                   RebateBotNew.mq5 |
//|                        Advanced MT5 Rebate Trading Expert Advisor |
//|                                  Copyright 2024, Lorenzo Tabarroni |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lorenzo Tabarroni"
#property link      ""
#property version   "1.00"
#property description "Advanced rebate trading bot with multiple strategies"

#include <Trade\Trade.mqh>

// Input Parameters
input group "=== Trading Settings ==="
input double LotSize = 0.01;                    // Lot size per trade
input int MaxTradesPerDay = 180;                // Maximum trades per day
input int MinutesBetweenTrades = 8;             // Minutes between trades
input double MaxSpreadPips = 0.8;               // Maximum spread in pips
input int MagicNumber = 12345;                  // Magic number

input group "=== Risk Management ==="
input double StopLossPips = 8.0;                // Stop loss in pips
input double TakeProfitPips = 12.0;             // Take profit in pips
input double RiskPercentage = 1.0;              // Risk per trade %
input bool UseTrailingStop = true;              // Enable trailing stop
input double TrailingStopPips = 5.0;            // Trailing stop distance

input group "=== Strategy Settings ==="
input int RSI_Period = 14;                      // RSI period
input double RSI_Oversold = 30;                 // RSI oversold level
input double RSI_Overbought = 70;               // RSI overbought level
input int MA_Fast = 10;                         // Fast MA period
input int MA_Slow = 20;                         // Slow MA period
input bool UseVolumeFilter = true;              // Use volume filter
input double MinVolumeMultiplier = 1.2;         // Minimum volume multiplier

// Global Variables
CTrade trade;
int tradesCountToday = 0;
datetime lastTradeTime = 0;
datetime currentDay = 0;

// Indicator handles
int rsiHandle;
int maFastHandle;
int maSlowHandle;
int volumeHandle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== RebateBotNew v1.0 Initialized ===");
   Print("Max trades per day: ", MaxTradesPerDay);
   Print("Lot size: ", LotSize);
   Print("Risk per trade: ", RiskPercentage, "%");
   
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   // Initialize indicators
   rsiHandle = iRSI(_Symbol, PERIOD_M5, RSI_Period, PRICE_CLOSE);
   maFastHandle = iMA(_Symbol, PERIOD_M5, MA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   maSlowHandle = iMA(_Symbol, PERIOD_M5, MA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   volumeHandle = iVolumes(_Symbol, PERIOD_M5, VOLUME_TICK);
   
   if(rsiHandle == INVALID_HANDLE || maFastHandle == INVALID_HANDLE || 
      maSlowHandle == INVALID_HANDLE || volumeHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicators");
      return INIT_FAILED;
   }
   
   // Count today's trades
   tradesCountToday = CountTodayTrades();
   currentDay = TimeCurrent() - (TimeCurrent() % 86400);
   
   Print("Today's trades so far: ", tradesCountToday);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== RebateBotNew Deinitialized ===");
   Print("Reason: ", reason);
   
   // Release indicator handles
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(maFastHandle != INVALID_HANDLE) IndicatorRelease(maFastHandle);
   if(maSlowHandle != INVALID_HANDLE) IndicatorRelease(maSlowHandle);
   if(volumeHandle != INVALID_HANDLE) IndicatorRelease(volumeHandle);
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
      Print("New day started. Trades count reset to: ", tradesCountToday);
   }
   
   // Check trading conditions
   if(!CanTrade()) return;
   
   // Check spread
   double spread = GetCurrentSpread();
   if(spread > MaxSpreadPips)
   {
      return;
   }
   
   // Get trading signals
   int signal = GetTradingSignal();
   
   if(signal == 1) // Buy signal
   {
      ExecuteTrade(ORDER_TYPE_BUY);
   }
   else if(signal == -1) // Sell signal
   {
      ExecuteTrade(ORDER_TYPE_SELL);
   }
   
   // Manage existing positions
   ManagePositions();
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
//| Get trading signal                                               |
//+------------------------------------------------------------------+
int GetTradingSignal()
{
   // Get indicator values
   double rsi[3];
   double maFast[3];
   double maSlow[3];
   double volume[3];
   
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3 ||
      CopyBuffer(maFastHandle, 0, 0, 3, maFast) < 3 ||
      CopyBuffer(maSlowHandle, 0, 0, 3, maSlow) < 3 ||
      CopyBuffer(volumeHandle, 0, 0, 3, volume) < 3)
   {
      return 0; // No signal if can't get data
   }
   
   int signal = 0;
   
   // RSI signals
   if(rsi[0] < RSI_Oversold && rsi[1] >= RSI_Oversold)
      signal += 2; // Strong buy signal
   else if(rsi[0] > RSI_Overbought && rsi[1] <= RSI_Overbought)
      signal -= 2; // Strong sell signal
   
   // Moving average crossover
   if(maFast[0] > maSlow[0] && maFast[1] <= maSlow[1])
      signal += 1; // Buy signal
   else if(maFast[0] < maSlow[0] && maFast[1] >= maSlow[1])
      signal -= 1; // Sell signal
   
   // Volume filter
   if(UseVolumeFilter)
   {
      double avgVolume = (volume[1] + volume[2]) / 2;
      if(volume[0] < avgVolume * MinVolumeMultiplier)
         signal = 0; // Cancel signal if volume too low
   }
   
   // Return normalized signal
   if(signal >= 2) return 1;      // Buy
   else if(signal <= -2) return -1; // Sell
   else return 0;                   // No trade
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculate stop loss and take profit
   double sl, tp;
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - StopLossPips * _Point * 10;
      tp = price + TakeProfitPips * _Point * 10;
   }
   else
   {
      sl = price + StopLossPips * _Point * 10;
      tp = price - TakeProfitPips * _Point * 10;
   }
   
   // Execute trade
   if(trade.PositionOpen(_Symbol, orderType, LotSize, price, sl, tp, "RebateBotNew"))
   {
      tradesCountToday++;
      lastTradeTime = TimeCurrent();
      
      Print("TRADE EXECUTED: ", EnumToString(orderType), 
            " | Price: ", price,
            " | SL: ", sl,
            " | TP: ", tp,
            " | Trades today: ", tradesCountToday);
   }
   else
   {
      Print("TRADE FAILED: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!UseTrailingStop) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && 
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentPrice;
            double newSL;
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               newSL = currentPrice - TrailingStopPips * _Point * 10;
               
               if(newSL > currentSL && newSL > openPrice)
               {
                  trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
               }
            }
            else
            {
               currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               newSL = currentPrice + TrailingStopPips * _Point * 10;
               
               if(newSL < currentSL && newSL < openPrice)
               {
                  trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
   }
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
