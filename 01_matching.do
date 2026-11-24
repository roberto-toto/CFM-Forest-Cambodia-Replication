clear

   ***************************************
   ***************************************

	   * Universal Matching Do-File *

   ***************************************
   ***************************************

include "$code/programs.do"


****************************************
****************************************
* Matching (PRAKA)
****************************************
****************************************
if $PrakaSample == 1 {


***********
* Program *
***********
capture program drop Praka_Match
program Praka_Match

* Pre-process
preprocess
display "$treat_type"

* Praka Year
keep if Year_Praka==`1' | treat==0

* FILTER: Drop Within-Cohort Groups with Insufficient Data
bysort $group_var: egen group_treat_count_praka = total(treat)
drop if group_treat_count_praka==0
drop if group_treat_count_praka<70

* The "Change" Variables
gen ch_adj`1'_`2' = tcc_adj`1' - tcc_adj`2'
	label var ch_adj`1'_`2' "Ch. TCC `2'-`1'"
gen ch_adj`3'_`1' = tcc_adj`3' - tcc_adj`1'
	label var ch_adj`3'_`1' "Ch. TCC `1'-`3'"
gen chPlantat`1'_`2' = Plantat`1' - Plantat`2'
	label var chPlantat`1'_`2' "Ch. Plantat. `2'-`1'"


* Praka Matching Covars
global praka_matchvars 		ch_adj`1'_`2' tcc_adj`1' chPlantat`1'_`2' Plantat`1' Farm`1' Forest`1' elevation slope d_road d_edge pop_2000
global praka_matchvars_old 	ch_adj`1'_`2' tcc_adj`1' Farm`1' Farm`4' Farm`5' Farm`6' Farm`7' ///
							Plantat`1' Plantat`4' Plantat`5' Plantat`6' Plantat`7' elevation slope d_road d_edge pop_2000

* Local for group looping list
levelsof $group_var , local(group_list)

if $cem == 0 {
* Matching Loop
foreach j in `group_list' {

	preserve

	display "Running Matching for Group: `grp'"

	* Set seed
	set seed 339487731

	* Run matching
	if $psm_replacement == 1 {
		display "Running PSM with Replacement"
		psmatch2 treat ($praka_matchvars ) if  $group_var == `j', out(ch_adj`3'_`1') $psm_replacement_options
	}
	if $psm_noreplacement == 1 {
		display "Running PSM without Replacement"
		psmatch2 treat ($praka_matchvars  ) if  $group_var == `j', out(ch_adj`3'_`1') $psm_noreplacement_options
	}
	if $psm_caliper == 1 {
        display "Running PSM with Caliper"
        psmatch2 treat ($praka_matchvars) if  $group_var == `j', out(ch_adj`3'_`1') $psm_caliper_options
    }

	* Drop unmatched controls using pair variables
    gen pair = $pair_id_var if $pair_treated_var == 0
    replace pair = $pair_control_var if $pair_treated_var == 1
    bysort pair: egen paircount = count(pair)
    drop if paircount < 2

	covarlabels

	*Save file of matches for this group
	gen MATCHGROUP = `j'
	save "$Matching/$sample/$matchgroup/intermediate/Praka_`1'_`j'_match $treat_type.dta", replace

    restore

	display "***** Restart Loop"
	}

	****************************************
	* Combine MatchExact Datasets (for Praka Year)
	****************************************
	* Extract the first group explicitly
		levelsof $group_var , local(group_list)
		local first_group : word 1 of `group_list'

	* Use the first file separately
		use "$Matching/$sample/$matchgroup/intermediate/Praka_`1'_`first_group'_match $treat_type.dta", clear

	* Loop through the remaining groups and append them
		foreach v of local group_list {
			if "`v'" != "`first_group'" {
				append using "$Matching/$sample/$matchgroup/intermediate/Praka_`1'_`v'_match $treat_type.dta"
			}
		}

	* Create unique pair IDs, and sort matched pairs
	egen pair_unique = group(pair $group_var )
	sort pair_unique treat
	capture drop duplicate
	duplicates tag pair_unique, gen(duplicate)
		if $psm_replacement == 0 & $psm_caliper == 0 {
			assert duplicate == 1
		}
		drop duplicate

	* Placeholders for cem vars
	foreach v in cem_strata cem_matched cem_weights {
		gen `v' = .
		}

	* Finalize and Save
	gen Cohort = `1'
	order Grid_ID treat treat_Pct treat_Ha PA Cohort
	save "$Matching/$sample/$matchgroup/Praka `1' Matched $method $treat_type.dta", replace

	}


