using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;
using System.IO;
using Stolyzer.Framework;

namespace Stolyzer.Strategies {

	public class RiSK : Strategy 
	{
        private RiSKConfig _config = new RiSKConfig();
        IBroker _broker;
        IChartIndicator rs;
		
        public RiSK() {

		}

        public override object Config { get { return _config; } set { _config = (RiSKConfig)value; } }

        public override void Init(IBroker broker)
        {
			_broker = broker;
			rs = _broker.CreateIndicator("RelativeStrength");
			((IChartIndicatorConfig)rs.Config).Period = 14;
        }
        StockRecord FindStock(StockRecord[] portfolio , string sym, string xchid) {
        	foreach(StockRecord r in portfolio) {
        		if(r.Name == sym && r.ExchangeID == xchid) return r;	
        	}
        	return null;
        }

        public override void Tick(string sym, string xchid, IElement[] elements)
        {
			IElement e = elements[elements.Length -1];
			Series s = new Series(elements);
			double[] result = rs.Calculate(s);
			
			if(result[0] < 30) {
				_broker.Buy(sym, xchid, e.Close, 100, "RiSK buy");
			} else if(result[0] > 70) {
				StockRecord[] portfolio = _broker.GetPortfolio();
				StockRecord ws = FindStock(portfolio, sym, xchid);
				
				if(ws != null) {
					double vol;
					if(ws.Volume > 100) vol = 100;
					else vol = ws.Volume;
					_broker.Sell(sym, xchid, e.Close, vol, "RiSK sell");
				}
			}
        }

        public override string ToString() {
            return "RiSK";
        }
	}

    public class RiSKConfig 
    {
        public RiSKConfig() {  }
    }
}