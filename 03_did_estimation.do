clear

   ***************************************
   ***************************************

	   * Difference-in-Differences (Full Sample) *

   ***************************************
   ***************************************

include "$code/programs.do"

* Area units
global area_unit "km2"
global area_mult = cond("$area_unit" == "acres", 2.47105, cond("$area_unit" == "km2", 0.01, 1))
global area_fmt  = cond("$area_unit" == "km2", "%9.1fc", "%12.0fc")
global area_lab  = cond("$area_unit" == "km2", "km2", "$area_unit")
global area_lab_tex = cond("$area_unit" == "km2", "km\textsuperscript{2}", "$area_unit")


****----------- DIFFERENCES-IN-DIFFERENCES -----------****
display "$sample $matchgroup"
display "$method $treat_type"
use "$Output/Country/$matchgroup/Period05 $method $treat_type.dta", clear

assert Legal_Stat!="Unsure"
assert Legal_Stat!="Converted to CPA"


********************************************************
* Create above/below median baseline adjusted TCC (2005)
********************************************************
capture drop aboveMEDtcc belowMEDtcc aboveMEDtcc_fyk belowMEDtcc_fyk

summarize tcc_adj2005 if tcc_adj2005 < ., detail
scalar med_tcc05 = r(p50)

gen aboveMEDtcc = tcc_adj2005 > med_tcc05 if tcc_adj2005 < .
gen belowMEDtcc = tcc_adj2005 <= med_tcc05 if tcc_adj2005 < .

label var aboveMEDtcc "Above median baseline adjusted TCC (2005)"
label var belowMEDtcc "Below median baseline adjusted TCC (2005)"

***************************
* Differences-in-Differences
***************************
xtset Grid_ID post


* Col 1: District SE
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num , ///
    fe i(Grid_ID) cluster(district_encode)
    avoided_share "(1) District SE"
    estimates store col1
    global att = _b[treat_post]
    estadd local Grid_FE        "Yes"
    estadd local ProvPost_FE    "Yes"
    estadd local Interactions   "No"
    estadd local Clustering     "District"

* Col 2: Province SE
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num , ///
    fe i(Grid_ID) cluster(province_num)
    avoided_share "(2) Province SE"
    estimates store col2
    estadd local Grid_FE        "Yes"
    estadd local ProvPost_FE    "Yes"
    estadd local Interactions   "No"
    estadd local Clustering     "Province"

* Col 3: Covariate interactions
xtreg ch_adj treat_post post mean_precip slope_post elevation_post d_road_post i(1).post#i.province_num , ///
    fe i(Grid_ID) cluster(district_encode)
    avoided_share "(3) Interactions"
    estimates store col3
    estadd local Grid_FE        "Yes"
    estadd local ProvPost_FE    "Yes"
    estadd local Interactions   "Yes"
    estadd local Clustering     "District"

* Col 4: Pooled OLS (no grid FE)
regress ch_adj treat_post post mean_precip i(1).post#i.province_num , ///
    robust cluster(district_encode)
    avoided_share "(4) No cell FE"
    estimates store col4
    estadd local Grid_FE        "No"
    estadd local ProvPost_FE    "Yes"
    estadd local Interactions   "No"
    estadd local Clustering     "District"

* Col 5: No ELCs
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
    if (treat==0 & ELC_Grid_Dist>0) | treat==1, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store col5
    estadd local Grid_FE        "Yes"
    estadd local ProvPost_FE    "Yes"
    estadd local Interactions   "No"
    estadd local Clustering     "District"

* Col 6: Known Formalization Year (FYK) sample
gen FYK = (inlist(Year_Praka,2007,2008,2010,2011,2013,2014,2015,2017,2018) & treat==1) | treat==0
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num if FYK==1, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store col6
    estadd local Grid_FE        "Yes"
    estadd local ProvPost_FE    "Yes"
    estadd local Interactions   "No"
    estadd local Clustering     "District"


* Col 7: Above-median baseline TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num  ///
    if aboveMEDtcc == 1, ///
    fe i(Grid_ID) cluster(district_encode)
    avoided_share "(5) Above-median TCC"
    estimates store col7
    estadd local Grid_FE        "Yes"
    estadd local ProvPost_FE    "Yes"
    estadd local Interactions   "No"
    estadd local Clustering     "District"

