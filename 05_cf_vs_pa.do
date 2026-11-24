clear

   ***************************************
   ***************************************

	   * Community Forests vs Protected Areas *

   ***************************************
   ***************************************

include "$code/programs.do"
display "$sample $matchgroup $method $treat_type"


**********************************************
******* MATCH PAs TO CF Counterfactual *******
**********************************************

*** (0) Setup
global keyvars Grid_ID tcc_adj2005 AdjTCC_05_00 Forest2005 Farm2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000 PA PA_Grid* PA_CF* ELC* province* district*

*** (1) Get Protected Area Observations
use "$input/Cleaned_Period.dta", clear

	*Keep only PA land
	keep if PA==1
	drop if treat==1

	*Keep only relevant variables
	keep ch_adj_tccB05 mean_precipB05 post treat treat_Pct treatC* $keyvars

	*Align variable names
	rename ch_adj_tccB05 ch_adj
	rename mean_precipB05 mean_precip

	*Save PA file
	tempfile PAs
	save `PAs'

	*Count PA cells
	codebook Grid_ID

*** (2) Add Protected Areas to Post-Matching Controls
use "$Output/$sample/$matchgroup/Period05 $method $treat_type.dta", clear

	*Only keep controls
	keep if treat==0
	assert PA!=1

	*Append PAs
	append using `PAs'

	*Keep only relevant variables
	keep ch_adj mean_precip post treat treat_Pct treatC* $keyvars

	*Create 'Control' Variable
	gen Control = 1 if PA==0
		replace Control = 0 if Control != 1
		drop treat

	* Order
	order Grid_ID Control PA

	* Reshape wide for matching
	reshape wide ch_adj mean_precip, i(Grid_ID) j(post)
	rename ch_adj0 ch_adj2005_1990
	rename ch_adj1 ch_adj2023_2005
	label var ch_adj2005_1990 "Ch Adj TCC 90-05"
	label var ch_adj2023_2005 "Ch Adj TCC 05-23"

save "$Output/CFvsPA/01_PA_and_Controls_Unmatched.dta", replace


*** (3) Match PAs to the Control Group Selected for the CFs
*
*
	use "$Output/CFvsPA/01_PA_and_Controls_Unmatched", clear

		*Check common support by match group
		tab $group_var PA
		tab $group_var Control

	*MATCHING LOOP

	* Drop Groups with Insufficient PA Observations
		bysort $group_var: egen group_PA_count = total(PA)
		display "Units Before Filter"
			tab $group_var PA
			codebook $group_var
		drop if group_PA_count == 0
		if $ProvinceExact == 1 {
			drop if group_PA_count < 200
			drop if province_name == "Takeo"
			}
		display "Units After Filter"
			tab $group_var PA
			codebook $group_var

	* Drop Groups with Insufficient Control Observations
		bysort $group_var: egen group_Control_count = total(Control)
		display "Units Before Filter"
			tab $group_var Control
			codebook $group_var
		drop if group_Control_count == 0
		if $ProvinceExact == 1 {
			drop if group_Control_count < 200
			drop if province_name == "Takeo"
			}
		display "Units After Filter"
			tab $group_var Control
			codebook $group_var

	*Matching PAs to Controls
	levelsof $group_var, local(group_list)
	display "Matching groups: `group_list'"

	foreach j in `group_list' {

		display "Running PA Matching for Group: `j'"
		count if $group_var==`j' & PA==1

		preserve

		* Set seed
		set seed 339487731

		**Use Controls as the treatment
		if 0 {
			display "Running PSM with Replacement"
			psmatch2 Control tcc_adj2005 ch_adj2005_1990 Forest2005 Farm2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000 if $group_var==`j', out(ch_adj2023_2005) neighbor(1) common
			}
		if 1 {
			display "Running PSM with No Replacement"
			capture noisily psmatch2 Control tcc_adj2005 ch_adj2005_1990 Forest2005 Farm2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000 if $group_var==`j', out(ch_adj2023_2005) noreplacement neighbor(1) common
			* If the probit does not converge (error 430), match on the 50-iteration probit score
			if _rc == 430 {
				display as error "Probit did not converge in group `j': matching on the 50-iteration probit score"
				capture probit Control tcc_adj2005 ch_adj2005_1990 Forest2005 Farm2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000 if $group_var==`j', iterate(50)
				predict double ps_cap if $group_var==`j'
				psmatch2 Control if $group_var==`j', pscore(ps_cap) out(ch_adj2023_2005) noreplacement neighbor(1) common
				drop ps_cap
			}
			else if _rc != 0 {
				exit _rc
			}
			}

		*Keep only observations from group of iteration
		keep if $group_var==`j'

		*Drop unmatched controls using pair variables
		gen pair = _id if _treated ==0
			replace pair = _n1 if _treated ==1
			bysort pair: egen paircount = count(pair)
		drop if paircount < 2
			count if Control==1
			tab PA Control

		*Drop observations with really bad common support (PSM methods only)
		if 1 {
			replace _pdif = 0 if _pdif == .
			bysort pair: egen pdif = max(_pdif)
			drop if pdif > 0.005
			}

		*Save file of this group
		gen MATCHGROUP = `j'
		save "$Matching/CFvsPA/$matchgroup/intermediate/`j'_match.dta", replace

		restore
	}

	*Combine matched group datasets
	levelsof $group_var, local(group_list)
	local first_group : word 1 of `group_list'

	use "$Matching/CFvsPA/$matchgroup/intermediate/`first_group'_match.dta", clear
	foreach v of local group_list {
		if "`v'" != "`first_group'" {
			append using "$Matching/CFvsPA/$matchgroup/intermediate/`v'_match.dta"
		}
	}

	*Create unique ID by match group and Grid_ID
	egen unique_ID_match = group($group_var Grid_ID)

	*Sort matched pairs
	sort $group_var pair $pair_treated_var

	*Save matched file
	order Grid_ID Control PA
	save "$Output/CFvsPA/02_PA_and_Controls_Matched.dta", replace


