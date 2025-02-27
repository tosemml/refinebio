import os
import re
from datetime import datetime

from setuptools import find_packages, setup

# allow setup.py to be run from any path
os.chdir(os.path.normpath(os.path.join(os.path.abspath(__file__), os.pardir)))

VERSION_FILE = "version"
try:
    with open(VERSION_FILE, "rt") as version_file:
        version_string = version_file.read().strip().split("-")[0]
except OSError:
    print(
        "Cannot read version file to determine system version. "
        "Please create a file common/version containing an up to date system version."
    )
    raise

version_re = re.compile(
    r"^([1-9][0-9]*!)?(0|[1-9][0-9]*)"
    "(\.(0|[1-9][0-9]*))*((a|b|rc)(0|[1-9][0-9]*))"
    "?(\.post(0|[1-9][0-9]*))?(\.dev(0|[1-9][0-9]*))?$"
)
if not version_re.match(version_string):
    # Generate version based on the datetime.now(): e.g., 2023.5.17.dev1684352560.
    now = datetime.now()
    version_string = f"{now.strftime('%Y.%-m.%-d.dev')}{int(datetime.timestamp(now))}"

setup(
    name="data-refinery-common",
    version=version_string,
    packages=find_packages(),
    include_package_data=True,
    # These values are based on what is in common/requirements.txt.
    install_requires=[
        "boto3>=1.9.16",
        "coverage>=4.5.1",
        "daiquiri>=1.5.0",
        "django>=3.2,<4",
        "raven>=6.9.0",
        "requests>=2.10.1",
        "retrying>=1.3.3",
        "psycopg2-binary>=2.7.5",
    ],
    license="BSD License",
    description="Common functionality to be shared between Data Refinery sub-projects.",
    url="https://www.greenelab.com",
    author="Kurt Wheeler",
    author_email="team@greenelab.com",
    classifiers=[
        "Environment :: Web Environment",
        "Framework :: Django",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: BSD License",
        "Operating System :: Ubuntu",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3.5",
        "Programming Language :: Python :: 3.6",
        "Topic :: Internet :: WWW/HTTP",
    ],
)
