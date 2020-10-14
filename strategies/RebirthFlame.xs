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

	public class RebirthFlame : Strategy 
	{
        private RebirthFlameConfig _config = new RebirthFlameConfig();
        IBroker _broker;
        IChartIndicator _bb;
        RebirtCacheList _cache = new RebirtCacheList();
		
        public RebirthFlame() {

		}

        public override object Config { get { return _config; } set { _config = (RebirthFlameConfig)value; } }
        public override int TickSize {get { return 26; } }

        public override void Init(IBroker broker)
        {
		_broker = broker;
            _bb = _broker.CreateIndicator("BollingerBand");
            IChartIndicatorConfig config = (IChartIndicatorConfig)_bb.Config;
            config.Period = 26;
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
		//IElement e = elements[0];
            IElement element = elems[elems.Length -1];
            RebirthCache cache = _cache.Find(sym, xchid);
            Report r;
            double avg;
            double stddev;
            if(cache == null) {
            	cache = new RebirthCache(sym, xchid, _broker.Now);
            	_cache.Add(cache);
				cache.report = _broker.GetReport(sym, xchid);
	            if(_broker.GetDailyReturn(sym, xchid, 5, out avg, out stddev)) {
	           		//if( _config.mode == RebirthMode.Strict && avg < 0) return;		//daily average less than zero
	            	//set value
	            	cache.avg = avg;
	            	cache.stddev = stddev;
	            }
            	
            } else {
            	if((_broker.Now - cache.stamp).TotalDays > 26) {
					cache.report = _broker.GetReport(sym, xchid);
		            if(_broker.GetDailyReturn(sym, xchid, 5, out avg, out stddev)) {
		           		//if( _config.mode == RebirthMode.Strict && avg < 0) return;		//daily average less than zero
	            		cache.avg = avg;
	            		cache.stddev = stddev;
		            }
		            //set stamp
	            	cache.stamp = _broker.Now;
            	}
            }
            r = cache.report;
            avg = cache.avg;
            stddev = cache.stddev;
            
			if(r == null) return;
			if(r.book_value == null) return;
	        if( _config.mode != RebirthMode.BlueFlame && avg <= 0) return;		//daily average less than zero
            //Console.WriteLine(r.book_value);
            //if(r.der > _config.der) return;		//skip if der is higher than config
			if(r.eps < 0) return;					//skip if eps negative
            //bb.Calculate
            string xsym = String.Format("{0}.{1}", sym, xchid);
            Series s = new Series(elems);
            
            double[] bbs = _bb.Calculate(s);
            StockRecord[] porttfolio = _broker.GetPortfolio();
            StockRecord ws = FindStock(porttfolio, sym, xchid);
            if (_broker.Account.CurrentCapital == 0) {
            		Console.WriteLine("not enough capital");
            		return;        //not enough balance
            }
            double allocated_capital = 0;
            //if (ws != null && ws.Volume == 0) allocated_capital = _broker.Account.CurrentCapital / 5;
            //else allocated_capital = _broker.Account.CurrentCapital / 20;
            allocated_capital = _broker.Account.CurrentCapital / 100; 
            allocated_capital *= Math.Abs(((avg / stddev) > 10)?5:(1+(avg * 4 / stddev)));
            if (bbs != null && bbs.Length == 2)
            {
                double high = bbs[0];     //high
                double low = bbs[1];        //low
                Console.WriteLine(String.Format("BB Result : {0} - {1}", high, low));
                if(element.Close < low)
                {
                    string remark = "";
                    int rate = 0;
                    double vol = allocated_capital / low;
                    if(ws != null) {
                    	if((element.Close / ws.AvgPrice) < 0.7) rate++;
                    }
                    //_broker.Buy(sym, xchid, low, vol);
					if((element.Close / r.book_value) < _config.buy_pbv) {
						rate++;
						remark += "PBV";
						//_broker.Buy(sym, xchid, element.Close, 100);
					}
					if((element.Close / r.eps) < _config.buy_per) {
						rate++;
						remark += "PER";
						//_broker.Buy(sym, xchid, element.Close, 100);
					}
					if(((r.book_value / element.Close) * r.roe) > _config.buy_roe) {
						rate++;
						remark += "ROE";
						//_broker.Buy(sym, xchid, element.Close, 100);
					}
					if(rate >= (int)_config.mode) _broker.Buy(sym, xchid, element.Close, vol, "BUY " + remark);
                }
                if(element.Close > high && high != 0)
                {
                    //if (ws.Volume == 0) return;
                    double vol = 0;
                    //_broker.Sell(sym, xchid, high, vol);
                    int rate = 0;
                    string remark = "";
					if((element.Close / r.book_value) > _config.sell_pbv) {
						rate++;
						remark += "PBV";
						//_broker.Sell(sym, xchid, element.Close, vol);
					}
					if((element.Close / r.eps) > _config.sell_per) {
						rate++;
						remark += "PER";
						//_broker.Sell(sym, xchid, element.Close, vol);
					}
					if(((r.book_value / element.Close) * r.roe) < _config.sell_roe) {
						rate++;
						remark += "ROE";
						//_broker.Buy(sym, xchid, element.Close, 100);
					}
                    if(ws != null) {
                    	if((element.Close / ws.AvgPrice) > 1.33) rate++;
                    	if(rate > 2)
                    		vol = ws.Volume;
                    	else if(rate > 1) 
                    		vol = ws.Volume /1.61;
                    	else 
                    		vol = ws.Volume /2;
                    	if(ws.Volume < 100) vol = ws.Volume;
                    }
					int min_rate = (((int)_config.mode - 1) <= 0)? 1 : ((int)_config.mode - 1);
					if(rate >= min_rate) _broker.Sell(sym, xchid, element.Close, vol, "SELL " + remark);
                }
            }
		
        }

        public override string ToString() {
            return "RebirthFlame";
        }
	}

	public enum RebirthMode { GoldFlame=3, RedFlame=2, BlueFlame=1 };
    public class RebirthFlameConfig 
    {
        public RebirthFlameConfig() { buy_pbv=0.8; sell_pbv=1.2; der=10; buy_per=8; sell_per=16; mode=RebirthMode.BlueFlame; buy_roe=15; sell_roe=2; }
        
        [DisplayName("Buy PBV (less than 0.)")]
        public double buy_pbv { get; set; }
        
        [DisplayName("Sell PBV (greater than 0.)")]
        public double sell_pbv { get; set; }
        
        [DisplayName("DER (max 0.)")]
        public double der { get; set; }
        
        [DisplayName("Buy PER (less than 0.)")]
        public double buy_per { get; set; }
        
        [DisplayName("Sell PER (greater than 0.)")]
        public double sell_per { get; set; }
        
        [DisplayName("Buy ROE (greater than %)")]
        public double buy_roe { get; set; }
        
        [DisplayName("Sell ROE (less than %)")]
        public double sell_roe { get; set; }
        
        [DisplayName("Flame Mode")]
        public RebirthMode mode { get; set; }
        
        
    }
    
    public class RebirtCacheList : List<RebirthCache>
    {
    	public RebirthCache Find(string name, string xname) {
    		foreach(RebirthCache c in this) if(c.name==name && c.xname==xname) return c;
    		return null;
    	}
    }
    
    public class RebirthCache {
    	public RebirthCache(string name, string xname, DateTime stamp) { this.name = name; this.xname = xname; this.stamp = stamp; this.avg=0; this.stddev = 0; this.report=null; }
    	public string name{get;set;}
    	public string xname {get;set;}
   		public DateTime stamp { get;set; }
    	public Report report {get; set;}
    	public double avg {get; set;}
    	public double stddev {get; set;}
    }
}