*** (4) Fetch CFs linked to Postmatching PA-Control Data
use "$Output/CFvsPA/02_PA_and_Controls_Matched.dta", clear

	*Tag controls used by PA matching
	keep if Control==1
	keep Grid_ID
	gen CommonControl = 1

	tempfile commoncontrol
	save `commoncontrol'

	*Get CFs that correspond to these Common Controls
	use "$Matching/$sample/$matchgroup/Matched05 $method $treat_type.dta", clear

		*Merge Common Controls
		merge 1:1 Grid_ID using `commoncontrol'
		order Grid_ID treat $group_var pair paircount _merge Common

		*Keep CF cells that are matched to a "Common Control"
		bysort $group_var pair: egen KEEP = max(CommonControl)
		keep if KEEP == 1
		rename treat CF_relevant

		*Precip rename for appending
		rename precip2023_2005 mean_precip1
		rename precip2005_1990 mean_precip0

		*Keep only relevant variables
		keep CF_relevant ch_adj2023_2005 ch_adj2005_1990 mean_precip* $keyvars
		order Grid_ID CF_relevant ch_adj2023_2005 ch_adj2005_1990 mean_precip* $keyvars
		drop PA*

		save "$Output/CFvsPA/03_CF_Relevant.dta", replace

*** (5) Match CFs to Controls
	use"$Output/CFvsPA/03_CF_Relevant.dta", clear
	tab CF_relevant
	gen Control = 1 if CF_relevant==0
		replace Control = 0 if CF_relevant==1

	*Matching CFs to Controls
	levelsof $group_var, local(group_list)
	display "Matching groups: `group_list'"

	foreach j in `group_list' {

		display "Running CF Matching for Group: `j'"
		count if $group_var==`j' & CF_relevant==1

		preserve

		* Set seed
		set seed 339487731

		**Use Controls as the treatment
		if 0 {
			display "Running PSM with Replacement"
			psmatch2 Control tcc_adj2005 ch_adj2005_1990 Forest2005 Farm2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000 if $group_var==`j', out(ch_adj2023_2005) neighbor(1) common
			}
		if 1 {
			display "Running PSM with No Replacement"
			psmatch2 Control tcc_adj2005 ch_adj2005_1990 Forest2005 Farm2005 Plantat2005 Plantat_05_00 elevation slope d_road d_edge pop_2000 if $group_var==`j', out(ch_adj2023_2005) noreplacement neighbor(1) common
			}

		*Keep only observations from group of iteration
		keep if $group_var==`j'

		*Drop unmatched controls using pair variables
		gen pair = _id if _treated ==0
			replace pair = _n1 if _treated ==1
			bysort pair: egen paircount = count(pair)
		drop if paircount < 2
			count if Control==1
			tab CF_relevant Control

		*Drop observations with really bad common support (PSM methods only)
		if 0 {
			replace _pdif = 0 if _pdif == .
			bysort pair: egen pdif = max(_pdif)
			drop if pdif > 0.005
			}

		*Save file of this group
		gen MATCHGROUP = `j'
		save "$Matching/CFvsPA/$matchgroup/intermediate/`j'_match_Control_CF.dta", replace

		restore
	}

	*Combine matched group datasets
	levelsof $group_var, local(group_list)
	local first_group : word 1 of `group_list'

	use "$Matching/CFvsPA/$matchgroup/intermediate/`first_group'_match_Control_CF.dta", clear
	foreach v of local group_list {
		if "`v'" != "`first_group'" {
			append using "$Matching/CFvsPA/$matchgroup/intermediate/`v'_match_Control_CF.dta"
		}
	}

	*Create unique ID by match group and Grid_ID
	egen unique_ID_match = group($group_var Grid_ID)

	*Sort matched pairs
	sort $group_var pair $pair_treated_var

	*Save matched file
	order Grid_ID Control CF_relevant
	save "$Output/CFvsPA/04_Controls_and_CFs_Matched.dta", replace


	*Save just post-matching relevant CFs
	use "$Output/CFvsPA/04_Controls_and_CFs_Matched.dta", clear
	keep if CF_relevant==1
	assert Control==0
	drop Control
	save "$Output/CFvsPA/04_Postmatching_CF_relevant.dta", replace


