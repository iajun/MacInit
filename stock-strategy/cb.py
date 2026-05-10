# -*- coding: utf-8 -*-
import sys
sys.path.append('..')
import math
from datetime import datetime
import time
import pandas as pd
from decimal import Decimal, getcontext
#设定浮点数精度为10位
getcontext().prec = 10

from xtquant import xtconstant
from quant.trading.base import TraderBase
from quant.trading.subscribe import TraderSubscribe
import quant.xt.get as xt_get
from quant.trading.strategy import Strategy
from quant.trading.task.cb_10004_config import get_code_config, get_sellout_config

import data.cb as cb
import data.stock as stock
import utils.tools as tools
from trading.cb_task import Task
import utils.wechat as wechat


class CB_Strategy(Strategy):
    def __init__(self, job_id=10004):
        Strategy.__init__(self, job_id=job_id)
        
        # 记录循环操作到具体哪天
        self.cur_date = None
        # 记录当天执行的分钟数
        self.cur_time = None

        # 最大持仓债券个数
        self.max_position_codes = 8

        # 默认配置
        self.default_config = {
            'step': 0.5, #网格价格波动
            'max_positon_volume': 100, #最大持仓数量
            'single_purchase': 10, #单笔购买数量
            'repeat': True, # 清仓后是否继续建仓购买
        }
        # 缓存每天关注的个债配置信息
        self.daily_code_config = {}
        # 缓存最新tick价格
        self.full_tick = None

    
    # 加载配置
    def load_config(self):
        daily_code_config = {}
        code_config = get_code_config()
        for key, value in code_config.items():
            daily_code_config[key] = {**self.default_config, **value}
        self.daily_code_config = daily_code_config
    
    # 更新每日关注可转债最新tick价格
    def update_tick(self):
        daily_codes = self.daily_code_config.keys()
        self.full_tick = xt_get.get_full_tick(code_list=daily_codes)

    # 获取个债最新tick信息
    def get_last_tick(self, code):
        market_code = tools.code_to_market_upper(code=code)
        code_tick = self.full_tick[market_code]
        res = {
            'last_price': code_tick['lastPrice'],
            'open': code_tick['open'],
            'last_close': code_tick['lastClose'],
        }
        return res

    # 计算个债网格最新买卖价格点
    def get_buy_sell_price_config(self):
        buy_sell_config = {}
        for code, code_config in self.daily_code_config.items():
            print(code)
            # 默认为0
            buy_price = 0
            sell_price = 0
            trade_list = self.get_trade_detail(code)
            if len(trade_list) < 1:
                position_num = 0
                print('未建仓')
                # 只有价格高于sell_price才卖出
                sell_price = 10000
                # 假如配置了清仓不再购买，直接返回
                if code_config['repeat'] is not True:
                    print('清仓不再购买',code_config)
                    buy_sell_config[code] = {
                        'name': code_config['name'],
                        'buy_price': -1000,
                        'sell_price': sell_price
                    }
                    continue

                # 判断当日有没有购买过
                today_trade_df = self.get_today_trade_list(code=code)
                # 当日没有购买过
                if today_trade_df.empty:                    
                    tick_info = self.get_last_tick(code=code)
                    # 假如当日开盘比昨日收盘大超过step，以开盘价后最高价回落-step当做购买价
                    code_bar = xt_get.get_bar(code_list=[code],period='1m',start_time=self.cur_date,end_time=self.cur_date)
                    if len(code_bar) < 1:
                        buy_price = tick_info['open'] - code_config['step']
                    else:
                        max_close = code_bar['close'].max()
                        buy_price = max_close - code_config['step']

                else:
                    # 当日购买过，但已清仓，计算清仓后最高价是否回撤step
                    latest_row = today_trade_df.iloc[-1]
                    latest_traded_time = latest_row['traded_time'] * 1000
                    latest_traded_price = latest_row['traded_price'] 
                    code_bar = xt_get.get_bar(code_list=[code],period='1m',start_time=self.cur_date,end_time=self.cur_date)

                    # 清仓后交易的bar
                    lastest_bar = code_bar.loc[code_bar['time']>latest_traded_time]
                    if len(lastest_bar) < 1:
                        # 假如为空，则以最后一次交易计算
                        buy_price = latest_traded_price - code_config['step']
                    else:
                        # 以最大收盘值计算回撤购买
                        max_close_price = lastest_bar['close'].max()
                        # 假如最大收盘价在下跌，则以最后一次清仓价格为基准计算
                        if max_close_price < latest_traded_price:
                            max_close_price = latest_traded_price
                        print('最大收盘价', max_close_price)
                        buy_price = max_close_price - code_config['step']

                # 假如购买价已经跌穿了最小价格限制，则控制，不让购买
                if buy_price < code_config['min_price']:
                    buy_price = -10000
                
                # 假如购买价已经超过了最大值，以最大值购买
                if buy_price > code_config['max_price']:
                    buy_price = code_config['max_price']
                
                print('建仓价格', buy_price)

            else:
                print('已建仓')
                trade_df = pd.DataFrame(trade_list)
                trade_df.sort_values(by=['traded_time'], ascending=[True], inplace=True)
                # print(trade_df[['datetime', 'traded_price', 'order_type','traded_volume','traded_amount']])
                # 获取个股重新建仓后网格剩余买点
                buy_points_list_df = self.get_grid_buy_points(trade_list_df=trade_df)

                # 计算下个买点step
                repeat_buy_times = self.get_operate_repeat_times(trade_list_df=trade_df, order_type=xtconstant.STOCK_BUY)
                # step采用二阶函数 step+1.5(n)/10
                step =  round((code_config['step'] + 1.5 ** repeat_buy_times / 10), 3)

                latest_row = trade_df.iloc[-1]
                # 最后一个点不管买卖操作，下个买点都是最新操作价格-step
                buy_price = latest_row['traded_price'] - step

                # 假如购买价已经跌穿了最小价格限制，则控制，不让购买
                if buy_price < code_config['min_price']:
                    buy_price = -10000
                
                # 假如购买价已经超过了最大值，则不给购买
                if buy_price > code_config['max_price']:
                    buy_price = -10000

                print('买点计算',repeat_buy_times, step, buy_price, len(buy_points_list_df))

                # 以网格单位作为卖出点
                if len(buy_points_list_df)>0:
                    # 以剩下的买点中最新1个买点加上step当做卖点
                    # 计算下个卖点step
                    repeat_sell_times = self.get_operate_repeat_times(trade_list_df=trade_df, order_type=xtconstant.STOCK_SELL)
                    if repeat_sell_times > 0:
                        # step采用二阶函数 step+1.2(n)/10
                        step =  round((code_config['step'] + 1.2 ** repeat_sell_times / 10), 3)
                    else:
                        step = code_config['step']
                    sell_price = buy_points_list_df.iloc[-1]['traded_price'] + step

                else:
                    # 假如没有买入点了，则不需要卖出
                    sell_price = 10000
            res = self.cal_position_detail(code)
            buy_sell_config[code] = {
                'name': code_config['name'],
                'buy_price': buy_price,
                'sell_price': sell_price,
                'position': res['position_num']
            }

        return buy_sell_config
    
    # 判断当前是否需要卖出和买入
    def get_buy_sell_list(self):
        # 计算个债网格最新买卖价格点
        buy_sell_config = self.get_buy_sell_price_config()
        print('buy_sell_config', pd.DataFrame.from_dict(buy_sell_config, orient='index'))
        self.send_wc_interval(key='buy_sell_config', content=str(buy_sell_config), interval=60*3)

        sell_list = []
        buy_list = []
        for code, config in buy_sell_config.items():
            # 获取最新价格
            tick_info = self.get_last_tick(code=code)
            print('ttt',code, tick_info)
            last_price = tick_info['last_price']
            if last_price > config['sell_price']:
                trade_list = self.get_trade_detail(code)
                trade_df = pd.DataFrame(trade_list)
                trade_df.sort_values(by=['traded_time'], ascending=[True], inplace=True)
                buy_points_list_df = self.get_grid_buy_points(trade_list_df=trade_df)

                # # 假如只剩最后1个买点，采用冲高回落的方式进行卖出
                # if len(buy_points_list_df) == 1:
                #     left_buy_point = buy_points_list_df.iloc[0]
                #     traded_time = left_buy_point['traded_time'] * 1000
                #     code_bar = xt_get.get_bar(code_list=[code],period='tick',start_time=self.cur_date,end_time=self.cur_date)
                #     lastest_bar = code_bar.loc[code_bar['time']>traded_time]
                #     if len(lastest_bar)>0:
                #         max_high = lastest_bar['high'].max()
                #         # 计算最新价有没有比1分钟bar最高价回落0.08%
                #         down_ratio = (max_high-last_price) / max_high * 100
                #         if down_ratio > 0.08:
                #             sell_list.append({
                #                 'code': code,
                #                 'price': config['sell_price']
                #             })
                #             self.log(f'插入卖出队列：{code},sell_price:{config["sell_price"]},last_price:{last_price},max_high:{max_high}')
                #             continue
                # else:
                #     sell_list.append({
                #         'code': code,
                #         'price': config['sell_price']
                #     })
                #     self.log(f'插入卖出队列：{code},sell_price:{config["sell_price"]},last_price:{last_price}')
                #     continue

                # 全部采用冲高回落的方式进行卖出
                left_buy_point = buy_points_list_df.iloc[0]
                traded_time = left_buy_point['traded_time'] * 1000
                code_bar = xt_get.get_bar(code_list=[code],period='tick',start_time=self.cur_date,end_time=self.cur_date)
                lastest_bar = code_bar.loc[code_bar['time']>traded_time]
                if len(lastest_bar)>0:
                    max_high = lastest_bar['high'].max()
                    # 计算最新价有没有比1分钟bar最高价回落0.08%
                    down_ratio = (max_high-last_price) / max_high * 100
                    if down_ratio > 0.08:
                        # sell_list.append({
                        #     'code': code,
                        #     'price': config['sell_price']
                        # })
                        # self.log(f'插入卖出队列：{code},sell_price:{config["sell_price"]},last_price:{last_price},max_high:{max_high}')
                        
                        # 判断是否已经存在同类型挂单
                        stock_orders = self.get_stock_orders(code=code, order_type=xtconstant.STOCK_SELL)
                        if len(stock_orders) < 1:
                            # 卖出直接挂市价单快速卖出
                            self.sell(code=code, volume=self.daily_code_config[code]['single_purchase'])
                        else:
                            self.log(f'重复挂单，已经存在同类型的卖单：{code}')
                            wechat.send_md(content=f'# 重复挂单\n 已经存在同类型的卖单{code}')
                        continue
    

            if last_price < config['buy_price']:
                # 新增规则，下跌反弹再买入，防止直线下跌
                # 判断当日有没有购买过
                today_trade_df = self.get_today_trade_list(code=code)
                if len(today_trade_df)>0:
                    # 获取当日最后一条操作记录，判断最后一次操作和最新时间内，是否存在下跌反弹
                    latest_row = today_trade_df.iloc[-1]
                    latest_traded_time = latest_row['traded_time'] * 1000
                else:
                    latest_traded_time = 0
                
                code_bar = xt_get.get_bar(code_list=[code],period='1m',start_time=self.cur_date,end_time=self.cur_date)
                lastest_bar = code_bar.loc[code_bar['time']>latest_traded_time]
                if lastest_bar.empty:
                    continue
                min_close = lastest_bar['close'].min()
                # 计算最新价有没有比1分钟bar最低收盘价反弹0.08%
                up_ratio = (last_price-min_close) / min_close * 100
                if up_ratio>0.08:
                    buy_list.append({
                        'code': code,
                        'price': config['buy_price']
                    })
                    self.log(f'插入买入队列：{code},buy_price:{config["buy_price"]},last_price:{last_price},min_close:{min_close}')

        return {
            'sell_list': sell_list,
            'buy_list': buy_list
        }

    # 执行交易操作
    def trading(self):
        # 更新每日关注转债的最新tick价格
        self.update_tick()

        # 获取买卖列表
        res = self.get_buy_sell_list()
        sell_list = res['sell_list']
        buy_list = res['buy_list']
        
        # # 执行卖出操作
        # for item in sell_list:
        #     code = item['code']
        #     price = item['price']
        #     self.log(f'卖出：{code}')
        #     # 判断是否已经存在同类型挂单
        #     stock_orders = self.get_stock_orders(code=code, order_type=xtconstant.STOCK_SELL)
        #     if len(stock_orders) < 1:
        #         # 卖出直接挂市价单快速卖出
        #         res = self.sell(code=code, volume=self.daily_code_config[code]['single_purchase'])
        #     else:
        #         self.log(f'重复挂单，已经存在同类型的卖单：{code}')
        #         wechat.send_md(content=f'# 重复挂单\n 已经存在同类型的卖单{code}')

        # 假如没有符合购买的，退出
        if len(buy_list) <1:
            return
        
        # 假如有多个股需要购买，持仓量最少的股，优先购买
        code_position_list = []
        for item in buy_list:
            code = item['code']
            price = item['price']
            code_position_df = self.get_position(code=code)
            if len(code_position_df)<1:
                code_position_list.append({
                    'code': code,
                    'volume': 0,
                    'price': price
                })
            else:
                row = code_position_df.iloc[0]
                position_volume = row['can_use_volume']
                # 持仓量超过最大限制,不再继续购买
                if position_volume >= self.daily_code_config[code]['max_positon_volume']:
                    # print('达到最大持仓量', code)
                    wechat.send_md(content=f'# 达到最大持仓量\n 停止购买 {code} {position_volume}')
                    continue
                code_position_list.append({
                    'code': code,
                    'volume': position_volume,
                    'price': price
                })

        if len(code_position_list)<1:
            return
        code_position_df = pd.DataFrame(code_position_list)
        code_position_df.sort_values(by=['volume'], ascending=True, inplace=True)
        
        # 执行买入操作
        for index, item in code_position_df.iterrows():
            time.sleep(1)
            code = item['code']
            price = item['price']
            self.log(f'买入：{code}')
            # 判断是否已经存在同类型挂单
            stock_orders = self.get_stock_orders(code=code, order_type=xtconstant.STOCK_BUY)
            if len(stock_orders) < 1:
                res = self.buy(code=code, volume=self.daily_code_config[code]['single_purchase'], price=price)
            else:
                self.log(f'重复挂单，已经存在同类型的买单：{code}')
                wechat.send_md(content=f'# 重复挂单\n 已经存在同类型的买单{code}')

    # 强制清仓
    def sell_out(self):
        sellout_config = get_sellout_config()
        if len(sellout_config) < 1:
            return False
        for code in sellout_config:
            # 查看是否有持仓
            code_position_df = self.get_position(code=code)
            if code_position_df.empty:
                continue
            row = code_position_df.iloc[0]
            position_volume = row['can_use_volume']
            print('清仓', code, position_volume)
            self.sell(code=code, volume=position_volume)

    # 初始化每日任务
    def start(self):
        # 链接qmt初始化
        self.trader_start()

        self.cur_date = datetime.now().strftime('%Y-%m-%d')
        print('task is start', self.cur_date)
        # 加载配置
        self.load_config()
        # 强制清仓
        self.sell_out()

    # 关闭每日任务
    def stop(self):
        # 链接qmt初始化
        self.trader_stop()
        
    # 定时执行函数
    def run(self):
        self.cur_date = datetime.now().strftime('%Y-%m-%d')
        self.cur_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print('task is running', self.cur_time)
        # 获取上个周期的没有完成交易的挂单，然后撤销掉
        stock_orders = self.get_stock_orders()
        self.log(f'挂单数量：{len(stock_orders)}')
        for item in stock_orders:
            order_id = item['order_id']
            code = item['stock_code']
            print('撤单', order_id, code)
            # 同步撤单
            self.cancel_stock_order(order_id=order_id, code=code)

        # 开始执行交易操作
        self.trading()


if __name__ == '__main__':
    readme = '''
        网格策略实盘 10004
    '''
    print('hello world')

    strategy = CB_Strategy(job_id=10004)

    is_strategy_start = False
    while True:
        # 获取当前时间
        now_localtime = time.strftime("%H:%M:%S", time.localtime())
        if ('09:30:00' <= now_localtime <= '11:30:00') or ('13:00:00' <= now_localtime <= '15:00:00'):
            if not is_strategy_start:
                strategy.start()
                is_strategy_start = True
                is_close_check_trade = False

            strategy.run()
            time.sleep(3)
        elif now_localtime > '15:00:00':
            if is_strategy_start is True:
                # 收盘核对数据
                strategy.check_trade_log()
                wechat.send_md(content=f'# 核对交易数据完成\n')
                strategy.trader_stop()
                is_strategy_start = False
            print('收盘时间')
            time.sleep(60)
        else:
            # 获取当前日期
            cur_date = time.strftime("%Y-%m-%d", time.localtime())
            print(cur_date)
            # 判断是否开盘
            is_open = stock.is_trading_by_date(date=cur_date)
            if not is_open:
                print('当天不开盘', cur_date)
                break
                
            print('不在盘中时间', cur_date, now_localtime)
            time.sleep(5)