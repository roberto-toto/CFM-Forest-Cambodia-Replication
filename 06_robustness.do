clear

   ***************************************
   ***************************************
   
	   * Robustness *
	   
   ***************************************
   ***************************************
   
include "$code/programs.do"
*=============================================================*
* PART 1: JACKKNIFE BY PROVINCE
*=============================================================*

****----------- LOAD DATA -----------****
use "$Output/Country/$matchgroup/Period05 $method $treat_type.dta", clear
xtset Grid_ID post


****----------- BASELINE ESTIMATE -----------****
xtreg ch_adj treat_post post mean_precip i.post#i.province_num, ///
    fe i(Grid_ID) cluster(district_encode)

estimates store jk_baseline
scalar b_base  = _b[treat_post]
scalar se_base = _se[treat_post]
scalar n_base  = e(N)

di "Baseline: b = " b_base "  SE = " se_base

* Provinces with treated cells
levelsof province_num if treat == 1, local(provinces)
local n_prov : word count `provinces'
di "Jackknifing across `n_prov' provinces..."

* Collect results into postfile
tempfile prov_jk
tempname pf_prov
postfile `pf_prov' ///
    str30 label int province_num double(coef se n delta) ///
    using `prov_jk', replace

* Baseline row (province_num = 0 as sentinel)
post `pf_prov' ("Overall") (0) (b_base) (se_base) (n_base) (0)

foreach p of local provinces {

    quietly levelsof province_name if province_num == `p', local(plab) clean
    local shortlab = substr("`plab'", 1, 25)

    quietly xtreg ch_adj treat_post post mean_precip i.post#i.province_num ///
        if province_num != `p', ///
        fe i(Grid_ID) cluster(district_encode)

    estimates store jkp_`p'
    local delta_p = _b[treat_post] - b_base

    post `pf_prov' ("`shortlab'") (`p') (_b[treat_post]) (_se[treat_post]) (e(N)) (`delta_p')
    di "Drop `plab': b = " _b[treat_post] "  delta = " `delta_p'
}

postclose `pf_prov'


*--- Sort provinces by effect size ---*
use `prov_jk', clear
gsort -coef

local pcf_sorted ""
local nrows = _N
forvalues i = 1/`nrows' {
    local lbl  = label[`i']
    local pnum = province_num[`i']
    if `pnum' == 0 {
        local pcf_sorted `"`pcf_sorted' (jk_baseline, keep(treat_post) rename(treat_post = "`lbl'") mfcolor(navy) mcolor(navy) msize(medsmall))"'
    }
    else {
        local pcf_sorted `"`pcf_sorted' (jkp_`pnum', keep(treat_post) rename(treat_post = "`lbl'") mfcolor(white) mcolor(navy) msize(small))"'
    }
}

*--- Province jackknife coefplot ---*
coefplot `pcf_sorted', ///
    xline(`=b_base', lcolor(navy) lpattern(dash) lwidth(thin)) ///
    xline(0, lcolor(gs10) lpattern(shortdash) lwidth(thin)) ///
    msymbol(D) ///
    ciopts(lcolor(navy%50) lwidth(thin)) ///
    xlabel(, format(%4.0f) labsize(vsmall) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) ///
    xtitle("CFM Effect on TCC (pp)", size(vsmall)) ///
    ytitle("") ylabel(, labsize(vsmall)) ///
    legend(off) ///
    graphregion(color(white) margin(l=0 r=3 t=2 b=2)) ///
    plotregion(color(white) margin(l=0 r=5 t=1 b=1)) ///
    xsize(7) ysize(9) scheme(s2mono)

graph export "$DFigures/SI Robustness Figure 2a.pdf", replace as(pdf)


*=============================================================*
* PART 2: JACKKNIFE BY COHORT
*=============================================================*

use "$Output/Praka/$matchgroup/Period $method $treat_type.dta", clear
xtset Unique_ID post
rename ch_adjtot ch_adj


****----------- BASELINE ESTIMATE -----------****
xtreg ch_adj treat_post post precip i.post#i.province_num, ///
    fe i(Grid_ID) cluster(district_encode)

estimates store jk_baseline
scalar b_base  = _b[treat_post]
scalar se_base = _se[treat_post]
scalar n_base  = e(N)

di "Baseline: b = " b_base "  SE = " se_base

*----------------------------------------------

* Confirm Cohort exists
cap confirm variable Cohort
if _rc {
    di as error "WARNING: Cohort not found. Check variable name for CF establishment year."
    di as error "Cohort jackknife skipped."
    stop
}

levelsof Cohort if treat == 1 & Cohort < ., local(cohorts)
local n_coh : word count `cohorts'
di "Jackknifing across `n_coh' cohorts..."

tempfile cohort_jk
tempname pf_coh
postfile `pf_coh' ///
    str30 label int cohort_year double(coef se n delta) ///
    using `cohort_jk', replace

* Baseline row (cohort_year = 0 as sentinel)
post `pf_coh' ("Overall") (0) (b_base) (se_base) (n_base) (0)

foreach c of local cohorts {

    quietly xtreg ch_adj treat_post post precip i.post#i.province_num ///
        if Cohort != `c' | treat == 0, ///
        fe i(Grid_ID) cluster(district_encode)

    estimates store jkc_`c'
    local delta_c = _b[treat_post] - b_base

    post `pf_coh' ("`c'") (`c') (_b[treat_post]) (_se[treat_post]) (e(N)) (`delta_c')
    di "Drop cohort `c': b = " _b[treat_post] "  delta = " `delta_c'
}

postclose `pf_coh'


