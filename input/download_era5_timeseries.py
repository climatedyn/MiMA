#!env python

import argparse
import cdsapi
from datetime import datetime, timedelta
import numpy as np
parser = argparse.ArgumentParser()
parser.add_argument('start_date',help="Start date. Format YYYY-MM-DD.")
parser.add_argument('end_date',help="End date (including). Format YYYY-MM-DD.")
parser.add_argument('--vars_3d',default=['ozone_mass_mixing_ratio'],nargs='+',help="List of 3D variables to download.")
parser.add_argument('--vars_2d',default=['skin_temperature'],nargs='+',help="List of 2D variables to download.")
parser.add_argument('-g',dest='grid',default=['1.0','1.0'],nargs=2,help="Select grid resolution. [1.0 x 1.0].")
args = parser.parse_args()

in_dates = {'sdate':args.start_date,'edate':args.end_date}
dates = {}
for date in ['sdate','edate']:
    year,month,day = [int(i) for i in in_dates[date].split(':')[0].split('-')]
    dates[date] = {
        'year' : year,
        'month': month,
        'day'  : day
    }

start = datetime(**dates['sdate'])
end   = datetime(**dates['edate'])
dateFormat = '%Y-%m-%d'
date_str = '/'.join([start.strftime(dateFormat),end.strftime(dateFormat)])

p_levs = ['1','2','3','5','7','10',
          '20','30','50','70','100','125',
          '150','175','200','225','250','300',
          '350','400','450','500','550','600',
          '650','700','750','775','800','825',
          '850','875','900','925','950','975',
          '1000']

c = cdsapi.Client()

print('DOWNLOADING 3D TIMESERIES BETWEEN {0} AND {1}.'.format(date_str.split('/')[0],date_str.split('/')[1]))
c.retrieve(
    'reanalysis-era5-pressure-levels',
    {
        'product_type'  : 'reanalysis',
        'variable'      : args.vars_3d,
        'pressure_level': p_levs,
        'date'          : date_str,
        'time'          : 00,
        'format'        : 'netcdf',
        'grid'          : args.grid,
    },
    'download_3d.nc')

print('DOWNLOADING 2D DATA.')
c.retrieve(
    'reanalysis-era5-single-levels',
    {
        'product_type'  : 'reanalysis',
        'variable'      : args.vars_2d,
        'date'          : date_str,
        'time'          : 00,
        'format'        : 'netcdf',
        'grid'          : args.grid,
    },
    'download_2d.nc')




