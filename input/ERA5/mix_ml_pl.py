import xarray as xr
from aostools import inout as ai
import numpy as np
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('--pl',dest='pl_file',help="name of file containing data from ERA5-pressure levels.")
parser.add_argument('--ml',dest='ml_file',help="name of file containing data from ERA model levels.")
parser.add_argument('-o',dest='out_file',help="name of interpolated output file.")
args = parser.parse_args()


pl = xr.open_dataset(args.pl_file).rename({'pressure_level':'level','valid_time':'time'})
ml = xr.open_dataset(args.ml_file)
lon_attrs = ml.longitude.attrs
lat_attrs = ml.latitude.attrs
lev_attrs = ml.level.attrs
if len(ml.time) < 2:
    domain = ml.isel(time=0)
else:
    domain = ml
pli = pl.interp_like(domain)

weight = 0.5*(1 + np.tanh((pli.level-100)/10))

interps = []
for var in ml.data_vars:
    if 'level' in ml[var].dims:
        interp = weight*pli[var].reduce(np.nan_to_num) + ml[var].reduce(np.nan_to_num)*(1-weight)
    else:
        interp = ml[var]
    interp.name = var
    interps.append(interp)
out = xr.merge(interps)
out.longitude.attrs = lon_attrs
out.latitude.attrs = lat_attrs
out.level.attrs=lev_attrs
#print('Compressing data.')
#enc = ai.DefCompress(out,list(out.data_vars))
enc = {}
for var in out.variables:
    enc[var] = {'dtype':np.float32}
print('Writing '+args.out_file)
out.to_netcdf(args.out_file,encoding=enc)
