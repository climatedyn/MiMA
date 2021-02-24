#!env python

## We assume one downloads ERA5 data in multiple files.
# File 1: 3D atmospheric fields. These are u,v,t,q and need to be renamed ucomp,vcomp,temp,sphum. These are initial conditions and do not need to contain time. To remove time, these fields are averaged over time, assuming we only have one timestep anyway.
# Note that this means if ozone is present, it will also be time averaged here. Use `convert_era5_to_timeseries.py` if time-varying ozone is needed.
# File 2a: Ozone if required. o3 can be in File 1 as well.
# File 2b: Surface fields. These are sp (required) and possibly t2m or skt. sp needs to be renamed ps and added to File 1, while t2m is read independently by the surface code and goes into its own file.
#
#
# For all files, need to rename lon-lat and invert lat.
# For 3D files, need to change units to 'hPa'.
##

import xarray as xr

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-A',dest='atmos_file',default=None,help='Name of ERA5 file containing u,v,t,q (all required).')
parser.add_argument('-S',dest='surf_file',default=None,help='Name of ERA5 file containing sp (required),t2m or skt (optional).')
parser.add_argument('-T',dest='ts_file',default=None,help='Name of ERA5 file containing t2m or skt (optional). This is in case surface temperature is not inside `surf_file`.')
parser.add_argument('-O',dest='o3_file',default=None,help='Name of ERA5 file containing o3 (optional).')
parser.add_argument('-o',dest='a_out',default=None,help='Name of 3D initial conditions file for MiMA.')
parser.add_argument('--ts-out',dest='ts_out',default=None,help='Name of surface temperature input file for MiMA (optional).')
parser.add_argument('--o3-out',dest='o3_out',default=None,help='Name of ozone input file for MiMA (optional).')
parser.add_argument('-a',dest='average',action='store_false',help='DO NOT average over time. Averaging is recommended for initial conditions, but not for continuous forcing such as ozone or surface temperature.')
parser.add_argument('-O',dest='o3_file',default=None,help='Name of ERA5 file containing o3 (optional).')
parser.add_argument('-o',dest='a_out',default=None,help='Name of 3D initial conditions file for MiMA.')
parser.add_argument('--ts-out',dest='ts_out',default=None,help='Name of surface temperature input file for MiMA (optional).')
parser.add_argument('--o3-out',dest='o3_out',default=None,help='Name of ozone input file for MiMA (optional).')
parser.add_argument('-a',dest='average',action='store_true',help='Perform time average. This will create a time-independent input which will be considered climatology in MiMA. [False]')
args = parser.parse_args()


if args.o3_file is not None and args.o3_out is None:
    raise ValueError('-O has been set - need to set --o3-out!')


def DefCompress(x,varName=None):
    """Stolen from `aostools`.
       Produce encoding dictionary for to_netcdf(encoding=encodeDict).

        INPUTS:
            x       : either a xarray.DataArray or xarray.Dataset
            varName : only encode that variable. If None, encode all variables
        OUTPUTS:
            encodeDict : dictionary containing compressing information for each
                          variable. To be used as x.to_netcdf(encoding=encodeDict)
    """
    import numpy as np
    # check whether x is a Dataset or DataArray
    try:
        keys = x.variables.keys()
        is_dataset = True
    except:
        is_dataset = False
    # make a list of variables
    if varName is None:
        vars = []
        if is_dataset:
            for var in x.data_vars.keys():
                vars.append(var)#.encode("utf-8"))
        else:
            vars.append(x.name)#.encode("utf-8"))
    else:
        if isinstance(varName,list):
            vars = varName
        else:
            vars = [varName]
    # now loop over all variables
    encodeDict = {}
    bytes = 16
    fillVal = -2**(bytes-1)
    for var in vars:
        if is_dataset:
            filtr = np.isfinite(x[var])
            dataMin = x[var].where(filtr).min().values
            dataMax = x[var].where(filtr).max().values
        else:
            filtr = np.isfinite(x)
            dataMin = x.where(filtr).min().values
            dataMax = x.where(filtr).max().values
        scale_factor=(dataMax - dataMin) / (2**bytes - 2)
        add_offset = (dataMax + dataMin) / 2
        encodeDict[var] = {
            'dtype':'short',
            'scale_factor':scale_factor,
            'add_offset': add_offset,
            '_FillValue': fillVal}
    return encodeDict
    
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

if args.atmos_file is not None:
    da = xr.open_dataset(args.atmos_file).sortby('latitude')
    if len(da.time) > 1 and args.average:
        print('WARNING: AVERAGING {0} OVER {1} TIMESTEPS.'.format(args.atmos_file,len(da.time)))
    if args.average:
        da = da.mean(dim='time')
if args.surf_file is not None:
    ds = xr.open_dataset(args.surf_file).sortby('latitude')
    if len(ds.time) > 1 and args.average:
        print('WARNING: AVERAGING {0} OVER {1} TIMESTEPS.'.format(args.surf_file,len(ds.time)))
    if args.average:
        ds = ds.mean(dim='time')
if args.ts_file is not None:
    dt = xr.open_dataset(args.ts_file).sortby('latitude')
    if args.average:
        if len(dt.time) > 1:
              print('WARNING: AVERAGING {0} OVER {1} TIMESTEPS.'.format(args.ts_file,len(dt.time)))
        dt = dt.mean(dim='time')
