//+------------------------------------------------------------------+
//|                                                   TesteRSI_2.mq5 |
//|                                                  Leonardo Santos |
//|                                             https://www.mql5.com |
//| @description
//|   
//|   - Insere preco medio
//|   - TODO: add multiplicador de preco medio progressivo
//|   
//+------------------------------------------------------------------+

#property copyright "Leonardo Santos"
#property link      "https://www.mql5.com"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
// #include <Tester.mqh>

enum BuyOrSell
  {
   BUY,
   SELL,
   BOTH,
  };
  
enum BMFBOV
{
   BMF, // BMF (Minis)
   BOVESPA // Bovespa (Acoes)
};


//--- input parameters
input string            separator1        = "---General Settings---";  // #############################
// input double            ContractsNr       = 0.1;               // Number of contracts
input BMFBOV            mercado           = BOVESPA;
input double            Amount            = 5000;              // Valor da Compra
input ENUM_TIMEFRAMES   mytimeframe       = 0;                 // Timeframe
input double            StopLevel         = 1.3;               // Stop level com base em 130% da barra anterior
input double            MinPointsToProfit = 50;                // Min Points to Profit
input BuyOrSell         BuyOrSell_        = BOTH;              // Buy, Sell or Both?

input string            separator11       = "---MeanPrice Settings---"; // #############################
input double            MaxMeanPriceX     = 3;                 // Make mean price N times
input double            PointsFirstMeanPrice     = 100;                 // Min points to first mean price
input bool              CloseWinning      = false;             // Close only when Profit > 0

input string            separator2        = "---RSI2 Settings---"; // #############################
input int               RSIPeriod         = 2;                 // RSI Period
input int               RSILimit          = 5;                 // RSI threshold to open position
input int               RSIBars           = 1;                 // Number of bars for RSI over/under threshold
input bool              CheckLongSMA      = false;             // Uses Long SMA?
input int               SMA1Period        = 200;               // Long SMA Period
input int               SMASHORTPeriod    = 7;                 // SMA to Close Position

input string            separator3           = "---Time Settings---"; // #############################
input bool              CheckInterval_bool   = false;             // Check Time Interval?
input int               StartHour            = 9;                 // Start hour
input int               StartMinute          = 0;                 // Start minute
input int               EndHour              = 17;                // Stop hour
input int               EndMinute            = 30;                // Stop minute


int               iSMA1_handle;
int               iSMASHORT_handle;
int               iRSI_handle; 
int               CandleTimeFrame;

string            my_symbol;
// ENUM_TIMEFRAMES   mytimeframe;
string            buy_time;

double            iRSI_buf[];
double            iSMA1_buf[];
double            iSMASHORT_buf[];

double            Open_buf[];
double            Close_buf[];
double            High_buf[];
double            Low_buf[];

double            stop_loss = 0;
double            old_atr = -1;
extern double     is_stop = false;
extern string     negociacao_bloqueada_dia = "";    

CTrade            m_Trade;                                     //structure for execution of trades
CPositionInfo     m_Position;                                  //structure for obtaining information of positions
CAccountInfo      m_AccountInfo;

extern int        Expert_ID = 1743;
int               _MagicNumber = 0;

//+------------------------------------------------------------------+

//| Expert initialization function                                   |

//+------------------------------------------------------------------+

/*
double OnTester()
{
    return HelperOnTester();
}
*/

double OnTester()
{
  double  param = 0.0;

//  Balance max + min Drawdown + Trades Number:
  double  balance = TesterStatistics(STAT_PROFIT);
  double  min_dd = TesterStatistics(STAT_BALANCE_DD);
  if(min_dd > 0.0)
  {
    min_dd = 1.0 / min_dd;
  }
  double  trades_number = TesterStatistics(STAT_TRADES);
  param = balance * min_dd * trades_number;

  return(param);
}