*** (6) Return to PA Postmatch Dataset, and bring in the Relevant CFs
	use "$Output/CFvsPA/02_PA_and_Controls_Matched.dta", clear
		keep ch_adj2023_2005 ch_adj2005_1990 mean_precip* Control $keyvars

		*Append Relevant CFs
		append using "$Output/CFvsPA/04_Postmatching_CF_relevant.dta"

		*Update varnames, completeness, and order
		rename CF_relevant CF
		order Grid_ID CF PA Control ch_adj2023_2005 ch_adj2005_1990 mean_precip*
		replace CF = 0 if CF!=1
		replace Control = 0 if Control !=1
		replace PA = 0 if PA !=1
		sort Grid_ID Control PA CF

		****** Assess Sample *******
		codebook Grid_ID if CF==1
		codebook Grid_ID if PA==1
		codebook Grid_ID if Control==1

		*Cell Type (for mapping)
		gen celltype = "CF" if CF==1
			replace celltype = "PA" if PA==1
			replace celltype = "Control" if Control==1
			assert celltype!=""
			order celltype, after(Grid_ID)
		*Save
		save "$Output/CFvsPA/04_CFvsPA_Postmatching.dta", replace


*** (5) Period Panel

**PERIOD PANEL**
use "$Output/CFvsPA/04_CFvsPA_Postmatching.dta", clear
	rename ch_adj2023_2005   ch_adj1
	rename ch_adj2005_1990   ch_adj0

	reshape long ch_adj mean_precip, i(Grid_ID) j(post)
		label var post "Post-2005"
		label var ch_adj "TCC Change"
		label var mean_precip "Mean Precip (mm)"
		label var Forest2005 "Forest (%) 2005"
		label var Farm2005 "Farm (%) 2005"
		label var Plantat2005 "Plantat (%) 2005"
		label var Plantat_05_00 "Ch Plantat (pp) 00-05"

	gen CF_post = CF*post
		label var CF_post "CF x Post"

	gen PA_post = PA*post
		label var PA_post "PA x Post"

save "$Output/CFvsPA/05_CFvsPA_Postmatching_Period.dta", replace


**********************************************
		******* ESTIMATION *******
**********************************************
****----------- HETEROGENEITY: CF vs PA Comparison -----------****
****--------------------------------------------------------------------------****

use "$Output/CFvsPA/05_CFvsPA_Postmatching_Period.dta", clear
xtset Grid_ID post

* --- Grouping variables ---
summarize tcc_adj2005 if tcc_adj2005 < ., detail
scalar med_tcc = r(p50)
gen aboveMED  = (tcc_adj2005 >  med_tcc) if tcc_adj2005 < .
gen belowMED  = (tcc_adj2005 <= med_tcc) if tcc_adj2005 < .

