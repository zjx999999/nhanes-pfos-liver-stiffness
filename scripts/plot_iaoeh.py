"""Presentation-only plotting from frozen aggregate CSVs. No raw-data or model analysis."""
from pathlib import Path
import csv,json,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
from matplotlib.transforms import blended_transform_factory
from matplotlib.colors import to_rgb
from matplotlib.lines import Line2D
import re
R=Path(__file__).resolve().parents[1];D=R/'data';F=R/'figures'/'iaoeh';F.mkdir(parents=True,exist_ok=True)
plt.rcParams.update({'font.family':'Arial','font.size':9.5,'axes.titlesize':10.5,'axes.labelsize':10,'xtick.labelsize':9.5,'ytick.labelsize':9.5,'svg.fonttype':'none','pdf.fonttype':42,'ps.fonttype':42,'axes.spines.top':False,'axes.spines.right':False,'axes.linewidth':.7,'savefig.facecolor':'white'})
C=['#1B4F72','#C24D00'];M=['o','s'];P=['2017-2018','2021-2023'];Y=['2017–18','2021–23'];audit=[];critical=[];points=[];plot_rows=[];flow_connections=[];domain_markers=[]
def read(n):return list(csv.DictReader((D/n).open()))
T=read('table1.csv');prim=read('primary_model_comparison.csv');sens=read('sensitivity_with_probe.csv');sec=read('secondary_models.csv');flows=read('sample_flow.csv');missing=read('missingness.csv');selection=read('complete_case_selection.csv');dist=read('exposure_distribution.csv')
def f(x):return float(x)
def fmt(x):
 x=f(x);return f'{x:.5f}' if 0<abs(x)<.001 else f'{x:.4f}'
def pv(x):return '<0.0001' if f(x)<.0001 else f'{f(x):.4f}' if f(x)<.001 else f'{f(x):.3f}'
def tr(p,v,cat=''):return next(r for r in T if r['period']==p and r['variable']==v and r['category']==cat)
def light(c,a):return tuple(a*x+(1-a) for x in to_rgb(c))
def clean(ax):ax.spines['left'].set_visible(False);ax.grid(axis='x',color='#E4E7EA',lw=.6,zorder=0)
def title(fig,x,y,t):fig.text(x,y,t,fontweight='bold',fontsize=10.5,ha='left')
def panel(ax,l,t):ax.set_title(l+'  '+t,loc='left',fontweight='bold',pad=13)
def legend(fig,x=.5,y=.01):
 fig.legend(handles=[Line2D([],[],color=C[i],marker=M[i],ls='none',label=Y[i]) for i in range(2)],loc='lower center',bbox_to_anchor=(x,y),ncol=2,frameon=False,fontsize=9.5)
