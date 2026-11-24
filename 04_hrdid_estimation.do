clear
clear matrix
clear mata

   ***************************************
   ***************************************

	   * Staggered Difference-in-Differences (Formalization Sample) *

   ***************************************
   ***************************************

include "$code/programs.do"
display "$treat_type"


** PREPARE DATA FOR STAGGERED ESTIMATORS **
use "$Output/$sample/$matchgroup/Annual $method $treat_type.dta", clear

	*Periods
	keep if year>=2001 & year <= 2023

	*Outcome
	global outcome tcc_adj

	*Selection Covariates
	global covars elevation slope d_road d_edge Btcc_adj BForest BFarm BPlantat

	*Baseline Variables
	foreach v in tcc_adj Forest Farm Plantat {
		gen b`v' = `v' if year==Cohort
		bysort Unique_ID: egen B`v' = max(b`v')
			drop b`v'
			assert B`v' != .
		}

	* Median Baseline TCC

		* Version 1: Global median
		egen med_btcc_global = median(Btcc_adj)
		gen aboveMED_global   = (Btcc_adj >= med_btcc_global)
		gen belowMED_global   = (Btcc_adj <  med_btcc_global)

		* Version 2: Cohort-specific medians
		bysort Cohort: egen med_btcc_cohort = median(Btcc_adj)
		gen aboveMED_cohort   = (Btcc_adj >= med_btcc_cohort)
		gen belowMED_cohort   = (Btcc_adj <  med_btcc_cohort)


		* Report medians
		display "Global median Btcc_adj:  " %5.1f med_btcc_global[1]
		display ""
		display "Cohort-specific medians:"
		levelsof Cohort, local(cohort_list)
		foreach c of local cohort_list {
			quietly summarize med_btcc_cohort if Cohort == `c', meanonly
			display "  Cohort `c':  " %5.1f r(mean)
		}

		* Set Median Choice (global or cohort)
		global med_type cohort

	* Quartiles

		xtile Q4Btcc_adj = Btcc_adj, nq(4)

	*post
	gen post = year>=Cohort

	*gvar
	replace Cohort = 0 if treat==0

	*Confidence intervals
	global ci 95

	*Drop duplicate controls

************************
*** DEFINE TREATMENT ***
gen TREAT = treat==1 & recenter>=0
************************

********************
*** DEFINE PANEL ***
xtset Unique_ID year
********************

********************************************************************************
********************************************************************************
								* ESTIMATION *
********************************************************************************
********************************************************************************

************************
**       XTHDID       **
************************


	****************************************************
	* Not-Yet-Treated Controls
	****************************************************

	xthdidregress aipw ($outcome $covars precip) (TREAT $covars), ///
			group(Cohort) controlg(notyet) vce(cluster district_encode)

	estat aggregation, dynamic(-5 -4 -3 -2 -1 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15) ///
		graph(title("") ytitle("CFM Effect on TCC (pp)") xtitle("Years Since Formalization") legend(off) ciopts(recast(rcap) color(black)) ///
		yscale(range(-5 15)) ylabel(-5(5)15))
	graph export "$DFigures/Figure 1d.png", replace as(png)

	estat aggregation, overall

	* Cohort-by-year effects
	capture noisily estat atetplot, xtitle("Year") ytitle("CFM Effect on TCC (pp)") xlabel(2000(5)2020) xscale(range(2001 2023))
	if _rc == 0 graph export "$DFigures/SI Figure 8a.png", replace as(png)


			****************************************************
			* Not-Yet-Treated Controls: High Baseline TCC
			****************************************************
			preserve

			keep if aboveMED_$med_type == 1

			xthdidregress aipw ($outcome $covars precip) (TREAT $covars), ///
				group(Cohort) controlg(notyet) vce(cluster district_encode)

			estat aggregation, dynamic(-5 -4 -3 -2 -1 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15) ///
				graph(title("") ytitle("CFM Effect on TCC (pp)") xtitle("Years Since Formalization") legend(off) ciopts(recast(rcap) color(black)) ///
				yscale(range(-5 20)) ylabel(-5(5)20))
			graph export "$DFigures/SI Figure 2a.png", replace as(png)

			estat aggregation, cohort ///
				graph(title("") ytitle("CFM Effect on TCC (pp)") xtitle("Cohort") legend(off) ciopts(recast(rcap) color(black)) ///
				yscale(range(-2 20)) ylabel(-2(4)20))
			graph export "$DFigures/SI Figure 2b.png", replace as(png)

			estat aggregation, overall

			* Cohort-by-year effects
			capture noisily estat atetplot, xtitle("Year") ytitle("CFM Effect on TCC (pp)") xlabel(2000(5)2020) xscale(range(2001 2023))
			if _rc == 0 graph export "$DFigures/SI Figure 8b.png", replace as(png)
			restore

			****************************************************
			* Not-Yet-Treated Controls: Low Baseline TCC
			****************************************************
			preserve

			keep if belowMED_$med_type == 1

			xthdidregress aipw ($outcome $covars precip) (TREAT $covars), ///
				group(Cohort) controlg(notyet) vce(cluster district_encode)

			estat aggregation, dynamic(-5 -4 -3 -2 -1 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15) ///
				graph(title("") ytitle("CFM Effect on TCC (pp)") xtitle("Years Since Formalization") legend(off) ciopts(recast(rcap) color(black)) ///
				yscale(range(-5 20)) ylabel(-5(5)20))
			graph export "$DFigures/SI Figure 2c.png", replace as(png)

			estat aggregation, cohort ///
				graph(title("") ytitle("CFM Effect on TCC (pp)") xtitle("Cohort") legend(off) ciopts(recast(rcap) color(black)) ///
				yscale(range(-2 20)) ylabel(-2(4)20))
			graph export "$DFigures/SI Figure 2d.png", replace as(png)

			estat aggregation, overall

			* Cohort-by-year effects
			capture noisily estat atetplot, xtitle("Year") ytitle("CFM Effect on TCC (pp)") xlabel(2000(5)2020) xscale(range(2001 2023))
			if _rc == 0 graph export "$DFigures/SI Figure 8c.png", replace as(png)
			restore
