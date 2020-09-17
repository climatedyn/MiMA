#!env python

import argparse
import cdsapi
from datetime import datetime, timedelta
import numpy as np
import subprocess
parser = argparse.ArgumentParser()
parser.add_argument('-s',dest='start_date',help="Start date. Format YYYY-MM-DD.")
parser.add_argument('-e',dest='end_date',default=None,help="End date (including). Format YYYY-MM-DD.")
parser.add_argument('-g',dest='grid',default=['1.0','1.0'],nargs=2,help="Select grid resolution. [1.0 x 1.0].")
parser.add_argument('--o3',dest='ozone',action='store_true',help="also download ozone data.")
parser.add_argument('-a',dest='avg',action='store_true',help="DO NOT average over all downloaded timesteps. Passed on to convert_era5_to_input.py.")
args = parser.parse_args()

in_dates = {'sdate':args.start_date,'edate':args.end_date}
dates = {}
datelist = ['sdate']
if args.end_date is not None:
    datelist.append('edate')
for date in datelist:
    year,month,day = [int(i) for i in in_dates[date].split(':')[0].split('-')]
    dates[date] = {
        'year' : year,
        'month': month,
        'day'  : day
    }

dateFormat = '%Y-%m-%d'
start = datetime(**dates['sdate'])
if args.end_date is None:
    date_str_pl = start.strftime(dateFormat)
    date_str_ml = date_str_pl
else:
    end   = datetime(**dates['edate'])
    date_str_pl = '/'.join([start.strftime(dateFormat),end.strftime(dateFormat)])
    date_str_ml = date_str_pl.replace('/','/to/')


p_levs = ['1','2','3','5','7','10',
          '20','30','50','70','100','125',
          '150','175','200','225','250','300',
          '350','400','450','500','550','600',
          '650','700','750','775','800','825',
          '850','875','900','925','950','975',
          '1000']
vars3d = ['u_component_of_wind','v_component_of_wind','temperature','specific_humidity']
if args.ozone:
    vars3d.append('ozone_mass_mixing_ratio')
vars2d = ['skin_temperature','surface_pressure']

m_levs = '1/3/5/7/9/11/13/15/17/19/21/23/25/27/29/31/33/35/37/39/41/43/45/47/49/51/53/55/57/59/61/63/65/67/69/71/73/75/77/79/81/83/85/87/89/91/93/95/97/99/101/103/105/107/109/111/113/115/117/119/121/123/125/127/129/131'
params = '130/131/132/133'
if args.ozone:
    params = params+'/203'

c = cdsapi.Client()

if args.end_date is None:
    file3d = 'download_3d_levels.{0}.nc'.format(args.start_date)
    file2d = 'download_2d.{0}.nc'.format(args.start_date)
else:
    file3d = 'download_3d.levels.{0}-{1}.nc'.format(args.start_date,args.end_date)
    file2d = 'download_2d.{0}-{1}.nc'.format(args.start_date,args.end_date)

file3d_ml = file3d.replace('levels','ml')
file3d_pl = file3d.replace('levels','pl')

if args.end_date is None:
    print('DOWNLOADING 2D DATA FOR DATE {0}.'.format(args.start_date))
else:
    print('DOWNLOADING 2D DATA BETWEEN {0} AND {1}.'.format(args.start_date,args.end_date))
c.retrieve(
    'reanalysis-era5-single-levels',
    {
        'product_type'  : 'reanalysis',
        'variable'      : vars2d,
        'date'          : date_str_pl,
        'time'          : '00',
        'format'        : 'netcdf',
        'grid'          : args.grid,
    },
    file2d)

if args.end_date is None:
    print('DOWNLOADING 3D DATA FOR DATE {0}.'.format(args.start_date))
else:
    print('DOWNLOADING 3D DATA BETWEEN {0} AND {1}.'.format(args.start_date,args.end_date))
print('  FIRST, ON MODEL LEVELS')
c.retrieve(
    'reanalysis-era5-complete',
    {
        'class'         : 'ea',
        'type'          : 'an',
        'stream'        : 'oper',
        'expver'        : '1',
        'param'         : params,
        'levelist'      : m_levs,
        'levtype'       : 'ml',
        'date'          : date_str_ml,
        'time'          : '00:00:00',
        'format'        : 'netcdf',
        'grid'          : args.grid,
    },
    file3d_ml)
print('    CONVERTING MODEL LEVELS TO PRESSURE LEVELS')
subprocess.run(['python','ecmwf_hybrid_to_pressure.py','-A',file3d_ml,'-S',file2d,'-o',file3d_ml])

print('  SECOND, ON PRESSURE LEVELS')
c.retrieve(
    'reanalysis-era5-pressure-levels',
    {
        'product_type'  : 'reanalysis',
        'variable'      : vars3d,
        'pressure_level': p_levs,
        'date'          : date_str_pl,
        'time'          : '00',
        'format'        : 'netcdf',
        'grid'          : args.grid,
    },
    file3d_pl)

file3d_mix = file3d.replace('.levels','')
print('MERGING MODEL LEVEL AND PRESSURE LEVEL DATA INTO ONE FILE.')
subprocess.run(['python','mix_ml_pl.py','--ml',file3d_ml,'--pl',file3d_pl,'-o',file3d_mix])

arglist = ['convert_era5_to_input.py','-A',file3d_mix,'-S',file2d,'-T',file2d,'--ts-out',file2d.replace('download_2d','tsurf'),'-o',file2d.replace('download_2d','initial_conditions')]
if args.avg:
    arglist.append('-a')
if args.ozone:
    arglist = arglist + ['--o3-out',file2d.replace('download_2d','ozone')]
print('CREATING INITIAL CONDITIONS.')
subprocess.run(['python']+arglist)

#subprocess.run(['rm',file3d_pl,file3d_ml,file2d,file3d_mix])