******************************
*CEM: Coarsened Exact Matching
******************************
if $cem == 1 {
	display "Running CEM"
	cem ///
		ch_adj`1'_`2'  (-5 0)                ///
		tcc_adj`1'     (20 40 60)            ///
		Farm`1'        (1 4)                 ///
		Forest`1'      (3 7)                 ///
		Plantat`1'     (1)                   ///
		elevation      (50 150 300 500)      ///
		slope          (2 5 10 20)           ///
		d_road         (500 2000 5000 10000) ///
		d_edge         (1 3 10)              ///
		pop_2000       (1 3 8)               ///
		$group_var     (#0),                 ///
		treatment(treat) showbreaks 	     ///
		k2k
	* Finalize and Save
	drop if cem_matched == 0
	gen pair_unique = .
	gen Cohort = `1'
	order Grid_ID treat treat_Pct treat_Ha PA Cohort
	save "$Matching/$sample/$matchgroup/Praka `1' Matched $method $treat_type.dta", replace
	}


end

* Run Matching for each Praka Cohort
Praka_Match 2007 2002 2013   2003 2004 2005 2006
Praka_Match 2008 2003 2014   2004 2005 2006 2007
Praka_Match 2010 2005 2016   2006 2007 2008 2009
Praka_Match 2011 2006 2017   2007 2008 2009 2010
Praka_Match 2013 2008 2019   2009 2010 2011 2012
Praka_Match 2014 2009 2020   2010 2011 2012 2013
Praka_Match 2015 2010 2021   2011 2012 2013 2014
Praka_Match 2017 2012 2023   2013 2014 2015 2016
Praka_Match 2018 2013 2023   2014 2015 2016 2017

****************************************
* APPEND PRAKA COHORTS + Add Unique ID
****************************************
use "$Matching/$sample/$matchgroup/Praka 2007 Matched $method $treat_type.dta", clear

	* Append
	foreach v in 2008  2010 2011  2013 2014 2015 2017 2018 {
		append using "$Matching/$sample/$matchgroup/Praka `v' Matched $method $treat_type.dta"
	}

	* Unique ID
	egen Unique_ID = group(Grid_ID Cohort)
	order Unique_ID, before(Grid_ID)

save "$Matching/$sample/$matchgroup/Matched $method $treat_type.dta", replace


****************************************
* POST-MATCHING PANELS (PRAKA)
****************************************

* ANNUAL Panel
use "$Matching/$sample/$matchgroup/Matched $method $treat_type.dta", clear

	*Reshape
	reshape long ch tcc ch_adj tcc_adj precip Forest Farm NonForNat NonVeg Plantat Water Other, i(Grid_ID Cohort) j(year)

	*'Recenter' Variable
	gen recenter = year - Cohort
	order recenter, after(year)

	keep Unique_ID Grid_ID Cohort year recenter ///
        treat treat_Pct treat_Ha treatCFany treatCFnoPA* treatCFinPA* treatCPA CFinPA* CFnoPA* CF CPA CBF_Type PA ///
        PA_CF_ID PA_CF_ID_num PA_CF_year PA_CF_ha PA_CF_type PA_CF_name PA_CF_HaOverlap CF_Ha_inPA CF_Ha_outPA ///
        PA_Cell_ID PA_Cell_ID_num PA_Cell_year PA_Cell_ha PA_Cell_type PA_Cell_name ///
        CF_Grid_Dist PA_Grid_Dist PA_Cell_PctOverlap PA_CF_PctOverlap ELC* ///
        ch tcc ch_adj tcc_adj precip Forest Farm Plantat NonVeg NonForNat Water Other ///
        elevation slope aspect d_road d_edge dist_yr dist_mag pop_2000 ///
        district* province* Ecoregion* buff* ///
        CF_Unique CF_Hectares Year_Praka Establish Legal_Stat ///
        pair_unique cem_strata cem_matched cem_weights

	order Unique_ID Grid_ID Cohort year recenter ///
        treat treat_Pct treat_Ha treatCFany treatCFnoPA* treatCFinPA* treatCPA CFinPA* CFnoPA* CF CPA CBF_Type PA ///
        PA_CF_ID PA_CF_ID_num PA_CF_year PA_CF_ha PA_CF_type PA_CF_name PA_CF_HaOverlap CF_Ha_inPA CF_Ha_outPA ///
        PA_Cell_ID PA_Cell_ID_num PA_Cell_year PA_Cell_ha PA_Cell_type PA_Cell_name ///
        CF_Grid_Dist PA_Grid_Dist PA_Cell_PctOverlap PA_CF_PctOverlap ELC* ///
        ch tcc ch_adj tcc_adj precip Forest Farm Plantat NonVeg NonForNat Water Other ///
        elevation slope aspect d_road d_edge dist_yr dist_mag pop_2000 ///
        district* province* Ecoregion* buff* ///
        CF_Unique CF_Hectares Year_Praka Establish Legal_Stat ///
        pair_unique cem_strata cem_matched cem_weights

	save "$Output/$sample/$matchgroup/Annual $method $treat_type.dta", replace


* PERIOD Panel (Recentered)
use "$Matching/$sample/$matchgroup/Matched $method $treat_type.dta", clear

	* Define the list of cohorts
	local cohorts 2007 2008 2010 2011 2013 2014 2015 2017 2018

	* 1. Loop to generate preXXtot and postXXtot, preXXprecip and postXXprecip
	foreach c of local cohorts {
		*Pre-period = 6
		local preminus = `c' - 6
		if 1 {
			*Post-periods
			if `c' == 2007 {
				local postplus 2014
			}
			else if `c' == 2008 {
				local postplus 2015
			}
			else if `c' == 2010 {
				local postplus 2017
			}
			else if `c' == 2011 {
				local postplus 2018
			}
			else if `c' == 2013 {
				local postplus 2020
			}
			else if `c' == 2014 {
				local postplus 2021
			}
			else if `c' == 2015 {
				local postplus 2022
			}
			else if `c' == 2017 {
				local postplus 2023
			}
			else if `c' == 2018 {
				local postplus 2023
			}

		gen pre`c'_adjtot = -(tcc_adj`preminus' - tcc_adj`c') if Cohort == `c'
		gen post`c'_adjtot = -(tcc_adj`c' - tcc_adj`postplus') if Cohort == `c'
		}
	}

	* 2. Change in TCC over Period
		gen ch_adjtot0 = .
		gen ch_adjtot1 = .

		foreach c of local cohorts {
			replace ch_adjtot0 = pre`c'_adjtot  if Cohort == `c'
			replace ch_adjtot1 = post`c'_adjtot if Cohort == `c'

		}

	* 3. Mean Precipitation and Land Cover over Period
	foreach c of local cohorts {

		foreach v in tcc_adj precip Forest Farm Plantat NonVeg NonForNat Water Other {

			* Pre-period
			local preminus = `c' - 6
			local plist0
			forvalues y = `preminus'/`=`c'' {
				local plist0 `plist0' `v'`y'
				}
			egen `v'`c'0 = rowmean(`plist0') if Cohort == `c'


			* Post-period
			local plist1
			forvalues y = `=`c'+1'/`postplus' {
				local plist1 `plist1' `v'`y'
			}
			egen `v'`c'1 = rowmean(`plist1') if Cohort == `c'
		}
	}

	foreach v in tcc_adj precip Forest Farm Plantat NonVeg NonForNat Water Other {

		gen mean`v'0 = .
		gen mean`v'1 = .

		foreach c of local cohorts {

			*Create pre/post general vars for reshape
			replace mean`v'0 = `v'`c'0 if Cohort == `c'
			replace mean`v'1 = `v'`c'1 if Cohort == `c'
			}
		}

	* 4. Baseline Land Cover
	foreach v in tcc_adj Forest Farm Plantat NonVeg NonForNat Water Other {

		gen B`v' = .

		foreach c of local cohorts {

			replace B`v' = `v'`c' if Cohort == `c'
			}
		}

	*Reshape
	drop pre2* post2* ch20* ch19* ch_adj20* tcc20* tcc19* tcc_adj20* tcc_adj19* precip20* precip19* ///
	Forest20* Farm20* Plantat20* NonVeg20* NonForNat20* Water20* Other20*

	reshape long ch_adjtot meantcc_adj meanprecip meanForest meanFarm meanPlantat meanNonVeg meanNonForNat meanWater meanOther, i(Unique_ID) j(post)
		assert post==1 | post==0

	*Rename the "Mean" Variables
	foreach v in tcc_adj precip Forest Farm Plantat NonVeg NonForNat Water Other {
		rename mean`v' `v'
	}

	*Interactions and Labels
	gen treat_post = treat*post
		label var treat_post "CF x Post"
	gen treat_pct_post = treat_Pct*post
		label var treat_pct_post "Pct. CF x Post"
	gen treat_ha_post = treat_Ha*post
		label var treat_ha_post "Ha CF x Post"
	foreach v in slope elevation aspect d_road d_edge Btcc_adj BForest BFarm BPlantat BNonVeg BNonForNat BWater BOther {
		gen `v'_post = `v'*post
		}
		label var slope_post "Slope x Post"
		label var elevation_post "Elev. x Post"
		label var aspect_post "Aspect x Post"
		label var d_road_post "D. Road x Post"
		label var d_edge_post "D. Forest x Post"
	foreach v in tcc_adj Forest Farm Plantat NonVeg NonForNat Water Other {
		label var B`v'_post "`v' x Post"
	}
	capture gen PA_post = PA * post
		capture label var PA_post "PA x Post"
		capture order PA_post, after(PA)
	label var post "Post-Praka"

	keep    Unique_ID Cohort Grid_ID treat post ///
        treat_Pct treat_Ha treatCFany treatCFnoPA* treatCFinPA* treatCPA CFinPA* CFnoPA* CF CPA CBF_Type PA ///
        PA_CF_ID PA_CF_ID_num PA_CF_year PA_CF_ha PA_CF_type PA_CF_name PA_CF_HaOverlap CF_Ha_inPA CF_Ha_outPA ///
        PA_Cell_ID PA_Cell_ID_num PA_Cell_year PA_Cell_ha PA_Cell_type PA_Cell_name ///
        CF_Grid_Dist PA_Grid_Dist PA_Cell_PctOverlap PA_CF_PctOverlap ELC* ///
        ch_adjtot tcc_adj precip Forest Farm Plantat NonVeg NonForNat Water Other B* ///
        elevation slope aspect d_road d_edge dist_yr dist_mag pop_2000 *_post ///
        district* province* Ecoregion* buff* ///
        CF_Unique CF_Hectares Year_Praka Establish Legal_Stat ///
        pair_unique cem_strata cem_matched cem_weights

	order   Unique_ID Cohort Grid_ID treat post ///
        treat_Pct treat_Ha treatCFany treatCFnoPA* treatCFinPA* treatCPA CFinPA* CFnoPA* CF CPA CBF_Type PA ///
        PA_CF_ID PA_CF_ID_num PA_CF_year PA_CF_ha PA_CF_type PA_CF_name PA_CF_HaOverlap CF_Ha_inPA CF_Ha_outPA ///
        PA_Cell_ID PA_Cell_ID_num PA_Cell_year PA_Cell_ha PA_Cell_type PA_Cell_name ///
        CF_Grid_Dist PA_Grid_Dist PA_Cell_PctOverlap PA_CF_PctOverlap ELC* ///
        ch_adjtot tcc_adj precip Forest Farm Plantat NonVeg NonForNat Water Other B* ///
        elevation slope aspect d_road d_edge dist_yr dist_mag pop_2000 *_post ///
        district* province* Ecoregion* buff* ///
        CF_Unique CF_Hectares Year_Praka Establish Legal_Stat ///
        pair_unique cem_strata cem_matched cem_weights

	* Save
	save "$Output/$sample/$matchgroup/Period $method $treat_type.dta", replace


}

