#!/usr/bin/env python3

import pprint
import logging
import sys
import pkg_resources
import requests
import re

'''
    console-based Modoboa version checker
    Author  : Olaf Zevenboom
    License : ISC (same license as Modoboa to keep things simple)
    Version : 0.6
'''

'''
  TODO
  - make code more pythonic
  - comply with pep8 etc
  - more thorough testing
  - promote tool
  - consider adding a tui
'''


'''
    configuration of Modoboa-Django configuration file
    should be ok when this script is executed from within the same venv
'''
modoboa_settings_file = sys.prefix + "/" + "instance/instance/settings.py"

'''
    regular expressions
'''
regex_api = r"^MODOBOA_API_URL[=\s]+['\"](.+)['\"]"
regex_apps = r"^MODOBOA_APPS\s*=\s*\(([^)]+)"
regex_enabled = r"^[^#](\s+'modoboa_)([^']+)"
regex_disabled = r"^\s*[#](\s+'modoboa_)([^']+)"

'''
    configuration of logging
'''
# note: __file__ is not always present, but quite likely in our case
#       https://stackoverflow.com/questions/606561/how-to-get-filename-of-the-main-module-in-python
filelogger = True
stdiologger = True
scriptname = 'modoboa_version_checker'
#scriptname = __name__.__file__
loglevel = logging.DEBUG
logger = logging.getLogger(scriptname)
logger.setLevel(loglevel)  # general debug level  ---> link to verbose argument
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
# Create console logger
if stdiologger:
    logh = logging.StreamHandler()
    logh.setLevel(loglevel)
    logh.setFormatter(formatter)
    logger.addHandler(logh)
# Create file logger
if filelogger:
    logh = logging.FileHandler(scriptname + ".log", "w",
                               encoding=None, delay="true")
    logh.setLevel(loglevel)
    logh.setFormatter(formatter)
    logger.addHandler(logh)


def get_modoboa_api_url_from_file(settingsfile):
    """Retrieve API URL from Django configuration file.

    Parameters
    ----------
    settingsfile : string
        Full path and filename of configuration file.

    Returns
    -------
    string
        Return the URL
        Or None if not found

    """
    try:
        fh = open(settingsfile, "rt")
        sf = fh.read()
        fh.close()
    except IOError:
        print("Issues with opening file: %s" % settingsfile)
        exit(1)
    mua = re.search(regex_api, sf, re.MULTILINE)
    if mua:
        mua = mua.group(1)
    return mua


def get_modoboa_apps_from_file(settingsfile, regex):
    """Get list of Modoboa apps as defined in the confifuration file.

    Parameters
    ----------
    settingsfile : string
        Description of parameter `settingsfile`.
    regex : string
        Description of parameter `regex`.

    Returns
    -------
    list
        List of Modoboa apps that are defined in the configuration file.

    """
    logger.debug("Getting listed apps from " + settingsfile + " using regex: " + regex)
    try:
        fh = open(settingsfile, "rt")
        sf = fh.read()
        fh.close()
    except IOError:
        print("Issues with opening file: %s" % settingsfile)
        exit(1)
    # now build a list of Modoboa extensions
    logger.debug(sf)
    modoboa_apps = []
    msa = re.search(regex_apps, sf, re.MULTILINE)
    if msa:
        msa = msa.group(0)
        print("modoboa apps found in %s" % settingsfile)
        logger.debug(msa)
        for fullitem in re.finditer(regex, msa, re.MULTILINE):
            item = fullitem.group(2).strip()
            logger.debug(item)
            if (item[1] != "#"):
                modoboa_apps.append(item)
    return modoboa_apps


def get_modoboa_apps_from_apiserver(apiurl):
    """Get a list from the API server on the internet of all Modoboa Apps.

    Parameters
    ----------
    apiurl : string
        URI of API server.

    Returns
    -------
    list
        List of Modoboa Apps or None if none found.

    """
    apiurl = apiurl.rstrip('/') + "/versions/"
    cr = requests.get(apiurl)
    sc = cr.status_code
    cc = None
    if (sc == 200):
        cc = cr.json()
    else:
        logger.info("Could not retrieve information from : " + apiurl)
        logger.info("Received from API server HTTP status code : " + str(sc))
    return cc


def get_upgradable_packagelist():
    """Get list of Modoboa apps which have a newer version available.

    Returns
    -------
    list
        List of Modoboa Apps with never versions available.
        Or an empty list if none available.

    """
    upgradable = []  # None
    for app in modoboa_apps:
        current_version = modoboa_app_get_current_version(app)
        latest_version = modoboa_app_get_last_version(modoboa_apps_data, app)
        if current_version:
            if current_version < latest_version:
                upgradable.append(app)
    return upgradable


