clear all
macro drop _all
set more off
set graphics off

   ***************************************
   ***************************************

	   * Master Do-File *

   ***************************************
   ***************************************

* Replication code for: Formalizing community forests reduces deforestation by over one third
* in a Southeast Asian context of extreme commodity pressure (Toto et al.)
*
* 1. Put the input files (Cleaned.dta, Cleaned_Period.dta) in a folder called input inside this folder.
* 2. Set the folder below.
* 3. Run this file. Requires Stata 18 or later.


****************************************
* SET THIS FOLDER
****************************************
global root "C:/Users/yourname/CFM-Forest-Cambodia-Replication"	// folder that contains this file

* Where the datasets and results are written (default: inside the folder above)
global out "$root"


****************************************
* WHAT TO RUN (1 = run, 0 = skip)
****************************************
global run_main			1	// main results: Table 1, Figures 1-5, SI Figures 1-4, 6, 8, SI Tables 1, 3-5
global run_robust		1	// robustness: SI Tables 2, 6, SI Figure 7, SI Robustness Figures 1-4 and Tables 1-3 (needs run_main first)
global install_packages	0	// 1 = install the user-written packages below


****************************************
* PACKAGES
****************************************
if $install_packages == 1 {
	foreach p in psmatch2 cem coefplot estout covbal grc1leg2 panelview schemepack {
		ssc install `p', replace
	}
	net install balanceplot, from("https://tdmize.github.io/data/balanceplot") replace
	net install grc1leg, from("http://www.stata.com/users/vwiggins") replace
}


****************************************
* FOLDERS (no changes needed)
****************************************
global code		"$root"
global input	"$root/input"

* Datasets and working files made by the code
global Output	"$out/data/Outputs"
global Matching	"$out/data/Matching"
global tables	"$out/data/Scratch/Tables"
global figures	"$out/data/Scratch/Figures"

* Paper tables and figures
global DTables	"$out/output/Tables"
global DFigures	"$out/output/Figures"

* Create the folders
foreach d in "$out/data" "$Output" "$Matching" "$out/data/Scratch" "$tables" "$figures" ///
	"$figures/CFvsPA" "$figures/Land Use" "$figures/Land Use/Intermediate" "$figures/Praka" "$figures/Praka/intermediate" ///
	"$out/output" "$DTables" "$DFigures" {
	cap mkdir "`d'"
}
foreach s in Country Praka {
	foreach d in "$Output/`s'" "$Matching/`s'" "$tables/`s'" "$figures/`s'" {
		cap mkdir "`d'"
	}
	foreach g in Province Ecoregion {
		foreach d in "$Output/`s'/`g'" "$Output/`s'/`g'/SubMatch" "$Output/`s'/`g'/Placebo2000" ///
			"$Matching/`s'/`g'" "$Matching/`s'/`g'/intermediate" "$Matching/`s'/`g'/SubMatch" ///
			"$Matching/`s'/`g'/SubMatch/intermediate" "$Matching/`s'/`g'/Placebo2000" ///
			"$Matching/`s'/`g'/Placebo2000/intermediate" "$tables/`s'/`g'" "$figures/`s'/`g'" ///
			"$figures/`s'/`g'/Robustness" "$figures/`s'/`g'/SumStats" "$figures/`s'/`g'/intermediate" {
			cap mkdir "`d'"
		}
	}
}
foreach d in "$Output/CFvsPA" "$Output/CFvsPA/SubMatch" "$Matching/CFvsPA" ///
	"$Matching/CFvsPA/Province" "$Matching/CFvsPA/Province/intermediate" "$Matching/CFvsPA/Province/SubMatch" ///
	"$Matching/CFvsPA/Ecoregion" "$Matching/CFvsPA/Ecoregion/intermediate" "$Matching/CFvsPA/Ecoregion/SubMatch" {
	cap mkdir "`d'"
}

confirm file "$input/Cleaned.dta"
confirm file "$input/Cleaned_Period.dta"


****************************************
* 1. MAIN RESULTS
****************************************
if $run_main == 1 {
	* Matching: full sample (main)
	do "$code/settings.do" Country Province PSM-NoReplace
	do "$code/01_matching.do"				// SI Figures 3b and 4

	* Matching: formalization sample (cohorts)
	do "$code/settings.do" Praka Province PSM-NoReplace
	do "$code/01_matching.do"

	do "$code/settings.do" Country Province PSM-NoReplace
	do "$code/02_sumstats.do"				// SI Tables 1a, 1b, 3, 5; Figures 1a-b and 2b; SI Figures 1, 3a, 6

	do "$code/settings.do" Country Province PSM-NoReplace
	do "$code/03_did_estimation.do"			// Table 1; Figures 1c, 2a, 2c-d, 3, 5; SI Table 4

	do "$code/settings.do" Praka Province PSM-NoReplace
	do "$code/04_hrdid_estimation.do"		// Figure 1d; SI Figures 2 and 8

	do "$code/settings.do" Country Province PSM-NoReplace
	do "$code/05_cf_vs_pa.do"				// Figure 4
}


****************************************
* 2. ROBUSTNESS (needs run_main first; CEM matching takes many hours)
****************************************
if $run_robust == 1 {
	* Ecoregion matching
	do "$code/settings.do" Country Ecoregion PSM-NoReplace
	do "$code/01_matching.do"
	do "$code/settings.do" Country Ecoregion PSM-NoReplace
	do "$code/03_did_estimation.do"			// SI Table 2

	* Alternate matching methods
	foreach m in PSM-Replace PSM-Caliper CEM {
		do "$code/settings.do" Country Province `m'
		do "$code/01_matching.do"
	}

	do "$code/settings.do" Country Province PSM-NoReplace
	do "$code/06_robustness.do"				// SI Robustness Figures 1-4 and Tables 1-3; SI Table 6; SI Figure 7
}

set graphics on
display as result "Done. Paper tables and figures are in $DTables and $DFigures"
