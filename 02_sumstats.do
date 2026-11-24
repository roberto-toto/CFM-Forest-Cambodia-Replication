clear

   ***************************************
   ***************************************

	   * Summary Statistics *

   ***************************************
   ***************************************

include "$code/programs.do"


*_______________________________________________________________________________
** 1A. Pre-Matching Table (Full Sample)
global CountrySample 	1
include "$code/programs.do"

capture program drop PreTableV2
program PreTableV2

preprocess2

** Land Cover %
foreach v in Forest Farm Plantat NonForNat NonVeg Water Other {
		cap replace `v'20`1' = 9 if `v'20`1' > 9
		cap replace `v'20`1' = `v'20`1' / 9 * 100
		cap label var `v'20`1' "`v' (\%), 20`1'"
	}

** Top Variable
means ch_adj_tccB`1'

label var ch_adj_tccB`1' "TCC Change (pp), 20`2'--2023"
esttab col4_ch_adj_tccB`1' col3_ch_adj_tccB`1' norm_diff_ch_adj_tccB`1'_1 varrat_ch_adj_tccB`1'_1 using "${tables}/$sample/$matchgroup/Balance_Prematch`1'_v2 $matchgroup $method $treat_type.tex", ///
	prehead("& Treated & Untreated & Norm. diff & Var ratio \\ \hline \\") ///
	replace fragment cells("mean(fmt(%9.2fc))") label style (tex) collabels(none) nomtitle noline nonumbers noobs

* Horizontal line
esttab using "${tables}/$sample/$matchgroup/Balance_Prematch`1'_v2 $matchgroup $method $treat_type.tex", ///
    append fragment ///
    prehead("\\ \hline \\")  ///
	style(tex) collabels(none) nomtitle noline nonumbers noobs

label var ch_adj_tccB`1' "TCC Change (pp), 19`3'--20`1'"
esttab col2_ch_adj_tccB`1' col1_ch_adj_tccB`1' norm_diff_ch_adj_tccB`1'_0 varrat_ch_adj_tccB`1'_0 using "${tables}/$sample/$matchgroup/Balance_Prematch`1'_v2 $matchgroup $method $treat_type.tex", ///
	append fragment cells("mean(fmt(%9.2fc))") label style (tex) collabels(none) nomtitle noline nonumbers noobs

**Middle Variables
means_timeinvariant Plantat_`1'_00 "Plantation Change (pp) 2000--20`1'"	"Prematch`1'_v2"
means_timeinvariant tcc_adj20`1'	"TCC (\%), 20`1'"				"Prematch`1'_v2"
means_timeinvariant Plantat20`1'	"Plantation (\%), 20`1'"			"Prematch`1'_v2"
means_timeinvariant Forest20`1'	"Forest (\%), 20`1'"				"Prematch`1'_v2"
means_timeinvariant Farm20`1'	"Farm (\%), 20`1'"				"Prematch`1'_v2"
means_timeinvariant elevation 	"Elevation (m)"					"Prematch`1'_v2"
means_timeinvariant slope 		"Slope (deg)"					"Prematch`1'_v2"
means_timeinvariant pop_2000	"Population, 2000"				"Prematch`1'_v2"
means_timeinvariant d_edge 		"Dist to Forest Edge (m)"		"Prematch`1'_v2"

**Bottom Variable
means d_road
label var d_road "Dist to Road (m)"
esttab col2_d_road col1_d_road norm_diff_d_road_0 varrat_d_road_0 using "${tables}/$sample/$matchgroup/Balance_Prematch`1'_v2 $matchgroup $method $treat_type.tex", append fragment cells("mean(fmt(%9.2fc))") label style (tex) collabels(none) nomtitle noline nonumbers noobs

** CFM Overlap
estpost sum treat_Pct if treat == 1 & post == 0
estimates store col2_treat_Pct
estpost sum treat_Pct if treat == 0 & post == 0
estimates store col1_treat_Pct
label var treat_Pct "CFU Overlap (\%)"
esttab col2_treat_Pct col1_treat_Pct using "${tables}/$sample/$matchgroup/Balance_Prematch`1'_v2 $matchgroup $method $treat_type.tex", append fragment cells("mean(fmt(%9.2fc))") label style (tex) collabels(none) nomtitle noline nonumbers noobs stats(N, fmt(%12.0gc) labels("Observations"))

end

PreTableV2 "05" "06" "90"
copy "${tables}/$sample/$matchgroup/Balance_Prematch05_v2 $matchgroup $method $treat_type.tex" "$DTables/SI Table 1a.tex", replace

*_______________________________________________________________________________
** 1B. Post-Matching Tables
global CountrySample 	1
global PrakaSample 		0
include "$code/programs.do"

capture program drop PostTableV2
program PostTableV2

use "$Output/Country/$matchgroup/Period05 $method $treat_type.dta", clear

assert Legal_Stat!="Unsure"
assert Legal_Stat!="Converted to CPA"

** Land Cover %
LCperc_main

** Top Variable
means ch_adj

label var ch_adj "TCC Change (pp), 20`2'--2023"
esttab col4_ch_adj col3_ch_adj norm_diff_ch_adj_1 varrat_ch_adj_1 using "${tables}/$sample/$matchgroup/Balance_Postmatch`1'_v2 $matchgroup $method $treat_type.tex", ///
    prehead("& Treated & Control & Norm. diff & Var ratio \\ \hline \\") ///
    replace fragment cells("mean(fmt(%9.2fc))") label style(tex) collabels(none) nomtitle noline nonumbers noobs

* Horizontal line
esttab using "${tables}/$sample/$matchgroup/Balance_Postmatch`1'_v2 $matchgroup $method $treat_type.tex", ///
    append fragment ///
    prehead("\\ \hline \\")  ///
	style(tex) collabels(none) nomtitle noline nonumbers noobs

label var ch_adj "TCC Change (pp), 19`3'--20`1'"
esttab col2_ch_adj col1_ch_adj norm_diff_ch_adj_0 varrat_ch_adj_0 using "${tables}/$sample/$matchgroup/Balance_Postmatch`1'_v2 $matchgroup $method $treat_type.tex", ///
	append fragment cells("mean(fmt(%9.2fc))") label style (tex) collabels(none) nomtitle noline nonumbers noobs

**Middle Variables
means_timeinvariant Plantat_`1'_00 	"Plantation Change (pp) 2000--20`1'"	"Postmatch`1'_v2"
means_timeinvariant tcc_adj20`1'		"TCC (\%), 20`1'"					"Postmatch`1'_v2"
means_timeinvariant Plantat20`1'		"Plantation (\%), 20`1'"				"Postmatch`1'_v2"
means_timeinvariant Forest20`1'		"Forest (\%), 20`1'"					"Postmatch`1'_v2"
means_timeinvariant Farm20`1'		"Farm (\%), 20`1'"					"Postmatch`1'_v2"
means_timeinvariant elevation 		"Elevation (m)"						"Postmatch`1'_v2"
means_timeinvariant slope 			"Slope (deg)"						"Postmatch`1'_v2"
means_timeinvariant pop_2000		"Population, 2000"					"Postmatch`1'_v2"
means_timeinvariant d_edge 			"Dist to Forest Edge (m)"			"Postmatch`1'_v2"

**Bottom Variable
means d_road
label var d_road "Dist to Road (m)"
esttab col2_d_road col1_d_road norm_diff_d_road_0 varrat_d_road_0 using "${tables}/$sample/$matchgroup/Balance_Postmatch`1'_v2 $matchgroup $method $treat_type.tex", append fragment cells("mean(fmt(%9.2fc))") label style (tex) collabels(none) nomtitle noline nonumbers noobs

** CFM Overlap
estpost sum treat_Pct if treat == 1 & post == 0
estimates store col2_treat_Pct
estpost sum treat_Pct if treat == 0 & post == 0
estimates store col1_treat_Pct
label var treat_Pct "CFU Overlap (\%)"
esttab col2_treat_Pct col1_treat_Pct using "${tables}/$sample/$matchgroup/Balance_Postmatch`1'_v2 $matchgroup $method $treat_type.tex", append fragment cells("mean(fmt(%9.2fc))") label style (tex) collabels(none) nomtitle noline nonumbers noobs stats(N, fmt(%12.0gc) labels("Observations"))

end

PostTableV2 "05" "06" "90"
copy "${tables}/Country/$matchgroup/Balance_Postmatch05_v2 $matchgroup $method $treat_type.tex" "$DTables/SI Table 1b.tex", replace

*_______________________________________________________________________________
** 1C. Post-Matching Balance by Baseline TCC (High vs Low)
*_______________________________________________________________________________
use "$Output/Country/$matchgroup/Period05 $method $treat_type.dta", clear
assert Legal_Stat!="Unsure"
assert Legal_Stat!="Converted to CPA"
keep if post == 0

* Median split
quietly summarize tcc_adj2005 if tcc_adj2005 < ., detail
scalar med_tcc05b = r(p50)
gen aboveMED_tcc = (tcc_adj2005 > med_tcc05b) if tcc_adj2005 < .

LCperc_other
labels_sumstats

local covars "ch_adj Plantat_05_00 tcc_adj2005 Plantat2005 Forest2005 Farm2005 elevation slope pop_2000 d_edge d_road"

tempname fh
file open `fh' using "$DTables/SI Table 5.tex", write replace
file write `fh' "{" _n "\begin{tabular}{l*{8}{c}}" _n "\hline\hline" _n
file write `fh' " & \multicolumn{4}{c}{High Baseline TCC} & \multicolumn{4}{c}{Low Baseline TCC} \\ \cmidrule(lr){2-5}\cmidrule(lr){6-9}" _n
file write `fh' " & Treated & Control & Norm. diff & Var ratio & Treated & Control & Norm. diff & Var ratio \\" _n "\hline" _n
foreach v of local covars {
	local row : variable label `v'
	foreach h in 1 0 {
		quietly summarize `v' if aboveMED_tcc == `h' & treat == 1
		local mt = r(mean)
		local vt = r(Var)
		quietly summarize `v' if aboveMED_tcc == `h' & treat == 0
		local mc = r(mean)
		local vc = r(Var)
		local nd = (`mt' - `mc') / sqrt((`vt' + `vc') / 2)
		local vr = `vt' / `vc'
		local row "`row' & `: display %9.2fc `mt'' & `: display %9.2fc `mc'' & `: display %9.2f `nd'' & `: display %9.2f `vr''"
		display as text "`v' (aboveMED_tcc = `h'): T `: display %9.2f `mt''  C `: display %9.2f `mc''  ND `: display %6.2f `nd''  VR `: display %6.2f `vr''"
	}
	file write `fh' "`row' \\" _n
}
foreach h in 1 0 {
	foreach t in 1 0 {
		quietly count if aboveMED_tcc == `h' & treat == `t'
		local n`h'`t' : display %12.0fc r(N)
	}
}
file write `fh' "\hline" _n "Observations & `n11' & `n10' & & & `n01' & `n00' & & \\" _n "\hline\hline" _n "\end{tabular}" _n "}" _n
file close `fh'


*_______________________________________________________________________________
** 2. Post-Matching Distributions
use "$Output/Country/$matchgroup/Period05 $method $treat_type.dta", clear
assert Legal_Stat!="Unsure"
assert Legal_Stat!="Converted to CPA"

include "$code/programs.do"
LCperc_other
labels_graph

local gphdir "$figures/$sample/$matchgroup/intermediate"
cap mkdir "`gphdir'"

foreach v in tcc_adj2005 Forest2005 Farm2005 Plantat2005 Plantat_05_00 ch_adj elevation slope d_road d_edge pop_2000 {

	local lab : variable label `v'

	if "`v'" == "ch_adj" {
		label variable ch_adj "TCC Change, 1990-2005"
	}

	twoway ///
    (kdensity `v' if treat==1 & post==0, color(blue%50) lwidth(medthin)) ///
    (kdensity `v' if treat==0 & post==0, color(red%50) lwidth(medthin)), ///
    legend(order(1 "Treat" 2 "Control")) ///
    title("`lab'", size(*0.9)) ///
	xtitle("") ytitle("") ///
    xlabel(, grid) ylabel(, grid)
	graph save "`gphdir'/`v'.gph", replace
}
grc1leg2 "`gphdir'/elevation.gph" "`gphdir'/slope.gph" ///
        "`gphdir'/d_road.gph" "`gphdir'/d_edge.gph" "`gphdir'/pop_2000.gph" ///
        "`gphdir'/tcc_adj2005.gph" "`gphdir'/Forest2005.gph" ///
        "`gphdir'/Farm2005.gph" "`gphdir'/Plantat2005.gph" ///
        "`gphdir'/Plantat_05_00.gph" "`gphdir'/ch_adj.gph", ///
        legendfrom("`gphdir'/elevation.gph") pos(6) lcols(2) legscale(small)

		graph export "$DFigures/SI Figure 3a.png", replace as(png)


*_______________________________________________________________________________
** 3A1. Parallel Trends Graph

	*Treat vs Control: TCC Adjusted
	use "$Output/Country/$matchgroup/Annual05 $method $treat_type.dta", clear
	assert Legal_Stat!="Unsure"
	assert Legal_Stat!="Converted to CPA"

	collapse (mean) tcc tcc_adj, by(year treat)

		***********
		* TCC Adjustment
		replace tcc_adj = tcc if year < 2000
		***********

	tw (line tcc_adj year if treat==1, color("51 166 166") lwidth(0.5)) ///
	   (line tcc_adj year if treat==0, color("242 80 65") lwidth(0.5)), ///
	   legend(lab(1 "{bf:Treated}") lab(2 "{bf:Control}") size(*1.15) pos(6) col(2)) ///
	   ytitle("Tree Canopy Cover (%)", size(*1.15)) xtitle("Year", size(*1.1)) xlabel(1990(2)2023, angle(45) labsize(small)) xline(2005)
	graph export "$DFigures/Figure 1a.png", replace as(png)


** 3A3. Parallel Trends Graph (Above/Below Median Baseline TCC)
	use "$Output/Country/$matchgroup/Annual05 $method $treat_type.dta", clear
	assert Legal_Stat!="Unsure"
	assert Legal_Stat!="Converted to CPA"

	* Define high/low TCC split at median
	bysort Grid_ID: egen tcc_adj2005 = max(cond(year == 2005, tcc_adj, .))
	quietly summarize tcc_adj2005 if tcc_adj2005 < ., detail
	scalar med_tcc05b = r(p50)
	gen aboveMED_tcc = (tcc_adj2005 > med_tcc05b) if tcc_adj2005 < .

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
		  graph save "$figures/$sample/$matchgroup/SumStats/Parallel Trends AboveMedianTCC $matchgroup $method $treat_type.gph", replace
	restore
	keep if aboveMED_tcc==0
		tw (line tcc_adj year if treat==1, color("51 166 166") lwidth(0.5)) ///
		   (line tcc_adj year if treat==0, color("242 80 65") lwidth(0.5)), ///
		   legend(lab(1 "{bf:Treated}") lab(2 "{bf:Control}") size(*1.15) pos(6) col(2)) ///
		   ytitle("Tree Canopy Cover (%)", size(*1.15)) ylabel(10(10)60, labsize(*1.115)) ///
		   xtitle("Year", size(*1.1)) xlabel(2000(2)2023, angle(45) labsize(*1.15)) xline(2005) ///
		   title("Below Median Baseline TCC", size(*0.8))
		  graph save "$figures/$sample/$matchgroup/SumStats/Parallel Trends BelowMedianTCC $matchgroup $method $treat_type.gph", replace

	grc1leg2  	"$figures/$sample/$matchgroup/SumStats/Parallel Trends AboveMedianTCC $matchgroup $method $treat_type.gph" ///
				"$figures/$sample/$matchgroup/SumStats/Parallel Trends BelowMedianTCC $matchgroup $method $treat_type.gph", ///
				legendfrom("$figures/$sample/$matchgroup/SumStats/Parallel Trends AboveMedianTCC $matchgroup $method $treat_type.gph") position(6)
	graph export "$DFigures/Figure 2b.png", replace as(png)


*_______________________________________________________________________________
** 4. Formalization TCC Parallel Trends Graph

	use "$Output/Praka/$matchgroup/Annual $method $treat_type.dta", clear
	assert Legal_Stat!="Unsure"
	assert Legal_Stat!="Converted to CPA"
	gen treatyear = Cohort
	tostring(Cohort), replace
	replace Cohort = Cohort + "_C" if treat==0
	replace Cohort = Cohort + "_T" if treat==1
	keep CF_Unique Cohort year tcc_adj tcc ch_adj ch PA CPA Farm Forest Plantat province_name treatyear
	replace tcc_adj = tcc if year<2000
	collapse (mean) tcc_adj tcc ch_adj ch CPA Farm Forest Plantat , by(Cohort treatyear year)
	gen treat = 1 if year >= treatyear
		replace treat = 0 if treat!=1
	replace treat = 0 if strpos(Cohort,"_C")

	gen recenter = year - treatyear


	* TCC
	foreach v in 2007 2008 2010 2011 2013 2014 2015 2017 2018 {
		preserve
		keep if treatyear==`v'
		global endyear = 2023 - treatyear
		panelview tcc_adj treat if recenter>=-6, ///
			i(Cohort) t(recenter) type(outcome) prepost ///
			subtitle("`v'") ytitle("Tree Canopy Cover (%)", size(small)) xtitle("") xlabel(-6(3)$endyear, angle(45) labsize(small)) xline(0) ///
			legend(pos(6)) graphregion(fcolor(white))
		graph save "$figures/Praka/intermediate/TvC_tcc_`v'.gph", replace
		restore
	}
	grc1leg "$figures/Praka/intermediate/TvC_tcc_2007.gph" "$figures/Praka/intermediate/TvC_tcc_2008.gph" ///
			"$figures/Praka/intermediate/TvC_tcc_2010.gph" "$figures/Praka/intermediate/TvC_tcc_2011.gph" ///
			"$figures/Praka/intermediate/TvC_tcc_2013.gph" "$figures/Praka/intermediate/TvC_tcc_2014.gph" ///
			"$figures/Praka/intermediate/TvC_tcc_2015.gph" "$figures/Praka/intermediate/TvC_tcc_2017.gph" ///
			"$figures/Praka/intermediate/TvC_tcc_2018.gph", pos(6) cols(3)
			graph export "$DFigures/SI Figure 1.png", replace as(png)


*_______________________________________________________________________________
* 5. CF Summary Table

	** 5A Prematching CF Table

		* CF Means by Cohort
		preprocess2

		drop if post==1
		keep if treat==1
		keep if Year_Praka<=2021 | Year_Praka==.
		rename Year_Praka Praka
			label var Praka "Praka"
			replace Praka=999 if Praka==0
			replace Praka=999 if mi(Praka)
			tostring Praka, replace
			replace Praka = "Unknown" if Praka=="999"

		collapse (mean) CF_Hectares tcc_adj2005 Plantat2005 Forest2005 Farm2005 elevation slope d_road d_edge pop_2000, by(CF_Unique Praka)
		LCperc_other
		CFtable_labels
		eststo clear
		bysort Praka: eststo: quietly estpost summarize ///
			CF_Hectares tcc_adj2005 Plantat2005 Forest2005 Farm2005 elevation slope d_road d_edge pop_2000
		esttab , cells("mean(fmt(2))") label nodepvar collabels(, none)
		esttab using "$DTables/SI Table 3.tex", ///
			cells("mean(fmt(%9.0fc))") label nodepvar nonumber collabels(none) ///
			stats(N, fmt(%9.0gc) labels("N (CFs)")) replace


*_______________________________________________________________________________
** 6. Stack Land Use Plots
include "$code/programs.do"
*CFs vs Controls
use "$Output/Country/Province/Annual05 $method $treat_type.dta", clear

	*CFs
	preserve
	keep if treat==1
	StackedArea "Treated"
	restore
	*Controls
	preserve
	keep if treat==0 & PA==0
	StackedArea "Control"
	restore
	*Plot
	grc1leg       "$figures/Land Use/Intermediate/Treated.gph" ///
				  "$figures/Land Use/Intermediate/Control.gph",  ///
				  legendfrom("$figures/Land Use/Intermediate/Treated.gph") position(6)
	graph export "$DFigures/Figure 1b.png", replace as(png)
	copy "$DFigures/Figure 1b.png" "$DFigures/SI Figure 6.png", replace
