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

	public class StockScreener : Strategy 
	{
        private StockScreenerConfig _config = new StockScreenerConfig();
        private IBroker _broker;
		
        public StockScreener() {

		}

        public override object Config { get { return _config; }  }

        public override void Init(IBroker broker)
        {
		_broker = broker;
        }

        public override void Tick(string sym, string xchid, IElement[] elements)
        {
             IElement element = elements[elements.Length -1];
		Report r = _broker.GetReport(sym, xchid);
		if(r == null) return;
		if(r.der > _config.der) return;
		if(_config.buy_pbv != 0 || _config.buy_per != 0 || _config.buy_roe != 0) {
			if(    ((element.Close / r.book_value) < _config.buy_pbv || _config.buy_pbv == 0) && 
					 ((r.eps * 100 / element.Close) < _config.buy_per || _config.buy_per == 0) &&
					 ((r.roe * 100 / element.Close) < _config.buy_roe || _config.buy_roe == 0)    ) {
				_broker.Buy(sym, xchid, element.Close, 100);
			}
		}
		if(_config.sell_pbv != 0 || _config.sell_per != 0 || _config.sell_roe != 0) {
			if(    ((element.Close / r.book_value) > _config.sell_pbv || _config.sell_pbv == 0) && 
					 ((r.eps * 100 / element.Close) > _config.sell_per || _config.sell_per == 0) &&
					 ((r.roe * 100 / element.Close) > _config.sell_roe || _config.sell_roe == 0)    ) {
				_broker.Sell(sym, xchid, element.Close, 100);
			}	
		}
        }

        public override string ToString() {
            return "Stock Screener";
        }
	}

    public class StockScreenerConfig 
    {
        public StockScreenerConfig() { buy_pbv=0; sell_pbv=0; der=0; buy_per=0; sell_per = 0; buy_roe=0; sell_roe = 0; }
        
        [DisplayName("Buy PBV")]
        public double buy_pbv { get; set; }
        
        [DisplayName("Sell PBV")]
        public double sell_pbv { get; set; }
        
        [DisplayName("DER")]
        public double der { get; set; }
        
        [DisplayName("Buy PER")]
        public double buy_per { get; set; }
        
        [DisplayName("Sell PER")]
        public double sell_per { get; set; }
        
        [DisplayName("Buy ROE")]
        public double buy_roe { get; set; }
        
        [DisplayName("Sell ROE")]
        public double sell_roe { get; set; }
    }
}