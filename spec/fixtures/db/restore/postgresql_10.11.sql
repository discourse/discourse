--
-- PostgreSQL database dump
--

-- Dumped from database version 10.11 (Debian 10.11-1.pgdg100+1)
-- Dumped by pg_dump version 10.11 (Debian 10.11-1.pgdg100+1)

-- Started on 2019-12-28 00:24:29 UTC

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

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 198 (class 1259 OID 16573)
-- Name: foo; Type: TABLE; Schema: public; Owner: -

CREATE TABLE public.foo (
    id integer NOT NULL
);