*--- Sort cohorts by effect size ---*
use `cohort_jk', clear
gsort -coef

local pcc_sorted ""
local nrows = _N
forvalues i = 1/`nrows' {
    local lbl = label[`i']
    local cyr = cohort_year[`i']
    if `cyr' == 0 {
        local pcc_sorted `"`pcc_sorted' (jk_baseline, keep(treat_post) rename(treat_post = "`lbl'") mfcolor(navy) mcolor(navy) msize(medsmall))"'
    }
    else {
        local pcc_sorted `"`pcc_sorted' (jkc_`cyr', keep(treat_post) rename(treat_post = "Cohort `lbl'") mfcolor(white) mcolor(navy) msize(small))"'
    }
}

*--- Cohort jackknife coefplot ---*
coefplot `pcc_sorted', ///
    xline(`=b_base', lcolor(navy) lpattern(dash) lwidth(thin)) ///
    xline(0, lcolor(gs10) lpattern(shortdash) lwidth(thin)) ///
    msymbol(D) ///
    ciopts(lcolor(navy%50) lwidth(thin)) ///
    xlabel(, format(%4.0f) labsize(vsmall) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) ///
    xtitle("CFM Effect on TCC (pp)", size(vsmall)) ///
    ytitle("") ylabel(, labsize(vsmall)) ///
    legend(off) ///
    graphregion(color(white) margin(l=0 r=3 t=2 b=2)) ///
    plotregion(color(white) margin(l=0 r=5 t=1 b=1)) ///
    xsize(7) ysize(7) scheme(s2mono)

graph export "$DFigures/SI Robustness Figure 2b.pdf", replace as(pdf)


*=============================================================*
* PART 3: ALTERNATE MATCHING METHODS
*=============================================================*

****************************************
* SAMPLE TO HOLD FIXED
****************************************
local fixed_sample CFnoPAcell
	global fixed_sample `fixed_sample'

****************************************
* METHODS TO COMPARE
****************************************


****------------------------------------------------
* LOOP: Load each method, run main spec + TCC splits
****------------------------------------------------

local ster_dir "$Output/Country/$matchgroup"
local treat_type "`fixed_sample'_Main"

foreach MM in replace norep caliper cem {

	if "`MM'" == "replace"  local method "PSM-Replace"
	if "`MM'" == "norep"    local method "PSM-NoReplace"
	if "`MM'" == "caliper"  local method "PSM-Caliper"
	if "`MM'" == "cem"      local method "CEM"

	if "`MM'" == "cem"      local wgt "[pweight=cem_weights]"
	else                       local wgt ""

	display as text _newline "============================================"
	display as text "Sample: `fixed_sample'   Method: `method'"
	display as text "============================================"

	* Load data
	use "`ster_dir'/Period05 `method' `treat_type'.dta", clear

	xtset Grid_ID post

	* Count the units for later
	quietly count if treat==1 & post==0
		local n_treat_`MM' = r(N)
	quietly count if treat==0 & post==0
		local n_control_`MM' = r(N)
	quietly levelsof CF_Unique if treat==1 & post==0
		local n_cf_`MM' = r(r)

	** MAIN ESTIMATION
	xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
		`wgt', fe i(Grid_ID) cluster(district_encode)
	estimates save "`ster_dir'/mmcompare_`MM'_main.ster", replace

	** HIGH VS LOW TCC SUBSAMPLES
	capture drop aboveMEDtcc1 belowMEDtcc1
	summarize tcc_adj2005 if tcc_adj2005 < ., detail
	scalar med_tcc05_1 = r(p50)
	gen aboveMEDtcc1 = tcc_adj2005 > med_tcc05_1 if tcc_adj2005 < .
	gen belowMEDtcc1 = tcc_adj2005 <= med_tcc05_1 if tcc_adj2005 < .

	xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
		`wgt' if aboveMEDtcc1 == 1, fe i(Grid_ID) cluster(district_encode)
	estimates save "`ster_dir'/mmcompare_`MM'_hi1.ster", replace

	xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
		`wgt' if belowMEDtcc1 == 1, fe i(Grid_ID) cluster(district_encode)
	estimates save "`ster_dir'/mmcompare_`MM'_lo1.ster", replace

}


****------------------------------------------------
* RELOAD ALL ESTIMATES
****------------------------------------------------

foreach MM in replace norep caliper cem {
	estimates use "`ster_dir'/mmcompare_`MM'_main.ster"
	estimates store mm_`MM'_main
	estimates use "`ster_dir'/mmcompare_`MM'_hi1.ster"
	estimates store mm_`MM'_hi1
	estimates use "`ster_dir'/mmcompare_`MM'_lo1.ster"
	estimates store mm_`MM'_lo1
}


****------------------------------------------------
* Graph 2: TCC Median across methods
****------------------------------------------------
coefplot ///
	(mm_replace_main, keep(treat_post) rename(treat_post = "Overall")       mfcolor(navy))  ///
	(mm_replace_hi1,  keep(treat_post) rename(treat_post = "High TCC")      mfcolor(white)) ///
	(mm_replace_lo1,  keep(treat_post) rename(treat_post = "Low TCC")       mfcolor(white)) ///
	(mm_norep_main,   keep(treat_post) rename(treat_post = "Overall ")      mfcolor(navy))  ///
	(mm_norep_hi1,    keep(treat_post) rename(treat_post = "High TCC ")     mfcolor(white)) ///
	(mm_norep_lo1,    keep(treat_post) rename(treat_post = "Low TCC ")      mfcolor(white)) ///
	(mm_caliper_main, keep(treat_post) rename(treat_post = "Overall  ")     mfcolor(navy))  ///
	(mm_caliper_hi1,  keep(treat_post) rename(treat_post = "High TCC  ")    mfcolor(white)) ///
	(mm_caliper_lo1,  keep(treat_post) rename(treat_post = "Low TCC  ")     mfcolor(white)) ///
	(mm_cem_main,     keep(treat_post) rename(treat_post = "Overall   ")    mfcolor(navy))  ///
	(mm_cem_hi1,      keep(treat_post) rename(treat_post = "High TCC   ")   mfcolor(white)) ///
	(mm_cem_lo1,      keep(treat_post) rename(treat_post = "Low TCC   ")    mfcolor(white)), ///
	headings("Overall"    = "{bf:With Replacement}" ///
	         "Overall "   = "{bf:No Replacement}"   ///
	         "Overall  "  = "{bf:Caliper (2.0)}"          ///
	         "Overall   " = "{bf:CEM}",             ///
	         labsize(small)) ///
	xline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
	msymbol(D) msize(medsmall) mcolor(navy) ///
	ciopts(lcolor(navy) lwidth(medthin)) ///
	xlabel(-2.5(2.5)15, format(%4.1f) labsize(vsmall) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) ///
	xtitle("CFM Effect on TCC (pp)", size(small)) ///
	ytitle("") ylabel(, labsize(vsmall)) ///
	legend(off) ///
	title("Main DID Effects by Alternate Matching Methods", size(medium)) ///
	graphregion(color(white) margin(l=0 r=3 t=2 b=2)) ///
	plotregion(color(white) margin(l=0 r=5 t=1 b=1)) ///
	xsize(7) ysize(5) ///
	scheme(s2mono)
graph save "$figures/Country/$matchgroup/intermediate/MethodCompare_TCC $matchgroup $fixed_sample.gph", replace

****------------------------------------------------
* Graph 3: Include Sample Sizes
****------------------------------------------------

* Make Sample Size Bar Chart, then Combine to Graph 2
clear
set obs 4
gen method_num = _n
gen n_treat   = cond(method_num==1, `n_treat_replace',   ///
                cond(method_num==2, `n_treat_norep',     ///
                cond(method_num==3, `n_treat_caliper',   `n_treat_cem')))
gen n_control = cond(method_num==1, `n_control_replace', ///
                cond(method_num==2, `n_control_norep',   ///
                cond(method_num==3, `n_control_caliper', `n_control_cem')))
graph bar (mean) n_treat (mean) n_control, ///
	over(method_num, relabel(1 "With Replacement" 2 "No Replacement" 3 "Caliper (2.0)" 4 "CEM")) ///
	legend(order(1 "Treated" 2 "Control") size(small) pos(6) cols(2)) ///
	blabel(bar, format(%9.0f) size(vsmall)) ///
	ylab(, labsize(small)) ///
	ytitle("Grid Cells", size(small)) ///
	subtitle("# CFs:  Replace(`n_cf_replace')  NoRep(`n_cf_norep')  Caliper(`n_cf_caliper')  CEM(`n_cf_cem')", size(vsmall)) ///
	title("Sample Sizes by Alternate Matching Methods", size(medium)) ///
	graphregion(color(white)) scheme(s2mono)
graph save "$figures/Country/$matchgroup/intermediate/mmcompare_tcc_bar.gph", replace

* Combine and export
graph combine "$figures/Country/$matchgroup/intermediate/MethodCompare_TCC $matchgroup $fixed_sample.gph" ///
		       "$figures/Country/$matchgroup/intermediate/mmcompare_tcc_bar.gph", ///
	cols(2) xsize(11) ysize(5) graphregion(color(white)) scheme(s2mono)
graph export "$DFigures/SI Robustness Figure 1.pdf", replace as(pdf)


*=============================================================*
* PART 4: MATCHING WITHIN BASELINE TCC SUBGROUPS
*=============================================================*

****************************************
****************************************
* (4.1) MATCHING WITHIN BASELINE TCC HALVES (COUNTRY)
****************************************
****************************************
global match_vars "ch_adj2005_1990 tcc_adj2005 Farm2005 Forest2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000"
global outcome_var "ch_adj2023_2005"

* Median baseline TCC
use "$Output/$sample/$matchgroup/Period05 $method $treat_type.dta", clear
summarize tcc_adj2005 if tcc_adj2005 < ., detail
scalar med_tcc05 = r(p50)
display "Median baseline TCC (main matched sample): " med_tcc05

foreach h in Above Below {

	* Pre-process
	preprocess

	* Keep the half
	if "`h'" == "Above" keep if tcc_adj2005 >  med_tcc05 & tcc_adj2005 < .
	if "`h'" == "Below" keep if tcc_adj2005 <= med_tcc05

	* Drop groups with no CF cells in this half
	bysort $group_var: egen group_treat_half = total(treat)
	drop if group_treat_half == 0
	tab $group_var treat

	* Matching Loop
	levelsof $group_var, local(group_list)
	local done
	foreach j in `group_list' {
		preserve
		display "Running Matching for Group: `j' (`h' median TCC)"

		* Set seed
		set seed 339487731

		capture noisily psmatch2 treat ($match_vars) if $group_var == `j', out($outcome_var) $psm_noreplacement_options
		local rc = _rc
		* If the probit does not converge (error 430), match on the 50-iteration probit score
		if `rc' == 430 {
			display as error "Probit did not converge in group `j': matching on the 50-iteration probit score"
			capture probit treat $match_vars if $group_var == `j', iterate(50)
			capture predict double ps_cap if $group_var == `j'
			if _rc == 0 {
				capture noisily psmatch2 treat if $group_var == `j', pscore(ps_cap) out($outcome_var) $psm_noreplacement_options
				local rc = _rc
			}
			capture drop ps_cap
		}
		if `rc' != 0 {
			display as error "Matching failed in group `j' (error `rc'): group skipped"
			restore
			continue
		}

		* Drop treated and control cells that lack support
		gen pair = $pair_id_var if $pair_treated_var == 0
		replace pair = $pair_control_var if $pair_treated_var == 1
		bysort pair: egen paircount = count(pair)
		drop if paircount < 2

		*Save file of matches for this group
		gen MATCHGROUP = `j'
		save "$Matching/$sample/$matchgroup/SubMatch/intermediate/`j'_match05 `h' $method $treat_type.dta", replace

		restore
		local done `done' `j'
	}
	display "Matched groups (`h' median TCC): `done'"

	* Combine MatchExact Datasets
	local first_group : word 1 of `done'
	use "$Matching/$sample/$matchgroup/SubMatch/intermediate/`first_group'_match05 `h' $method $treat_type.dta", clear
	foreach v of local done {
		if "`v'" != "`first_group'" {
			append using "$Matching/$sample/$matchgroup/SubMatch/intermediate/`v'_match05 `h' $method $treat_type.dta"
		}
	}

	* Create unique pair IDs, and sort matched pairs
	egen pair_unique = group(pair $group_var)
	sort pair_unique treat
	capture drop duplicate
	duplicates tag pair_unique, gen(duplicate)
	assert duplicate == 1
	drop duplicate

	* Placeholders for cem vars
	foreach v in cem_strata cem_matched cem_weights {
		gen `v' = .
	}
	save "$Matching/$sample/$matchgroup/SubMatch/Matched05 `h' $method $treat_type.dta", replace
}


****************************************
****************************************
* (4.2) POST-MATCHING PANELS (both halves)
****************************************
****************************************
foreach h in Above Below {

* ANNUAL Panel (TCC and precipitation only)
use "$Matching/$sample/$matchgroup/SubMatch/Matched05 `h' $method $treat_type.dta", clear
	local annualvars Grid_ID treat province_num district_encode
	forvalues y = 1990/2023 {
		local annualvars `annualvars' tcc_adj`y' precip`y'
	}
	keep `annualvars'
	reshape long tcc_adj precip, i(Grid_ID) j(year)
	gen aboveMEDtcc = ("`h'" == "Above")
	save "$Output/$sample/$matchgroup/SubMatch/Annual05 `h' $method $treat_type.dta", replace

* PERIOD Panel (05)
use "$Matching/$sample/$matchgroup/SubMatch/Matched05 `h' $method $treat_type.dta", clear
rename ch2023_2005 ch1
rename ch2005_1990 ch0
rename ch_adj2023_2005 	ch_adj1
rename ch_adj2005_1990	ch_adj0
rename precip2023_2005 mean_precip1
rename precip2005_1990 mean_precip0

	* Keep and reorder key variables
	keep 	Grid_ID treat treat_Pct treat_Ha treatCFany treatCFnoPA* treatCFinPA* treatCPA CFinPA* CFnoPA* CF CPA CBF_Type PA  ///
			PA_CF_ID PA_CF_ID_num PA_CF_year PA_CF_ha PA_CF_type PA_CF_name PA_CF_HaOverlap CF_Ha_inPA CF_Ha_outPA ///
			PA_Cell_ID PA_Cell_ID_num PA_Cell_year PA_Cell_ha PA_Cell_type PA_Cell_name ///
			CF_Grid_Dist PA_Grid_Dist PA_Cell_PctOverlap PA_CF_PctOverlap ELC* ///
			ch1 ch0 ch_adj1 ch_adj0 mean_precip* elevation slope aspect d_road d_edge pop tcc2005 tcc_adj2005 ///
			AdjTCC_05_00 Forest2005 Farm2005 Farm_05_00 Plantat2005 Plantat_05_00 NonForNat2005 NonVeg2005 Water2005 Other2005 ///
			district* province* Ecoregion* buff* CF_Unique CF_Hectares Year_Praka Establish Legal_Stat ///
			pair_unique cem_strata cem_matched cem_weights

	order 	Grid_ID treat treat_Pct treat_Ha treatCFany treatCFnoPA* treatCFinPA* treatCPA CFinPA* CFnoPA* CF CPA CBF_Type PA  ///
			PA_CF_ID PA_CF_ID_num PA_CF_year PA_CF_ha PA_CF_type PA_CF_name PA_CF_HaOverlap CF_Ha_inPA CF_Ha_outPA ///
			PA_Cell_ID PA_Cell_ID_num PA_Cell_year PA_Cell_ha PA_Cell_type PA_Cell_name ///
			CF_Grid_Dist PA_Grid_Dist PA_Cell_PctOverlap PA_CF_PctOverlap ELC* ///
			ch1 ch0 ch_adj1 ch_adj0 mean_precip* elevation slope aspect d_road d_edge pop tcc2005 tcc_adj2005 ///
			AdjTCC_05_00 Forest2005 Farm2005 Farm_05_00 Plantat2005 Plantat_05_00 NonForNat2005 NonVeg2005 Water2005 Other2005 ///
			district* province* Ecoregion* buff* CF_Unique CF_Hectares Year_Praka Establish Legal_Stat ///
			pair_unique cem_strata cem_matched cem_weights

	* Reshape data for period panel
	reshape long ch ch_adj mean_precip, i(Grid_ID) j(post)

	* Labels
	label var post "Post-2005"
	label var ch "TCC Change"
	label var ch_adj "Adj TCC Change"
	label var mean_precip "Precip Change (mm)"
	foreach v in Forest2005 NonForNat2005 NonVeg2005 Water2005 Other2005 {
		label var `v' "`v' (%) 2005"
	}
	label var Farm2005 "Farm (%) 2005"
	label var Plantat2005 "Plantat (%) 2005"
	label var Farm_05_00 "Ch Farm (pp) 00-05"
	label var Plantat_05_00 "Ch Plantat (pp) 00-05"
	label var AdjTCC_05_00 "Ch Adj TCC 00-05"
	label var tcc2005 "TCC (%) 2005"
	label var tcc_adj2005 "Adj TCC (%) 2005"

	* Interaction Vars
	gen treat_post = treat * post
		label var treat_post "CF x Post"
	gen treat_pct_post = treat_Pct * post
		label var treat_pct_post "Pct. CF x Post"
	gen treat_ha_post = treat_Ha * post
		label var treat_ha_post "Ha CF x Post"
	capture foreach v in slope elevation aspect d_road d_edge PA {
		gen `v'_post = `v' * post
	}
	label var slope_post "Slope x Post"
	label var elevation_post "Elev. x Post"
	label var aspect_post "Aspect x Post"
	label var d_road_post "D. Road x Post"
	label var d_edge_post "D. Forest x Post"
	capture label var PA_post "PA x Post"

	*Order new variables
	order treat_post treat_pct_post treat_ha_post, after(treat)
	order slope_post elevation_post aspect_post d_road_post d_edge_post, after(tcc_adj2005)
	order PA_post, after(PA)

	* Subgroup indicator
	gen aboveMEDtcc = ("`h'" == "Above")

	* Save period panel dataset
	save "$Output/$sample/$matchgroup/SubMatch/Period05 `h' $method $treat_type.dta", replace
}


****************************************
****************************************
* (4.3) TABLE 1 COLUMNS 5-6 AND FIGURE 2a WITH SUBGROUP MATCHING
****************************************
****************************************
* Main estimate
use "$Output/$sample/$matchgroup/Period05 $method $treat_type.dta", clear
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store col1
    global att = _b[treat_post]

* Subgroup-matched sample: both halves
use "$Output/$sample/$matchgroup/SubMatch/Period05 Above $method $treat_type.dta", clear
append using "$Output/$sample/$matchgroup/SubMatch/Period05 Below $method $treat_type.dta"
gen belowMEDtcc = 1 - aboveMEDtcc

*----------------------------------------------------------------------
* Columns 5-6 with subgroup matching
*----------------------------------------------------------------------
foreach h in above below {
	if "`h'" == "above" local est "sm_col7"
	if "`h'" == "below" local est "sm_col8"
	xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
	    if `h'MEDtcc == 1, fe i(Grid_ID) cluster(district_encode)
	    estimates store `est'
	    local b = _b[treat_post]
	    quietly summarize ch_adj if e(sample) & treat == 1 & post == 1
	    local cf_loss = -r(mean) + `b'
	    quietly summarize treat_Pct if e(sample) & treat == 1 & post == 1
	    local area = `b' / 100 * 0.09 * r(sum) / 100
	    estadd scalar cf_loss = `cf_loss'
	    estadd scalar share   = 100 * `b' / `cf_loss'
	    estadd scalar area    = `area'
	    estadd scalar cells   = e(N_g)
	    estadd local Grid_FE      "Yes"
	    estadd local ProvPost_FE  "Yes"
	    estadd local Interactions "No"
	    estadd local Clustering   "District"
}

* LaTeX table
esttab sm_col7 sm_col8 using "${tables}/$sample/$matchgroup/Robustness SubMatch Columns 5-6 $matchgroup $method $treat_type.tex", ///
	label replace starlevels(* 0.10 ** 0.05 *** 0.01) nogaps nonumber nonotes ///
	keep(treat_post) varlabels(treat_post "CFM Impact") ///
	varwidth(3) style(tex) ///
	mgroups("Baseline TCC (2005)", pattern(1 0) ///
		span prefix(\multicolumn{@span}{c}{) suffix(}) ///
		erepeat(\cmidrule(lr){@span})) ///
	mtitles("(5) Above Med." "(6) Below Med.") ///
	b(%9.2f) se(%9.2f) ///
	stats(cells Grid_FE ProvPost_FE Interactions Clustering, ///
		fmt(%12.0fc 0 0 0 0) ///
		labels("Observations" "Grid FE" "Prov-Post FE" "Interactions" "Clustering"))
copy "${tables}/$sample/$matchgroup/Robustness SubMatch Columns 5-6 $matchgroup $method $treat_type.tex" ///
     "$DTables/SI Robustness Table 1.tex", replace

*----------------------------------------------------------------------
* Deforestation Pressure Index
*----------------------------------------------------------------------
quietly summarize d_road if d_road < .
gen d_road_std = (d_road - r(mean)) / r(sd)
quietly summarize d_edge if d_edge < .
gen d_edge_std = (d_edge - r(mean)) / r(sd)
quietly summarize pop_2000 if pop_2000 < .
gen pop_std = (pop_2000 - r(mean)) / r(sd)
quietly summarize ELC_Grid_Dist if ELC_Grid_Dist < .
gen ELC_dist_std = (ELC_Grid_Dist - r(mean)) / r(sd)
gen def_press_idx = (-ELC_dist_std - d_road_std - d_edge_std + pop_std) / 4
label var def_press_idx "Deforestation pressure index"
	quietly summarize def_press_idx if def_press_idx < ., detail
	scalar med_def_press = r(p50)
	gen hi_def_press = (def_press_idx > med_def_press) if def_press_idx < .

* High def press + High TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
    if hi_def_press == 1 & aboveMEDtcc == 1, fe i(Grid_ID) cluster(district_encode)
    estimates store sm_dp_HiHi
* High def press + Low TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
    if hi_def_press == 1 & belowMEDtcc == 1, fe i(Grid_ID) cluster(district_encode)
    estimates store sm_dp_HiLo
* Low def press + High TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
    if hi_def_press == 0 & aboveMEDtcc == 1, fe i(Grid_ID) cluster(district_encode)
    estimates store sm_dp_LoHi
* Low def press + Low TCC
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num ///
    if hi_def_press == 0 & belowMEDtcc == 1, fe i(Grid_ID) cluster(district_encode)
    estimates store sm_dp_LoLo

****------------------------------------------------
* Heterogeneity Figure (Figure 2a with subgroup matching)
****------------------------------------------------
coefplot ///
    (col1,       keep(treat_post) rename(treat_post = "{bf:Main}")                mfcolor(navy)) ///
    (sm_col7,    keep(treat_post) rename(treat_post = "High TCC")                 mfcolor(white)) ///
    (sm_col8,    keep(treat_post) rename(treat_post = "Low TCC")                  mfcolor(white)) ///
    (sm_dp_HiHi, keep(treat_post) rename(treat_post = "High Pressure, High TCC")  mfcolor(white)) ///
    (sm_dp_LoHi, keep(treat_post) rename(treat_post = "Low Pressure, High TCC")   mfcolor(white)) ///
    (sm_dp_HiLo, keep(treat_post) rename(treat_post = "High Pressure, Low TCC")   mfcolor(white)) ///
    (sm_dp_LoLo, keep(treat_post) rename(treat_post = "Low Pressure, Low TCC")    mfcolor(white)), ///
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
graph export "$DFigures/SI Robustness Figure 3a.pdf", replace as(pdf)


****************************************
****************************************
* (4.4) FIGURE 2b-d WITH SUBGROUP MATCHING
****************************************
****************************************
use "$Output/$sample/$matchgroup/SubMatch/Annual05 Above $method $treat_type.dta", clear
append using "$Output/$sample/$matchgroup/SubMatch/Annual05 Below $method $treat_type.dta"
rename aboveMEDtcc aboveMED_tcc
tempfile annual_sm
save `annual_sm'

** Parallel Trends Graph (Above/Below Median Baseline TCC)
	collapse (mean) tcc_adj, by(year treat aboveMED_tcc)
	keep if year>1999

	preserve
		keep if aboveMED_tcc==1
		tw (line tcc_adj year if treat==1, color("51 166 166") lwidth(0.5)) ///
		   (line tcc_adj year if treat==0, color("242 80 65") lwidth(0.5)), ///
		   legend(lab(1 "{bf:Treated}") lab(2 "{bf:Control}") size(*1.15) pos(6) col(2)) ///
		   ytitle("Tree Canopy Cover (%)", size(*1.15)) ylabel(10(10)60, labsize(*1.115)) ///
		   xtitle("Year", size(*1.1)) xlabel(2000(2)2023, angle(45) labsize(*1.15)) xline(2005) ///
		   title("Above Median Baseline TCC", size(*0.8))
		  graph save "$figures/Country/$matchgroup/Robustness/SubMatch Parallel Trends AboveMedianTCC $matchgroup $method $treat_type.gph", replace
	restore
	keep if aboveMED_tcc==0
		tw (line tcc_adj year if treat==1, color("51 166 166") lwidth(0.5)) ///
		   (line tcc_adj year if treat==0, color("242 80 65") lwidth(0.5)), ///
		   legend(lab(1 "{bf:Treated}") lab(2 "{bf:Control}") size(*1.15) pos(6) col(2)) ///
		   ytitle("Tree Canopy Cover (%)", size(*1.15)) ylabel(10(10)60, labsize(*1.115)) ///
		   xtitle("Year", size(*1.1)) xlabel(2000(2)2023, angle(45) labsize(*1.15)) xline(2005) ///
		   title("Below Median Baseline TCC", size(*0.8))
		  graph save "$figures/Country/$matchgroup/Robustness/SubMatch Parallel Trends BelowMedianTCC $matchgroup $method $treat_type.gph", replace

	grc1leg2  	"$figures/Country/$matchgroup/Robustness/SubMatch Parallel Trends AboveMedianTCC $matchgroup $method $treat_type.gph" ///
				"$figures/Country/$matchgroup/Robustness/SubMatch Parallel Trends BelowMedianTCC $matchgroup $method $treat_type.gph", ///
				legendfrom("$figures/Country/$matchgroup/Robustness/SubMatch Parallel Trends AboveMedianTCC $matchgroup $method $treat_type.gph") position(6)
	graph export "$DFigures/SI Robustness Figure 3b.png", replace as(png)

** Dynamic DiD: Stratified by Above/Below Median TCC
use `annual_sm', clear
xtset Grid_ID year
gen post = year>2005

* Above-median TCC
xtreg tcc_adj ib(2005).year##i.treat precip c.year#i.province_num c.year#i.post#i.province_num ///
	if year>=2000 & aboveMED_tcc == 1, fe i(Grid_ID) cluster(district_encode)
est store sm_HiTCC, title(High TCC)

* Below-median TCC
xtreg tcc_adj ib(2005).year##i.treat precip c.year#i.province_num c.year#i.post#i.province_num ///
	if year>=2000 & aboveMED_tcc == 0, fe i(Grid_ID) cluster(district_encode)
est store sm_LoTCC, title(Low TCC)

foreach m in HiTCC LoTCC {
	if "`m'" == "HiTCC" local fname "SI Robustness Figure 3c"
	if "`m'" == "LoTCC" local fname "SI Robustness Figure 3d"
	coefplot sm_`m', keep(2000.year#1.treat 2001.year#1.treat 2002.year#1.treat 2003.year#1.treat 2004.year#1.treat 2005.year#1.treat 2006.year#1.treat 2007.year#1.treat 2008.year#1.treat 2009.year#1.treat 2010.year#1.treat 2011.year#1.treat 2012.year#1.treat 2013.year#1.treat 2014.year#1.treat 2015.year#1.treat 2016.year#1.treat 2017.year#1.treat 2018.year#1.treat 2019.year#1.treat 2020.year#1.treat 2021.year#1.treat 2022.year#1.treat 2023.year#1.treat) order(*year) vertical ///
	    coeflabels(2000.year#1.treat="00" 2001.year#1.treat="01" 2002.year#1.treat="02" 2003.year#1.treat="03" 2004.year#1.treat="04" 2005.year#1.treat="05" 2006.year#1.treat="06" 2007.year#1.treat="07" 2008.year#1.treat="08" 2009.year#1.treat="09" 2010.year#1.treat="10" 2011.year#1.treat="11" 2012.year#1.treat="12" 2013.year#1.treat="13" 2014.year#1.treat="14" 2015.year#1.treat="15" 2016.year#1.treat="16" 2017.year#1.treat="17" 2018.year#1.treat="18" 2019.year#1.treat="19" 2020.year#1.treat="20" 2021.year#1.treat="21" 2022.year#1.treat="22" 2023.year#1.treat="23") ///
	    groups(2000.year#1.treat - 2004.year#1.treat = "{bf:Pre-CFM}" ///
	           2006.year#1.treat - 2023.year#1.treat = "{bf:Post-CFM}") ///
	    yline(0, lpattern(line)) ylabel(-5(5)20) xline(06, lcolor("236 196 77")) ///
	    color(gray) ciopts(lcolor(black) lwidth(thin)) pstyle(p12) ///
	    title("") ytitle("CFM Effect on TCC (pp)") note("", size(vsmall))
	graph export "$DFigures/`fname'.png", replace as(png)
}


****************************************
****************************************
* (4.5) CONTROL-GROUP CANOPY LOSS BY DEFORESTATION PRESSURE AND BASELINE TCC (SI Table 6)
****************************************
****************************************
use "$Output/$sample/$matchgroup/Period05 $method $treat_type.dta", clear

quietly summarize d_road if d_road < .
gen d_road_std = (d_road - r(mean)) / r(sd)
quietly summarize d_edge if d_edge < .
gen d_edge_std = (d_edge - r(mean)) / r(sd)
quietly summarize pop_2000 if pop_2000 < .
gen pop_std = (pop_2000 - r(mean)) / r(sd)
quietly summarize ELC_Grid_Dist if ELC_Grid_Dist < .
gen ELC_dist_std = (ELC_Grid_Dist - r(mean)) / r(sd)
gen def_press_idx = (-ELC_dist_std - d_road_std - d_edge_std + pop_std) / 4

* Quintiles
_pctile def_press_idx if treat == 1 & post == 0, nq(5)
gen press_q = 1 + (def_press_idx > r(r1)) + (def_press_idx > r(r2)) + (def_press_idx > r(r3)) + (def_press_idx > r(r4)) if def_press_idx < .
_pctile tcc_adj2005 if treat == 1 & post == 0, nq(5)
gen tcc_q = 1 + (tcc_adj2005 > r(r1)) + (tcc_adj2005 > r(r2)) + (tcc_adj2005 > r(r3)) + (tcc_adj2005 > r(r4)) if tcc_adj2005 < .

keep if treat == 0 & post == 1
gen ctrl_loss = -ch_adj
collapse (mean) ctrl_loss (count) n_controls = ctrl_loss, by(tcc_q press_q)
list tcc_q press_q ctrl_loss n_controls, sepby(tcc_q) noobs

* LaTeX table
tempname fh
file open `fh' using "${tables}/$sample/$matchgroup/Control Loss by Pressure and TCC $matchgroup $method $treat_type.tex", write replace
file write `fh' "\begin{tabular}{lccccc}" _n "\hline\hline" _n
file write `fh' " & \multicolumn{5}{c}{Deforestation pressure quintile} \\ \cmidrule(lr){2-6}" _n
file write `fh' "Baseline TCC quintile & P1 (low) & P2 & P3 & P4 & P5 (high) \\" _n "\hline" _n
forvalues t = 5(-1)1 {
	local row "Q`t'"
	if `t' == 5 local row "Q5 (high)"
	if `t' == 1 local row "Q1 (low)"
	forvalues q = 1/5 {
		quietly summarize ctrl_loss if tcc_q == `t' & press_q == `q'
		local row "`row' & `: display %5.1f r(mean)'"
	}
	file write `fh' "`row' \\" _n
}
file write `fh' "\hline\hline" _n "\end{tabular}" _n
file close `fh'
copy "${tables}/$sample/$matchgroup/Control Loss by Pressure and TCC $matchgroup $method $treat_type.tex" ///
     "$DTables/SI Table 6.tex", replace


****************************************
****************************************
* (4.6) FIGURE 4 (CF vs PA) WITH SUBGROUP MATCHING
****************************************
****************************************
global keyvars Grid_ID tcc_adj2005 AdjTCC_05_00 Forest2005 Farm2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000 PA PA_Grid* PA_CF* ELC* province* district*
global cfpa_vars "tcc_adj2005 ch_adj2005_1990 Forest2005 Farm2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000"

foreach h in Above Below {

*** (1) Get Protected Area Observations in this half
use "$input/Cleaned_Period.dta", clear
	keep if PA==1
	drop if treat==1
	if "`h'" == "Above" keep if tcc_adj2005 >  med_tcc05 & tcc_adj2005 < .
	if "`h'" == "Below" keep if tcc_adj2005 <= med_tcc05
	keep ch_adj_tccB05 mean_precipB05 post treat treat_Pct treatC* $keyvars
	rename ch_adj_tccB05 ch_adj
	rename mean_precipB05 mean_precip
	tempfile PAs
	save `PAs'

*** (2) Add Protected Areas to the half's Post-Matching Controls
use "$Output/$sample/$matchgroup/SubMatch/Period05 `h' $method $treat_type.dta", clear
	keep if treat==0
	assert PA!=1
	append using `PAs'
	keep ch_adj mean_precip post treat treat_Pct treatC* $keyvars
	gen Control = 1 if PA==0
		replace Control = 0 if Control != 1
		drop treat
	order Grid_ID Control PA
	reshape wide ch_adj mean_precip, i(Grid_ID) j(post)
	rename ch_adj0 ch_adj2005_1990
	rename ch_adj1 ch_adj2023_2005
	label var ch_adj2005_1990 "Ch Adj TCC 90-05"
	label var ch_adj2023_2005 "Ch Adj TCC 05-23"

*** (3) Match PAs to the Control Group
	* Drop Groups with Insufficient PA or Control Observations
	bysort $group_var: egen group_PA_count = total(PA)
	drop if group_PA_count == 0
	if $ProvinceExact == 1 {
		drop if group_PA_count < 200
		drop if province_name == "Takeo"
		}
	bysort $group_var: egen group_Control_count = total(Control)
	drop if group_Control_count == 0
	if $ProvinceExact == 1 {
		drop if group_Control_count < 200
		drop if province_name == "Takeo"
		}

	levelsof $group_var, local(group_list)
	local done
	foreach j in `group_list' {
		display "Running PA Matching for Group: `j' (`h' median TCC)"
		preserve
		set seed 339487731
		capture noisily psmatch2 Control $cfpa_vars if $group_var==`j', out(ch_adj2023_2005) noreplacement neighbor(1) common
		local rc = _rc
		* If the probit does not converge (error 430), match on the 50-iteration probit score
		if `rc' == 430 {
			display as error "Probit did not converge in group `j': matching on the 50-iteration probit score"
			capture probit Control $cfpa_vars if $group_var==`j', iterate(50)
			capture predict double ps_cap if $group_var==`j'
			if _rc == 0 {
				capture noisily psmatch2 Control if $group_var==`j', pscore(ps_cap) out(ch_adj2023_2005) noreplacement neighbor(1) common
				local rc = _rc
			}
			capture drop ps_cap
		}
		if `rc' != 0 {
			display as error "PA matching failed in group `j' (error `rc'): group skipped"
			restore
			continue
		}
		keep if $group_var==`j'
		gen pair = _id if _treated ==0
			replace pair = _n1 if _treated ==1
			bysort pair: egen paircount = count(pair)
		drop if paircount < 2
		*Drop observations with really bad common support
		replace _pdif = 0 if _pdif == .
		bysort pair: egen pdif = max(_pdif)
		drop if pdif > 0.005
		gen MATCHGROUP = `j'
		save "$Matching/CFvsPA/$matchgroup/SubMatch/`j'_match `h'.dta", replace
		restore
		local done `done' `j'
	}
	local first_group : word 1 of `done'
	use "$Matching/CFvsPA/$matchgroup/SubMatch/`first_group'_match `h'.dta", clear
	foreach v of local done {
		if "`v'" != "`first_group'" {
			append using "$Matching/CFvsPA/$matchgroup/SubMatch/`v'_match `h'.dta"
		}
	}
	egen unique_ID_match = group($group_var Grid_ID)
	sort $group_var pair $pair_treated_var
	order Grid_ID Control PA
	save "$Output/CFvsPA/SubMatch/02_PA_and_Controls_Matched `h'.dta", replace

*** (4) Fetch CFs linked to Postmatching PA-Control Data
use "$Output/CFvsPA/SubMatch/02_PA_and_Controls_Matched `h'.dta", clear
	keep if Control==1
	keep Grid_ID
	gen CommonControl = 1
	tempfile commoncontrol
	save `commoncontrol'

	use "$Matching/$sample/$matchgroup/SubMatch/Matched05 `h' $method $treat_type.dta", clear
		merge 1:1 Grid_ID using `commoncontrol'
		bysort $group_var pair: egen KEEP = max(CommonControl)
		keep if KEEP == 1
		rename treat CF_relevant
		rename precip2023_2005 mean_precip1
		rename precip2005_1990 mean_precip0
		keep CF_relevant ch_adj2023_2005 ch_adj2005_1990 mean_precip* $keyvars
		order Grid_ID CF_relevant ch_adj2023_2005 ch_adj2005_1990 mean_precip* $keyvars
		drop PA*
		save "$Output/CFvsPA/SubMatch/03_CF_Relevant `h'.dta", replace

*** (5) Match CFs to Controls
	use "$Output/CFvsPA/SubMatch/03_CF_Relevant `h'.dta", clear
	gen Control = 1 if CF_relevant==0
		replace Control = 0 if CF_relevant==1

	levelsof $group_var, local(group_list)
	local done
	foreach j in `group_list' {
		display "Running CF Matching for Group: `j' (`h' median TCC)"
		preserve
		set seed 339487731
		capture noisily psmatch2 Control $cfpa_vars if $group_var==`j', out(ch_adj2023_2005) noreplacement neighbor(1) common
		local rc = _rc
		if `rc' == 430 {
			display as error "Probit did not converge in group `j': matching on the 50-iteration probit score"
			capture probit Control $cfpa_vars if $group_var==`j', iterate(50)
			capture predict double ps_cap if $group_var==`j'
			if _rc == 0 {
				capture noisily psmatch2 Control if $group_var==`j', pscore(ps_cap) out(ch_adj2023_2005) noreplacement neighbor(1) common
				local rc = _rc
			}
			capture drop ps_cap
		}
		if `rc' != 0 {
			display as error "CF matching failed in group `j' (error `rc'): group skipped"
			restore
			continue
		}
		keep if $group_var==`j'
		gen pair = _id if _treated ==0
			replace pair = _n1 if _treated ==1
			bysort pair: egen paircount = count(pair)
		drop if paircount < 2
		gen MATCHGROUP = `j'
		save "$Matching/CFvsPA/$matchgroup/SubMatch/`j'_match_Control_CF `h'.dta", replace
		restore
		local done `done' `j'
	}
	local first_group : word 1 of `done'
	use "$Matching/CFvsPA/$matchgroup/SubMatch/`first_group'_match_Control_CF `h'.dta", clear
	foreach v of local done {
		if "`v'" != "`first_group'" {
			append using "$Matching/CFvsPA/$matchgroup/SubMatch/`v'_match_Control_CF `h'.dta"
		}
	}
	keep if CF_relevant==1
	assert Control==0
	drop Control
	save "$Output/CFvsPA/SubMatch/04_Postmatching_CF_relevant `h'.dta", replace