def save(fig,n,source,description):
 for ax in fig.axes:
  if ax.axison:
   lo,hi=sorted(ax.get_xlim());ax.set_xticks([t for t in ax.get_xticks() if lo<=t<=hi])
 fig.canvas.draw();ren=fig.canvas.get_renderer();bounds=fig.bbox;clipped=[]
 for t in fig.findobj(matplotlib.text.Text):
  if not t.get_visible() or not t.get_text():continue
  bb=t.get_window_extent(ren)
  if bb.x0<bounds.x0-1 or bb.x1>bounds.x1+1 or bb.y0<bounds.y0-1 or bb.y1>bounds.y1+1:clipped.append(t.get_text())
 collisions=[]
 for i,a in enumerate(critical):
  if a.figure is not fig:continue
  ab=a.get_window_extent(ren)
  for b in critical[i+1:]:
   if b.figure is fig and ab.overlaps(b.get_window_extent(ren)):collisions.append([a.get_text(),b.get_text()])
  for b in points:
   if b.figure is fig and ab.overlaps(b.get_window_extent(ren)):collisions.append([a.get_text(),'data marker'])
 title_checks=[{'text':t.get_text(),'horizontal_alignment':t.get_ha(),'x0_pixels':t.get_window_extent(ren).x0} for t in fig.findobj(matplotlib.text.Text) if t.get_text() and re.match(r'^[abc]\s+',t.get_text())]
 assert all(t['horizontal_alignment']=='left' for t in title_checks)
 extra={'panel_title_alignment':title_checks}
 if n=='Figure1':
  records=[]
  for ar,upper,lower in flow_connections:
   ab=ar.arrow_patch.get_window_extent(ren);ub=upper.get_window_extent(ren);lb=lower.get_window_extent(ren)
   stroke=max(upper.get_linewidth(),lower.get_linewidth(),ar.arrow_patch.get_linewidth())*fig.dpi/72/2
   top_clearance=ub.y0-ab.y1-2*stroke;bottom_clearance=ab.y0-lb.y1-2*stroke
   assert top_clearance>0 and bottom_clearance>0,(top_clearance,bottom_clearance)
   records.append({'upper_box_to_arrow_clearance_pixels':top_clearance,'arrow_to_lower_box_clearance_pixels':bottom_clearance})
  extra['arrow_box_clearances']=records;extra['arrow_box_touch_or_overlap']=False
 if n=='Figure3':
  overlaps=[]
  for i,(name,a) in enumerate(domain_markers):
   aa=a.get_window_extent(ren)
   for other,b in domain_markers[i+1:]:
    if aa.overlaps(b.get_window_extent(ren)):overlaps.append([name,other])
  assert not overlaps,overlaps
  extra['domain_median_marker_overlaps']=overlaps;extra['domain_markers']=len(domain_markers)
 assert not clipped and not collisions,{'figure':n,'clipped':clipped,'collisions':collisions}
 (R/'evidence'/f'{n}_geometry.json').write_text(json.dumps({'outside_figure':clipped,'critical_label_collisions':collisions,**extra},indent=2))
 output_name={'Figure1':'Fig1','Figure2':'FigS2','Figure3':'FigS3','Figure4':'Fig2','Figure5':'FigS4','Figure6':'Fig3','SupplementaryFigureS1':'FigS1'}[n]
 for ext in ['png','pdf','svg','eps']:
  if ext=='svg':
   with plt.rc_context({'svg.fonttype':'path'}):fig.savefig(F/f'{output_name}.{ext}')
  else:fig.savefig(F/f'{output_name}.{ext}',**({'dpi':600} if ext in ['png','tif'] else {}))
 audit.append({'figure':n,'size_inches':list(fig.get_size_inches()),'source_files':source,'description':description,'minimum_font_pt':min(t.get_fontsize() for t in fig.findobj(matplotlib.text.Text) if t.get_text()),'new_model':False});plt.close(fig)
# 1: preserve nested sample domains; separate weighted selection summaries.
fig=plt.figure(figsize=(6.5,8.0));a=fig.add_axes([.05,.59,.90,.34]);a.set_axis_off();panel(a,'a','Survey samples and analytic domains')
stages=['DEMO rows','Age >=20','PFAS positive-weight adults','Eligible adult PFAS/LUX intersection','Eligible complete main-model covariates'];labs=['Survey participants','Adults aged ≥20 years','Positive PFAS weight','Also complete VCTE','Primary complete cases']
for j,p in enumerate(P):
 a.text(.25+.5*j,.985,Y[j],ha='center',color=C[j],fontweight='bold',transform=a.transAxes)
 ns=[int(next(r['n'] for r in flows if r['period']==p and r['stage']==stage)) for stage in stages]
 boxes=[];ys=[]
 for k,(lab,n) in enumerate(zip(labs,ns)):
  y=.80-k*.19;x=.015+j*.5
  box=FancyBboxPatch((x,y),.46,.12,boxstyle='round,pad=0.003',facecolor='#F2F5F7',edgecolor=C[j],lw=.9,transform=a.transAxes)
  a.add_patch(box);boxes.append(box);ys.append(y)
  ratio='' if k==0 else f' | {100*n/ns[k-1]:.1f}% of prior'
  a.text(x+.23,y+.060,f'{lab}\nn={n:,}{ratio}',ha='center',va='center',fontsize=10.5,transform=a.transAxes)
 for k in range(4):
  # True patch boundaries include pad=.003; both endpoints lie strictly in the gap.
  arrow=a.annotate('',xy=(x+.23,ys[k+1]+.12+.003+.007),xytext=(x+.23,ys[k]-.003-.007),xycoords='axes fraction',arrowprops={'arrowstyle':'->','color':C[j],'lw':1.0,'mutation_scale':10,'shrinkA':2,'shrinkB':2})
  flow_connections.append((arrow,boxes[k],boxes[k+1]))