* Deforestation Pressure Index
capture drop d_road_std ELC_dist_std d_edge_std pop_std ext_press_idx hipressure
quietly summarize ELC_Grid_Dist if ELC_Grid_Dist < .
gen ELC_dist_std  = (ELC_Grid_Dist - r(mean)) / r(sd)
quietly summarize d_road if d_road < .
gen d_road_std    = (d_road - r(mean)) / r(sd)
quietly summarize d_edge if d_edge < .
gen d_edge_std    = (d_edge - r(mean)) / r(sd)
quietly summarize pop_2000 if pop_2000 < .
gen pop_std       = (pop_2000 - r(mean)) / r(sd)
gen ext_press_idx = (-ELC_dist_std - d_road_std - d_edge_std + pop_std) / 4
label var ext_press_idx "Deforestation pressure index (ELC proximity, road access, edge proximity, population - equal 1/4 weights)"
drop d_road_std ELC_dist_std d_edge_std pop_std

quietly summarize ext_press_idx if ext_press_idx < ., detail
scalar med_pressure = r(p50)
gen hipressure = (ext_press_idx > med_pressure) if ext_press_idx < .
label var hipressure "Above-median deforestation pressure"


* --- CF Subgroup Regressions ---
* Full sample
xtreg ch_adj CF_post post mean_precip i.post#i.province_num if PA!=1, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store CF_full
    local att_cf = _b[CF_post]

* Baseline TCC (median split)
xtreg ch_adj CF_post post mean_precip i.post#i.province_num ///
    if PA!=1 & aboveMED==1, fe i(Grid_ID) cluster(district_encode)
    estimates store CF_HiTCC

xtreg ch_adj CF_post post mean_precip i.post#i.province_num ///
    if PA!=1 & belowMED==1, fe i(Grid_ID) cluster(district_encode)
    estimates store CF_LoTCC

* Deforestation Pressure 2x2
xtreg ch_adj CF_post post mean_precip i.post#i.province_num ///
    if PA!=1 & aboveMED==1 & hipressure==1, fe i(Grid_ID) cluster(district_encode)
    estimates store CF_HiHi

xtreg ch_adj CF_post post mean_precip i.post#i.province_num ///
    if PA!=1 & aboveMED==1 & hipressure==0, fe i(Grid_ID) cluster(district_encode)
    estimates store CF_HiLo

xtreg ch_adj CF_post post mean_precip i.post#i.province_num ///
    if PA!=1 & belowMED==1 & hipressure==1, fe i(Grid_ID) cluster(district_encode)
    estimates store CF_LoHi

xtreg ch_adj CF_post post mean_precip i.post#i.province_num ///
    if PA!=1 & belowMED==1 & hipressure==0, fe i(Grid_ID) cluster(district_encode)
    estimates store CF_LoLo


* --- PA Subgroup Regressions ---
* Full sample
xtreg ch_adj PA_post post mean_precip i.post#i.province_num if CF!=1, ///
    fe i(Grid_ID) cluster(district_encode)
    estimates store PA_full
    local att_pa = _b[PA_post]

* Baseline TCC (median split)
xtreg ch_adj PA_post post mean_precip i.post#i.province_num ///
    if CF!=1 & aboveMED==1, fe i(Grid_ID) cluster(district_encode)
    estimates store PA_HiTCC

xtreg ch_adj PA_post post mean_precip i.post#i.province_num ///
    if CF!=1 & belowMED==1, fe i(Grid_ID) cluster(district_encode)
    estimates store PA_LoTCC

* Deforestation Pressure 2x2
xtreg ch_adj PA_post post mean_precip i.post#i.province_num ///
    if CF!=1 & aboveMED==1 & hipressure==1, fe i(Grid_ID) cluster(district_encode)
    estimates store PA_HiHi

xtreg ch_adj PA_post post mean_precip i.post#i.province_num ///
    if CF!=1 & aboveMED==1 & hipressure==0, fe i(Grid_ID) cluster(district_encode)
    estimates store PA_HiLo

xtreg ch_adj PA_post post mean_precip i.post#i.province_num ///
    if CF!=1 & belowMED==1 & hipressure==1, fe i(Grid_ID) cluster(district_encode)
    estimates store PA_LoHi

xtreg ch_adj PA_post post mean_precip i.post#i.province_num ///
    if CF!=1 & belowMED==1 & hipressure==0, fe i(Grid_ID) cluster(district_encode)
    estimates store PA_LoLo