*** (6) Return to PA Postmatch Dataset, and bring in the Relevant CFs
	use "$Output/CFvsPA/SubMatch/02_PA_and_Controls_Matched `h'.dta", clear
		keep ch_adj2023_2005 ch_adj2005_1990 mean_precip* Control $keyvars
		append using "$Output/CFvsPA/SubMatch/04_Postmatching_CF_relevant `h'.dta"
		rename CF_relevant CF
		replace CF = 0 if CF!=1
		replace Control = 0 if Control !=1
		replace PA = 0 if PA !=1
		gen aboveMED = ("`h'" == "Above")

**PERIOD PANEL**
	rename ch_adj2023_2005   ch_adj1
	rename ch_adj2005_1990   ch_adj0
	reshape long ch_adj mean_precip, i(Grid_ID) j(post)
	gen CF_post = CF*post
	gen PA_post = PA*post
	save "$Output/CFvsPA/SubMatch/05_CFvsPA_Postmatching_Period `h'.dta", replace
}

****----------- HETEROGENEITY: CF vs PA with subgroup matching -----------****
* Main Figure 4 estimates
use "$Output/CFvsPA/05_CFvsPA_Postmatching_Period.dta", clear
xtreg ch_adj CF_post post mean_precip i.post#i.province_num if PA!=1, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store CF_full
    local att_cf = _b[CF_post]