b=fig.add_axes([.25,.36,.68,.14]);panel(b,'b','Missing primary-model variables (%)')
for j,p in enumerate(P):
 vv=[f(next(r['pct_missing'] for r in missing if r['period']==p and r['variable']==x)) for x in ['log2_PFOS','BMXBMI','alcohol_status']];ys=np.arange(3)+(.17 if j else -.17)
 b.barh(ys,vv,height=.27,color=C[j])
 for y,x in zip(ys,vv):b.text(x+.18,y,f'{x:.1f}%',va='center',fontsize=9.5)
b.set(yticks=range(3),yticklabels=['Total PFOS','BMI','Alcohol category'],xlim=(0,16));b.invert_yaxis();clean(b)
c=fig.add_axes([.25,.12,.46,.15]);panel(c,'c','Available PFOS by inclusion status')
for j,p in enumerate(P):
 for k,status in enumerate(['FALSE','TRUE']):
  r=next(r for r in selection if r['period']==p and r['variable']=='PFOS_total' and r['included_complete_case']==status);y=k+(.20 if j else -.20)
  c.errorbar(f(r['mean']),y,xerr=f(r['se']),color=C[j],marker=M[j],ms=5,capsize=3,ls='none')
  c.text(1.06,y,f'{f(r["mean"]):.2f} (±{f(r["se"]):.2f})',transform=c.get_yaxis_transform(),va='center',fontsize=9.5,color=C[j])
c.set(yticks=[0,1],yticklabels=['Excluded','Included'],ylim=(1.55,-.55),xlim=(2,7.3),xlabel='Weighted mean PFOS (ng/mL)');clean(c);legend(fig)
save(fig,'Figure1',['sample_flow.csv','missingness.csv','complete_case_selection.csv'],'Flow boxes have padded gaps and arrows confined strictly to white channels; selection means, SEs and eligibility counts unchanged.')
# 2: categorical percentages; continuous means/SE only. IQRs remain in Table 1.
fig=plt.figure(figsize=(6.5,7.5));a=fig.add_axes([.34,.55,.43,.36]);panel(a,'a','Population composition')
cats=[('sex','Male','Male'),('race_group','Hispanic','Hispanic'),('race_group','NH Black','Non-Hispanic Black'),('race_group','NH White','Non-Hispanic White'),('race_group','Other','Other/multiracial'),('diabetes','Diagnosed','Diagnosed diabetes'),('alcohol_status','lifetime_never','Alcohol: lifetime never'),('alcohol_status','former_past_year','Alcohol: no past year'),('alcohol_status','current_less_than_weekly','Alcohol: <weekly'),('alcohol_status','current_weekly_plus','Alcohol: ≥weekly'),('probe','M','Probe: M')]
for j,p in enumerate(P):
 for i,(v,cat,_) in enumerate(cats):
  r=tr(p,v,cat);x=f(r['weighted_mean'])*100;y=i+(.17 if j else -.17);a.barh(y,x,height=.27,color=C[j],hatch='///' if j==0 else '...',edgecolor='white',linewidth=.35);a.errorbar(x,y,xerr=f(r['se'])*100,ecolor=C[j],capsize=2,lw=1)
