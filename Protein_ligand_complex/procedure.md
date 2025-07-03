# GROMACS Molecular Dynamics Protocols

A comprehensive step-by-step guide for performing molecular dynamics simulations using GROMACS, specifically designed for protein-ligand complex studies.

## Overview

This protocol covers the complete workflow from initial system preparation to final analysis, including ligand parameterization, system setup, equilibration, and production runs with subsequent analysis.

## Prerequisites

- GROMACS installation
- UCSF Chimera
- Access to SwissParam web service
- Basic understanding of molecular dynamics concepts

## Step 1: System Preparation in Chimera

### 1.1 Ligand Preparation
1. Open the best pose ligand with the receptor protein PDB file in Chimera
2. Delete the protein chain, keeping only the ligand
3. Add hydrogens to the ligand
4. Save the ligand as `LIG.mol2`

### 1.2 Ligand File Corrections
Edit the `LIG.mol2` file to ensure proper formatting:

1. **First line check**: Ensure `@<TRIPOS>MOLECULE` is the first line
   - Delete any headers or empty spaces if necessary

2. **Molecule name**: After `@<TRIPOS>MOLECULE`, change the molecule name to `LIG`

3. **Bond order arrangement**: Use the following script to properly arrange bond orders:
   ```bash
   perl sort_mol2_bonds.pl LIG.mol2 LIG.mol2
   ```

