
******************************
**    Health Care Worker    **
**        Analysis	        **
**                          **
**       Aaron Chafetz      **
**      USAID/OHA/SPER      **
**      August 28, 2015     **
**     Last Updated 8/28    **
******************************

/*
////////////////////////////////////////////////////////////////////////////////
  
  Outline
	- SET DIRECTORIES
	- IMPORT AND CLEAN DATA
	- MERGE
	- ANALYSIS

 Data sources
	- World Bank WDI

	
////////////////////////////////////////////////////////////////////////////////	
*/


********************************************************************************
********************************************************************************
	
** SET DIRECTORIES **

	clear
	set more off

*  must be run each time Stata is opened
	/* Choose the project path location to where you want the project parent 
	   folder to go on your machine. Make sure it ends with a forward slash */
	global projectpath "/Users/Aaron/Desktop"
	cd "$projectpath"
	
* Run a macro to set up study folder
	* Name the file path below
	local pFolder HealthCareWorkers
	foreach dir in `pFolder' {
		confirmdir "`dir'"
		if `r(confirmdir)'==170 {
			mkdir "`dir'"
			display in yellow "Project directory named: `dir' created"
			}
		else disp as error "`dir' already exists, not created."
		cd "$projectpath/`dir'"
		}
	* end

* Run initially to set up folder structure
* Choose your folders to set up as the local macro `folders'
	local folders RawData StataOutput StataFigures ExcelOutput Documents
	foreach dir in `folders' {
		confirmdir "`dir'"
		if `r(confirmdir)'==170 {
				mkdir "`dir'"
				disp in yellow "`dir' successfully created."
			}
		else disp as error "`dir' already exists. Skipped to next folder."
	}
	*end
* Set up global file paths located within project path
	* these folders must exist in the parent folder
	global projectpath `c(pwd)'
	global data "$projectpath/RawData/"
	global output "$projectpath/StataOutput/"
	global graph "$projectpath/StataFigures/"
	global excel "$projectpath/ExcelOutput/"
	disp as error "If initial setup, move data to RawData folder."


********************************************************************************
********************************************************************************

** IMPORT AND CLEAN DATA **

* Thresholds for WB Country Classifications with GNI (by year)
	* Source - https://datahelpdesk.worldbank.org/knowledgebase/articles/378833-how-are-the-income-group-thresholds-determined
	
	import excel "$data\WBclass.xls", sheet("Thresholds") cellrange(A7:AP24) firstrow clear
	drop in 1/13
	drop B-O
	
	* label years
		foreach year of var P-AP{
			local l`year' : variable label `year'
			rename `year' y`l`year''
		}
		*end

	* transpose
		gen id = _n
		qui: reshape long y, i(Dataforcalendaryear) j(year)
		drop Dataforcalendaryear
		qui: reshape wide y, i(year) j(id)
		drop y1
		split y2, gen(mid) parse("-") destring ignore(",") force
			rename mid1 lowermid_l
			lab var lowermid_l "Lower middle income lower bound"
			rename mid2 lowermid_u
			lab var lowermid_u "Lower middle income upper bound"
		split y3, gen(mid) parse("-") destring ignore(",") force
			drop mid1
			rename mid2 uppermid_u
			lab var uppermid_u "Upper middle income upper bound"
		drop y2-y4
	* save
		save "$output\classlvls.dta", replace

*WB Regions
	
	import excel "$data\WBcountryinfo.xlsx", sheet("WB") firstrow clear
	keep CountryCode Region
	encode Region, gen(region)
	rename CountryCode ctrycode
	drop Region
	save "$output\wbregions.dta", replace

*WDI Data
	*http://data.worldbank.org/
	local count = 1
	foreach f in arvpct chw_p1000 condomuse_f_pct condomuse_m_pct deathrate_p1000 eduprimary_pct gdp_pc gni_pc healthexp_pc healthexp_pct hivprev_pct lifeexp literacy_pct nursemidwives_p1000 physicians_p1000 pop {
		
		di "Cleaning file: (`count') `f' "
		
		import excel "$data/`f'.xls", sheet("Data") cellrange(A4:BG253) firstrow clear
		
		* label years
			foreach year of var E-BG{
					local l`year' : variable label `year'
					rename `year' y`l`year''
				}
				*end
		* drop indicator variables
			drop IndicatorName IndicatorCode
			
		* rename for merge with concordance file 
			rename CountryName ctry
			rename CountryCode ctrycode
			
		* gen unique id for reshaping
			gen id  = _n
			
		* reshape to have one column for year, country, and flow
			qui: reshape long y, i(id) j(year)
			qui: drop id
			rename y `f'
	
		* sort for merging
			sort ctry year 
		

		* save
			qui: save "$output/`f'.dta", replace
			
		local count = `count' + 1
		}
		*end
	

********************************************************************************
********************************************************************************
	
** MERGE **

	*merge data together
		use "$output/arvpct.dta", clear
		foreach f in chw_p1000 condomuse_f_pct condomuse_m_pct deathrate_p1000 eduprimary_pct gdp_pc gni_pc healthexp_pc healthexp_pct hivprev_pct lifeexp literacy_pct nursemidwives_p1000 physicians_p1000 pop {
			di "Merging file: `f'"
			qui: merge 1:1 ctry year using "$output/`f'.dta", nogen
			}
			*end
		qui: merge m:1 year using "$output\classlvls.dta", nogen //for yearly ctry classification
			di "Merging file: classlvls"
			
	*add/change WB country codes to match for merging with regions
		qui: replace ctrycode = "ADO" if ctry=="Andorra"		qui: replace ctrycode = "ZAR" if ctry=="Congo, Dem. Rep."		qui: replace ctrycode = "IMY" if ctry=="Isle of Man"		qui: replace ctrycode = "KSV" if ctry=="Kosovo"		qui: replace ctrycode = "ROM" if ctry=="Romania"		qui: replace ctrycode = "TMP" if ctry=="Timor-Leste"		qui: replace ctrycode = "WBG" if ctry=="West Bank and Gaza"
	
	*merge with region	
		qui: merge m:1 ctrycode using "$output\wbregions.dta", nogen
	
	*add source data
		ds year, not
		foreach v of varlist `r(varlist)'{
			note `v': Source: World Bank WDI (Aug 29, 2015)
			}
			*end	
			
