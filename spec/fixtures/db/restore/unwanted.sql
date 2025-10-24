--
-- PostgreSQL database dump
--

-- Dumped from database version 12.2 (Debian 12.2-2.pgdg100+1)
-- Dumped by pg_dump version 12.2 (Debian 12.2-2.pgdg100+1)

-- Started on 2020-06-15 08:06:34 UTC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


    --
-- TOC entry 198 (class 1259 OID 16585)
-- Name: foo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.foo (
    id integer NOT NULL,
    topic_id integer,
    user_id integer
);


CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';

CREATE EXTENSION IF NOT EXISTS postgres_fdw WITH SCHEMA public;

COMMENT ON EXTENSION postgres_fdw IS 'foreign-data wrapper for remote PostgreSQL servers';

CREATE FUNCTION discourse_functions.raise_topic_status_updates_readonly() RETURNS trigger
  LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'Discourse: topic_status_updates is read only';
END
$$;


CREATE SERVER discourse_foo_fdw FOREIGN DATA WRAPPER postgres_fdw OPTIONS (
    dbname 'discourse_foo',
    host 'localhost',
    port '5432'
);

CREATE USER MAPPING FOR discourse SERVER discourse_foo_fdw OPTIONS (
    password '123',
    "user" 'discourse'
);

CREATE FOREIGN TABLE public.foo_sso_records (
    external_id character varying,
    external_email character varying
)
SERVER discourse_foo_fdw
OPTIONS (
    schema_name 'public',
    table_name 'single_sign_on_records'
);