### 1.3 Ligand Parameterization
1. Upload `LIG.mol2` to [SwissParam](http://www.swissparam.ch/)
2. Download the generated ZIP folder containing force field parameters

### 1.4 Receptor Preparation
1. Open the best pose ligand with receptor PDB file in Chimera
2. Delete the ligand molecule
3. Perform DockPrep on the protein
4. Save as `REC.pdb`

### 1.5 Working Directory Setup
1. Create a working folder for GROMACS
2. Copy contents of the SwissParam ZIP file into this folder
3. Copy the DockPrep `REC.pdb` file into the working folder
4. Copy all required `.mdp` files into the working folder

## Step 2: GROMACS Setup

### 2.1 Environment Setup
```bash
# Source GROMACS (if manually compiled)
source /usr/local/gromacs/bin/GMXRC
```

### 2.2 Topology Generation
```bash
# Generate topology for receptor
gmx pdb2gmx -f REC.pdb -ignh
# Select: 8 (CHARMM27)
# Select: 1 (TIP3P)

# Convert ligand to GROMACS format
gmx editconf -f LIG.pdb -o LIG.gro
```

### 2.3 System Assembly
```bash
# Edit configuration files
gedit conf.gro LIG.gro
```

**Manual editing steps:**
- Copy content from 3rd line of `LIG.gro` to `conf.gro` up to the 2nd last line
- Check the column number where LIG.gro data ends (x) in conf.gro
- Replace the value in 2nd line by x-3
- Verify the system in Chimera

## Step 3: Topology File Modifications

### 3.1 Edit topol.top
```bash
gedit topol.top
```

Add the following after the forcefield parameters section:
```
; Include ligand topology 
#include "LIG.itp"
```

At the bottom of the file, add:
```
LIG                 1
```
(Align exactly below the existing protein entry)

### 3.2 Edit lig.itp
```bash
gedit lig.itp
```

Change the moleculetype section from:
```
[ moleculetype ]
; Name nrexcl
lig_gmx2 3
```
to:
```
[ moleculetype ]
; Name nrexcl
LIG 3
```

## Step 4: System Solvation and Ionization

### 4.1 Create Simulation Box
```bash
gmx editconf -f conf.gro -d 1.0 -bt triclinic -o box.gro
```

### 4.2 Add Solvent
```bash
gmx solvate -cp box.gro -cs spc216.gro -p topol.top -o box_sol.gro
```

### 4.3 Add Ions
```bash
# Prepare for ion addition
gmx grompp -f ions.mdp -c box_sol.gro -p topol.top -o ION.tpr
# OR (if warnings occur)
gmx grompp -f ions.mdp -c box_sol.gro -maxwarn 2 -p topol.top -o ION.tpr

# Add ions
gmx genion -s ION.tpr -p topol.top -conc 0.1 -neutral -o box_sol_ion.gro
# Select: 15 (SOL)
```

## Step 5: Energy Minimization

```bash
gmx grompp -f EM.mdp -c box_sol_ion.gro -p topol.top -o EM.tpr
# OR (if warnings occur)
gmx grompp -f EM.mdp -c box_sol_ion.gro -maxwarn 2 -p topol.top -o EM.tpr

gmx mdrun -v -deffnm EM
```

## Step 6: Position Restraints Setup

### 6.1 Create Ligand Index
```bash
gmx make_ndx -f LIG.gro -o index_LIG.ndx
```
Commands in make_ndx:
```
> 0 & ! a H*
> q
```

### 6.2 Generate Ligand Position Restraints
```bash
gmx genrestr -f LIG.gro -n index_LIG.ndx -o posre_LIG.itp -fc 1000 1000 1000
# Select group "3"
```

### 6.3 Update Topology
Edit `topol.top` and add after the existing position restraint section:
```
; Ligand position restraints
#ifdef POSRES
#include "posre_LIG.itp"
#endif
```

### 6.4 Create System Index
```bash
gmx make_ndx -f EM.gro -o index.ndx
```
Commands in make_ndx:
```
> 1 | 13
> q
```

## Step 7: Equilibration

### 7.1 NVT Equilibration
```bash
gmx grompp -f NVT.mdp -c EM.gro -r EM.gro -p topol.top -n index.ndx -maxwarn 2 -o NVT.tpr
gmx mdrun -deffnm NVT
```

### 7.2 NPT Equilibration
```bash
gmx grompp -f NPT.mdp -c NVT.gro -r NVT.gro -p topol.top -n index.ndx -maxwarn 2 -o NPT.tpr
gmx mdrun -deffnm NPT
```

## Step 8: Production Run

```bash
# Modify MD.mdp to set desired simulation time
gedit MD.mdp

gmx grompp -f MD.mdp -c NPT.gro -t NPT.cpt -p topol.top -n index.ndx -maxwarn 2 -o MD.tpr
gmx mdrun -v -deffnm MD
```

## Step 9: Trajectory Post-Processing

### 9.1 Recentering and Rewrapping
```bash
gmx trjconv -s MD.tpr -f MD.xtc -o MD_center.xtc -center -pbc mol -ur compact
# Choose "Protein" for centering and "System" for output
```

### 9.2 Extract First Frame
```bash
gmx trjconv -s MD.tpr -f MD_center.xtc -o start.pdb -dump 0
```

## Step 10: Analysis

### 10.1 RMSD Calculations
```bash
gmx rms -s MD.tpr -f MD_center.xtc -o rmsd.xvg -tu ns
# Select: 4 (Backbone)
# Select: 13 (LIG)

# Visualize results
xmgrace rmsd.xvg
```

### 10.2 RMSF Calculations
```bash
gmx rmsf -s MD.tpr -f MD_center.xtc -o rmsf.xvg
# Select: 4 (Backbone)

# Visualize results
xmgrace rmsf.xvg
```

### 10.3 Hydrogen Bond Analysis
```bash
gmx hbond -s MD.tpr -f MD_center.xtc -num hb.xvg -tu ns
# Select: 1 (Protein)
# Select: 13 (LIG)

# Visualize results
xmgrace hb.xvg
```

### 10.4 Radius of Gyration
```bash
gmx gyrate -s MD.tpr -f MD_center.xtc -o gyrate1.xvg
# Choose the group of your choice

# Visualize results
xmgrace gyrate1.xvg
```

### 10.5 Energy Analysis
```bash
gmx energy -f MD.edr -o energy1.xvg
# Choose the option of your choice

# Visualize results
xmgrace -nxy energy1.xvg
```

## Notes

- Always verify system integrity using molecular visualization tools
- Adjust simulation parameters in MDP files according to your specific system requirements
- Monitor convergence during equilibration phases
- Consider extending simulation time for better sampling if needed
- Use appropriate force field parameters for your specific system

## Troubleshooting

- If you encounter warnings during `gmx grompp`, use the `-maxwarn 2` flag
- Ensure all file paths and names are correct
- Check that all required files are in the working directory
- Verify that the ligand topology is correctly integrated with the protein topology