xtreg ch_adj PA_post post mean_precip i.post#i.province_num if CF!=1, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store PA_full
    local att_pa = _b[PA_post]

* Subgroup-matched CF vs PA sample: both halves
use "$Output/CFvsPA/SubMatch/05_CFvsPA_Postmatching_Period Above.dta", clear
append using "$Output/CFvsPA/SubMatch/05_CFvsPA_Postmatching_Period Below.dta"
gen belowMED = 1 - aboveMED

* Deforestation pressure index
quietly summarize ELC_Grid_Dist if ELC_Grid_Dist < .
gen ELC_dist_std  = (ELC_Grid_Dist - r(mean)) / r(sd)
quietly summarize d_road if d_road < .
gen d_road_std    = (d_road - r(mean)) / r(sd)
quietly summarize d_edge if d_edge < .
gen d_edge_std    = (d_edge - r(mean)) / r(sd)
quietly summarize pop_2000 if pop_2000 < .
gen pop_std       = (pop_2000 - r(mean)) / r(sd)
gen ext_press_idx = (-ELC_dist_std - d_road_std - d_edge_std + pop_std) / 4
quietly summarize ext_press_idx if ext_press_idx < ., detail
scalar med_pressure = r(p50)
gen hipressure = (ext_press_idx > med_pressure) if ext_press_idx < .

