# zfs-filsystem based Arch-linux installaion (work-in-progress)

Still work in progress..

# Make ISO on windows with ArchLinux with WSL2

I have tried using the windows features **wsl2** to install archlinux (which you can find in the windows store) and it works to use to make the iso. In order to be able to use wsl2, if you haven't already done this, press the windows + x (or search for run) and choose run, and then write optionalFeatures and check the box for **Windows Subsystem for Linux** and reboot. I would recommend using the newest terminal for windows, e.g., windows terminal preview on windows store, and powershell 7 preview. Open powershell and write `wsl --update` and set wsl default version as 2 if you haven't already, e.g., `wsl --set-default-version 2`. After setting up arch, you should be able to make the ISO.


# Why do this?

Again, since zfs is neither officially supported by arch nor available as a filesystem 
available on the officially supported images of any linux distribution!
Although a few projects currently exist using zfs OS architectureand and actively
developed, it is not publicallly avaiable as the os on computers.
Therefore, arch wiki or guides to do certain sections may not be applicable,
despite the vastness of the arch wiki. 

So why this sacrifise? remember, the goal is to get the zfs-filesystem, 
which is, like linux, based on unix. Therefore, the outcome is to get the
zfs OS architecture and its great and attractive features, and since we 
install it on arch, you will additionally get access to great features such
as the AUR as a bonus. This comeas at the cost of not always having
the answer readily available at your fingertios. Although zfs was relased 
in 2005 as the OS system on computers available to the public and was
upported as OpenSolaris, active development stopped in 2010 after Oracle 
acquired it, so the zfs-filesystem hasn't been a part of any 
officially supported project available for the public for over a decade. 

However, active development has never stopped since 2010, and and is being 
used by Oracle and officially in the sense that the zfs-filesystem architecture 
but it is nevertheless not available as the os on computers officially. In fact, 
the original codebase began in the early 1980's and was released by 
Sun Microsystems as operating system on computers for the first time in 1991. So, 
the zfs-filesystem has been actively developed for around 42 years and despite early
development starting only a few years after Windows was founded, and is being praised 
for being extremely well developed, which is hardly surprising for a file-system that
has been under development, in some form or another, for around 40 years.

so why else go through all this to get a zfs OS archistechture on Arch linux?
As just mentioned, zfs is extremely well developed and has 40 years of work behind it.
Remember, if you have several hard-disks you can get substantialt performance increase in
disc I/O speed, i.e., faster disc read and write operations, and faster data
transfer between the physical hard-drives and RAM. Even if you only have one hard-drive, 
you can still enjoy zfs and its many other features.

# Script automating building the ISO

I have made a script to automate building the arch zfs .iso file. To use  the script, you need to first to give it permission to execute, read and write, i.e., you need to first write `sudo chmod u+rwx nfs_ISO_build_guide.sh` or just `sudo chmod +rwx nfs_ISO_build_guide.sh`. The script needs you to use sudo and needs you password to work. If you are uncomfortable about that, you can just check the script. Alternatively, you can execute the commands youself, but a part of the script executes a nested python script that checks the latest zfs update, and then feeds the information to bash or zsh (or whatever you are using, just don't use fish as your terminal shell) to update the pacman.conf file in order to change the repos so that they align. Otherwise, you may experience issued with incompatible linux kernels with respect to zfs. The script changes the pacman.conf so that packages from the arch archive from the same date the latest zfs release was made are installed. So if you want to do it manually, I would suggest making a bash script that starts with the part that changes the /etc/pacman.conf permissions and ends with `echo "pacman.conf has been updated."`. It might still work even you ignore this part, but I have experienced problems where it doesn't because after the iso was made some new linux kernel has been released, thus the iso will not necessarily be stable over time.

If have included a script that changes pacman.conf so that the packages installed with match with the latest zfs release. Just change the variable as instructed in the script to point to the location of the pacman.conf you want changed.
