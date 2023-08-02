# Scripts
Scripts for personal tasks automation

* TSBTRFS: Timeshift mode change automation (from BTRFS to RSYNC and back).

---

## TSBTRFS
Timeshift offers two options of backups for BTRFS systems. The first
option is the RSYNC mode, wich takes time, but allows the backup to be
stored in any available partition. The other one is the BTRFS mode, wich
takes fast snapshots, also automatically -- when the system packages are
updated -- but, only allowing to store these snapshots in the system root
partition.

Thinking about this and trying to use both features in an easy way, this script
automates the transition between BTRFS and RSYNC modes, allowing to have both
types of backups, so as to make it possible to take snapshots to an external
drive, for example, and keep monitoring the system updates, so then, the fast
BTRFS snapshots can be taken.