* clean
	* label variables
		lab var year "Year"
		lab var ctry "Country (WB)"		lab var ctrycode "Country Code (WB)"		lab var arvpct "Antiretroviral therapy coverage (% of people living with HIV)"		lab var chw_p1000 "Community health workers (per 1,000 people)"		lab var condomuse_f_pct "Condom use, population ages 15-24, female (% of females ages 15-24)"		lab var condomuse_m_pct "Condom use, population ages 15-24, male (% of females ages 15-24)"		lab var deathrate_p1000 "Death rate, crude (per 1,000 people)"		lab var eduprimary_pct "Primary completion rate, total (% of relevant age group)"		lab var gdp_pc "GDP per capita (constant 2005 US$)"		lab var healthexp_pc "Health expenditure per capita (current US$)"		lab var healthexp_pct "Health expenditure, total (% of GDP)"		lab var hivprev_pct "Prevalence of HIV, total (% of population ages 15-49)"		lab var lifeexp "Life expectancy at birth, total (years)"		lab var literacy_pct "Literacy rate, adult total (% of people ages 15 and above)"		lab var nursemidwives_p1000 "Nurses and midwives (per 1,000 people)"		lab var physicians_p1000 "Physicians (per 1,000 people)"		lab var pop "Population"
		
	* add yearly country classification (staring in 1988)
		gen yrlyinclvl = .
		replace yrlyinclvl = 1 if gni_pc < lowermid_l
		replace yrlyinclvl = 2 if gni_pc >= lowermid_l & gni_pc <= lowermid_u
		replace yrlyinclvl = 3 if gni_pc > lowermid_u & gni_pc <= uppermid_u
		replace yrlyinclvl = 4 if gni_pc > uppermid_u & gni_pc!=.
		replace yrlyinclvl=. if year<1988
		lab var yrlyinclvl "WB Annual Country Classification"
			lab def yrlyinclvl 1 "Lower income" 2 " Lower middle income" ///
				3 "Upper middle income" 4 "High income"
			lab val yrlyinclvl yrlyinclvl
		drop lowermid_l lowermid_u uppermid_u gni_pc
	
	* encode country name
		encode ctry, gen(ctryn) lab(ctry)
		drop ctry
		rename ctryn ctry
		order year ctry
		
	* reorder
		order year ctry ctrycode region yrlyinclvl chw_p1000 ///
			nursemidwives_p1000 physicians_p1000 arvpct condomuse_f_pct ///
			condomuse_m_pct hivprev_pct pop lifeexp deathrate_p1000 gdp_pc ///
			eduprimary_pct literacy_pct healthexp_pc healthexp_pct
	
	* set as panel data
		xtset ctry year
	
	*gen variables
		
		* create health worker "workforce" percent
			egen healthworkers_p1000 = rowtotal(chw_p1000 nursemidwives_p1000 physicians_p1000)
				lab var healthworkers_p1000 "Total health workers (per 1,000 people)"
			foreach t in chw nursemidwives physicians {
				gen `t'_pct = `t'_p1000/healthworkers_p1000*100
					local varlabel : var label `t'_p1000
					local newlabel : subinstr local varlabel " (per 1,000 people)" ", percent of total health workers", all
					lab var `t'_pct "`newlabel'
				}
				* end
				
	* save
		save "$output\healthworkers.dta", replace