* --- CF and PA Subgroup Regressions ---
foreach g in CF PA {
	if "`g'" == "CF" local excl "PA!=1"
	if "`g'" == "PA" local excl "CF!=1"
	foreach s in HiTCC LoTCC HiHi HiLo LoHi LoLo {
		if "`s'" == "HiTCC" local cond "`excl' & aboveMED==1"
		if "`s'" == "LoTCC" local cond "`excl' & belowMED==1"
		if "`s'" == "HiHi"  local cond "`excl' & aboveMED==1 & hipressure==1"
		if "`s'" == "HiLo"  local cond "`excl' & aboveMED==1 & hipressure==0"
		if "`s'" == "LoHi"  local cond "`excl' & belowMED==1 & hipressure==1"
		if "`s'" == "LoLo"  local cond "`excl' & belowMED==1 & hipressure==0"
		capture drop n_grp n_ctl
		bysort province_num: egen n_grp = total((`g'==1) * (`cond'))
		bysort province_num: egen n_ctl = total((Control==1) * (`cond'))
		xtreg ch_adj `g'_post post mean_precip i.post#i.province_num ///
		    if (`cond') & n_grp > 0 & n_ctl > 0, fe i(Grid_ID) cluster(district_encode)
		    estimates store `g'_sm_`s'
	}
}

* --- Panels: Community Forests and Protected Areas ---
foreach g in CF PA {
	if "`g'" == "CF" {
		local col "31 73 125"
		local ttl "Community Forests"
		local att `att_cf'
		local xt "CFM Effect on TCC (pp)"
	}
	if "`g'" == "PA" {
		local col "51 122 122"
		local ttl "Protected Areas"
		local att `att_pa'
		local xt "PA Effect on TCC (pp)"
	}
	coefplot ///
	    (`g'_full,      keep(`g'_post) rename(`g'_post = "{bf:Main}")                mfcolor("`col'")) ///
	    (`g'_sm_HiTCC,  keep(`g'_post) rename(`g'_post = "High TCC")                 mfcolor(white)) ///
	    (`g'_sm_LoTCC,  keep(`g'_post) rename(`g'_post = "Low TCC")                  mfcolor(white)) ///
	    (`g'_sm_HiHi,   keep(`g'_post) rename(`g'_post = "High Pressure, High TCC")  mfcolor(white)) ///
	    (`g'_sm_HiLo,   keep(`g'_post) rename(`g'_post = "Low Pressure, High TCC")   mfcolor(white)) ///
	    (`g'_sm_LoHi,   keep(`g'_post) rename(`g'_post = "High Pressure, Low TCC")   mfcolor(white)) ///
	    (`g'_sm_LoLo,   keep(`g'_post) rename(`g'_post = "Low Pressure, Low TCC")    mfcolor(white)), ///
	    headings(" "                       = "{bf:Main}" ///
	             "High TCC"                = "{bf:Baseline TCC}" ///
	             "High Pressure, High TCC" = "{bf:Deforestation Pressure}", ///
	             labsize(vsmall)) ///
	    title("{bf:`ttl'}", size(medium) color("`col'")) ///
	    xline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
	    xline(`att', lcolor(grey) lpattern(dot) lwidth(med)) ///
	    msymbol(D) msize(medsmall) mcolor("`col'") ///
	    ciopts(lcolor("`col'") lwidth(medthin)) ///
	    xlabel(0(10)20, format(%4.0f) labsize(vsmall) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) ///
	    xscale(range(-5 20)) ///
	    xtitle("`xt'", size(vsmall)) ///
	    ytitle("") ylabel(, labsize(vsmall)) ///
	    legend(off) ///
	    graphregion(color(white) margin(l=0 r=3 t=2 b=2)) ///
	    plotregion(color(white) margin(l=0 r=5 t=1 b=1)) ///
	    xsize(5) ysize(6) scheme(s2mono)
	graph save "$figures/Country/$matchgroup/Robustness/SubMatch Heter_`g'.gph", replace
}

graph combine ///
    "$figures/Country/$matchgroup/Robustness/SubMatch Heter_CF.gph" ///
    "$figures/Country/$matchgroup/Robustness/SubMatch Heter_PA.gph", ///
    rows(1) imargin(2 2 2 2) ///
    graphregion(color(white)) ///
    xsize(12) ysize(6) scheme(s2mono)
graph export "$DFigures/SI Robustness Figure 4.pdf", replace as(pdf)

display as result "05c_ROBUST (Subgroup Matching) done."


*=============================================================*
* PART 5: PLACEBO, PRESSURE TEST, AND TCC BINS
*=============================================================*

****************************************
****************************************
* (5.1) PLACEBO: MATCHING WITH BASELINE 2000, "EFFECT" OVER 2000-2005
****************************************
****************************************
* Main design over 2005-2010
use "$Matching/$sample/$matchgroup/Matched05 $method $treat_type.dta", clear
gen ch_adj2010_2005 = tcc_adj2010 - tcc_adj2005
egen precip2010_2005 = rowmean(precip2006-precip2010)
keep Grid_ID treat province_num district_encode ch_adj2005_1990 ch_adj2010_2005 precip2005_1990 precip2010_2005
rename (ch_adj2005_1990 ch_adj2010_2005 precip2005_1990 precip2010_2005) (ch_adj0 ch_adj1 mean_precip0 mean_precip1)
reshape long ch_adj mean_precip, i(Grid_ID) j(post)
gen treat_post = treat * post
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store col1_10
    estadd scalar cells = e(N_g)
    estadd local Pre  "1990--2005"
    estadd local Post "2005--2010"

* Pre-process
preprocess

* Placebo variables (baseline 2000)
gen ch_adj2000_1990 = tcc_adj2000 - tcc_adj1990
gen ch_adj2005_2000 = tcc_adj2005 - tcc_adj2000
egen precip2000_1990 = rowmean(precip1990-precip2000)
egen precip2005_2000 = rowmean(precip2001-precip2005)
label var ch_adj2000_1990 "Ch Adj TCC 90-00"
label var ch_adj2005_2000 "Ch Adj TCC 00-05"

* Matching variables measured at 2000
global match_vars "ch_adj2000_1990 tcc_adj2000 Farm2000 Forest2000 Plantat2000 elevation slope d_road d_edge pop_2000"
global outcome_var "ch_adj2005_2000"

* Matching Loop
levelsof $group_var, local(group_list)
local done
foreach j in `group_list' {
	preserve
	display "Running Placebo Matching for Group: `j'"

	* Set seed
	set seed 339487731

	capture noisily psmatch2 treat ($match_vars) if $group_var == `j', out($outcome_var) $psm_noreplacement_options
	local rc = _rc
	* If the probit does not converge (error 430), match on the 50-iteration probit score
	if `rc' == 430 {
		display as error "Probit did not converge in group `j': matching on the 50-iteration probit score"
		capture probit treat $match_vars if $group_var == `j', iterate(50)
		capture predict double ps_cap if $group_var == `j'
		if _rc == 0 {
			capture noisily psmatch2 treat if $group_var == `j', pscore(ps_cap) out($outcome_var) $psm_noreplacement_options
			local rc = _rc
		}
		capture drop ps_cap
	}
	if `rc' != 0 {
		display as error "Matching failed in group `j' (error `rc'): group skipped"
		restore
		continue
	}

	* Drop treated and control cells that lack support
	gen pair = $pair_id_var if $pair_treated_var == 0
	replace pair = $pair_control_var if $pair_treated_var == 1
	bysort pair: egen paircount = count(pair)
	drop if paircount < 2

	gen MATCHGROUP = `j'
	save "$Matching/$sample/$matchgroup/Placebo2000/intermediate/`j'_match00 $method $treat_type.dta", replace
	restore
	local done `done' `j'
}
display "Matched groups (placebo 2000): `done'"

