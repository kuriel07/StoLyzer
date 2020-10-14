using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;
using System.IO;
using Stolyzer.Framework;
//using Stolyzer.Indicators;

namespace Stolyzer.Strategies {


    public class BouncyBand : Strategy
    {
        IBroker _broker;
        IChartIndicator _bb;
        //private DragonLeapConfig _config;
        Dictionary<string, Series> quotes = new Dictionary<string, Series>();
        BouncyBandConfig _config = new BouncyBandConfig();
        
        public override object Config { get { return _config; } set { _config=(BouncyBandConfig)value; } }

        public BouncyBand()
        {

        }

        //public override object Config { get { return _config; } }

        public override void Init(IBroker broker)
        {
            _broker = broker;
            _bb = _broker.CreateIndicator("BollingerBand");
            IChartIndicatorConfig config = (IChartIndicatorConfig)_bb.Config;
            config.Period = 14;
        }
        StockRecord FindStock(StockRecord[] records, string sym, string xname)
        {
            foreach(StockRecord s in records)
            {
                if (s.Name == sym && s.ExchangeID == xname) return s;
            }
            return null;
        }

        public override void Tick(string sym, string xchid, IElement[] elems)
        {
            //bb.Calculate
            IElement element = elems[elems.Length -1];
            string xsym = String.Format("{0}.{1}", sym, xchid);
            Series s = new Series(elems);
            
#if false
            if (!quotes.TryGetValue(xsym, out s))
            {
                s = new Series();
                quotes.Add(xsym, s);
            }
            s.Add(element);
            if(s.Count >= 20)
            {
                s.RemoveAt(0);      //remove first element
            }
#endif
            double[] bbs = _bb.Calculate(s);
            StockRecord[] porttfolio = _broker.GetPortfolio();
            StockRecord ws = FindStock(porttfolio, sym, xchid);
            if (_broker.Account.CurrentCapital == 0) {
            		Console.WriteLine("not enough capital");
            		return;        //not enough balance
            }
            double allocated_capital = 0;
            if (ws != null && ws.Volume == 0) allocated_capital = _broker.Account.CurrentCapital / 5;
            else allocated_capital = _broker.Account.CurrentCapital / 20;
            if (bbs != null && bbs.Length == 2)
            {
                double high = bbs[0];     //high
                double low = bbs[1];        //low
                Console.WriteLine(String.Format("BB Result : {0} - {1}", high, low));
                if(element.Close < low)
                {
                    double vol = allocated_capital / low;
                    _broker.Buy(sym, xchid, low, vol);
                }
                if(element.Close > high && high != 0)
                {
                    //if (ws.Volume == 0) return;
                    double vol = 0;
                    if(ws != null) vol = ws.Volume;
                    _broker.Sell(sym, xchid, high, vol);
                }
            }
        }

        public override string ToString()
        {
            return "Bouncy Band";
        }
    }

    public class BouncyBandConfig 
    {
        
    }
}