if args.o3_file is not None:
    do = xr.open_dataset(args.o3_file).sortby('latitude')
    if args.average:
        if len(do.time) > 1:
              print('WARNING: AVERAGING {0} OVER {1} TIMESTEPS.'.format(args.o3_file,len(do.time)))
    da = da.mean(dim='time')
if args.surf_file is not None:
    ds = xr.open_dataset(args.surf_file).sortby('latitude')
    if len(ds.time) > 1:
        print('WARNING: AVERAGING {0} OVER {1} TIMESTEPS.'.format(args.surf_file,len(ds.time)))
    ds = ds.mean(dim='time')
if args.ts_file is not None:
    dt = xr.open_dataset(args.ts_file).sortby('latitude')
    if args.average:
        if len(dt.time) > 1:
              print('WARNING: AVERAGING {0} OVER {1} TIMESTEPS.'.format(args.ts_file,len(dt.time)))
        dt = dt.mean(dim='time')
if args.o3_file is not None:
    do = xr.open_dataset(args.o3_file).sortby('latitude')
    if args.average:
        do = do.mean(dim='time')

# now do all the necessary conversions
for var in new_names.keys():
    if args.atmos_file is not None:
        if var in da:
            da = da.rename({var:new_names[var]})
            if var == 'level':
                da[new_names[var]].attrs['units'] = 'hPa'
    if args.surf_file is not None:
        if var in ds:
            ds = ds.rename({var:new_names[var]})
    if args.ts_file is not None:
        if var in dt:
            dt = dt.rename({var:new_names[var]})
    if args.o3_file is not None:
        if var in do:
            do = do.rename({var:new_names[var]})
            if var == 'level':
                do[new_names[var]].attrs['units'] = 'hPa'
mds = []
if args.atmos_file is not None:
    mds.append(da)
if args.surf_file is not None:
    mds.append(ds)
if args.ts_file is not None:
    mds.append(dt)
dd = xr.merge(mds)
##########################################################
# finally, write the new files
##########################################################
ftype = 'f4'
ttype = ftype
#tunit = 'days since 1970-01-01T00:00:00'
tunit = str(dd.time[0].dt.strftime('days since %Y-%m-%dT%H:%M:%S').values)
tcal  = 'julian'
t_enc = {'units':tunit,'calendar':tcal,'dtype':ttype}
#
#
if args.a_out is not None:
    mima_init3 = xr.merge([dd['ucomp'],dd['vcomp'],dd['temp'],dd['sphum'],dd['ps']])
    #
    encode_dict = DefCompress(mima_init3)
    encode_dict['pfull']= {'dtype':ftype}
    if 'time' in mima_init3:
        encode_dict['time'] = t_enc
        mima_init3.encoding['unlimited_dims'] = ['time']
    mima_init3.to_netcdf(args.a_out,encoding=encode_dict)
    print(args.a_out)
if args.ts_out is not None:
    for var in dd.data_vars:
        if var == 't2m' or var == 'skt':
            break
    encode_dict = DefCompress(dd,var)
    if 'time' in dd:
        encode_dict['time'] = t_enc
        dd.encoding['unlimited_dims'] = ['time']
    dd[var].to_netcdf(args.ts_out,encoding=encode_dict)
    print(args.ts_out)
if args.o3_out is not None:
    if args.o3_file is None:
        encode_dict = DefCompress(da,'o3')
        encode_dict['pfull']= {'dtype':ftype}
        if 'time' in da:
            encode_dict['time'] = t_enc
            da.encoding['unlimited_dims'] = ['time']
        da['o3'].to_netcdf(args.o3_out,encoding=encode_dict)
    else:
        encode_dict = DefCompress(do)
        encode_dict['pfull']= {'dtype':ftype}
        if 'time' in do:
            encode_dict['time'] = t_enc
            do.encoding['unlimited_dims'] = ['time']
        do.to_netcdf(args.o3_out,encoding=encode_dict)
# finally, write the new files
##########################################################
ftype = 'f4'
ttype = ftype
tunit = 'days since 0001-01-01T00:00:00'
tcal  = 'julian'
t_enc = {'units':tunit,'calendar':tcal,'dtype':ttype}
#
#
if args.a_out is not None:
    mima_init3 = xr.merge([dd['ucomp'],dd['vcomp'],dd['temp'],dd['sphum'],dd['ps']])
    #
    encode_dict = DefCompress(mima_init3)
    encode_dict['pfull']= {'dtype':ftype}
    if 'time' in mima_init3:
        encode_dict['time'] = t_enc
    mima_init3.to_netcdf(args.a_out,encoding=encode_dict)
    print(args.a_out)
if args.ts_out is not None:
    for var in dd.data_vars:
        if var == 't2m' or var == 'skt':
            break
    encode_dict = DefCompress(dd,var)
    if 'time' in dd:
        encode_dict['time'] = t_enc
    dd[var].to_netcdf(args.ts_out,encoding=encode_dict)
    print(args.ts_out)
if args.o3_out is not None:
    if args.o3_file is None:
        encode_dict = DefCompress(da,'o3')
        encode_dict['pfull']= {'dtype':ftype}
        if 'time' in da:
            encode_dict['time'] = t_enc
        da['o3'].to_netcdf(args.o3_out,encoding=encode_dict)
    else:
        do.to_netcdf(args.o3_out)
    print(args.o3_out)
