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
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- TOC entry 7007 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 198 (class 1259 OID 16585)
-- Name: foo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.foo (
    id integer NOT NULL,
    topic_id integer,
    user_id integer
);


CREATE TRIGGER foo_topic_id_readonly BEFORE INSERT OR UPDATE OF redeemed_at ON public.foo FOR EACH ROW WHEN ((new.topic_id IS NOT NULL)) EXECUTE FUNCTION discourse_functions.raise_foo_topic_id_readonly();

CREATE TRIGGER foo_user_id_readonly BEFORE INSERT OR UPDATE OF user_id ON public.foo FOR EACH ROW WHEN ((new.user_id IS NOT NULL)) EXECUTE FUNCTION discourse_functions.raise_foo_user_id_readonly();
