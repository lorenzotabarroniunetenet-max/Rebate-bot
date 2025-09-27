//+------------------------------------------------------------------+
//|                                               RebateBot_Final.mq5 |
//|                                  Copyright 2024, Lorenzo Tabarroni |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Lorenzo Tabarroni"
#property version   "3.00"

#include <Trade\Trade.mqh>

input double TradeVolume = 0.01;
input int DailyTradeLimit = 180;
input int TradeIntervalMinutes = 8;
input double MaxSpread = 0.8;
input double StopLoss = 8.0;
input double TakeProfit = 12.0;
input int EA_Magic = 12345;

int dailyTradeCount = 0;
datetime lastOrderTime = 0;

int OnInit()
{
   Print("RebateBot Final Version Initialized");
   dailyTradeCount = GetTodayTradeCount();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("RebateBot Final Version Deinitialized");
}

void OnTick()
{
   if(!IsTradeAllowed())
      return;
   
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentSpread = (askPrice - bidPrice) / _Point;
   
   if(currentSpread > MaxSpread * 10)
      return;
   
   if(GetBuySignal())
      OpenTrade(ORDER_TYPE_BUY);
   else if(GetSellSignal())
      OpenTrade(ORDER_TYPE_SELL);
}

bool IsTradeAllowed()
{
   if(dailyTradeCount >= DailyTradeLimit)
      return false;
   
   datetime now = TimeCurrent();
   if(now - lastOrderTime < TradeIntervalMinutes * 60)
      return false;
   
   MqlDateTime dt;
   if(!TimeToStruct(now, dt))
      return false;
   
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   
   return true;
}

bool GetBuySignal()
{
   double rsiValue = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   if(rsiValue != EMPTY_VALUE && rsiValue < 30)
      return true;
   return false;
}

bool GetSellSignal()
{
   double rsiValue = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   if(rsiValue != EMPTY_VALUE && rsiValue > 70)
      return true;
   return false;
}

void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl, tp;
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = price - StopLoss * _Point * 10;
      tp = price + TakeProfit * _Point * 10;
   }
   else
   {
      sl = price + StopLoss * _Point * 10;
      tp = price - TakeProfit * _Point * 10;
   }
   
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = TradeVolume;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.magic = EA_Magic;
   request.comment = "RebateBot_Final";
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         dailyTradeCount++;
         lastOrderTime = TimeCurrent();
         Print("Trade executed: ", EnumToString(orderType), " at price: ", price);
      }
      else
      {
         Print("Trade failed with retcode: ", result.retcode);
      }
   }
   else
   {
      Print("OrderSend failed");
   }
}

int GetTodayTradeCount()
{
   int count = 0;
   datetime startOfDay = TimeCurrent() - (TimeCurrent() % 86400);
   
   HistorySelect(startOfDay, TimeCurrent());
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == EA_Magic)
         count++;
   }
   
   return count;
}
