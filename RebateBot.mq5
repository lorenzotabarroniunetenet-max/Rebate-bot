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

int tradesCountToday = 0;
datetime lastTradeTime = 0;

int OnInit()
{
   Print("RebateBot initialized");
   tradesCountToday = CountTodayTrades();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("RebateBot deinitialized");
}

void OnTick()
{
   if(!CanTrade())
      return;
   
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (currentAsk - currentBid) / _Point;
   
   if(spread > MaxSpreadPips * 10)
      return;
   
   if(ShouldBuy())
   {
      ExecuteTrade(ORDER_TYPE_BUY);
   }
   else if(ShouldSell())
   {
      ExecuteTrade(ORDER_TYPE_SELL);
   }
}

bool CanTrade()
{
   if(tradesCountToday >= MaxTradesPerDay)
      return false;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - lastTradeTime < MinutesBetwenTrades * 60)
      return false;
   
   MqlDateTime timeStruct;
   if(!TimeToStruct(currentTime, timeStruct))
      return false;
   
   if(timeStruct.day_of_week == 0 || timeStruct.day_of_week == 6)
      return false;
   
   return true;
}

bool ShouldBuy()
{
   double rsi = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   if(rsi != EMPTY_VALUE && rsi < 30)
      return true;
   return false;
}

bool ShouldSell()
{
   double rsi = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   if(rsi != EMPTY_VALUE && rsi > 70)
      return true;
   return false;
}

void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
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
   
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.magic = MagicNumber;
   request.comment = "RebateBot";
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         tradesCountToday++;
         lastTradeTime = TimeCurrent();
         Print("Trade executed: ", EnumToString(orderType));
      }
   }
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
         count++;
   }
   
   return count;
}
