import wrf
import xarray as xr
from aostools import inout as ai
import numpy as np
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-S',dest='surf_file',help="name of file containing surface pressure.")
parser.add_argument('-A',dest='atmos_file',help="name of file containing model level data.")
parser.add_argument('-o',dest='out_file',help="name of interpolated output file.")
args = parser.parse_args()

ps = xr.open_dataset(args.surf_file)['sp']
if 'number' in ps.dims: # ensemble mean
    ps = ps.mean('number')
#if len(ps.time) > 1:
#    print('FOUND {0} TIME STEPS IN {1}, TAKING THE FIRST, WHICH IS {2}.'.format(len(ps.time),args.surf_file,ps.time.values[0]))
#    ps = ps.isel(time=slice(0,1))
atmos = xr.open_dataset(args.atmos_file)
if 'number' in atmos.dims:
    atmos = atmos.mean('number')
#if len(atmos.time) > 1:
#    print('FOUND {0} TIME STEPS IN {1}, TAKING THE FIRST, WHICH IS {2}.'.format(len(atmos.time),args.atmos_file,atmos.time.values[0]))
#    atmos = atmos.isel(time=slice(0,1))
# now need to convert hybrid levels to pressure levels
#  a(n) and b(n) as per https://www.ecmwf.int/en/forecasts/documentation-and-support/137-model-levels
a_vals = [0.00000000e+00, 2.00036500e+00, 3.10224100e+00, 4.66608400e+00,
   6.82797700e+00, 9.74696600e+00, 1.36054240e+01, 1.86089310e+01,
   2.49857180e+01, 3.29857100e+01, 4.28792420e+01, 5.49554630e+01,
   6.95205760e+01, 8.68958820e+01, 1.07415741e+02, 1.31425507e+02,
   1.59279404e+02, 1.91338562e+02, 2.27968948e+02, 2.69539581e+02,
   3.16420746e+02, 3.68982361e+02, 4.27592499e+02, 4.92616028e+02,
   5.64413452e+02, 6.43339905e+02, 7.29744141e+02, 8.23967834e+02,
   9.26344910e+02, 1.03720117e+03, 1.15685364e+03, 1.28561035e+03,
   1.42377014e+03, 1.57162292e+03, 1.72944898e+03, 1.89751929e+03,
   2.07609595e+03, 2.26543164e+03, 2.46577051e+03, 2.67734814e+03,
   2.90039136e+03, 3.13511938e+03, 3.38174365e+03, 3.64046826e+03,
   3.91149048e+03, 4.19493066e+03, 4.49081738e+03, 4.79914941e+03,
   5.11989502e+03, 5.45299072e+03, 5.79834473e+03, 6.15607422e+03,
   6.52694678e+03, 6.91187061e+03, 7.31186914e+03, 7.72741211e+03,
   8.15935400e+03, 8.60852539e+03, 9.07640039e+03, 9.56268262e+03,
   1.00659785e+04, 1.05846318e+04, 1.11166621e+04, 1.16600674e+04,
   1.22115479e+04, 1.27668730e+04, 1.33246689e+04, 1.38813311e+04,
   1.44321396e+04, 1.49756152e+04, 1.55082568e+04, 1.60261152e+04,
   1.65273223e+04, 1.70087891e+04, 1.74676133e+04, 1.79016211e+04,
   1.83084336e+04, 1.86857188e+04, 1.90312891e+04, 1.93435117e+04,
   1.96200430e+04, 1.98593906e+04, 2.00599316e+04, 2.02196641e+04,
   2.03378633e+04, 2.04123086e+04, 2.04420781e+04, 2.04257188e+04,
   2.03618164e+04, 2.02495117e+04, 2.00870859e+04, 1.98740254e+04,
   1.96085723e+04, 1.92902266e+04, 1.89174609e+04, 1.84897070e+04,
   1.80069258e+04, 1.74718398e+04, 1.68886875e+04, 1.62620469e+04,
   1.55966953e+04, 1.48984531e+04, 1.41733242e+04, 1.34277695e+04,
   1.26682578e+04, 1.19013398e+04, 1.11333047e+04, 1.03701758e+04,
   9.61751562e+03, 8.88045312e+03, 8.16337500e+03, 7.47034375e+03,
   6.80442188e+03, 6.16853125e+03, 5.56438281e+03, 4.99379688e+03,
   4.45737500e+03, 3.95596094e+03, 3.48923438e+03, 3.05726562e+03,
   2.65914062e+03, 2.29424219e+03, 1.96150000e+03, 1.65947656e+03,
   1.38754688e+03, 1.14325000e+03, 9.26507813e+02, 7.34992188e+02,
   5.68062500e+02, 4.24414063e+02, 3.02476563e+02, 2.02484375e+02,
   1.22101563e+02, 6.27812500e+01, 2.28359380e+01, 3.75781300e+00,
   0.00000000e+00, 0.00000000e+00]