* Combine
local first_group : word 1 of `done'
use "$Matching/$sample/$matchgroup/Placebo2000/intermediate/`first_group'_match00 $method $treat_type.dta", clear
foreach v of local done {
	if "`v'" != "`first_group'" {
		append using "$Matching/$sample/$matchgroup/Placebo2000/intermediate/`v'_match00 $method $treat_type.dta"
	}
}
egen pair_unique = group(pair $group_var)
sort pair_unique treat
capture drop duplicate
duplicates tag pair_unique, gen(duplicate)
assert duplicate == 1
drop duplicate

* Placebo period panel
keep Grid_ID treat province_num district_encode ch_adj2000_1990 ch_adj2005_2000 precip2000_1990 precip2005_2000
rename (ch_adj2000_1990 ch_adj2005_2000 precip2000_1990 precip2005_2000) (ch_adj0 ch_adj1 mean_precip0 mean_precip1)
reshape long ch_adj mean_precip, i(Grid_ID) j(post)
gen treat_post = treat * post
	label var treat_post "CFM Impact"

* Placebo estimate
xtreg ch_adj treat_post post mean_precip i(1).post#i.province_num, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store placebo
    estadd scalar cells = e(N_g)
    estadd local Pre  "1990--2000"
    estadd local Post "2000--2005"

