/*
Author: RVT
Purpose: Define programs and filename macros for repeated use
*/


****************************************
* Automated Globals and Matching Variables
****************************************
if $CountrySample == 1 {
    global sample "Country"
}
if $PrakaSample == 1 {
    global sample "Praka"
}
if $EstabSample == 1 {
    global sample "Establishment"
}
if $ProvinceExact == 1 {
    global group_var "province_num"
    global matchgroup "Province"
}
if $EcoregionExact == 1 {
    global group_var "Ecoregion_code"
    global matchgroup "Ecoregion"
}
* Naming convention for matched pairs based on method
if $psm_replacement == 1 {
	global method "PSM-Replace"
}
if $psm_noreplacement == 1 {
	global method "PSM-NoReplace"
}
if $psm_caliper == 1 {
	global method "PSM-Caliper"
}
if $psm_replacement == 1 | $psm_noreplacement == 1 | $psm_caliper == 1 {
    global pair_treated_var "_treated"
    global pair_id_var "_id"
    global pair_control_var "_n1"
}
if $cem == 1 {
    global pair_treated_var "cem_treated"
    global pair_id_var "cem_id"
    global pair_control_var "cem_control"
	global method "CEM"
}

****************************************
* Pre-Processing Program (matching do-files)
****************************************
capture program drop preprocess
program preprocess

* LOAD DATASET
use "$input/Cleaned.dta", clear

	* Drop CFs with "Unsure" Legal Status
	drop if Legal_Stat=="Unsure"
	drop if Legal_Stat=="Converted to CPA"

	* Drop CPAs
	drop if CPA==1

	* Check Valid CF Count
	codebook CF_Unique

	* Sample Summary Before Matching
		display "Cells Before CFU Filter"
		tab $group_var treatCFany
		display "CFUs Before CFU Filter: Full Sample"
		codebook CF_Unique
		display "CFUs Before CFU Filter: Formalization Sample"
		codebook CF_Unique if Year_Praka!=.

	**************************************************
	* Matching Selection Criteria (Manual Adjustments)
	**************************************************

	* Filter Sample to Treatment
	display "ISOLATE TREATMENT GROUP"

	drop if buff3000m==1 & treat==0
	drop if CFinPAcell==1
	drop if PA==1
	assert treat==CFnoPAcell
	local treatgroup "CFnoPAcell"
	display "ISOLATED: `treatgroup'"

	* Sample Summary Before "Interior" Filter
		display "Units Before Interior Filter"
		tab $group_var treat
		display "CFUs Before Interior Filter: Full Sample"
		codebook CF_Unique
		display "CFUs Before Interior Filter: Formalization Sample"
		codebook CF_Unique if Year_Praka!=.
		tab Year_Praka treat

	if $Interior == 1 {
		keep if treat == 0 | treat_Pct >= 50
		local cellgroup "Main"
	}
	if $Border == 1 {
		keep if treat == 0 | treat_Pct < 50
		local cellgroup "Border"
	}

	* FILTERS: Drop Groups with Insufficient Data

		*Count treated units in each group
		bysort $group_var: egen group_treat_count = total(treat)

		* Sample Summary Before Filters
		display "Units After Interior Filter"
		tab $group_var treat
		display "CFUs After Interior Filter: Full Sample"
		codebook CF_Unique
		display "CFUs After Interior Filter: Formalization Sample"
		codebook CF_Unique if Year_Praka!=.
		tab Year_Praka treat
		tab province_name treat

		*Drop groups with no/low CFs
		drop if group_treat_count == 0
		if $ProvinceExact == 1 {
			drop if province_name == "Takeo"
			drop if inlist(province_name,"Kampong Cham","Preah Sihanouk","Svay Rieng","Kep","Pailin")
			}

		* Sample Summary After Filters
		display "Units After Group-Dropping Filters"
		tab $group_var treat
		display "CFUs After Group-Dropping Filters: Full Sample"
		codebook CF_Unique
		display "CFUs After Group-Dropping Filters: Formalization Sample"
		codebook CF_Unique if Year_Praka!=.
		tab Year_Praka treat


		display "-----------------FILTERS COMPLETE-------------------"

	* DEFINE TREAT GROUP (LAST)
	global treat_type "`treatgroup'_`cellgroup'"

