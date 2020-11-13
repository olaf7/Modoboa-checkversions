#Modoboa versionchecker

## Why
As a systemadministrator on Linux you probably are very comfortable with a terminal; it helps you to quickly get things done. A fast check from your favorite environment to see if everything is still up to date is convenient, starting a new webbrowser session, including login, not always.

##Added benefits
The script can be scripted itself and or easily extended with new and extra functionality. Originally I had in mind to add these features as well:

### Possible feature: TUI
Why not make things more user friendly and make the script usable in two ways: provide a classic command line interface as well as a Text User Interface (TUI).

### Possible feature: package management
This script could be turned into a enabled/disable and/or install/uninstall script and obviously an update script.
However this has some serious drawbacks at the moment:
* not all installs / updates just need the same 3 commands to be executed. Sometimes additions actions need to be performed on **settings.py** for instance.
* enable/disable can therefor also include more than just adding or removing a hash (#) in front of a Modoboda App.
* when calling manage.py all output, including errors and warnings, need to be properly parsed and managed.

# Installation
Just copy the script into the virtual environment into which Modoboa is installed. and make sure its dependencies are met by pip installling (if not yet available):
* pprint (optional)
* logging
* sys
* pkg_resources
* requests
* re