# Replication code

Toto et al., "Formalizing community forests reduces deforestation by over one third in a Southeast Asian context of extreme commodity pressure"

## How to run

1. Download `Cleaned.dta` and `Cleaned_Period.dta` from Zenodo [DOI to be added] and put them in a folder called `input` inside this folder.
2. Open `00_master.do` and set `global root` to this folder.
3. Run `00_master.do` in Stata 18 or later. On the first run, set `install_packages` to 1.

The paper's tables and figures are saved in `output/Tables` and `output/Figures`, named as in the paper. `OUTPUTS.md` lists which do-file makes each one.
