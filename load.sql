-- load.sql
USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS AI_HANDSON_GIT_DB;
CREATE SCHEMA IF NOT EXISTS AI_HANDSON_GIT_DB.GIT;
USE SCHEMA AI_HANDSON_GIT_DB.GIT;

CREATE OR REPLACE API INTEGRATION ai_handson_git_integration
    API_PROVIDER         = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/hilasnow/snowflake_ai_handson_20260924/')
    ENABLED              = TRUE;

CREATE OR REPLACE GIT REPOSITORY ai_handson_git_repo
    API_INTEGRATION = ai_handson_git_integration
    ORIGIN           = 'https://github.com/hilasnow/snowflake_ai_handson_20260924.git';

ALTER GIT REPOSITORY ai_handson_git_repo FETCH;

EXECUTE IMMEDIATE FROM @ai_handson_git_repo/branches/main/setup.sql;
