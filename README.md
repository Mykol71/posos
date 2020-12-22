posos
-----

Development Rquirements -
-------------------------
- Store mirrors of all dependancies locally (Repos), and work from those mirrors. In the event a dependancy becomes unavailable, remove the external check during the install. (These will become action items to remedy for this app.)
- Keep "functions" of this app in individual bash scripts. (To simplfy CLI, API, and Web support.)
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