end


****************************************
* Pre-Processing Program (Period file)
****************************************
capture program drop preprocess2
program preprocess2

* LOAD DATASET
use "$input/Cleaned_Period.dta", clear

	* Drop CFs with "Unsure" Legal Status
	drop if Legal_Stat=="Unsure"
	drop if Legal_Stat=="Converted to CPA"

	* Drop CPAs
	drop if CPA==1

	* Check Valid CF Count
	codebook CF_Unique

	* Sample Summary Before Matching
		display "Cells Before CFU Filter"
		tab $group_var treatCFany
		display "CFUs Before CFU Filter: Full Sample"
		codebook CF_Unique
		display "CFUs Before CFU Filter: Formalization Sample"
		codebook CF_Unique if Year_Praka!=.

	**************************************************
	* Matching Selection Criteria (Manual Adjustments)
	**************************************************

	* Filter Sample to Treatment
	display "ISOLATE TREATMENT GROUP"

	drop if buff3000m==1 & treat==0
	drop if CFinPAcell==1
	drop if PA==1
	assert treat==CFnoPAcell
	local treatgroup "CFnoPAcell"
	display "ISOLATED: `treatgroup'"

	* Sample Summary Before "Interior" Filter
		display "Units Before Interior Filter"
		tab $group_var treat
		display "CFUs Before Interior Filter: Full Sample"
		codebook CF_Unique
		display "CFUs Before Interior Filter: Formalization Sample"
		codebook CF_Unique if Year_Praka!=.
		tab Year_Praka treat

	if $Interior == 1 {
		keep if treat == 0 | treat_Pct >= 50
		local cellgroup "Main"
	}
	if $Border == 1 {
		keep if treat == 0 | treat_Pct < 50
		local cellgroup "Border"
	}

	* FILTERS: Drop Groups with Insufficient Data

		*Count treated units in each group
		bysort $group_var: egen group_treat_count = total(treat)

		* Sample Summary Before Filters
		display "Units After Interior Filter"
		tab $group_var treat
		display "CFUs After Interior Filter: Full Sample"
		codebook CF_Unique
		display "CFUs After Interior Filter: Formalization Sample"
		codebook CF_Unique if Year_Praka!=.
		tab Year_Praka treat

		*Drop groups with no/low CFs
		drop if group_treat_count == 0
		if $ProvinceExact == 1 {
			drop if group_treat_count < 200
			drop if province_name == "Takeo"
			}

		* Sample Summary After Filters
		display "Units After Group-Dropping Filters"
		tab $group_var treat
		display "CFUs After Group-Dropping Filters: Full Sample"
		codebook CF_Unique
		display "CFUs After Group-Dropping Filters: Formalization Sample"
		codebook CF_Unique if Year_Praka!=.
		tab Year_Praka treat


		display "-----------------FILTERS COMPLETE-------------------"

	* DEFINE TREAT GROUP (LAST)
	global treat_type "`treatgroup'_`cellgroup'"

end


*************************
* Covar Labels
*************************
cap program drop covarlabels
program covarlabels