b_vals = [0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00, 0.00000e+00,
   7.00000e-06, 2.40000e-05, 5.90000e-05, 1.12000e-04, 1.99000e-04,
   3.40000e-04, 5.62000e-04, 8.90000e-04, 1.35300e-03, 1.99200e-03,
   2.85700e-03, 3.97100e-03, 5.37800e-03, 7.13300e-03, 9.26100e-03,
   1.18060e-02, 1.48160e-02, 1.83180e-02, 2.23550e-02, 2.69640e-02,
   3.21760e-02, 3.80260e-02, 4.45480e-02, 5.17730e-02, 5.97280e-02,
   6.84480e-02, 7.79580e-02, 8.82860e-02, 9.94620e-02, 1.11505e-01,
   1.24448e-01, 1.38313e-01, 1.53125e-01, 1.68910e-01, 1.85689e-01,
   2.03491e-01, 2.22333e-01, 2.42244e-01, 2.63242e-01, 2.85354e-01,
   3.08598e-01, 3.32939e-01, 3.58254e-01, 3.84363e-01, 4.11125e-01,
   4.38391e-01, 4.66003e-01, 4.93800e-01, 5.21619e-01, 5.49301e-01,
   5.76692e-01, 6.03648e-01, 6.30036e-01, 6.55736e-01, 6.80643e-01,
   7.04669e-01, 7.27739e-01, 7.49797e-01, 7.70798e-01, 7.90717e-01,
   8.09536e-01, 8.27256e-01, 8.43881e-01, 8.59432e-01, 8.73929e-01,
   8.87408e-01, 8.99900e-01, 9.11448e-01, 9.22096e-01, 9.31881e-01,
   9.40860e-01, 9.49064e-01, 9.56550e-01, 9.63352e-01, 9.69513e-01,
   9.75078e-01, 9.80072e-01, 9.84542e-01, 9.88500e-01, 9.91984e-01,
   9.95003e-01, 9.97630e-01, 1.00000e+00]
pf_vals = [0.01,0.0255,0.0388,0.0575,0.0829,0.1168,0.1611,0.218,0.2899,
   0.3793,0.4892,0.6224,0.7821,0.9716,1.1942,1.4535,1.7531,2.0965,2.4875,
   2.9298,3.427,3.9829,4.601,5.2851,6.0388,6.8654,7.7686,8.7516,9.8177,
   10.9703,12.2123,13.5469,14.977,16.5054,18.1348,19.8681,21.7076,23.656,
   25.7156,27.8887,30.1776,32.5843,35.1111,37.7598,40.5321,43.4287,46.4498,
   49.5952,52.8644,56.2567,59.7721,63.4151,67.1941,71.1187,75.1999,79.4496,83.8816,
   88.5112,93.3527,98.4164,103.71,109.2417,115.0198,121.0526,127.3487,133.917,
   140.7663,147.9058,155.3448,163.0927,171.1591,179.5537,188.2867,197.3679,
   206.8078,216.6166,226.805,237.3837,248.3634,259.7553,271.5704,283.82,296.5155,
   309.6684,323.2904,337.3932,351.9887,367.0889,382.7058,398.8516,415.5387,432.7792,
   450.5858,468.9708,487.947,507.5021,527.5696,548.0312,568.7678,589.6797,610.6646,
   631.6194,652.4424,673.0352,693.3043,713.1631,732.5325,751.3426,769.5329,787.0528,
   803.8622,819.9302,835.2358,849.7668,863.519,876.4957,888.7066,900.1669,910.8965,
   920.9193,930.2618,938.9532,947.024,954.5059,961.4311,967.8315,973.7392,979.1852,
   984.2002,988.8133,993.0527,996.9452,1000.5165,1003.7906,1006.79,1009.5363,1012.0494]
levs = np.arange(len(a_vals))+1
a = xr.DataArray(a_vals,coords=[('level',levs)])
b = xr.DataArray(b_vals,coords=[('level',levs)])
phalf = (ps*b + a)*0.01 # Pa to hPa
# pf is the pressure levels we want to interpolate onto
#  they are between the phalf levels
pf= xr.DataArray(pf_vals,coords=[('level',0.5*(levs[1:] + levs[:-1]))])
# pfull are the 3D pressures on pf levels
pfull = phalf.interp_like(pf).assign_coords({'level':levs[:-1]})
# the 3D file does not necessarily contain all model levels, so need to
#  select only the ones in the file
pfull = pfull.sel(level=atmos.level)
plev  = pf.assign_coords({'level':(pf.level-0.5).astype(int)}).sel(level=atmos.level.values)
# extrapolation results in NaNs in wrf.interpz3d
epsilon = 1.e-5
if plev[1] > pfull.min() and plev[0] < pfull.min():
    plev[0] = pfull.min()+epsilon
#  finally run wrf.interpz3d to interpolate model levels onto pressure levels
out_vars = []
for var in atmos.data_vars:
    out = wrf.interpz3d(atmos[var],pfull.transpose('time','level','latitude','longitude'),plev,missing=np.nan)
    #out = wrf.interplevel(atmos[var],pfull.transpose('time','level','latitude','longitude'),plev,missing=np.nan,squeeze=False)
    # fill value is handeled by DefCompress later
    del out.attrs['missing_value']
    del out.attrs['_FillValue']
    del out.attrs['vert_units']
    out.name = var
    out_vars.append(out)
ds = xr.merge(out_vars)
#print('Compressing variables')
#enc = ai.DefCompress(ds,list(atmos.data_vars))
enc = {}
for var in ds.variables:
    enc[var] = {'dtype':np.float32}
#print('Writing file '+args.out_file)
ds.to_netcdf(args.out_file,encoding=enc)
print('Written file '+args.out_file)
