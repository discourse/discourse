--
-- PostgreSQL database dump
--

\restrict VpojEJAqEpwQGC51Qahqy5HuxojaPyXwIn1sY1NOaXoE3DEeFgA2kgTwfKSGDV5

-- Dumped from database version 15.14 (Debian 15.14-1.pgdg12+1)
-- Dumped by pg_dump version 15.14 (Debian 15.14-1.pgdg12+1)

-- Started on 2025-09-14 20:35:33 UTC

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
-- TOC entry 9 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;

--
-- TOC entry 697 (class 1259 OID 21550)
-- Name: admin_notices; Type: TABLE; Schema: public; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 782 (class 1259 OID 10556041)
-- Name: foo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.foo (
    id integer NOT NULL
);

--
-- PostgreSQL database dump complete
--

\unrestrict VpojEJAqEpwQGC51Qahqy5HuxojaPyXwIn1sY1NOaXoE3DEeFgA2kgTwfKSGDV5
