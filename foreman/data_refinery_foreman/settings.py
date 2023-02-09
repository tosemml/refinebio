"""
Django settings for data_refinery_foreman project.

Generated by 'django-admin startproject' using Django 1.10.6.

For more information on this file, see
https://docs.djangoproject.com/en/1.10/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/1.10/ref/settings/
"""

import os
import sys

from data_refinery_common.utils import get_env_variable, get_env_variable_gracefully

# https://dev.to/rubyflewtoo/upgrading-to-django-3-2-and-fixing-defaultautofield-warnings-518n
DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/1.10/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = get_env_variable("DJANGO_SECRET_KEY")

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = get_env_variable("DJANGO_DEBUG") == "True"

ALLOWED_HOSTS = []


# Application definition

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.postgres",
    "data_refinery_common",
    "data_refinery_foreman.surveyor",
    "data_refinery_foreman.foreman",
    "raven.contrib.django.raven_compat",
    "computedfields",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "data_refinery_foreman.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "data_refinery_foreman.wsgi.application"


# Database
# https://docs.djangoproject.com/en/1.10/ref/settings/#databases

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql_psycopg2",
        "NAME": get_env_variable("DATABASE_NAME"),
        "USER": get_env_variable("DATABASE_USER"),
        "PASSWORD": get_env_variable("DATABASE_PASSWORD"),
        "HOST": get_env_variable("DATABASE_HOST"),
        "PORT": get_env_variable("DATABASE_PORT"),
        "OPTIONS": {"connect_timeout": get_env_variable("DATABASE_TIMEOUT")},
        "TEST": {
            # Our environment variables for test have a different
            # database name than the other envs so just use that
            # rather than letting Django munge it.
            "NAME": get_env_variable("DATABASE_NAME")
        },
    }
}


# Password validation
# https://docs.djangoproject.com/en/1.10/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]


# Internationalization
# https://docs.djangoproject.com/en/1.10/topics/i18n/

LANGUAGE_CODE = "en-us"

TIME_ZONE = "UTC"

USE_I18N = True

USE_L10N = True

USE_TZ = True


# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/1.10/howto/static-files/

STATIC_URL = "/static/"


# Caching
# https://docs.djangoproject.com/en/2.2/topics/cache/

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.db.DatabaseCache",
        "LOCATION": "cache_table",
    }
}


# Setting the RAVEN_CONFIG when RAVEN_DSN isn't set will cause the
# following warning:
# /usr/local/lib/python3.6/site-packages/raven/conf/remote.py:91:
# UserWarning: Transport selection via DSN is deprecated. You should
# explicitly pass the transport class to Client() instead.
RAVEN_DSN = get_env_variable_gracefully("RAVEN_DSN", None)

# AWS Secrets manager will not let us store an empty string.
if RAVEN_DSN == "None":
    RAVEN_DSN = None

if RAVEN_DSN:
    RAVEN_CONFIG = {"dsn": RAVEN_DSN}
else:
    # Preven raven from logging about how it's not configured...
    import logging

    raven_logger = logging.getLogger("raven.contrib.django.client.DjangoClient")
    raven_logger.setLevel(logging.CRITICAL)

RUNNING_IN_CLOUD = get_env_variable("RUNNING_IN_CLOUD") == "True"

MAX_JOBS_PER_NODE = int(get_env_variable("MAX_JOBS_PER_NODE"))
MAX_DOWNLOADER_JOBS_PER_NODE = int(get_env_variable("MAX_DOWNLOADER_JOBS_PER_NODE"))

# For testing purposes, sometimes we do not want to dispatch jobs unless specifically told to
AUTO_DISPATCH_BATCH_JOBS = get_env_variable_gracefully("AUTO_DISPATCH_BATCH_JOBS") != "False"

AWS_BATCH_QUEUE_WORKERS_NAMES = sorted(
    get_env_variable("REFINEBIO_JOB_QUEUE_WORKERS_NAMES").split(",")
)
AWS_BATCH_QUEUE_SMASHER_NAME = get_env_variable("REFINEBIO_JOB_QUEUE_SMASHER_NAME")
AWS_BATCH_QUEUE_COMPENDIA_NAME = get_env_variable("REFINEBIO_JOB_QUEUE_COMPENDIA_NAME")
AWS_BATCH_QUEUE_ALL_NAMES = sorted(get_env_variable("REFINEBIO_JOB_QUEUE_ALL_NAMES").split(","))