int OnInit() {  

    CandleTimeFrame = 0;
    switch ( mytimeframe )
    {
        case PERIOD_MN1: CandleTimeFrame = 302400; break;
        case PERIOD_W1:  CandleTimeFrame = 10080; break;
        case PERIOD_D1:  CandleTimeFrame = 1140; break;
        case PERIOD_H4:  CandleTimeFrame = 240; break;
        case PERIOD_H1:  CandleTimeFrame = 60; break;
        case PERIOD_M30: CandleTimeFrame = 30; break;
        case PERIOD_M15: CandleTimeFrame = 15; break;
        case PERIOD_M10: CandleTimeFrame = 10; break;
        case PERIOD_M5:  CandleTimeFrame = 5; break;
        case PERIOD_M1:  CandleTimeFrame = 1; break;
        default: CandleTimeFrame = 60; break;
   }

    // _MagicNumber = Expert_ID * 10 + CandleTimeFrame;
    _MagicNumber = 11111;
    m_Trade.SetExpertMagicNumber(_MagicNumber);
    // HELPER_MagicNumber = _MagicNumber;

   my_symbol = Symbol();
   // mytimeframe=Period();
   // mytimeframe = mytimeframe;

   // MOVING AVERAGE1
   iSMA1_handle=iMA(my_symbol,mytimeframe,SMA1Period,0,MODE_SMA,PRICE_CLOSE);
   if(iSMA1_handle==INVALID_HANDLE){
      Print("Failed to get the indicator handle");
      return(-1);
   }
   
   iSMASHORT_handle=iMA(my_symbol,mytimeframe,SMASHORTPeriod,0,MODE_SMA,PRICE_CLOSE);
   if(iSMASHORT_handle==INVALID_HANDLE){
      Print("Failed to get the indicator handle");
      return(-1);
   }

   // RSI
   iRSI_handle=iRSI(my_symbol,mytimeframe,RSIPeriod,PRICE_CLOSE);
   if(iRSI_handle==INVALID_HANDLE){
      Print("Failed to get the indicator handle");
      return(-1);
   }
   
   ArraySetAsSeries(iSMA1_buf,true);
   ArraySetAsSeries(iSMASHORT_buf,true);
   ArraySetAsSeries(iRSI_buf,true);
   ArraySetAsSeries(Open_buf,true);
   ArraySetAsSeries(Close_buf,true);
   ArraySetAsSeries(High_buf,true);
   ArraySetAsSeries(Low_buf,true);

   return(INIT_SUCCEEDED);

}

  

//+------------------------------------------------------------------+

//| Expert deinitialization function                                 |

//+------------------------------------------------------------------+

void OnDeinit(const int reason) {
   IndicatorRelease(iSMA1_handle);
   IndicatorRelease(iSMASHORT_handle);
   IndicatorRelease(iRSI_handle);
   ArrayFree(iSMA1_buf);
   ArrayFree(iSMASHORT_buf);
   ArrayFree(iRSI_buf);
   ArrayFree(Open_buf);
   ArrayFree(Close_buf);
   ArrayFree(High_buf);
   ArrayFree(Low_buf);
}



// funcao para verificar se o parametro esta no intervalo de tempo pré-definido

bool CheckInterval(datetime my_date) {

   if (!CheckInterval_bool)
      return true;

   // verifica tempo dentro de intervalo
   string time_str = TimeToString(my_date, TIME_MINUTES);
   ushort u_sep = StringGetCharacter(":",0);
   string time_arr[];
   StringSplit(time_str, u_sep, time_arr);
   int hora = (int)StringToInteger(time_arr[0]);
   int minuto = (int)StringToInteger(time_arr[1]);
   
   // printf("HORARIOOOO: %d:%d", hora, minuto);
   int start_time60 = StartHour * 60 + StartMinute;
   int end_time60 = EndHour * 60 + EndMinute;
   int user_time60 = hora * 60 + minuto;
   if (user_time60 >= start_time60 && user_time60 <= end_time60) {
      return true;
   }

   return false;

}

