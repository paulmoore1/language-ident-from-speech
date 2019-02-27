# Copying GlobalPhone

Use rsync. First, on DICE, copy from NFS (`/group/corpora/public/global_phone`) to home directory:
```bash
rsync -av --no-perms --omit-dir-times /afs/inf.ed.ac.uk/group/corpora/public/global_phone/Ukrainian/ ~/lid/global_phone/Ukrainian
```

Then, on cluster head node, copy from DICE home (AFS) to cluster node scratch disk:
```bash
rsync -av --no-perms --omit-dir-times /afs/inf.ed.ac.uk/user/s15/s1513472/lid/global_phone/Ukrainian/ /disk/scratch/lid/global_phone/Ukrainian
```