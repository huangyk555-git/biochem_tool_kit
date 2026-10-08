#!/usr/bin/env python3
"""Optional developer audit against independently installed Biopython; not an app dependency.
Usage: python3 scripts/scientific-crosscheck.py work/scientific.json
"""
import json, math, sys
import Bio
from Bio.SeqUtils import MeltingTemp
from Bio.SeqUtils.ProtParam import ProteinAnalysis
report=json.load(open(sys.argv[1],encoding='utf8'))
checks=0
def check(actual,expected,tolerance=1e-7):
    global checks
    assert math.isclose(actual,expected,rel_tol=0,abs_tol=tolerance), (actual,expected)
    checks+=1
for r in report['dna']:
    check(r['nn'],MeltingTemp.Tm_NN(r['sequence'],nn_table=MeltingTemp.DNA_NN3,dnac1=r['concentration'],dnac2=r['concentration'],Na=r['salt'],selfcomp=r['selfComplementary'],saltcorr=5))
    check(r['wallace'],MeltingTemp.Tm_Wallace(r['sequence']))
    if 'basic' in r: check(r['basic'],MeltingTemp.Tm_GC(r['sequence'],valueset=8,Na=r['salt']))
for r in report['proteins']:
    p=ProteinAnalysis(r['sequence'])
    check(r['mw'],p.molecular_weight());check(r['pi'],p.isoelectric_point(),1e-4)
    reduced,oxidized=p.molar_extinction_coefficient()
    check(r['reduced'],reduced);check(r['oxidized'],oxidized)
print(f'{checks} independent scientific comparisons passed; Biopython {Bio.__version__}.')