def get_installable_packagelist():
    """Get Modoboa Apps that are not installed yet.

    Returns
    -------
    list
        List of not yet installed Modoboa Apps.
        Empty list if all apps are already installed.

    """
    installable = []  # None
    for app in modoboa_apps:
        current_version = modoboa_app_get_current_version(app)
        #latest_version = modoboa_app_get_last_version(modoboa_apps_data, app)
        if not current_version:
            installable.append(app)
    return installable


def get_disabled_packagelist():
    """Get a list of commenteed out Modoboa Apps.

    Returns
    -------
    list
        List of disabled Modoboa Apps.
        Returns an empty list of no apps are disabled.

    """
    disabled = []  # None
    for app in modoapps_disabled:
        disabled.append(app)
    return disabled


def modoboa_app_get_url(rawdata, appname):
    """Get the URL of a Modoboa App.
       Probably hosted on GitHub.

    Parameters
    ----------
    rawdata : raw data
        Raw data as retrieved from the API server. Probably in JSON format.
    appname : string
        Name of the app of which we want to retrieve the URL of.

    Returns
    -------
    string
        URI of the app.

    """
    # if (rawdata == None):
    #   return None
    # logger.debug(rawdata)
    url = None
    for item in rawdata:
        en = item["name"]
        #ev = item["version"]
        eu = item["url"]
        if (en == appname):
            url = eu
            break
    return url


def modoboa_app_get_last_version(rawdata, appname):
    """Get most recent version availble of a Modoboa Apps
       as availble on the internet.

    Parameters
    ----------
    rawdata : rawdata
        Rawdata as retrieved from the API server. Probably in JSON format.
    appname : string
        Name of the Modoboa App we want to query.

    Returns
    -------
    string
        Modoboa App version or None if not found.

    """
    # if (rawdata == None):
    #   return None
    ver = None
    for item in rawdata:
        en = item["name"]
        ev = item["version"]
        #eu = item["url"]
        if (en == appname):
            ver = ev
            break
    return ver


def modoboa_app_get_current_version(appname):
    """
            Get currently installed version of a Modoboa component
                uses pkg_resources to query installed packages

    Parameters
    ----------
    appname : string
        Name of Modoboa component

    Returns
    -------
    pkg.version
        Versionstring of installed package or None if not installed
    """
    try:
        pkg = pkg_resources.get_distribution(appname)
    except pkg_resources.DistributionNotFound:
        pkg = None
        logger.info("Component " + appname + " is not installed.")
    pkg_version = None
    if pkg:
        pkg_version = pkg.version
    return pkg_version


def modoboa_app_get_all(rawdata):
    """Get sorted list of Modoboa Apps from raw data

    Parameters
    ----------
    rawdata : rawdata
        Raw data as retrieved from the API server.

    Returns
    -------
    list
        List of named of Modoboa Apps.

    """
    modoapps = []
    for item in rawdata:
        en = item["name"]
        ev = item["version"]
        eu = item["url"]
        modoapps.append(en)
    modoapps.sort()
    return modoapps


modoboa_api_url = get_modoboa_api_url_from_file(modoboa_settings_file)
modoapps_installed = get_modoboa_apps_from_file(modoboa_settings_file, regex_enabled)
modoapps_disabled = get_modoboa_apps_from_file(modoboa_settings_file, regex_disabled)

modoboa_apps_data = get_modoboa_apps_from_apiserver(modoboa_api_url)
modoboa_apps = modoboa_app_get_all(modoboa_apps_data)

'''
    now that we should have al info it is time to analyze and report
'''

# report
# pprint.pprint(modoboa_apps)
for app in modoboa_apps:
    current_version = modoboa_app_get_current_version(app)
    latest_version = modoboa_app_get_last_version(modoboa_apps_data, app)
    app_url = modoboa_app_get_url(modoboa_apps_data, app)
    status = "OK"
    if not current_version:
        current_version = "Not installed"
        status = "Installable"
    else:
        if current_version < latest_version:
            status = "Upgradable"
    print("Component : %s" % app)
    print("  Latest version available    : %s" % latest_version)
    print("  Currently installed version : %s" % current_version)
    print("  Status  : %s" % status)

print("List of upgradable components :")
pprint.pprint(get_upgradable_packagelist(), width=2)

print("List of optionally extra installable components :")
pprint.pprint(get_installable_packagelist(), width=2)

print("List of disabled components :")
pprint.pprint(get_disabled_packagelist(), width=2)