*------------------------------------------------------------------------------*
*------------------------------------------------------------------------------*
*------------------------------------------------------------------------------*
*------------------------------------------------------------------------------*


****************************************
****************************************
* Matching (COUNTRY) BASE 2005
****************************************
****************************************
if $CountrySample == 1 {

****************************
* Country Matching Variables
****************************
global match_vars "ch_adj2005_1990 tcc_adj2005 Farm2005 Forest2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000"
global outcome_var "ch_adj2023_2005"

* Pre-process
preprocess

* Local for group looping list
levelsof $group_var , local(group_list)

if $cem == 0 {
* Matching Loop
foreach j in `group_list' {
    preserve
    display "Running Matching for Group: `j'"

    * Set seed
    set seed 339487731

    * Run matching
    if $psm_replacement == 1 {
        display "Running PSM with Replacement"
        psmatch2 treat ($match_vars) if  $group_var == `j', out($outcome_var) $psm_replacement_options
    }
    if $psm_noreplacement == 1 {
        display "Running PSM without Replacement"
        psmatch2 treat ($match_vars) if  $group_var == `j', out($outcome_var) $psm_noreplacement_options
    }
    if $psm_caliper == 1 {
        display "Running PSM with Caliper"
        psmatch2 treat ($match_vars) if  $group_var == `j', out($outcome_var) $psm_caliper_options
    }

    * Drop treated and control cells that lack support
    gen pair = $pair_id_var if $pair_treated_var == 0
    replace pair = $pair_control_var if $pair_treated_var == 1
    bysort pair: egen paircount = count(pair)
	display "DROPPING UNMATCHED CONTROLS"
    drop if paircount < 2


	*Save file of matches for this group
	gen MATCHGROUP = `j'
	save "$Matching/$sample/$matchgroup/intermediate/`j'_match05 $method $treat_type.dta", replace

    restore
	}

****************************************
* Combine MatchExact Datasets (COUNTRY)
****************************************
	* Extract the first group explicitly
	levelsof $group_var , local(group_list)
	local first_group : word 1 of `group_list'

	* Use the first file separately
	use "$Matching/$sample/$matchgroup/intermediate/`first_group'_match05 $method $treat_type.dta", clear

	*Loop through the remaining groups and append them
	foreach v of local group_list {
		if "`v'" != "`first_group'" {
			append using "$Matching/$sample/$matchgroup/intermediate/`v'_match05 $method $treat_type.dta"
		}
	}

	* Create unique pair IDs, and sort matched pairs
	egen pair_unique = group(pair $group_var )
	sort pair_unique treat
	capture drop duplicate
	duplicates tag pair_unique, gen(duplicate)
		if $psm_replacement == 0 & $psm_caliper == 0 {
			assert duplicate == 1
		}
		drop duplicate

	* Placeholders for cem vars
	foreach v in cem_strata cem_matched cem_weights {
		gen `v' = .
	}
	save "$Matching/$sample/$matchgroup/Matched05 $method $treat_type.dta", replace
}

******************************
*CEM: Coarsened Exact Matching
******************************
if $cem == 1 {
	display "Running CEM"

	cem ///
		ch_adj2005_1990  (-15 0)           ///
		tcc_adj2005  (20 40 60)            ///
		Farm2005     (1 4)                 ///
		Forest2005   (3 7)                 ///
		Plantat2005  (1)                   ///
		elevation    (50 150 300 500)      ///
		slope        (2 5 10 20)           ///
		d_road       (500 2000 5000 10000) ///
		d_edge       (1 3 10)              ///
		pop_2000     (1 3 8)               ///
		$group_var   (#0),                 ///
		treatment(treat) showbreaks ///
		k2k

    drop if cem_matched == 0
    gen pair_unique = .
    save "$Matching/$sample/$matchgroup/Matched05 $method $treat_type.dta", replace
	}

****************************************
* MATCHING PERFORMANCE ANALYSIS (COUNTRY)
****************************************
if "$matchgroup" == "Province" & "$method" == "PSM-NoReplace" {
	use "$Matching/$sample/$matchgroup/Matched05 $method $treat_type.dta", clear

	* Common Support Plot
	twoway (histogram _pscore if treat == 1, color(red%30)) ///
	       (histogram _pscore if treat == 0, color(green%30)), ///
	       legend(order(1 "Treated" 2 "Control")) ///
	       title("") xti("Propensity Score")
	graph export "$DFigures/SI Figure 4.png", replace as(png)

	* Post-Match Balance Plot
	balanceplot $outcome_var $match_vars , group(treat) graphop(title("") subtitle("") xti("% Normalized Difference")) nosort table
	graph export "$DFigures/SI Figure 3b.png", replace as(png)
}


****************************************
* POST-MATCHING PANELS (COUNTRY)
****************************************
assert $CountrySample == 1

* ANNUAL Panel
use "$Matching/$sample/$matchgroup/Matched05 $method $treat_type.dta", clear
	reshape long ch tcc ch_adj tcc_adj precip Forest Farm NonForNat NonVeg Plantat Water Other, i(Grid_ID) j(year)
	save "$Output/$sample/$matchgroup/Annual05 $method $treat_type.dta", replace


* PERIOD Panel (05)
use "$Matching/$sample/$matchgroup/Matched05 $method $treat_type.dta", clear
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

	* Save period panel dataset
	save "$Output/$sample/$matchgroup/Period05 $method $treat_type.dta", replace


}
