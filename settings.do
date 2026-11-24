/*
Author: RVT
Purpose: Set the sample, matching group, and matching method for the next do-file.
Usage:   do "$code/settings.do" <Country|Praka> <Province|Ecoregion> <PSM-NoReplace|PSM-Replace|PSM-Caliper|CEM>
*/

args sample group method

****************************************
* CHOOSE SAMPLE & MATCHING
****************************************
* INTERIOR / BORDER
global Interior		1
global Border		0

* SAMPLE
global CountrySample	= ("`sample'" == "Country")
global PrakaSample		= ("`sample'" == "Praka")
global EstabSample		0

* MATCHING GROUP
global ProvinceExact	= ("`group'" == "Province")
global EcoregionExact	= ("`group'" == "Ecoregion")

* MATCHING METHOD
global psm_replacement		= ("`method'" == "PSM-Replace")
global psm_noreplacement	= ("`method'" == "PSM-NoReplace")
global psm_caliper			= ("`method'" == "PSM-Caliper")
global cem					= ("`method'" == "CEM")

* MATCHING OPTIONS
global psm_replacement_options 		"neighbor(1) common"
global psm_noreplacement_options 	"neighbor(1) noreplacement common"
global psm_caliper_options 			"neighbor(1) caliper(0.02) "	
global cem_options 					""

* TREATMENT GROUP NAME (used in file names)
global treat_type "CFnoPAcell_Main"

* Check the choices
assert $CountrySample + $PrakaSample == 1
assert $ProvinceExact + $EcoregionExact == 1
assert $psm_replacement + $psm_noreplacement + $psm_caliper + $cem == 1

* DEFINE MAIN GLOBALS ($sample, $matchgroup, $group_var, $method)
include "$code/programs.do"
display as result "Settings: $sample | $matchgroup | $method | $treat_type"
