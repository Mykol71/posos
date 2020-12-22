posos
-----

Babble -
--------
Aaas/EAaas do not exist yet. Why? Because architects are too busy handling the work load from all the new tools and services there are to; virtualize, standardize, configure, compile, deploy, network, protect, comply with, support, access, train, ... you see my point.

With virtualization and cloud, big business has latched on and is providing and developing new and quicker ways to do each of the individual architectual reposibilities at a very rapid pace. And, of course, these businesses will happily sell you training and/or certification in using those tools, feeding their bottom line with hungry to be accepted up-coming admins that desperately want those jobs with the companies that have those awesome new tools the soonest. So, now they can dictate the resourceneeds as well, at also a staggerling faster rate.

....





Development Rquirements -
-------------------------
- Store mirrors of all dependancies locally (Repos), and work from those mirrors. In the event a dependancy becomes unavailable, remove the external check during the install. (These will become action items to remedy for this app.)
- Keep "functions" of this app in individual bash scripts. (To simplfy CLI, API, Voice, and Web support.)
- "Public facing" documentation is stored in the docs folder for each application.
- Internal documentation is in the README in the applications root folder. (Example root folder: ~/posos/msposapp)
-  

TO DO -
-------

- github CLI auth changes.
- mash code.
- add podman suport for host-side RH/CentOS8.
- local repo for RH/CentOS8.
X make package/repo changes for RH8/CentOS8.
X fix backup scripts for account name.
X create isos repo
- admin maintenance menu
- patch method for these menus.
0 shellinabox config.
- Build RTI QA example for management.
X Test install on physical hardware. (It should not matter if it is an AWS instance or not.)
- logging and error capturing.
X create ostools subrepo.
- Seperate server installation routines by app.
- Prepare for use during an OS migration.
- Setup ostools documentation.
-    
