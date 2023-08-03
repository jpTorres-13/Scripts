# TSBTRFS
Script for manage Timeshift RSYNC backups in BTRFS systems.

---
## Description
TSBTRFS is an automation script thought to provide an easy Timeshift mode
changing from RSYNC to the BTRFS mode setted in a BTRFS system. The tool works
by **setting up the RSYNC mode** exclusively to **take a RSYNC snapshot** and
**store it in a desired partition** and to **delete the taken RSYNC snapshots**
when required.

**After finishing the RSYNC requested tasks**, the tool **sets back the BTRFS**
**mode**, so that the BTRFS features, such as the automatic quick sbapshots,
can be used normally.

---
## Features

* ### v1.0.0
    * Take RSYNC backups
    * Clear excedent RSYNC backups
    * Logging monitoring