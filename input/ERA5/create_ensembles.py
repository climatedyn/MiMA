#!env python

import xarray as xr
import numpy as np
from aostools import climate as ac
import argparse

parser = argparse.ArgumentParser(description="Create arbitrary number of input files to MiMA by bootstrapping a given input files along the time dimension. Requires multiple time steps within the input file.")
parser.add_argument('-i',dest='inputFile',help="Name of intial conditions file with multiple time steps.")
parser.add_argument('-t',dest='tsurfFile',default=None,help="Name of initial conditions file containing surface temperature.")
parser.add_argument('-O',dest='ozoneFile',default=None,help="Name of initial conditions file containing ozone.")
parser.add_argument('-n',dest='numMembers',type=int,help="Number of ensemble members.")
args = parser.parse_args()


# read the initial conditions from the respective files
init_conds = xr.open_dataset(args.inputFile)
if args.tsurfFile is not None:
    tsurf_init = xr.open_dataset(args.tsurfFile)
if args.ozoneFile is not None:
    ozone_init = xr.open_dataset(args.ozoneFile)


# get the random selection
rng = np.random.default_rng()
ntimes = len(init_conds.time)
randn = rng.integers(ntimes,size=(args.numMembers, ntimes))

def CreateMemberData(ds,filtr):
    ds = ds.isel(time=filtr).mean('time')
    if 'unlimited_dims' in ds.encoding:
        del ds.encoding['unlimited_dims']
    return ds

def CreateMemberName(base,m):
    return '_'.join([base.split('.nc')[0],'{0:03d}'.format(m)])+'.nc'

# now create the new inputs
for m in range(args.numMembers):
    ac.update_progress(m/args.numMembers,info='creating member files.')
    member = CreateMemberData(init_conds,randn[m,:])
    outFile = CreateMemberName(args.inputFile,m)
    member.to_netcdf(outFile)
    if args.tsurfFile is not None:
        member = CreateMemberData(tsurf_init,randn[m,:])
        outFile = CreateMemberName(args.tsurfFile,m)
        member.to_netcdf(outFile)
    if args.ozoneFile is not None:
        member = CreateMemberData(ozone_init,randn[m,:])
        outFile = CreateMemberName(args.ozoneFile,m)
ac.update_progress(1.0,info='creating member files.')
