#!env python

import argparse
import cdsapi
parser = argparse.ArgumentParser()
parser.add_argument('date',help="Date for initial conditions. Format YYYY-MM-DD:HH.")
parser.add_argument('-t',dest='tsurf',action='store_true',help="Also download surface temperature (skt). [False].")
parser.add_argument('-g',dest='grid',default=['1.0','1.0'],nargs=2,help="Select grid resolution. [1.0 x 1.0].")
args = parser.parse_args()

hour = args.date.split(':')[1]
year,month,day = args.date.split(':')[0].split('-')

variables3 = ['specific_humidity','temperature','u_component_of_wind','v_component_of_wind']
variables2 = ['surface_pressure']
if args.tsurf:
    variables2.append('skin_temperature')


p_levs = ['1','2','3','5','7','10',
          '20','30','50','70','100','125',
          '150','175','200','225','250','300',
          '350','400','450','500','550','600',
          '650','700','750','775','800','825',
          '850','875','900','925','950','975',
          '1000']
    
c = cdsapi.Client()

print('DOWNLOADING 3D INITIAL CONDITIONS.')
c.retrieve(
    'reanalysis-era5-pressure-levels',
    {
        'product_type'  : 'reanalysis',
        'variable'      : variables3,
        'pressure_level': p_levs,
        'year' : year,
        'month': month,
        'day'  : day,
        'time' : hour,
        'format': 'netcdf',
        'grid' : args.grid,
    },
    'download_3d.{0}-{1}-{2}_{3}00.nc'.format(year,month,day,hour)
)

print('DOWNLOADING 2D INITIAL CONDITIONS.')
c.retrieve(
    'reanalysis-era5-single-levels',
    {
        'product_type'  : 'reanalysis',
        'variable'      : variables2,
        'year' : year,
        'month': month,
        'day'  : day,
        'time' : hour,
        'format': 'netcdf',
        'grid' : args.grid,
    },
    'download_2d.{0}-{1}-{2}_{3}00.nc'.format(year,month,day,hour)
)