for i,(v,cat,_) in enumerate(cats):a.text(1.04,i,' / '.join(f'{f(tr(p,v,cat)["weighted_mean"])*100:.1f}' for p in P),transform=a.get_yaxis_transform(),va='center',fontsize=9.5)
a.text(1.04,1.04,'2017–18 /\n2021–23',transform=a.transAxes,fontsize=9.5,va='bottom')
a.set(yticks=range(len(cats)),yticklabels=[x[2] for x in cats],xlim=(0,100),xlabel='Weighted percentage (±SE)');a.invert_yaxis();clean(a)
title(fig,.04,.46,'b  Continuous measurements: mean ± SE')
vs=[('RIDAGEYR','Age (years)'),('BMXBMI','BMI (kg/m²)'),('LUXSMED','LSM (kPa)'),('LUXCAPM','CAP (dB/m)'),('egfr','eGFR (mL/min/1.73 m²)')]
for i,(v,lab) in enumerate(vs):
 ax=fig.add_axes([.14+(i%2)*.45,.34-(i//2)*.13,.34,.055]);ax.set_title(lab,fontsize=9.5,loc='left',pad=5)
 vals=[]
 for j,p in enumerate(P):
  r=tr(p,v);mu,se=f(r['weighted_mean']),f(r['se']);vals.extend([mu-se,mu+se,f(r['q25']),f(r['q75'])]);ax.errorbar(mu,j,xerr=se,color=C[j],marker=M[j],capsize=3,ls='none',ms=5)
 lo,hi=min(vals),max(vals);pad=max((hi-lo)*.25,.1);ax.set(yticks=[],ylim=(-.7,1.7),xlim=(lo-pad,hi+pad));ax.invert_yaxis();clean(ax);ax.locator_params(axis='x',nbins=3)
legend(fig,.76,.085)
save(fig,'Figure2',['table1.csv'],'Continuous means/SE only on five unit-specific axes; redundant complementary categories omitted from plot but retained in unchanged Table 1.')
# 3: PFAS medians/IQR and means/SE; aligned domain values and offset detection labels.
fig=plt.figure(figsize=(6.5,7.0));outer=fig.add_gridspec(1,1,left=.18,right=.96,top=.94,bottom=.54);sub=outer[0].subgridspec(4,1,hspace=.65)
ev=['PFOS_total','PFOA_total','LBXPFHS','LBXPFNA'];names=['Total PFOS','Total PFOA','PFHxS','PFNA'];delta=[]
for i,(v,name) in enumerate(zip(ev,names)):
 ax=fig.add_subplot(sub[i]);
 if i==0:panel(ax,'a','Complete-case PFAS summaries')
 for j,p in enumerate(P):
  r=tr(p,v);y=j*.26;ax.plot([f(r['q25']),f(r['q75'])],[y,y],color=light(C[j],.3),lw=5);ax.plot(f(r['median']),y,'D',color=C[j],ms=4);ax.errorbar(f(r['weighted_mean']),y+.06,xerr=f(r['se']),marker=M[j],color=C[j],ls='none',capsize=2,ms=4)
  ax.text(1.02,.72-j*.35,f'median {f(r["median"]):.2f}',transform=ax.transAxes,color=C[j],fontsize=9.5)
 change=100*(f(tr(P[1],v)['median'])/f(tr(P[0],v)['median'])-1);delta.append({'exposure':v,'complete_case_median_relative_difference_percent':change});ax.text(1.02,.02,f'Δmedian {change:+.1f}%',transform=ax.transAxes,fontsize=9.5)
 ax.set(yticks=[],ylim=(-.1,.5));ax.set_ylabel(name,rotation=0,ha='right',va='center',labelpad=10,fontsize=10);clean(ax);pos=ax.get_position();ax.set_position([pos.x0,pos.y0,pos.width*.70,pos.height])
fig.text(.18,.485,'ng/mL; bands/diamonds: IQR/median; points: mean ± SE',fontsize=9.5)
a=fig.add_axes([.18,.16,.24,.25]);b=fig.add_axes([.68,.16,.27,.25]);title(fig,.18,.445,'b  Domain medians');title(fig,.68,.445,'c  Detection')
a.text(1.06,1.02,'Complete /\navailable',transform=a.transAxes,fontsize=9.5,va='bottom')
for j,p in enumerate(P):
 for i,v in enumerate(ev):
  y=i+(.23 if j else -.23);cc=tr(p,v);av=next(r for r in dist if r['period']==p and r['exposure']==v)
  y_cc,y_av=y-.10,y+.10
  a.plot([f(cc['median']),f(av['median'])],[y_cc,y_av],color=C[j],lw=.8,zorder=1)
  filled,=a.plot(f(cc['median']),y_cc,marker=M[j],color=C[j],ms=5,ls='none',zorder=3)
  opened,=a.plot(f(av['median']),y_av,marker=M[j],mfc='white',mec=C[j],ms=5,ls='none',zorder=3)
  domain_markers.extend([(p+' '+v+' complete',filled),(p+' '+v+' available',opened)])
  t=a.text(1.06,y,f'{f(cc["median"]):.2f} / {f(av["median"]):.2f}',transform=a.get_yaxis_transform(),fontsize=9.5,va='center',color=C[j]);critical.append(t)
  det=f(av['weighted_detection'])*100;pt,=b.plot(det,y,marker=M[j],color=C[j],ms=5,ls='none');points.append(pt)
  t=b.annotate(f'{det:.1f}%',xy=(det,y),xytext=((7,0) if j==0 else (-7,0)),textcoords='offset points',ha='left' if j==0 else 'right',va='center',fontsize=9.5,color=C[j]);critical.append(t)
dets=[f(r['weighted_detection'])*100 for r in dist];xmin=min(88,min(dets)-4);xmax=max(105.5,max(dets)+5.7)
a.set(yticks=range(4),yticklabels=names,xlim=(0,7.2),ylim=(3.6,-.6),xlabel='Median (ng/mL)');b.set(yticks=[],xlim=(xmin,xmax),ylim=(3.6,-.6),xlabel='Detected (%)')
for ax in [a,b]:clean(ax)
fig.text(.18,.085,'Filled: complete cases; open: available exposure',fontsize=8.5,ha='left')
legend(fig,.5,.005);(D/'derived_descriptive_median_differences.json').write_text(json.dumps(delta,indent=2))
save(fig,'Figure3',['table1.csv','exposure_distribution.csv'],'Domain medians use vertically separated period/domain markers, with unchanged x values and paired labels; offsets are display only. No new distribution/model.')
# 4: full period names, capped residual intervals and readable numeric columns.
fig=plt.figure(figsize=(6.5,4.8));a=fig.add_axes([.32,.55,.16,.33]);b=fig.add_axes([.32,.20,.16,.10]);title(fig,.035,.965,'a  Adjustment tiers and inference')
u=next(r for r in read('samala_aligned_2017_unweighted.csv') if r['exposure']=='log2_PFOS');rows=[(P[0],'Unweighted*',u,True)]
for p in P:
 for k,lab in [('base_all_available','Base: available'),('base_same_complete_cases','Base: complete'),('extended_same_complete_cases','Extended: complete')]:rows.append((p,lab,next(r for r in prim if r['period']==p and r['model']==k),False))
trans=blended_transform_factory(fig.transFigure,a.transData)
for i,(p,lab,r,uw) in enumerate(rows):
 j=P.index(p)
 if not uw:
  lo,hi=f(r['ci_low_residual']),f(r['ci_high_residual']);col=light(C[j],.65);a.plot([lo,hi],[i,i],color=col,lw=1.2);a.vlines([lo,hi],i-.08,i+.08,color=col,lw=1.2)
 a.plot([f(r['ci_low']),f(r['ci_high'])],[i,i],color='#666666' if uw else C[j],lw=2.5);a.plot(f(r['beta']),i,marker='D' if uw else M[j],color='#666666' if uw else C[j],ms=5)
 for x,t in [(.49,f'{int(r["n"]):,}'),(.56,fmt(r['beta'])),(.65,f'[{fmt(r["ci_low"])}, {fmt(r["ci_high"])}]'),(.91,pv(r['p']))]:a.text(x,i,t,transform=trans,va='center',fontsize=9.2)
 plot_rows.append({'figure':'Figure4','period':p,'model':lab,**r})
for x,t in [(.49,'n'),(.56,'β'),(.65,'95% CI'),(.91,'P')]:fig.text(x,.91,t,fontweight='bold',fontsize=9.5)
a.set(yticks=range(7),yticklabels=[Y[P.index(p)]+' '+lab for p,lab,_,_ in rows],xlim=(-.075,.055),ylim=(6.5,-.5),xlabel='β per PFOS doubling');a.axvline(0,color='#555555',lw=.8);clean(a);a.tick_params(axis='y',labelsize=9.2)
title(fig,.035,.40,'b  Later minus earlier extended coefficient')
for x,t in [(.56,'Δβ'),(.65,'95% CI'),(.91,'P')]:fig.text(x,.335,t,fontweight='bold',fontsize=9.5)
difference_rows=read('cycle_effect_difference.csv')
for i,r in enumerate(difference_rows):
 x=f(r['beta_difference_2021_minus_2017']);b.errorbar(x,i,xerr=[[x-f(r['ci_low'])],[f(r['ci_high'])-x]],color='#333333',marker='o' if i==0 else 's',ls='none',capsize=3)
 
 for xx,t in [(.56,fmt(x)),(.65,f'[{fmt(r["ci_low"])}, {fmt(r["ci_high"])}]'),(.91,pv(r['p_difference']))]:b.text(xx,i,t,transform=blended_transform_factory(fig.transFigure,b.transData),va='center',fontsize=9.2)
b.set(yticks=[0,1],yticklabels=[('Design df=' if r['inference'].startswith('design') else 'Residual df=')+f"{f(r['df']):.2f}" for r in difference_rows],ylim=(1.6,-.6),xlim=(-.075,.055),xlabel='Coefficient difference');b.axvline(0,color='#555555',lw=.8);clean(b)
fig.text(.035,.027,'Thick: design-df CI; thin with end caps: residual-df CI\nBase residual df=9; extended df=4; domain design df=15',fontsize=9.2)
save(fig,'Figure4',['primary_model_comparison.csv','samala_aligned_2017_unweighted.csv','cycle_effect_difference.csv'],'Full period labels and opaque preblended .65 residual intervals with caps; frozen coefficients unchanged.')
# 5: secondary outcomes separated; aligned effect/CI and nominal/Holm columns.
fig=plt.figure(figsize=(6.5,7.8));axes=[fig.add_axes([.22,.65,.25,.25]),fig.add_axes([.22,.16,.25,.32])]
for k,(out,lab) in enumerate([('log_LSM','Secondary PFAS and log LSM'),('LUXCAPM','Secondary PFAS and CAP')]):
 ax=axes[k];title(fig,.035,.96 if k==0 else .56,('a' if k==0 else 'b')+'  '+lab)
 rr=[r for r in sec if r['outcome']==out and not(out=='log_LSM' and r['exposure']=='PFOS_total')]
 yy=.92 if k==0 else .51
 for x,t in [(.51,'β [95% CI]'),(.82,'P / Holm P')]:fig.text(x,yy,t,fontweight='bold',fontsize=9.5)
 for i,r in enumerate(rr):
  j=P.index(r['period']);ax.errorbar(f(r['beta']),i,xerr=[[f(r['beta'])-f(r['ci_low'])],[f(r['ci_high'])-f(r['beta'])]],color=C[j],marker=M[j],ls='none',capsize=2,ms=4)
  trans=blended_transform_factory(fig.transFigure,ax.transData);ax.text(.51,i,f'{fmt(r["beta"])}\n[{fmt(r["ci_low"])}, {fmt(r["ci_high"])}]',transform=trans,va='center',fontsize=9.2);ax.text(.82,i,pv(r['p'])+' / '+pv(r['p_holm_within_period_outcome']),transform=trans,va='center',fontsize=9.2)
  plot_rows.append({'figure':'Figure5',**r})
 ax.set(yticks=range(len(rr)),yticklabels=[Y[P.index(r['period'])]+' '+r['exposure'].replace('_total','') for r in rr],ylim=(len(rr)-.5,-.5),xlabel='β per doubling'+(' (log LSM)' if k==0 else ' (CAP dB/m)'));ax.axvline(0,color='#555555',lw=.8);clean(ax);ax.locator_params(axis='x',nbins=3)
legend(fig,.5,.012)
save(fig,'Figure5',['secondary_models.csv'],'All 14 secondary estimates with numeric beta/CI and nominal/Holm columns; separate units and axes.')
# 6: all seven existing sensitivity specifications, separate period panels.
fig=plt.figure(figsize=(6.5,7.6));ks=['primary_unknown_alcohol_category','primary_plus_eGFR','primary_LSM_le40','primary_strict_numeric_LUX_quality','primary_HBV_HCV_tests_negative','primary_plus_probe','linear_nPFOA_primary_covariates'];ls=['Unknown alcohol','Add eGFR','Restricted LSM ≤40','Strict VCTE quality','Viral-status restriction','Add M/XL probe','n-PFOA substitution*']
for j,p in enumerate(P):
 ax=fig.add_axes([.32,.60 if j==0 else .14,.21,.29]);title(fig,.035,.96 if j==0 else .50,('a' if j==0 else 'b')+'  '+Y[j]);h=.915 if j==0 else .455
 for x,t in [(.57,'β [95% CI]'),(.91,'P')]:fig.text(x,h,t,fontweight='bold',fontsize=9.5)
 for i,k in enumerate(ks):
  r=next(r for r in sens if r['period']==p and r['sensitivity']==k);beta=f(r['beta']);ax.errorbar(beta,i,xerr=[[beta-f(r['ci_low'])],[f(r['ci_high'])-beta]],color=C[j],marker=M[j],capsize=2,ls='none',ms=4)
  trans=blended_transform_factory(fig.transFigure,ax.transData);ax.text(.57,i,f'{fmt(beta)}\n[{fmt(r["ci_low"])}, {fmt(r["ci_high"])}]',transform=trans,va='center',fontsize=9.2);ax.text(.91,i,pv(r['p']),transform=trans,va='center',fontsize=9.2)
  plot_rows.append({'figure':'Figure6',**r})
 ref=next(r for r in prim if r['period']==p and r['model']=='extended_same_complete_cases');ax.axvline(f(ref['beta']),color=C[j],lw=1,ls='--');ax.set(yticks=range(7),yticklabels=ls,ylim=(6.5,-.5),xlim=(-.06,.055),xlabel='β per doubling (log LSM)');clean(ax);ax.locator_params(axis='x',nbins=3)
save(fig,'Figure6',['sensitivity_with_probe.csv','primary_model_comparison.csv'],'Seven saved specifications per period; no model added. n-PFOA estimates a different exposure.')
# S1: directional research roadmap, not a causal pathway diagram.
fig,ax=plt.subplots(figsize=(6.5,6.2));ax.set_axis_off();texts=[('1  Existing evidence','PFAS and liver-health studies\nEarlier NHANES 2017–18 VCTE analyses'),('2  Unresolved research questions','Later-period estimates; sample and model comparability\nCross-period association magnitude and uncertainty'),('3  Harmonized cross-period analysis','2017–18 / 2021–23: total PFOS and continuous LSM\nSeparate survey designs; models compared in identical complete cases\nEligible n=1,498 / 1,913; complete cases n=1,323 / 1,653'),('4  New empirical contributions','Later-period estimates and exposure summaries\nAdjustment sensitivity; cross-period effect size and precision')]
for i,(h,t) in enumerate(texts):
 x=.055;y=.77-i*.235;ax.add_patch(FancyBboxPatch((x,y),.89,.18,boxstyle='round,pad=.008',facecolor='#F2F5F7',edgecolor=C[0] if i<2 else C[1],lw=1,transform=ax.transAxes));ax.text(.5,y+.137,h,ha='center',va='center',fontweight='bold',fontsize=10.5,transform=ax.transAxes);ax.text(.5,y+.061,t,ha='center',va='center',fontsize=9.8,transform=ax.transAxes)
 if i<3:ax.annotate('',xy=(.5,y-.043),xytext=(.5,y-.010),xycoords='axes fraction',arrowprops={'arrowstyle':'-|>','mutation_scale':15,'lw':1.3,'color':'#34495E'})
ax.text(.5,.008,'Independent cross-sections; finalized plan followed exploratory results',ha='center',fontsize=9.5,transform=ax.transAxes);fig.subplots_adjust(left=.02,right=.98,top=.99,bottom=.04)
save(fig,'SupplementaryFigureS1',['manuscript and saved domain counts'],'Directional evidence-to-contribution roadmap; actual domains/complete cases and analysis history preserved.')
(R/'Figure_Provenance.json').write_text(json.dumps(audit,indent=2));(R/'evidence'/'plotted_model_rows.json').write_text(json.dumps(plot_rows,indent=2))
print(json.dumps(audit,indent=2))
