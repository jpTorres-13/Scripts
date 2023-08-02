# Scripts
Scripts for personal tasks automation

## TSBTRFS:
Installing Timeshift on a BTRFS system allows the user to use the fast BTRFS 
snapshots automatically after system updates, which is clearly an advantage. 
However, BTRFS snapshots can only be stored in the system root partition, not 
allowing backups to an external drive, for example. On the other hand, the user 
can opt for configure RSYNC mode, giving up BTRFS snapshots, but storing system 
backups on any partition.

Thinking about this problem, and trying to use both resources in an easy way, 
this script automates the transition between BTRFS and RSYNC modes, allowing to 
have both types of backups, not discarding backups stored in other partitions, 
nor post-upgrade quick backups.