esttab col1_10 placebo using "${tables}/$sample/$matchgroup/Robustness Placebo 2000 $matchgroup $method $treat_type.tex", ///
	label replace starlevels(* 0.10 ** 0.05 *** 0.01) nogaps nonumber nonotes ///
	keep(treat_post) varlabels(treat_post "CFM Impact (pp)") ///
	varwidth(3) ///
	mgroups("Main (baseline 2005)" "Placebo (baseline 2000)", pattern(1 1) ///
		span prefix(\multicolumn{@span}{c}{) suffix(}) ///
		erepeat(\cmidrule(lr){@span})) ///
	mtitles("(1)" "(2)") ///
	b(%9.2f) se(%9.2f) style(tex) ///
	stats(Pre Post cells, fmt(0 0 %12.0fc) labels("Pre-period" "Post-period" "Observations"))
copy "${tables}/$sample/$matchgroup/Robustness Placebo 2000 $matchgroup $method $treat_type.tex" ///
     "$DTables/SI Robustness Table 3.tex", replace


****************************************
****************************************
* (5.2) PRESSURE DIFFERENCE TEST WITHIN EACH BASELINE-TCC HALF
****************************************
****************************************
use "$Output/$sample/$matchgroup/Period05 $method $treat_type.dta", clear

* Above/below median baseline TCC
summarize tcc_adj2005 if tcc_adj2005 < ., detail
scalar med_tcc05 = r(p50)
gen aboveMEDtcc = tcc_adj2005 > med_tcc05 if tcc_adj2005 < .