bool CheckDuration(datetime buy_time_, int qnt_tempo) {

   qnt_tempo = qnt_tempo;
   string buy_time__ = TimeToString(buy_time_, TIME_MINUTES);

   ushort u_sep = StringGetCharacter(":",0);
   int minutos_compra;
  
   if (buy_time__ != NULL) {
      string time_arr1[];
      StringSplit(buy_time__, u_sep, time_arr1);
      int hora_compra = (int)StringToInteger(time_arr1[0]);
      int minuto_compra = (int)StringToInteger(time_arr1[1]);
      minutos_compra = hora_compra * 60 + minuto_compra;
   } else {
      minutos_compra = 0;
   }
   
   // horario agora
   string time_str2 = TimeToString(TimeCurrent(), TIME_MINUTES);
   string time_arr2[];
   StringSplit(time_str2, u_sep, time_arr2);
   int hora_agora = (int)StringToInteger(time_arr2[0]);
   int minuto_agora = (int)StringToInteger(time_arr2[1]);
   int minutos_agora = hora_agora * 60 + minuto_agora;
   
   
   
   if ((minutos_agora - minutos_compra) > qnt_tempo && minutos_compra > 0) {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//|  die Anzahl der Deals der offenen Position des Symbol            |
//+------------------------------------------------------------------+
int PositionDeals()
{
   uint total=0;
   ulong pos_id=0;
   if(PositionSelect(Symbol())) 
   {
      pos_id=(ENUM_POSITION_PROPERTY_INTEGER)PositionGetInteger(POSITION_IDENTIFIER);
      HistorySelectByPosition(pos_id);
      total=HistoryDealsTotal();
      return(total); 
   }
   return(0);
}

//+------------------------------------------------------------------+ 
//| Retorna a descrição string da operação                           | 
//+------------------------------------------------------------------+ 
string GetDealDescription(long deal_type,double price,double volume,string symbol,long ticket,long pos_ID) 
  { 
   string descr; 
//--- 
   switch(deal_type) 
     { 
      case DEAL_TYPE_BALANCE:                  return ("balance"); 
      case DEAL_TYPE_CREDIT:                   return ("credit"); 
      case DEAL_TYPE_CHARGE:                   return ("charge"); 
      case DEAL_TYPE_CORRECTION:               return ("correção"); 
      case DEAL_TYPE_BUY:                      descr="compra"; break; 
      case DEAL_TYPE_SELL:                     descr="vender"; break; 
      case DEAL_TYPE_BONUS:                    return ("bonus"); 
      case DEAL_TYPE_COMMISSION:               return ("comissão adicional"); 
      case DEAL_TYPE_COMMISSION_DAILY:         return ("comissão diária"); 
      case DEAL_TYPE_COMMISSION_MONTHLY:       return ("comissão mensal"); 
      case DEAL_TYPE_COMMISSION_AGENT_DAILY:   return ("comissão de agente diário"); 
      case DEAL_TYPE_COMMISSION_AGENT_MONTHLY: return ("comissão de agente mensal"); 
      case DEAL_TYPE_INTEREST:                 return ("taxa de juros"); 
      case DEAL_TYPE_BUY_CANCELED:             descr="cancelado comprar negócio"; break; 
      case DEAL_TYPE_SELL_CANCELED:            descr="cancelado vender negócio"; break; 
     } 
   descr=StringFormat("%s %G %G %s (ordem #%d, a posição ID %d)", 
                      descr,  // descrição atual 
                      price, // preço do negócio 
                      volume, // volume de negócio 
                      symbol, // ativo de negócio 
                      ticket, // ticket da ordem que provocou o negócio 
                      pos_ID  // ID de uma posição, na qual a negócio é incluído 
                      ); 
   return(descr); 
//--- 
  }

int PositionLastDealOpenPrice()
{

   ulong deal_ticket;            // bilhetagem da operação (deal) 
   ulong order_ticket;           // ticket da ordem que o negócio foi executado em 
   datetime transaction_time;    // tempo de execução de um negócio 
   long deal_type ;              // tipo de operação comercial 
   long position_ID;             // ID posição 
   string deal_description;      // descrição da operação 
   double volume;                // volume da operação 
   double price;                // preço da operação 
   string symbol;                // ativo da negociação 

   uint total=0;
   ulong pos_id=0;
   if(PositionSelect(Symbol())) 
   {
      pos_id=(ENUM_POSITION_PROPERTY_INTEGER)PositionGetInteger(POSITION_IDENTIFIER);
      HistorySelectByPosition(pos_id);

      // total=HistoryDealsTotal();
      int deals=HistoryDealsTotal(); 

      //--- agora processar cada trade (negócio) 
      for(int i=0;i<deals;i++) 
      { 
         deal_ticket=               HistoryDealGetTicket(i); 
         price=                     HistoryDealGetDouble(deal_ticket,DEAL_PRICE); 
         volume=                    HistoryDealGetDouble(deal_ticket,DEAL_VOLUME); 
         transaction_time=(datetime)HistoryDealGetInteger(deal_ticket,DEAL_TIME); 
         order_ticket=              HistoryDealGetInteger(deal_ticket,DEAL_ORDER); 
         deal_type=                 HistoryDealGetInteger(deal_ticket,DEAL_TYPE); 
         symbol=                    HistoryDealGetString(deal_ticket,DEAL_SYMBOL); 
         position_ID=               HistoryDealGetInteger(deal_ticket,DEAL_POSITION_ID); 
         deal_description=          GetDealDescription(deal_type,price,volume,symbol,order_ticket,position_ID); 
         //--- realizar uma boa formatação para o número de negócio 
         string print_index=StringFormat("% 3d",i); 
         //--- mostrar informações sobre o negócio 
         Print(print_index+": deal #",deal_ticket," em ",transaction_time,deal_description); 
         int a = 1;
      }       
      // return(total); 
   }
   return(0);
}

double GetPositionDealOpenPrice(int position)
{

   ulong deal_ticket;            // bilhetagem da operação (deal) 
   long position_ID;             // ID posição 
   double price;                // preço da operação 

   uint total=0;
   ulong pos_id=0;
   if(PositionSelect(Symbol())) 
   {

      pos_id=(ENUM_POSITION_PROPERTY_INTEGER)PositionGetInteger(POSITION_IDENTIFIER);
      HistorySelectByPosition(pos_id);

      int deals=HistoryDealsTotal(); 
      double position_deals[];
      ArrayResize(position_deals,deals);

      //--- agora processar cada trade (negócio)
      // in reverse order
      deal_ticket = HistoryDealGetTicket(deals - position - 1); 
      price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
      return price;

   }
   return 0;
   
}



//+------------------------------------------------------------------+

//| Expert tick function                                             |

//+------------------------------------------------------------------+

void OnTick() {

   // verify seconds to jump tick test
   /*
   ushort u_sep = StringGetCharacter(":",0);
   string time_str = TimeToString(TimeCurrent(), TIME_SECONDS);
   string time_arr[];
   StringSplit(time_str, u_sep, time_arr);
   int segundo_agora = (int)StringToInteger(time_arr[2]);
   if (segundo_agora % 10 != 0) {
      // Print("   Sai ", segundo_agora);
      return;
   }
   */

   // OnTester
   //static datetime old_day;
   //if(HelperIsNewDay(old_day)) {
  //    HelperLogDaytrade();
   //}

   bool err = false;
      
   double free_margin=0;
   double new_order_volume=0;
   
   // update data - FIX BUG de realizar varias operacoes em milisegundos
   m_Position.Select(my_symbol);
   
   double price_open = m_Position.PriceOpen();
   int position_deals = PositionDeals();
   double last_deals_diff = 0;
   
   err |= CopyBuffer(iSMA1_handle,0,0,2,iSMA1_buf) < 0 ? true : false;
   err |= CopyBuffer(iRSI_handle,0,0,RSIBars,iRSI_buf) < 0 ? true : false;
   err |= CopyOpen(my_symbol,mytimeframe,0,2,Open_buf) < 0 ? true : false;
   err |= CopyClose(my_symbol,mytimeframe,0,2,Close_buf) < 0 ? true : false;
   err |= CopyHigh(my_symbol,mytimeframe,0,3,High_buf) < 0 ? true : false;
   err |= CopyLow(my_symbol,mytimeframe,0,3,Low_buf) < 0 ? true : false;
   err |= CopyBuffer(iSMASHORT_handle,0,0,2,iSMASHORT_buf) < 0 ? true : false;
   
   if(err)
   {
      Print("Failed to copy data from the indicator buffer or price chart buffer");
      return;
   }
   
   // verifica RSI de acordo com a quantidade de barras que devem estar abaixo do limite
   bool RSI_COMPRA_OK = true;
   for (int i = 0; i < RSIBars; i++) {
      RSI_COMPRA_OK = RSI_COMPRA_OK && (iRSI_buf[i] < RSILimit);
   }
   
   bool RSI_VENDA_OK = true;
   for (int i = 0; i < RSIBars; i++) {
      RSI_VENDA_OK = RSI_VENDA_OK && (iRSI_buf[i] > (100-RSILimit));
   }
   
   double max_last2 = MathMax(High_buf[1], High_buf[2]);
   double min_last2 = MathMax(Low_buf[1], Low_buf[2]);
   
   bool STOP_BOM_COMPRA = (max_last2 - Close_buf[0]) > ((High_buf[0] - Low_buf[0])*StopLevel);
   bool STOP_BOM_VENDA = (Close_buf[0] - min_last2) > ((High_buf[0] - Low_buf[0])*StopLevel);

   // compra bools
   bool CONDICOES_COMPRA_IN = 
      CheckInterval(TimeCurrent())           // dentro do intervalo
      && RSI_COMPRA_OK                       // RSI ultrapassou o limite
      && STOP_BOM_COMPRA
      && (Close_buf[0] > iSMA1_buf[0] || !CheckLongSMA);          // acima da media movel maior

   // venda bools      
   bool CONDICOES_VENDA_IN = 
      CheckInterval(TimeCurrent()) 
      && RSI_VENDA_OK
      && STOP_BOM_VENDA
      && (Close_buf[0] < iSMA1_buf[0] || !CheckLongSMA);

   // OUT
   if(m_Position.Select(my_symbol)) {
      if(m_Position.PositionType() == POSITION_TYPE_BUY) {
         if (CloseWinning) {
            if (Close_buf[0] >= iSMASHORT_buf[0] && Close_buf[0] >= (price_open + MinPointsToProfit*Point())) {
               m_Trade.PositionClose(my_symbol, 0);
            }
         } else {
            if (Close_buf[0] >= iSMASHORT_buf[0]) {
               m_Trade.PositionClose(my_symbol, 0);
            }
         }
      }
      if(m_Position.PositionType() == POSITION_TYPE_SELL) { 
         if (CloseWinning) {
            if (Close_buf[0] <= iSMASHORT_buf[0] && Close_buf[0] <= (price_open - MinPointsToProfit*Point())) {
               m_Trade.PositionClose(my_symbol, 0);
            }
         } else {
            if (Close_buf[0] <= iSMASHORT_buf[0]) {
               m_Trade.PositionClose(my_symbol, 0);
            }
         }   
      }
   }   
   
   // distanced new avg price, or new entry
   double mean_factor = position_deals * 2;
   // double mean_factor = 1000;
   
   // COMPRA
   if(CONDICOES_COMPRA_IN && (BuyOrSell_ == BUY || BuyOrSell_ == BOTH))
   {
   
      if(m_Position.Select(my_symbol)) {

         // mean price situation
         // 1. check if I'm in the next candle using time based information
         // 2. actual candle > last candle
         if (m_Position.PositionType()==POSITION_TYPE_BUY) {
         
            // reach max contracts
            if (position_deals > MaxMeanPriceX)
               return;
         
            if (position_deals > 1)
               last_deals_diff = GetPositionDealOpenPrice(1) - GetPositionDealOpenPrice(0);

            if (
                  (CheckDuration(m_Position.TimeUpdate(), CandleTimeFrame))
                  && (Close_buf[0] < price_open)
                  // && ((price_open - Close_buf[0]) > (iSMASHORT_buf[0] - price_open))
                  && (
                        (GetPositionDealOpenPrice(0) - Close_buf[0]) >= last_deals_diff * mean_factor
                        || ((GetPositionDealOpenPrice(0) - Close_buf[0])/Point()) > 1000
                     )
                  && ((price_open - Close_buf[0]) > PointsFirstMeanPrice*Point())
               ) {

               // a new mean price * 2
               new_order_volume = m_Position.Volume();
               m_Trade.Buy(new_order_volume, my_symbol, Close_buf[0]);      
            }
         }   
      
         if(m_Position.PositionType()==POSITION_TYPE_SELL || m_Position.PositionType()==POSITION_TYPE_BUY) return;
      }

      // verifica saldo disponivel para realizar operacao
      free_margin = m_AccountInfo.FreeMargin();
      
      // acerta volume em lotes de 100 com o máximo saldo disponivel
      // new_order_volume = MathRound((free_margin * PercentualInvestir/100)/90);
      // new_order_volume = ContractsNr;
      if (mercado == BOVESPA)
         new_order_volume = (Amount/Close_buf[0])-MathMod((Amount/Close_buf[0]),100);
      else
         new_order_volume = Amount;
      
      m_Trade.Buy(new_order_volume, my_symbol, Close_buf[0]);

   } 

   // VENDA
   if(CONDICOES_VENDA_IN && (BuyOrSell_ == SELL || BuyOrSell_ == BOTH))
   {
      if(m_Position.Select(my_symbol)) {
      
         // mean price situation
         // 1. check if I'm in the next candle using time based information
         // 2. actual candle > last candle
         if (m_Position.PositionType()==POSITION_TYPE_SELL) {
         
            // reach max contracts
            if (position_deals > MaxMeanPriceX)
               return;

            if (position_deals > 1)
               last_deals_diff = GetPositionDealOpenPrice(0) - GetPositionDealOpenPrice(1);
         
            if (
                  (CheckDuration(m_Position.TimeUpdate(), CandleTimeFrame))
                  && (Close_buf[0] > price_open)
                  // && ((Close_buf[0] - price_open) > (price_open - iSMASHORT_buf[0]))
                  && (
                        (Close_buf[0] - GetPositionDealOpenPrice(0)) >= last_deals_diff * mean_factor
                        || ((Close_buf[0] - GetPositionDealOpenPrice(0))/Point()) > 1000
                     )
                  && ((Close_buf[0] - price_open) > PointsFirstMeanPrice*Point())
               ) {
               // a new mean price * 2
               new_order_volume = m_Position.Volume();
               m_Trade.Sell(new_order_volume, my_symbol, Close_buf[0]);      
            }
         }   
     
      
         if(m_Position.PositionType()==POSITION_TYPE_SELL || m_Position.PositionType()==POSITION_TYPE_BUY) return;
      }   

      // verifica saldo disponivel para realizar operacao
      free_margin = m_AccountInfo.FreeMargin();
      
      // acerta volume em lotes de 100 com o máximo saldo disponivel
      // new_order_volume = MathRound((free_margin * PercentualInvestir/100)/90);
      // new_order_volume = ContractsNr;
      if (mercado == BOVESPA)
         new_order_volume = (Amount/Close_buf[0])-MathMod((Amount/Close_buf[0]),100);
      else
         new_order_volume = Amount;
      
      // realiza a venda a mercado
      m_Trade.Sell(new_order_volume, my_symbol, Close_buf[0]);
      
   } 

    
}