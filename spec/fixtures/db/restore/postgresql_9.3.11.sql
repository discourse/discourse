--
-- PostgreSQL database dump
--

-- Dumped from database version 9.3.11
-- Dumped by pg_dump version 9.3.11
-- Started on 2019-12-27 20:54:40 UTC

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

DROP SCHEMA IF EXISTS restore CASCADE; CREATE SCHEMA restore; SET search_path = restore, public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 274 (class 1259 OID 18691)
-- Name: foo; Type: TABLE; Schema: public; Owner: -; Tablespace:
--

CREATE TABLE foo (
    id integer NOT NULL
);
