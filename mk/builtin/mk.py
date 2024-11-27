from mk import *

if_common     = RtlPackage('if_common')
peakrdl_intfs = RtlPackage('peakrdl_intfs')

if_common.rtl(find_files('if_common/*.sv'))

peakrdl_intfs.rtl       (find_files('peakrdl_intfs/*.sv'))
peakrdl_intfs.waivers   ('peakrdl_intfs/waivers.vlt')
peakrdl_intfs.skip_lint ()
