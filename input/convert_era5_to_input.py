#!env python

## We assume one downloads ERA5 data in three files.
# File 1: 3D atmospheric fields. These are u,v,t,q and need to be renamed ucomp,vcomp,temp,sphum. These are initial conditions and do not need to contain time (but can).
# File 2: 3D ozone. This will have to be a timeseries over the entire simulation period (or a climatology().
# File 3: 2D surface fields. These are sp,t2m. sp needs to be renamed ps and added to File 1, while t2m is read independently by the surface code and goes into its own file.
#
#
# For all files, need to rename lon-lat and invert lat.
# For 3D files, need to change units to 'hPa'.
##

import xarray as xr

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-A',dest='atmos_file',help='Name of ERA5 file containing u,v,t,q (all required).')
parser.add_argument('-S',dest='surf_file', help='Name of ERA5 file containing sp (required),t2m (optional).')
parser.add_argument('-O',dest='o3_file',default=None,help='Name of ERA5 file containing o3 (optional).')
parser.add_argument('--3d-out',dest='a_out',help='Name of 3D initial conditions file for MiMA.')
parser.add_argument('--ts-out',dest='ts_out',default=None,help='Name of surface temperature input file for MiMA (optional).')
parser.add_argument('--o3-out',dest='o3_out',default=None,help='Name of ozone input file for MiMA (optional).')
parser.add_argument('-a',dest='average',action='store_true',help='Perform time average. This will create a time-independent input which will be considered climatology in MiMA. [False]')
args = parser.parse_args()


if args.o3_file is not None and args.o3_out is None:
    raise ValueError('-O has been set - need to set --o3-out!')

new_names = {
    'longitude':'lon',
    'latitude' :'lat',
    'level'    :'pfull',
    'u'        :'ucomp',
    'v'        :'vcomp',
    't'        :'temp',
    'q'        :'sphum',
    'sp'       :'ps',
    }

da = xr.open_dataset(args.atmos_file).sortby('latitude')
ds = xr.open_dataset(args.surf_file).sortby('latitude')
if args.average:
    da = da.mean(dim='time')
    ds = ds.mean(dim='time')
if args.o3_file is not None:
    do = xr.open_dataset(args.o3_file)['o3'].sortby('latitude')
    if args.average:
        do = do.mean(dim='time')

# now do all the necessary conversions
for var in new_names.keys():
    if var in da:
        da = da.rename({var:new_names[var]})
        if var == 'level':
            da[new_names[var]].attrs['units'] = 'hPa'
    if var in ds:
        ds = ds.rename({var:new_names[var]})

# finally, write the new files
mima_init3 = xr.merge([da['ucomp'],da['vcomp'],da['temp'],da['sphum'],ds['ps']])
mima_init3.to_netcdf(args.a_out)
print(args.a_out)
if args.ts_out is not None:
    ds['t2m'].to_netcdf(args.ts_out)
    print(args.ts_out)
if args.o3_out is not None:
    if args.o3_file is None:
        da['o3'].to_netcdf(args.o3_out)
    else:
        do.to_netcdf(args.o3_out)
    print(args.o3_out)
