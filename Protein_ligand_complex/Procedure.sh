
#########STEPS FOR MD AS FOLLOWS######### 

---PREPARE LIGAND AND RECEPTOR IN CHIMERA----
1. open the best pose ligand with the receptor Protein.pdb file
2. Delete the chain of protein, in the residual ligand, add hydrogens and save it as LIG.mol2 as 'LIG.mol2'

#Open the LIG.mol2 file and in the second line 
#Correction to be made in LIG.mol2 
#Open LIG.mol2 by using gedit command or simplyopening file in any text editor.
2.1.	"@<TRIPOS>MOLECULE" make sure this is the first line in file
	delete the header and empty space if you have to
	
2.2.      "@<TRIPOS>MOLECULE” there will be name after this line maybe xxx.pdb or ****** or anything else
	change it to LIG 
	
2.3.	bond orders "@<TRIPOS>BOND" will be arranged differently in each file 
arrange them in specific order to avoid errors use 
perl sort_mol2_bonds.pl LIG.mol2 LIG.mol2 script

3. Go to SwissParam "http://www.swissparam.ch/" and upload the 'Lig.mol2 file'
4. Download the .zip folder
5. Again open the best pose ligand with the receptor .pdb file, delete ligand, Perform DockPrep of protein as save it as .pdb file as 'REC.pdb'
6. Make a working Folder for Gromacs, copy contents of the downloaded zip file into this folder, copy the DockPrep 'rec.pdb' in to working folder
7. Copy all the .mdp files into this working folder
8. Open the terminal in this working folder and proceed with Gromacs.  

---------GROMACS UBUNTU TUTORIAL-----------
source /usr/local/gromacs/bin/GMXRC	(If Gromacs is manually compiled / not for dirty install)  

gmx pdb2gmx -f REC.pdb -ignh
8 (CHARMM27)
1 (TIP3P)
gmx editconf -f LIG.pdb -o LIG.gro
gedit conf.gro LIG.gro
*(Copy content from 3rd line of lig.gro to the conf.gro file up to the 2nd last line)
*(Check the column number from where the lig.gro data ends (x) in conf.gro and replace the value in 2nd line by x-3)
*(Open file in chimera to check ligand and receptor)

-----EDIT THE FOLLOWING in topol.top -----
gedit topol.top
(add 

; Include ligand topology 
#include "LIG.itp"

below- Include forcefield parameters
#include "amberGS.ff/forcefield.itp")

AT THE BOTTOM OF THE SAME FILE PERFORM FOLLOWING CHANGES
(add LIG 1
align exactly below-
Protein_chain_E     1)

-----EDIT THE FOLLOWING in lig.itp -----

gedit lig.itp
[ moleculetype ]
; Name nrexcl
lig_gmx2 3
TO
[ moleculetype ]
; Name nrexcl
LIG 3
(in certain cases this will already be LIG 3 so for such case no change is needed)

----------

gmx editconf -f conf.gro -d 1.0 -bt triclinic -o box.gro

gmx solvate -cp box.gro -cs spc216.gro -p topol.top -o box_sol.gro

gmx grompp -f ions.mdp -c box_sol.gro -p topol.top -o ION.tpr      
(OR)
gmx grompp -f ions.mdp -c box_sol.gro -maxwarn 2 -p topol.top -o ION.tpr


gmx genion -s ION.tpr -p topol.top -conc 0.1 -neutral -o box_sol_ion.gro
15

gmx grompp -f EM.mdp -c box_sol_ion.gro -p topol.top -o EM.tpr     (OR)
gmx grompp -f EM.mdp -c box_sol_ion.gro -maxwarn 2 -p topol.top -o EM.tpr

gmx mdrun -v -deffnm EM

gedit nvt.mdp (This file is already modified)

Now make index files
 
gmx make_ndx -f LIG.gro -o index_LIG.ndx
	 > 0 & ! a H*
 	 > q

gmx genrestr -f LIG.gro -n index_LIG.ndx -o posre_LIG.itp -fc 1000 1000 1000
	> select group "3"
	
Now, open topol.top file

	at the end of the document 

	after 
		"; Include Position restraint file
		#ifdef POSRES
		#include "posre.itp"
		#endif

		"Here"

	add this 

		; Ligand position restraints
		#ifdef POSRES
		#include "posre_LIG.itp"
		#endif

Again, Make other Index file for System 

gmx make_ndx -f EM.gro -o index.ndx
	
	> 1 | 13
	> q
	
-----[NVT]-----
gedit NVT.mdp (This file is already modified)

gmx grompp -f NVT.mdp -c EM.gro -r EM.gro -p topol.top -n index.ndx -maxwarn 2 -o NVT.tpr
	
gmx mdrun -deffnm NVT


-----[NPT]-----
gedit NPT.mdp (This file is already modified)

gmx grompp -f NPT.mdp -c NVT.gro -r NVT.gro -p topol.top -n index.ndx -maxwarn 2 -o NPT.tpr
	
gmx mdrun -deffnm NPT

-----[FINAL MD RUN/PRODUCTION]-----
gedit NPT.mdp (Change MD RUN TIME as per your need)

gmx grompp -f MD.mdp -c NPT.gro -t NPT.cpt -p topol.top -n index.ndx -maxwarn 2 -o MD.tpr

gmx mdrun -v -deffnm MD


----[Recentering and Rewrapping Coordinates]----
gmx trjconv -s MD.tpr -f MD.xtc -o MD_center.xtc -center -pbc mol -ur compact
#Choose "Protein" for centering and "System" for output.

#To extract the first frame (t = 0 ns) of the trajectory, use trjconv -dump with the recentered trajectory:
gmx trjconv -s MD.tpr -f MD_center.xtc -o start.pdb -dump 0


------RMSD Calculations-----
gmx rms -s MD.tpr -f MD_center.xtc -o rmsd.xvg
gmx rms -s MD.tpr -f MD_center.xtc -o rmsd.xvg -tu ns
4
13


#(Select appropritate 2 options one by one and then open the output files in Grace) Select Backbone and then LIG

xmgrace rmsd.xvg

------RMSF Calculations-----
gmx rmsf -s MD.tpr -f MD_center.xtc -o rmsf.xvg
4

(Select appropritate Backbone open the output files in Grace)

xmgrace output.xvg

-----------h-bonds-------------------
gmx hbond -s MD.tpr -f MD_center.xtc -num hb.xvg
gmx hbond -s MD.tpr -f MD_center.xtc -num hb.xvg -tu ns
1
13
xmgrace hb.xvg

--------------Gyration Radius------------------
gmx gyrate -s MD.tpr -f MD_center.xtc -o gyrate1.xvg
#Choose the group of your choice 
xmgrace gyrate1.xvg

-------------ENERGY Calculations---------------
gmx energy -f MD.edr -o energy1.xvg
#Choose the option of your choice
xmgrace -nxy energy1.xvg

