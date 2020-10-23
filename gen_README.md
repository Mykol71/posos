mykos 1.0
---------

In the 1960's the push by .... for GNU opensource programming started to change the "cathedral" style development philosophy.

In the .... and with the creation of Linux, Linus Torvald revolutionized the way we get motivated development and testing support at minimal costs.

So, the open source concept has now twice inserted itself into big business and forced them to change their thinking a bit.

Next is virtualization, and then containers, with the ability to seperate smaller and smaller parts of a solution into a "cloud" service offering. (as well as track and charge for very small amounts of measure, like CPU cycles.)

I feel like one might make the argument that big business has just managed to only "cathedralize" architecture instead of development, because if you want to run a cloud service, you have to learn their language and how to talk to their backend, oh and also buy their service for it all to work. Oh and we will gladly sell you training on this complex solution to help you in the now dominated by us industry.

So not only have they managed to get their hooks back into development because they have programmers all making their code more cloud-friendly, but also now architecture. And now, they have the much faster method of opensource to add features to this cloud service provider. So, the bigger the company and investment, the faster they dominate the industry.

I asked our Windows Architect how he did something to handle that there is no persisted data with containers and he swore there was because he thought Microsoft's blob storage offering was using containers because they name (or use) "container" and a GUID as their ID for blob space. He didnt understand that they are merely using containers and some internal code to access their datastores, to produce the blob storage offering.

So where is the opensource, free, secure, development environment for the OS configuration and installation that has all the nice perks that virtualization brings?

TO DO
-----

- Genericize server deployment.
- create seperate volumes for each user in /home and /backups. (so can be preserved of host os upgrades.)
- Windows vms.
- Mac vms.
-- command line vm management.
--centos/rh minimal containers.
--ubuntu minimal containers.
--freebsd minimal containers.
- host-side rhel/centos8 support.
- package and repo info for rhel/centos8.
- replace tfrsync.pl with generic rsync commands, and/or filesystem snapshots.
- auto schedule backups to self of container?
- 