* --- Panel A: Community Forests ---
coefplot ///
    (CF_full,     keep(CF_post) rename(CF_post = "{bf:Main}")            mfcolor("31 73 125")) ///
    (CF_HiTCC,    keep(CF_post) rename(CF_post = "High TCC")                    mfcolor(white)) ///
    (CF_LoTCC,    keep(CF_post) rename(CF_post = "Low TCC")                     mfcolor(white)) ///
    (CF_HiHi,     keep(CF_post) rename(CF_post = "High Pressure, High TCC")     mfcolor(white)) ///
    (CF_HiLo,     keep(CF_post) rename(CF_post = "Low Pressure, High TCC")      mfcolor(white)) ///
    (CF_LoHi,     keep(CF_post) rename(CF_post = "High Pressure, Low TCC")      mfcolor(white)) ///
    (CF_LoLo,     keep(CF_post) rename(CF_post = "Low Pressure, Low TCC")       mfcolor(white)), ///
    headings(" "                       = "{bf:Main}" ///
             "High TCC"                = "{bf:Baseline TCC}" ///
             "High Pressure, High TCC" = "{bf:Deforestation Pressure}", ///
             labsize(vsmall)) ///
    title("{bf:Community Forests}", size(medium) color("31 73 125")) ///
    xline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
    xline(`att_cf', lcolor(grey) lpattern(dot) lwidth(med)) ///
    msymbol(D) msize(medsmall) mcolor("31 73 125") ///
    ciopts(lcolor("31 73 125") lwidth(medthin)) ///
    xlabel(0(10)20, format(%4.0f) labsize(vsmall) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) ///
    xscale(range(-5 20)) ///
    xtitle("CFM Effect on TCC (pp)", size(vsmall)) ///
    ytitle("") ylabel(, labsize(vsmall)) ///
    legend(off) ///
    graphregion(color(white) margin(l=0 r=3 t=2 b=2)) ///
    plotregion(color(white) margin(l=0 r=5 t=1 b=1)) ///
    xsize(5) ysize(6) scheme(s2mono)

graph save "$figures/CFvsPA/Heter_CF.gph", replace

* --- Panel B: Protected Areas ---
coefplot ///
    (PA_full,     keep(PA_post) rename(PA_post = "{bf:Main}")            mfcolor("51 122 122")) ///
    (PA_HiTCC,    keep(PA_post) rename(PA_post = "High TCC")                    mfcolor(white)) ///
    (PA_LoTCC,    keep(PA_post) rename(PA_post = "Low TCC")                     mfcolor(white)) ///
    (PA_HiHi,     keep(PA_post) rename(PA_post = "High Pressure, High TCC")     mfcolor(white)) ///
    (PA_HiLo,     keep(PA_post) rename(PA_post = "Low Pressure, High TCC")      mfcolor(white)) ///
    (PA_LoHi,     keep(PA_post) rename(PA_post = "High Pressure, Low TCC")      mfcolor(white)) ///
    (PA_LoLo,     keep(PA_post) rename(PA_post = "Low Pressure, Low TCC")       mfcolor(white)), ///
    headings(" "                       = "{bf:Main}" ///
             "High TCC"                = "{bf:Baseline TCC}" ///
             "High Pressure, High TCC" = "{bf:Deforestation Pressure}", ///
             labsize(vsmall)) ///
    title("{bf:Protected Areas}", size(medium) color("51 122 122")) ///
    xline(0, lcolor(red) lpattern(dash) lwidth(thin)) ///
    xline(`att_pa', lcolor(grey) lpattern(dot) lwidth(med)) ///
    msymbol(D) msize(medsmall) mcolor("51 122 122") ///
    ciopts(lcolor("51 122 122") lwidth(medthin)) ///
    xlabel(0(10)20, format(%4.0f) labsize(vsmall) grid glcolor(gs12) glpattern(dot) glwidth(vthin)) ///
    xscale(range(-5 20)) ///
    xtitle("PA Effect on TCC (pp)", size(vsmall)) ///
    ytitle("") ylabel(, labsize(vsmall)) ///
    legend(off) ///
    graphregion(color(white) margin(l=0 r=3 t=2 b=2)) ///
    plotregion(color(white) margin(l=0 r=5 t=1 b=1)) ///
    xsize(5) ysize(6) scheme(s2mono)

graph save "$figures/CFvsPA/Heter_PA.gph", replace

* --- Combine into parallel panel figure ---
graph combine ///
    "$figures/CFvsPA/Heter_CF.gph" ///
    "$figures/CFvsPA/Heter_PA.gph", ///
    rows(1) imargin(2 2 2 2) ///
    graphregion(color(white)) ///
    xsize(12) ysize(6) scheme(s2mono)

graph export "$DFigures/Figure 4.pdf", replace as(pdf)