********************************************************************************
********************************************************************************
	
** ANALYSIS **

use "$output\healthworkers.dta", clear

	* simple correlation between all variables
		pwcorr chw_p1000 nursemidwives_p1000 physicians_p1000 arvpct ///
			condomuse_f_pct condomuse_m_pct hivprev_pct deathrate_p1000 ///
			gdp_pc healthexp_pct lifeexp literacy_pct eduprimary_pct, star(.05)
			
	* GDP pc
		pwcorr gdp_pc chw_p1000 nursemidwives_p1000 physicians_p1000, star(.05)
		pwcorr gdp_pc chw_pct nursemidwives_pct physicians_pct, star(.05)
		
	* number of observations per year
		table year, c(n chw_p1000 n nursemidwives_p1000 n physicians_p1000)
	
	* avg distribution
	graph hbar (mean) chw_p1000 (mean) nursemidwives_p1000 ///
		(mean) physicians_p1000 if inlist(year, 2000, 2005, 2010), ///
		over(year, label(labsize(small))) over(region, label(labsize(small))) percentages stack /// 
		title ("Distribution of Health Workers") sub("Regional Mean") ///
		legend(order(1 "CHW" 2 "Nurses/Midwives" 3 "Physicians") rows(1) size(small))
		graph export "$graph/reghworkerdist.pdf", replace
	* health worker trends over time
		preserve
		*save value labels
			foreach v of var * {
				local l`v' : variable label `v'
									if `"`l`v''"' == "" {
					local l`v' "`v'"
				}
			}
			*end
		collapse (mean) chw_p1000 nursemidwives_p1000 physicians_p1000, by(region year)
		*re-attach variable labels
			foreach v of var * {
    	    label var `v' "`l`v''"
			}
			*end
		sort region year
		foreach t in chw nursemidwives physicians {
			local title : var label `t'_p1000
			twoway line `t' year, by(, title(`title')) by(region)
			graph export "$graph/`t'.pdf", replace
			}
		restore
	
	*correlation - health workers and health outcomes
		foreach t in chw nursemidwives physicians {
			pwcorr `t'_p1000 arvpct condomuse_f_pct condomuse_m_pct ///
				hivprev_pct lifeexp deathrate_p1000, star(.05) obs
			}
			*end
	local count = 1
	foreach x in chw nursemidwives physicians {
		foreach y in arvpct condomuse_f_pct condomuse_m_pct hivprev_pct lifeexp deathrate_p1000 {	
			di "graph: `x' and `y'"
			scatter `y' `x'_p1000, ///
				name(`x'`count',replace) nodraw
			local count = `count' + 1
			}
		local title : var label `x'_p1000
		graph combine `x'1 `x'2 `x'3 `x'4 `x'5 `x'6, title(`title')
		local count = 1
		}
		*end
		
*relative growth  
	*save value labels
		foreach v of var * {
			local l`v' : variable label `v'
				if `"`l`v''"' == "" {
					local l`v' "`v'"
				}
			}
			*end 
	collapse (mean) *_p1000 hivprev_pct arvpct condomuse_f_pct condomuse_m_pct gdp_pc, by(year)
	*re-attach variable labels
		foreach v of var * {
    	    label var `v' "`l`v''"
		}
		*end
	keep if year>=2000 & year<=2013
	*create rates
	ds year arvpct, not
	foreach v of varlist `r(varlist)' {
		gen ln_`v' = ln(`v')
		qui: sum ln_`v' if year==2000
			local baseval = `r(max)' 
		gen baseval`v' = `baseval'
		gen rate_`v'= ln_`v'*ln(ln_`v'/baseval`v')*100
			local label : var label `v'
			lab var rate_`v' "`label': change relative to 2000"
		drop ln_`v' baseval`v'
		}
		*end
		
	twoway line rate_chw_p1000 rate_nursemidwives_p1000 rate_physicians_p1000 year
	
	foreach v in chw nursemidwives physicians {
		local varlabel : var label `v'_p1000
		local newlabel : subinstr local varlabel " (per 1,000 people)" "", all
		twoway line rate_`v'_p1000 rate_hivprev_pct rate_condomuse_f_pct ///
			rate_condomuse_m_pct rate_gdp_pc year, ///
			legend(order(1 "`newlabel'" 2 "HIV Prevelance" 3 "Female Condom Use" ///
			4 "Male Condom Use" 5 "GDP") size(small)) ///
			title("Change relative to 2000") sub(`newlabel') ytitle("Percent")
			graph export "$graph/rate_`newlabel'.pdf", replace
		}
		*end
		
	