foreach x in Forest Farm {
	forvalues y = 2000/2023 {
		label var `x'`y' "`x' `y'"
	}
}

forvalues y = 2000/2023 {
		label var Plantat`y' "Plantation `y'"
	}

forvalues y = 2000/2023 {
	label var tcc_adj`y' "TCC `y'"
}

end

*************************
* CF Table Labels
*************************
cap program drop CFtable_labels
program CFtable_labels
cap gen ch_plantat2023_2005 = Plantat2023-Plantat2005
cap label var ch_adj2005_1990 "Ch. TCC (pp), 90--05"
cap label var ch_plantat2023_2005 "Ch. Plantat. (pp), 05--23"
cap label var ch_adj2023_2005 "Ch. TCC (pp)., 05--23"
cap label var tcc_adj2005 "TCC 2005 (\%)"
label var CF_Hectares "CF Area (Ha)"
cap label var Plantat2005 "Plantation 2005 (\%)"
cap label var Forest2005 "Forest 2005 (\%)"
cap label var Farm2005 "Farm 2005 (\%)"
label var elevation "Elevation (m)"
label var slope "Slope (deg)"
label var pop_2000 "Pop. Density 2000"
label var d_edge "Dist. Edge (m)"
label var d_road "Dist. Road (m)"
end

*************************
* Land Cover Percentages
*************************
cap program drop LCperc_main
program LCperc_main
foreach v in Forest Farm Plantat NonForNat NonVeg Water Other {
		cap replace `v'20`1' = `v'20`1' / 9 * 100
		cap label var `v'20`1' "`v' (\%), 20`1'"
	}
end
cap program drop LCperc_other
program LCperc_other
foreach v in Forest Farm Plantat NonForNat NonVeg Water Other {
		cap replace `v'2005 = `v'2005 / 9 * 100
		cap label var `v'2005 "`v' (\%), 2005"
	}
end

*************************
* Sumstat Labels
*************************
cap program drop labels_sumstats
program labels_sumstats
cap label var ch_adj      "TCC Change (pp), 1990--2005"
*main
cap label var Plantat_05_00   "Plantation Change (pp), 2000--2005"
cap label var tcc_adj2005 		"TCC (\%), 2005"
cap label var Plantat2005     "Plantation (\%), 2005"
cap label var Forest2005      "Forest (\%), 2005"
cap label var Farm2005        "Farm (\%), 2005"
*praka
cap label var ch_adjtot1   "TCC Change (pp), Post-Treat (All)"
cap label var ch_adjtot0   "TCC Change (pp), Pre-Treat (6yr)"
cap label var Btcc_adj    "TCC (\%), Baseline"
cap label var BPlantat		"Plantation (\%), Baseline"
cap label var BForest      "Forest (\%), Baseline"
cap label var BFarm        "Farm (\%), Baseline"
*any
label var elevation       "Elevation (m)"
label var slope           "Slope (deg)"
label var pop_2000        "Pop. Density, 2000"
label var d_edge          "Dist to Forest Edge (m)"
label var d_road          "Dist to Road (m)"
end

*************************
* Graph Labels
*************************
cap program drop labels_graph
program labels_graph
cap label var ch_adj      "TCC Change (pp), 1990--2005"
*main
cap label var Plantat_05_00   "Plantation Change (pp), 2000--2005"
cap label var tcc_adj2005 	  "TCC (%), 2005"
cap label var Plantat2005     "Plantation (%), 2005"
cap label var Forest2005      "Forest (%), 2005"
cap label var Farm2005        "Farm (%), 2005"
*praka
cap label var ch_adjtot1   "TCC Change (pp), Post-Treat (All)"
cap label var ch_adjtot0   "TCC Change (pp), Pre-Treat (6yr)"
cap label var Btcc_adj    "TCC (%), Baseline"
cap label var BPlantat		"Plantation (%), Baseline"
cap label var BForest      "Forest (%), Baseline"
cap label var BFarm        "Farm (%), Baseline"
*any
label var elevation       "Elevation (m)"
label var slope           "Slope (deg)"
label var pop_2000        "Pop. Density, 2000"
label var d_edge          "Dist to Forest Edge (m)"
label var d_road          "Dist to Road (m)"
end

*************************
* Sumstat Tables
*************************
**TOP VARIABLE (Time Variant)
capture program drop means
program means
estpost sum `1' if treat == 0 & post  == 0
estimates store col1_`1'
estpost sum `1' if treat == 1 & post  == 0
estimates store col2_`1'
estpost sum `1' if treat == 0 & post  == 1
estimates store col3_`1'
estpost sum `1' if treat == 1 & post  == 1
estimates store col4_`1'


foreach num in 0 1 {

ttest `1' if post == `num', by(treat)
preserve
replace `1' = (r(mu_2) - r(mu_1)) / sqrt( ( r(sd_2)^2 + r(sd_1)^2 )  / 2 )
estpost sum `1'
restore
estimates store norm_diff_`1'_`num'
ttest `1' if post == `num', by(treat)
preserve
replace `1' = (r(sd_2)^2)/(r(sd_1)^2)
estpost sum `1'
restore
estimates store varrat_`1'_`num'
}

end

**MIDDLE VARIABLES

*Time-invariant (Middle Variables)
capture program drop means_timeinvariant
program means_timeinvariant
estpost sum `1' if treat == 0 & post  == 0
estimates store col1_`1'
estpost sum `1' if treat == 1 & post  == 0
estimates store col2_`1'
estpost sum `1' if treat == 0 & post  == 1
estimates store col3_`1'
estpost sum `1' if treat == 1 & post  == 1
estimates store col4_`1'


foreach num in 0 1 {

ttest `1' if post == `num', by(treat)
preserve
replace `1' = (r(mu_2) - r(mu_1)) / sqrt( ( r(sd_2)^2 + r(sd_1)^2 )  / 2 )
estpost sum `1'
restore
estimates store norm_diff_`1'_`num'
ttest `1' if post == `num', by(treat)
preserve
replace `1' = (r(sd_2)^2)/(r(sd_1)^2)
estpost sum `1'
restore
estimates store varrat_`1'_`num'
}

label var `1' "`2'"
esttab col2_`1' col1_`1' norm_diff_`1'_0  varrat_`1'_0 using "${tables}/$sample/$matchgroup/Balance_`3' $matchgroup $method $treat_type.tex", append fragment cells("mean(fmt(%9.2fc))") label style (tex) collabels(none) nomtitle noline nonumbers noobs

end


*******************************************************
* Praka-Level Balance Table with Normalized Differences
*******************************************************

*************************
* Stacked Area Graphs
*************************
capture program drop StackedArea
program StackedArea

collapse (sum) Forest* Non* Farm* Plantat* Water* Other*, by(year)
gen group = "`1'"
drop if year<2000
gen total = Forest + Plantat + Farm + NonForNat + NonVeg + Water + Other

* Recalculate the cumulative variables in reverse order
gen cum_Forest = (Forest / total) * 100
gen cum_Plantat = cum_Forest + (Plantat / total) * 100
gen cum_Farm = cum_Plantat + (Farm / total) * 100
gen cum_NonForNat = cum_Farm + (NonForNat / total) * 100
gen cum_NonVeg = cum_NonForNat + (NonVeg / total) * 100
gen cum_Water = cum_NonVeg + (Water / total) * 100
gen cum_Other = cum_Water + (Other / total) * 100

* Generate a variable that equals zero for all observations
gen zero = 0

* Create the stacked area graph using the cumulative variables
twoway (rarea cum_Forest zero year, color(green%50) lcolor(green%1)) ///
       (rarea cum_Plantat cum_Forest year, color(orange%50) lcolor(orange%1)) ///
       (rarea cum_Farm cum_Plantat year, color(brown%50) lcolor(brown%1)) ///
       (rarea cum_NonForNat cum_Farm year, color(teal%50) lcolor(teal%1)) ///
       (rarea cum_NonVeg cum_NonForNat year, color(red)) ///
       (rarea cum_Water cum_NonVeg year, color(blue%50) lcolor(blue%1)) ///
       (rarea cum_Other cum_Water year, color(black%50) lcolor(black%1)), ///
       title("{bf:`1'}", size(*0.9)) ///
       xtitle("Year") ytitle("% of Total Area", size(*1.15)) ///
       xscale(range(2000 2023) noextend) xlabel(2000(5)2020) ///
	   xline(2005) ///
       yscale(range(0 100)) ylabel(0(20)100,labsize(*1.15)) ///
       legend(order(1 "Forest" 2 "Plantat" 3 "Farm" 4 "NonForNat" 5 "NonVeg" 6 "Water" 7 "Other") row(1) pos(6)) ///
       graphregion(color(white)) plotregion(fcolor(white))

graph save "$figures/Land Use/Intermediate/`1'.gph", replace

end


*************************
* Avoided-Loss Share (Table 1 and heatmap)
*************************
capture program drop avoided_share
program define avoided_share
	args spec

	local b1 = _b[treat_post]
	local se = _se[treat_post]
	local df = e(df_r)

	* (a) Predicted outcome with treatment switched off
	tempvar yhat
	if "`e(cmd)'" == "xtreg" {
		quietly predict double `yhat' if e(sample), xbu
	}
	else {
		quietly predict double `yhat' if e(sample), xb
	}
	quietly replace `yhat' = `yhat' - _b[treat_post] * treat_post

	* (b) Counterfactual loss of CF cells
	quietly summarize `yhat' if treat == 1 & post == 1 & e(sample)
	local cf = -r(mean)

	* (c) Observed loss of CF cells
	quietly summarize ch_adj if treat == 1 & post == 1 & e(sample)
	local obs = -r(mean)

	* (d) Share avoided and 95% CI
	local blo      = `b1' - invttail(`df', 0.025) * `se'
	local bhi      = `b1' + invttail(`df', 0.025) * `se'
	local share    = 100 * `b1' / (`obs' + `b1')
	local share_lo = cond(`obs' + `blo' > 0, 100 * `blo' / (`obs' + `blo'), .)
	local share_hi = 100 * `bhi' / (`obs' + `bhi')
	quietly nlcom (share: 100 * _b[treat_post] / (`obs' + _b[treat_post]))
	matrix _V = r(V)
	local share_se = sqrt(_V[1,1])
	local ci = "[" + strtrim(string(`share_lo', "%5.1f")) + ", " + strtrim(string(`share_hi', "%5.1f")) + "]"

	* (e) SE of the counterfactual loss
	local cfse = "(" + strtrim(string(`se', "%9.2f")) + ")"

	* (f) Avoided canopy loss (area)
	quietly summarize treat_Pct if treat == 1 & post == 1 & e(sample)
	local cfu_area = r(sum) / 100 * 9 * $area_mult
	local av_area    = `b1' / 100 * `cfu_area'
	local av_area_lo = (`b1' - invttail(`df', 0.025) * `se') / 100 * `cfu_area'
	local av_area_hi = (`b1' + invttail(`df', 0.025) * `se') / 100 * `cfu_area'
	local aci = "[" + strtrim(string(`av_area_lo', "$area_fmt")) + ", " + strtrim(string(`av_area_hi', "$area_fmt")) + "]"

	* (g) Stars
	local p     = 2 * ttail(`df', abs(`b1' / `se'))
	local stars = cond(`p' < .01, "***", cond(`p' < .05, "**", cond(`p' < .10, "*", "")))
	local share_str = strtrim(string(`share', "%5.1f")) + "`stars'"
	local area_str  = strtrim(string(`av_area', "$area_fmt")) + "`stars'"

	* Add to e() for esttab
	estadd scalar att        = `b1'
	estadd scalar att_se     = `se'
	estadd scalar cf_obs     = `obs'
	estadd scalar cf_loss    = `cf'
	estadd local  cf_se_str  "`cfse'"
	estadd scalar share      = `share'
	estadd scalar share_se   = `share_se'
	estadd scalar share_lo   = `share_lo'
	estadd scalar share_hi   = `share_hi'
	estadd local  share_ci   "`ci'"
	estadd scalar cfu_area   = `cfu_area'
	estadd scalar av_area    = `av_area'
	estadd scalar av_area_lo = `av_area_lo'
	estadd scalar av_area_hi = `av_area_hi'
	estadd local  av_area_ci "`aci'"
	estadd local  share_str  "`share_str'"
	estadd local  area_str   "`area_str'"
	estadd local  spec       "`spec'"

	di as text _n "  `spec'"
	di as text "    beta1 (avoided loss)        = " %6.2f `b1' "  (se " %4.2f `se' ")"
	di as text "    CF cells' observed loss     = " %6.2f `obs'
	di as text "    counterfactual loss (pred.) = " %6.2f `cf' "   check: observed + beta1 = " %6.2f `obs' + `b1'
	di as text "    avoided share               = " %5.1f `share' "%   95% CI `ci'"
	di as text "    avoided canopy loss         = `area_str' $area_unit   95% CI `aci'"
end