* Deforestation Pressure Index
quietly summarize d_road if d_road < .
gen d_road_std = (d_road - r(mean)) / r(sd)
quietly summarize d_edge if d_edge < .
gen d_edge_std = (d_edge - r(mean)) / r(sd)
quietly summarize pop_2000 if pop_2000 < .
gen pop_std = (pop_2000 - r(mean)) / r(sd)
quietly summarize ELC_Grid_Dist if ELC_Grid_Dist < .
gen ELC_dist_std = (ELC_Grid_Dist - r(mean)) / r(sd)
gen def_press_idx = (-ELC_dist_std - d_road_std - d_edge_std + pop_std) / 4
	quietly summarize def_press_idx if def_press_idx < ., detail
	scalar med_def_press = r(p50)
	gen hi_def_press = (def_press_idx > med_def_press) if def_press_idx < .

* One regression per half
foreach h in 1 0 {
	xtreg ch_adj c.treat_post##i.hi_def_press i(1).post#i.hi_def_press mean_precip i(1).post#i.province_num ///
	    if aboveMEDtcc == `h', fe i(Grid_ID) cluster(district_encode)
	local cells`h' = strtrim(string(e(N_g), "%12.0fc"))

	local k = 0
	foreach expr in "treat_post" "treat_post + 1.hi_def_press#c.treat_post" "1.hi_def_press#c.treat_post" {
		local ++k
		lincom `expr'
		local p = 2 * ttail(r(df), abs(r(estimate) / r(se)))
		local st ""
		if `p' < 0.10 local st "\sym{*}"
		if `p' < 0.05 local st "\sym{**}"
		if `p' < 0.01 local st "\sym{***}"
		local b`k'_`h'  = strtrim(string(r(estimate), "%9.2f")) + "`st'"
		local se`k'_`h' = "(" + strtrim(string(r(se), "%9.2f")) + ")"
	}
}

* LaTeX table
tempname fh
file open `fh' using "${tables}/$sample/$matchgroup/Robustness Pressure Test $matchgroup $method $treat_type.tex", write replace
file write `fh' "{" _n "\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}" _n
file write `fh' "\begin{tabular}{l*{2}{c}}" _n "\hline\hline" _n
file write `fh' " & \multicolumn{2}{c}{Baseline TCC (2005)} \\" _n "\cmidrule(lr){2-3}" _n
file write `fh' " & Above Med. & Below Med. \\" _n "\hline" _n
file write `fh' "CFM Impact, high pressure (pp) & `b2_1' & `b2_0' \\" _n
file write `fh' " & `se2_1' & `se2_0' \\" _n
file write `fh' "CFM Impact, low pressure (pp) & `b1_1' & `b1_0' \\" _n
file write `fh' " & `se1_1' & `se1_0' \\" _n
file write `fh' "\hline" _n
file write `fh' "Difference, high minus low (pp) & `b3_1' & `b3_0' \\" _n
file write `fh' " & `se3_1' & `se3_0' \\" _n
file write `fh' "\hline" _n
file write `fh' "Observations & `cells1' & `cells0' \\" _n
file write `fh' "\hline\hline" _n "\end{tabular}" _n "}" _n
file close `fh'
copy "${tables}/$sample/$matchgroup/Robustness Pressure Test $matchgroup $method $treat_type.tex" ///
     "$DTables/SI Robustness Table 2.tex", replace


****************************************
****************************************
* (5.3) CFM EFFECTS BY 10pp BASELINE-TCC BIN (SI Figure 7)
****************************************
****************************************
use "$Output/$sample/$matchgroup/Period05 $method $treat_type.dta", clear
gen tccbin = min(floor(tcc_adj2005 / 10), 7) if tcc_adj2005 < .
tab tccbin treat if post == 0

* One regression, all bins
xtreg ch_adj ibn.tccbin#c.treat_post ibn.tccbin#i(1).post mean_precip i(1).post#i.province_num, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store tcc_bins

coefplot tcc_bins, keep(*.tccbin#c.treat_post) ///
	msymbol(O) msize(medium) mcolor(navy) ///
	ciopts(lcolor(navy) lwidth(medthin)) ///
	coeflabels(0.tccbin#c.treat_post = "0-10" 1.tccbin#c.treat_post = "10-20" 2.tccbin#c.treat_post = "20-30" ///
	           3.tccbin#c.treat_post = "30-40" 4.tccbin#c.treat_post = "40-50" 5.tccbin#c.treat_post = "50-60" ///
	           6.tccbin#c.treat_post = "60-70" 7.tccbin#c.treat_post = "70-80") ///
	yline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
	ylabel(, labsize(small) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) xlabel(, labsize(small)) ///
	ytitle("CFM Effect on TCC (pp)") xtitle("Baseline TCC, 2005 (%)") ///
	legend(off) graphregion(color(white)) plotregion(color(white)) scheme(s2mono) ///
	vertical
graph export "$DFigures/SI Figure 7.pdf", replace as(pdf)

display as result "05d_ROBUST (Placebo and TCC Bins) done."