* Col 8: Below-median baseline TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num  ///
    if belowMEDtcc == 1, ///
    fe i(Grid_ID) cluster(district_encode)
    avoided_share "(6) Below-median TCC"
    estimates store col8
    estadd local Grid_FE        "Yes"
    estadd local ProvPost_FE    "Yes"
    estadd local Interactions   "No"
    estadd local Clustering     "District"

label var treat_post "CFM Impact"
label var post "Counterfactual"
****--------------------------------
* ROBUSTNESS TABLE (col1-col8)
****--------------------------------

* Observations (grid cells)
foreach m in col1 col2 col3 col4 col5 col6 col7 col8 {
	estimates restore `m'
	estadd scalar cells = e(N) / 2, replace
	estimates store `m'
}

* Show Robustness Table
estout col1 col2 col3 col4 col7 col8 col5 col6, ///
    cells(b(star fmt(2))) legend label ///
    order(treat_post post 1.post#1.PA mean_precip slope_post elevation_post d_road_post) ///
    keep(treat_post post 1.post#1.PA mean_precip slope_post elevation_post d_road_post) ///
    stats(cells Grid_FE ProvPost_FE Interactions Clustering, ///
        labels("Observations" "Grid FE" "Province-Period FE" "Interactions" "Clustering"))

	* LaTeX Robustness Table (SI Table 4; SI Table 2 with ecoregion matching)
	local sitab = cond("$matchgroup" == "Province", "SI Table 4", "SI Table 2")
	esttab col1 col2 col3 col4 col7 col8 col5 col6 ///
		using  "$DTables/`sitab'.tex", ///
		label replace starlevels(* 0.10 ** 0.05 *** 0.01) nogaps nonumber nonotes ///
		order(treat_post) ///
		keep(treat_post) ///
		varwidth(3) style(tex) ///
		mgroups("Full Sample" "Baseline TCC (2005)" "No ELCs" "Formalization", pattern(1 0 0 0 1 0 1 1) ///
			span prefix(\multicolumn{@span}{c}{) suffix(}) ///
			erepeat(\cmidrule(lr){@span})) ///
		mtitles("(1)" "(2)" "(3)" "(4)" "(5) Above Med." "(6) Below Med." "(7)" "(8)") ///
		b(%9.2f) se(%9.2f) ///
		stats(cells Grid_FE ProvPost_FE Interactions Clustering, ///
			fmt(%12.0fc 0 0 0 0) ///
			labels("Observations" "Grid FE" "Prov-Post FE" "Interactions" "Clustering"))

* Ecoregion matching: SI Table 2 only
if "$matchgroup" != "Province" exit


****------------------------------------------------
* Additional Specifications for Heterogeneity Figure
****------------------------------------------------

*----------------------------------------------------------------------
* (1) Baseline TCC
*----------------------------------------------------------------------

*----------------------------------------------------------------------
* (2) Deforestation Pressure Index
*----------------------------------------------------------------------
capture drop d_road_std d_edge_std pop_std slope_std elev_std ELC_dist_std ///
             pressure_idx_old def_press_idx ///
             hipressure hi_def_press

quietly summarize d_road if d_road < .
gen d_road_std = (d_road - r(mean)) / r(sd)

quietly summarize d_edge if d_edge < .
gen d_edge_std = (d_edge - r(mean)) / r(sd)

quietly summarize pop if pop < .
gen pop_std = (pop - r(mean)) / r(sd)

quietly summarize ELC_Grid_Dist if ELC_Grid_Dist < .
gen ELC_dist_std = (ELC_Grid_Dist - r(mean)) / r(sd)

* Deforestation Pressure Index
gen def_press_idx = (-ELC_dist_std - d_road_std - d_edge_std + pop_std) / 4
label var def_press_idx "Deforestation pressure index"


	quietly summarize def_press_idx if def_press_idx < ., detail
	scalar med_def_press = r(p50)
	gen hi_def_press = (def_press_idx > med_def_press) if def_press_idx < .
	label var hi_def_press "Above-median external deforestation pressure"


* High def press + High TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num  ///
    if hi_def_press == 1 & aboveMEDtcc == 1, ///
    fe i(Grid_ID) cluster(district_encode)
    avoided_share "High pressure, High TCC"
    estimates store dp_HiHi
    estadd local Grid_FE     "Yes"
    estadd local ProvPost_FE "Yes"
    estadd local Clustering  "District"

* High def press + Low TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num  ///
    if hi_def_press == 1 & belowMEDtcc == 1, ///
    fe i(Grid_ID) cluster(district_encode)
    avoided_share "High pressure, Low TCC"
    estimates store dp_HiLo
    estadd local Grid_FE     "Yes"
    estadd local ProvPost_FE "Yes"
    estadd local Clustering  "District"

* Low def press + High TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
    if hi_def_press == 0 & aboveMEDtcc == 1, ///
    fe i(Grid_ID) cluster(district_encode)
    avoided_share "Low pressure, High TCC"
    estimates store dp_LoHi
    estadd local Grid_FE     "Yes"
    estadd local ProvPost_FE "Yes"
    estadd local Clustering  "District"

* Low def press + Low TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
    if hi_def_press == 0 & belowMEDtcc == 1, ///
    fe i(Grid_ID) cluster(district_encode)
    avoided_share "Low pressure, Low TCC"
    estimates store dp_LoLo
    estadd local Grid_FE     "Yes"
    estadd local ProvPost_FE "Yes"
    estadd local Clustering  "District"

****------------------------------------------------
* Heterogeneity Figure
****------------------------------------------------

coefplot ///
    (col1,    keep(treat_post) rename(treat_post = "{bf:Main}")           mfcolor(navy)) ///
    (col7,    keep(treat_post) rename(treat_post = "High TCC")            mfcolor(white)) ///
    (col8,   keep(treat_post) rename(treat_post = "Low TCC")             mfcolor(white)) ///
    (dp_HiHi, keep(treat_post) rename(treat_post = "High Pressure, High TCC") mfcolor(white)) ///
    (dp_LoHi, keep(treat_post) rename(treat_post = "Low Pressure, High TCC")  mfcolor(white)) ///
    (dp_HiLo, keep(treat_post) rename(treat_post = "High Pressure, Low TCC")  mfcolor(white)) ///
    (dp_LoLo, keep(treat_post) rename(treat_post = "Low Pressure, Low TCC")   mfcolor(white)), ///
    headings(" "                       = "{bf:Main}" ///
             "High TCC"                = "{bf:Baseline TCC}" ///
             "High Pressure, High TCC" = "{bf:Deforestation Pressure}", ///
             labsize(vsmall)) ///
    xline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
	xline(${att}, lcolor(grey) lpattern(dot) lwidth(med)) ///
    msymbol(D) msize(medsmall) mcolor(navy) ///
    ciopts(lcolor(navy) lwidth(medthin)) ///
    xlabel(0(5)20, format(%4.0f) labsize(vsmall) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) ///
	xscale(range(-5 20)) ///
    xtitle("CFM Effect on TCC (pp)", size(vsmall)) ///
    ytitle("") ylabel(, labsize(vsmall)) ///
    legend(off) ///
    graphregion(color(white) margin(l=0 r=3 t=2 b=2)) ///
    plotregion(color(white) margin(l=0 r=5 t=1 b=1)) ///
    xsize(7) ysize(5) ///
    scheme(s2mono)

graph export "$DFigures/Figure 2a.pdf", replace as(pdf)

****************************
* ADJUSTED VS UNADJUSTED TCC
****************************
* Plantation Adjustment Trends
preserve
	*Treat vs Control X TCC vs TCC Adjusted
	use "$Output/Country/$matchgroup/Annual05 $method $treat_type.dta", clear
	assert Legal_Stat!="Unsure"
	assert Legal_Stat!="Converted to CPA"
	collapse (mean) tcc tcc_adj, by(year treat)
	replace tcc_adj=. if year<2000
	tw 	(line tcc_adj year if treat==1, color("51 166 166") lwidth(0.5) lpattern(solid)) ///
		(line tcc_adj year if treat==0, color("242 80 65") lwidth(0.5) lpattern(solid) ) ///
		(line tcc year if treat==1, color("51 166 166") lwidth(0.5) lpattern(dash)) ///
		(line tcc year if treat==0, color("242 80 65") lwidth(0.5) lpattern(dash)), ///
		legend(lab(3 "{bf:Treated: Not Adjusted}") lab(4 "{bf:Control: Not Adjusted}") ///
			  lab(1 "{bf:Treated: Adjusted}") lab(2 "{bf:Control: Adjusted}") pos(6) col(2)) ///
		ytitle("Tree Canopy Cover (%)",size(*1.25)) xlabel(1990(2)2023, angle(45) labsize(small)) xtitle("Year", size(*1.15)) xline(2005, lpattern(dash))
	graph save "$figures/Country/$matchgroup/SumStats/PlantatAdjust_trends $matchgroup $method $treat_type.gph", replace
restore

* Unadjusted TCC outcome
xtreg ch treat_post post mean_precip i(1).post#i.province_num , ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store undadjusted

coefplot ///
    (col1,   keep(treat_post) rename(treat_post = " ")   mfcolor(navy)) ///
    (undadjusted, keep(treat_post) rename(treat_post = " ") mfcolor(white)), ///
	vertical ///
    yline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
    msymbol(D) msize(*2) mcolor(navy) ///
    ciopts(lcolor(navy) lwidth(med)) ///
    xlabel("", format(%4.0f) labsize(vsmall) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) ///
	ylabel(, labsize(*0.8)) ///
    ytitle("CFM Effect on TCC (pp)", size(*0.975) margin(r=4)) ///
    xtitle("") ylabel(, labsize(*1.15)) ///
    legend(lab(2 "{bf:Adjusted}" "{bf:for Plantations}") lab(4 "{bf:Not Adjusted}" "{bf:for Plantations}") size(*0.95) pos(6) row(1) bmargin(t=10.5)) ///
    graphregion(color(white) margin(l=0 r=3 t=2 b=8.25)) ///
    plotregion(color(white) margin(l=0 r=5 t=1 b=1)) ///
    xsize(7) ysize(3) ///
    scheme(s2mono)
graph save "$figures/Country/$matchgroup/DID05_AdjVsUnadj $matchgroup $method $treat_type.gph", replace

graph combine 	"$figures/Country/$matchgroup/SumStats/PlantatAdjust_trends $matchgroup $method $treat_type.gph" ///
				"$figures/Country/$matchgroup/DID05_AdjVsUnadj $matchgroup $method $treat_type.gph"
	graph export "$DFigures/Figure 5.pdf", replace as(pdf)


*_________________________________ DYNAMIC DIFFERENCES-IN-DIFFERENCES ____________________________________________*
use "$Output/Country/$matchgroup/Annual05 $method $treat_type.dta", clear

xtset Grid_ID year

	*Period blocks to control for province-time effects
	gen post = year>2005
	gen year_10block = 1990 + floor((year - 1990) / 10) * 10
	gen year_5block = 1990 + floor((year - 1990) / 5) * 5
	gen year_2block = 1990 + floor((year - 1990) / 2) * 2

xtreg tcc_adj ib(2005).year##i.treat precip c.year#i.province_num c.year#i.post#i.province_num ///
	if year>=2000, fe i(Grid_ID) cluster(district_encode)
est store All, title(All)

coefplot All, keep(2005.year 2000.year#1.treat 2001.year#1.treat 2002.year#1.treat 2003.year#1.treat 2004.year#1.treat 2005.year#1.treat 2006.year#1.treat 2007.year#1.treat 2008.year#1.treat 2009.year#1.treat 2010.year#1.treat 2011.year#1.treat 2012.year#1.treat 2013.year#1.treat 2014.year#1.treat 2015.year#1.treat 2016.year#1.treat 2017.year#1.treat 2018.year#1.treat 2019.year#1.treat 2020.year#1.treat 2021.year#1.treat 2022.year#1.treat 2023.year#1.treat) order(*year ) vertical ///
coeflabels(2000.year#1.treat="00" 2001.year#1.treat="01" 2002.year#1.treat="02" 2003.year#1.treat="03" 2004.year#1.treat="04" 2005.year#1.treat="05" 2006.year#1.treat="06" 2007.year#1.treat="07" 2008.year#1.treat="08" 2009.year#1.treat="09" 2010.year#1.treat="10" 2011.year#1.treat="11" 2012.year#1.treat="12" 2013.year#1.treat="13" 2014.year#1.treat="14" 2015.year#1.treat="15" 2016.year#1.treat="16" 2017.year#1.treat="17" 2018.year#1.treat="18" 2019.year#1.treat="19" 2020.year#1.treat="20" 2021.year#1.treat="21" 2022.year#1.treat="22" 2023.year#1.treat="23") ///
groups(2000.year#1.treat - 2004.year#1.treat = "{bf:Pre-CFM}" ///
		2006.year#1.treat - 2023.year#1.treat = "{bf:Post-CFM}") ///
yline(0, lpattern(line)) ylabel(-5(5)15) xline(06, lcolor("236 196 77") ) ///
color(gray) ciopts(lcolor(black) lwidth(thin)) pstyle(p12) ///
title("") ytitle("CFM Effect on TCC (pp)") note("", size(vsmall))
graph export "$DFigures/Figure 1c.png", replace as(png)

****------------------------------------------------
* Dynamic DiD: Stratified by Above/Below Median TCC
****------------------------------------------------
* Define high/low TCC split at median
	assert tcc_adj!=.
	bysort Grid_ID: egen tcc_adj2005 = max(cond(year == 2005, tcc_adj, .))
	quietly summarize tcc_adj2005, detail
	scalar med_tcc05b = r(p50)
	gen aboveMED_tcc = (tcc_adj2005 > med_tcc05b)

* Above-median TCC
xtreg tcc_adj ib(2005).year##i.treat precip c.year#i.province_num c.year#i.post#i.province_num ///
	if year>=2000 & aboveMED_tcc == 1, fe i(Grid_ID) cluster(district_encode)
est store HiTCC, title(High TCC)

* Below-median TCC
xtreg tcc_adj ib(2005).year##i.treat precip c.year#i.province_num c.year#i.post#i.province_num ///
	if year>=2000 & aboveMED_tcc == 0, fe i(Grid_ID) cluster(district_encode)
est store LoTCC, title(Low TCC)

* Coefplot: Above-median TCC
coefplot HiTCC, keep(2000.year#1.treat 2001.year#1.treat 2002.year#1.treat 2003.year#1.treat 2004.year#1.treat 2005.year#1.treat 2006.year#1.treat 2007.year#1.treat 2008.year#1.treat 2009.year#1.treat 2010.year#1.treat 2011.year#1.treat 2012.year#1.treat 2013.year#1.treat 2014.year#1.treat 2015.year#1.treat 2016.year#1.treat 2017.year#1.treat 2018.year#1.treat 2019.year#1.treat 2020.year#1.treat 2021.year#1.treat 2022.year#1.treat 2023.year#1.treat) order(*year) vertical ///
    coeflabels(2000.year#1.treat="00" 2001.year#1.treat="01" 2002.year#1.treat="02" 2003.year#1.treat="03" 2004.year#1.treat="04" 2005.year#1.treat="05" 2006.year#1.treat="06" 2007.year#1.treat="07" 2008.year#1.treat="08" 2009.year#1.treat="09" 2010.year#1.treat="10" 2011.year#1.treat="11" 2012.year#1.treat="12" 2013.year#1.treat="13" 2014.year#1.treat="14" 2015.year#1.treat="15" 2016.year#1.treat="16" 2017.year#1.treat="17" 2018.year#1.treat="18" 2019.year#1.treat="19" 2020.year#1.treat="20" 2021.year#1.treat="21" 2022.year#1.treat="22" 2023.year#1.treat="23") ///
    groups(2000.year#1.treat - 2004.year#1.treat = "{bf:Pre-CFM}" ///
           2006.year#1.treat - 2023.year#1.treat = "{bf:Post-CFM}") ///
    yline(0, lpattern(line)) ylabel(-5(5)20) xline(06, lcolor("236 196 77")) ///
    color(gray) ciopts(lcolor(black) lwidth(thin)) pstyle(p12) ///
    title("") ytitle("CFM Effect on TCC (pp)") note("", size(vsmall))
graph export "$DFigures/Figure 2c.png", replace as(png)

* Coefplot: Below-median TCC
coefplot LoTCC, keep(2000.year#1.treat 2001.year#1.treat 2002.year#1.treat 2003.year#1.treat 2004.year#1.treat 2005.year#1.treat 2006.year#1.treat 2007.year#1.treat 2008.year#1.treat 2009.year#1.treat 2010.year#1.treat 2011.year#1.treat 2012.year#1.treat 2013.year#1.treat 2014.year#1.treat 2015.year#1.treat 2016.year#1.treat 2017.year#1.treat 2018.year#1.treat 2019.year#1.treat 2020.year#1.treat 2021.year#1.treat 2022.year#1.treat 2023.year#1.treat) order(*year) vertical ///
    coeflabels(2000.year#1.treat="00" 2001.year#1.treat="01" 2002.year#1.treat="02" 2003.year#1.treat="03" 2004.year#1.treat="04" 2005.year#1.treat="05" 2006.year#1.treat="06" 2007.year#1.treat="07" 2008.year#1.treat="08" 2009.year#1.treat="09" 2010.year#1.treat="10" 2011.year#1.treat="11" 2012.year#1.treat="12" 2013.year#1.treat="13" 2014.year#1.treat="14" 2015.year#1.treat="15" 2016.year#1.treat="16" 2017.year#1.treat="17" 2018.year#1.treat="18" 2019.year#1.treat="19" 2020.year#1.treat="20" 2021.year#1.treat="21" 2022.year#1.treat="22" 2023.year#1.treat="23") ///
    groups(2000.year#1.treat - 2004.year#1.treat = "{bf:Pre-CFM}" ///
           2006.year#1.treat - 2023.year#1.treat = "{bf:Post-CFM}") ///
    yline(0, lpattern(line)) ylabel(-5(5)20) xline(06, lcolor("236 196 77")) ///
    color(gray) ciopts(lcolor(black) lwidth(thin)) pstyle(p12) ///
    title("") ytitle("CFM Effect on TCC (pp)") note("", size(vsmall))
graph export "$DFigures/Figure 2d.png", replace as(png)


****************************************
****************************************
* TABLE 1 AND HEATMAP
****************************************
****************************************

****************************************
* TABLE 1 WITH THE AVOIDED-LOSS ROWS
****************************************
* Observations (grid cells) and bold share and area
foreach m in col1 col2 col3 col4 col7 col8 {
	estimates restore `m'
	estadd scalar cells = e(N) / 2, replace
	local s_tex = "\textbf{" + strtrim(string(e(share), "%9.0f")) + "}"
	local a_tex = "\textbf{" + strtrim(string(e(av_area), "%9.0fc")) + "}"
	estadd local share_tex "`s_tex'", replace
	estadd local area_tex  "`a_tex'", replace
	estimates store `m'
}

* Show Table 1
estout col1 col2 col3 col4 col7 col8, ///
    cells(b(star fmt(2)) se(par fmt(2))) legend label ///
    starlevels(* 0.10 ** 0.05 *** 0.01) varwidth(40) ///
    keep(treat_post) ///
    refcat(treat_post "CFM Impact", nolabel) ///
    varlabels(treat_post "  Avoided loss (pp)") ///
    stats(share av_area cf_loss cells Grid_FE ProvPost_FE Interactions Clustering, ///
        fmt(%9.0f %9.0fc %9.2f %12.0fc 0 0 0 0) ///
        labels("  Avoided loss (%)" "  Avoided loss ($area_lab)" "Counterfactual loss (pp)" ///
               "Observations" "Grid FE" "Province-Period FE" "Interactions" "Clustering"))

* LaTeX Table 1
esttab col1 col2 col3 col4 col7 col8 ///
	using "$DTables/Table 1.tex", ///
	label replace starlevels(* 0.10 ** 0.05 *** 0.01) nogaps nonumber nonotes booktabs ///
	keep(treat_post) ///
	varwidth(3) ///
	mgroups("Full Sample" "By Baseline TCC (2005)", pattern(1 0 0 0 1 0) ///
		span prefix(\multicolumn{@span}{c}{) suffix(}) ///
		erepeat(\cmidrule(lr){@span})) ///
	mtitles("(1)" "(2)" "(3)" "(4)" "(5) Above Med." "(6) Below Med.") ///
	cells(b(fmt(%9.2f) star par("\textbf{" "}")) se(fmt(%9.2f) par)) collabels(none) ///
	refcat(treat_post "CFM Impact", nolabel) ///
	coeflabels(treat_post "\quad Avoided loss (pp)") ///
	prefoot("%") ///
	stats(share_tex area_tex cf_loss cells Grid_FE ProvPost_FE Interactions Clustering, ///
		fmt(0 0 %9.2f %12.0fc 0 0 0 0) ///
		labels("\quad Avoided loss (\%)" "\quad Avoided loss ($area_lab_tex)" ///
		       "\midrule Counterfactual loss (pp)" ///
		       "Observations" "Grid FE" "Prov-Post FE" "Interactions" "Clustering"))


****************************************
* AVOIDED-LOSS NUMBERS (Results window)
****************************************
tempfile shares
tempname P
postfile `P' str12 model str32 spec double(N att att_se cf_obs cf_loss share share_se share_lo share_hi ///
                                             cfu_area av_area av_area_lo av_area_hi) ///
	using "`shares'", replace
foreach m in col1 col2 col3 col4 col7 col8 dp_HiHi dp_HiLo dp_LoHi dp_LoLo {
	estimates restore `m'
	post `P' ("`m'") ("`e(spec)'") (e(N)) (e(att)) (e(att_se)) (e(cf_obs)) (e(cf_loss)) ///
	         (e(share)) (e(share_se)) (e(share_lo)) (e(share_hi)) ///
	         (e(cfu_area)) (e(av_area)) (e(av_area_lo)) (e(av_area_hi))
}
postclose `P'

use "`shares'", clear
format att att_se cf_obs cf_loss %6.2f
format share share_se share_lo share_hi %5.1f
format cfu_area av_area av_area_lo av_area_hi $area_fmt
list model spec att cf_loss share share_lo share_hi av_area, noobs sep(6)


****************************************
****************************************
* HEATMAP (Figure 3)
****************************************
****************************************

* Matching covariates
local covs ch_adj2005_1990 tcc_adj2005 Farm2005 Forest2005 Plantat2005 Plantat_05_00 ///
           elevation slope d_road d_edge pop_2000

local nbc  5
local nbp  5
local minn 20


* Load
use "$Output/Country/$matchgroup/Period05 $method $treat_type.dta", clear


xtset Grid_ID post

* Pooled Col 1
quietly xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num, ///
    fe i(Grid_ID) cluster(district_encode)
di as text _n "Pooled Col 1 ATT = " %5.2f _b[treat_post]

* Pre-period TCC change on both rows
gen double _chpre = ch_adj if post == 0
bysort Grid_ID: egen double ch_adj2005_1990 = max(_chpre)
drop _chpre

* 2005-2023 canopy loss
gen double _l = -ch_adj if post == 1
bysort Grid_ID: egen double loss = max(_l)
drop _l


* Deforestation Pressure Index
quietly summarize d_road if d_road < .
gen d_road_std = (d_road - r(mean)) / r(sd)
quietly summarize d_edge if d_edge < .
gen d_edge_std = (d_edge - r(mean)) / r(sd)
quietly summarize pop if pop < .
gen pop_std = (pop - r(mean)) / r(sd)
quietly summarize ELC_Grid_Dist if ELC_Grid_Dist < .
gen ELC_dist_std = (ELC_Grid_Dist - r(mean)) / r(sd)
gen def_press_idx = (-ELC_dist_std - d_road_std - d_edge_std + pop_std) / 4


* Bins
quietly summarize tcc_adj2005 if treat == 1 & post == 0
scalar ce0      = r(min)
scalar ce`nbc'  = r(max)

gen byte canopy_bin = 1
if `nbc' > 1 {
    _pctile tcc_adj2005 if treat == 1 & post == 0, nq(`nbc')
    forvalues k = 1/`=`nbc'-1' {
        scalar ce`k' = r(r`k')
    }
    forvalues k = 1/`=`nbc'-1' {
        quietly replace canopy_bin = canopy_bin + (tcc_adj2005 >= scalar(ce`k'))
    }
}

gen byte pressure_bin = 1
if `nbp' > 1 {
    _pctile def_press_idx if treat == 1 & post == 0, nq(`nbp')
    forvalues k = 1/`=`nbp'-1' {
        scalar pe`k' = r(r`k')
    }
    forvalues k = 1/`=`nbp'-1' {
        quietly replace pressure_bin = pressure_bin + (def_press_idx >= scalar(pe`k'))
    }
}

gen int cell = (pressure_bin - 1) * `nbc' + canopy_bin

* Canopy ranges
di as text _n "Canopy bins (baseline TCC 2005, CF-cell quintiles):"
forvalues a = 1/`nbc' {
    local lo`a' = scalar(ce`=`a'-1')
    local hi`a' = scalar(ce`a')
    di as text "  Q`a': `lo`a'' to `hi`a''"
}


* One regression per grid cell
foreach v of local covs {
    quietly summarize `v' if post == 0
    scalar sd_`v' = r(sd)
    gen double x_`v' = .
}

tempfile res
tempname CT
postfile `CT' double(pressure_bin canopy_bin canopy_lo canopy_hi n_t n_c trt_loss ctrl_loss ///
                     beta1 se pval cf_loss cf_lo share_pct share_se share_lo share_hi ///
                     cfu_area av_area av_area_lo av_area_hi) using "`res'", replace

local ncell = `nbc' * `nbp'
forvalues k = 1/`ncell' {
    local b = ceil(`k' / `nbc')
    local a = `k' - (`b' - 1) * `nbc'

    * Cell counts and observed loss
    quietly count if cell == `k' & treat == 1 & post == 0
    local nt = r(N)
    quietly count if cell == `k' & treat == 0 & post == 0
    local nc = r(N)

    if `nt' == 0 | `nc' == 0 {
        post `CT' (`b') (`a') (`lo`a'') (`hi`a'') (`nt') (`nc') (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
        continue
    }

    quietly summarize loss if cell == `k' & treat == 1 & post == 0
    local lt = r(mean)
    quietly summarize loss if cell == `k' & treat == 0 & post == 0
    local lc = r(mean)

    * Centre covariates at the CF mean
    local adjlist ""
    foreach v of local covs {
        quietly summarize `v' if cell == `k' & treat == 1 & post == 0
        local mt = r(mean)
        quietly replace x_`v' = (`v' - `mt') / scalar(sd_`v') if cell == `k'
        local adjlist `adjlist' c.post#c.x_`v' c.treat_post#c.x_`v'
    }

    if `nt' < `minn' | `nc' < `minn' {
        post `CT' (`b') (`a') (`lo`a'') (`hi`a'') (`nt') (`nc') (`lt') (`lc') (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
        continue
    }

    * Col 1 with within-cell covariate adjustment
    capture quietly xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num `adjlist' ///
        if cell == `k', fe i(Grid_ID) cluster(district_encode)
    if _rc {
        di as error "  P`b' x Q`a': xtreg failed (rc = " _rc ") -- left blank"
        post `CT' (`b') (`a') (`lo`a'') (`hi`a'') (`nt') (`nc') (`lt') (`lc') (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.) (.)
        continue
    }

    * Avoided loss
    quietly avoided_share "P`b' x Q`a'"
    local pval = 2 * ttail(e(df_r), abs(e(att) / e(att_se)))
    local cflo = e(cf_loss) - invttail(e(df_r), 0.025) * e(att_se)

    post `CT' (`b') (`a') (`lo`a'') (`hi`a'') (`nt') (`nc') (e(cf_obs)) (`lc') ///
              (e(att)) (e(att_se)) (`pval') (e(cf_loss)) (`cflo') ///
              (e(share)) (e(share_se)) (e(share_lo)) (e(share_hi)) ///
              (e(cfu_area)) (e(av_area)) (e(av_area_lo)) (e(av_area_hi))
    di as text "  P`b' x Q`a'  n=`nt'/`nc'   beta1 = " %6.2f e(att) "  (se " %4.2f e(att_se) ///
               ")   avoided = " %5.1f e(share) "%   area = " %7.1f e(av_area) " $area_unit"
}

postclose `CT'


* Export
use "`res'", clear

* CF-weighted mean of the cell estimates
quietly summarize n_t if !missing(beta1)
local wsum = r(sum)
gen double _w = n_t * beta1 / `wsum'
quietly summarize _w
local wmean = r(sum)
drop _w
gen double weighted_mean_beta1 = `wmean'

format beta1 se cf_loss cf_lo trt_loss ctrl_loss %6.2f
format share_pct share_se share_lo share_hi %6.1f
format cfu_area av_area av_area_lo av_area_hi %9.1f
format pval %6.4f
list pressure_bin canopy_bin n_t n_c beta1 se pval cf_loss share_pct av_area, noobs sep(`nbc')
di as text "CF-weighted mean of cell beta1 = " %5.2f `wmean' " pp"

export delimited using "$DFigures/Figure 3 data.csv", replace
