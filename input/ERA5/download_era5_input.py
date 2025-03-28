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
parser.add_argument('-H',dest='hourly',action='store_true',help="Download hourly data. Applies to 2D data only. [False]")
parser.add_argument('--o3',dest='ozone',action='store_true',help="also download ozone data.")
parser.add_argument('-a',dest='avg',action='store_true',help="Average over all downloaded timesteps. Passed on to convert_era5_to_input.py.")
parser.add_argument('-E',dest='ensembles',default=None,help="Create multiple input files for ensemble runs. Defines number of members required. Passed on to create_ensembles.py.")
parser.add_argument('-D',dest='download_only',action='store_true',help="Only download data, but don't do any further operations. Helpfull if node with internet access does not have enough memory.")
parser.add_argument('-A',dest='analysis_only',action='store_true',help="Only perform analysis steps. Assumens that all data has been downloaded (for instance, with -D flag).")
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
postFormat = '%Y%m%d'
start = datetime(**dates['sdate'])
if args.end_date is None:
    date_str_pl = start.strftime(dateFormat)
    date_str_ml = date_str_pl
    postfix     = start.strftime(postFormat)
else:
    end   = datetime(**dates['edate'])
    date_str_pl = '/'.join([start.strftime(dateFormat),end.strftime(dateFormat)])
    date_str_ml = date_str_pl.replace('/','/to/')
    postfix     = '-'.join([start.strftime(postFormat),end.strftime(postFormat)])


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

file3d = 'download_3d_levels.{0}.nc'.format(postfix)
file2d = 'download_2d.{0}.nc'.format(postfix)

file3d_ml = file3d.replace('levels','ml')
file3d_ml2pl = file3d.replace('levels','ml2pl')
file3d_pl = file3d.replace('levels','pl')

if not args.analysis_only:
    if args.end_date is None:
        print('DOWNLOADING 2D DATA FOR DATE {0}.'.format(args.start_date))
    else:
        print('DOWNLOADING 2D DATA BETWEEN {0} AND {1}.'.format(args.start_date,args.end_date))
    dict_2d = {
            'product_type'  : 'reanalysis',
            'variable'      : vars2d,
            'date'          : date_str_pl,
            'time'          : '00',
            'format'        : 'netcdf',
            'grid'          : args.grid,
    }
    if args.hourly:
        dict_2d['time'] : ','.join(['{0:02d}'.format(h) for h in np.arange(24)])
    c.retrieve(
        'reanalysis-era5-single-levels',
        dict_2d,
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

if not args.download_only:
    print('    CONVERTING MODEL LEVELS TO PRESSURE LEVELS')
    command = ['python','ecmwf_hybrid_to_pressure.py','-A',file3d_ml,'-S',file2d,'-o',file3d_ml2pl]
    print(' '.join(command))
    subprocess.run(command)

if not args.analysis_only:
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

if args.download_only:
    import sys
    print('ALL DATA DOWNLOADED. EXITING (-D FLAG SET).')
    sys.exit(0)

file3d_mix = file3d.replace('_levels','')
print('MERGING MODEL LEVEL AND PRESSURE LEVEL DATA INTO ONE FILE.')
command = ['python','mix_ml_pl.py','--ml',file3d_ml2pl,'--pl',file3d_pl,'-o',file3d_mix]
print(' '.join(command))
subprocess.run(command)

init_conds_file = file2d.replace('download_2d','initial_conditions')
tsurf_file = file2d.replace('download_2d','tsurf')

arglist = ['convert_era5_to_input.py','-A',file3d_mix,'-S',file2d,'-T',file2d,'--ts-out',tsurf_file,'-o',init_conds_file]
if ( args.avg ) or ( args.ensembles is not None ):
    arglist.append('-a')
if args.ozone:
    ozone_file = file2d.replace('download_2d','ozone')
    arglist = arglist + ['--o3-out',ozone_file]
print('CREATING INITIAL CONDITIONS.')
command = ['python']+arglist
print(' '.join(command))
subprocess.run(command)

if args.ensembles is not None:
    arglist = ['create_ensembles.py','-i',init_conds_file,'-t',tsurf_file,'-n',args.ensembles]
    if args.ozone:
        arglist = arglist + ['-O',ozone_file]
    print('CREATING ENSEMBLE INITIAL CONDITIONS.')
print('DONE.')

