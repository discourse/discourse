--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

DROP INDEX public.unique_schema_migrations;
DROP INDEX public.post_timings_unique;
DROP INDEX public.post_timings_summary;
DROP INDEX public.index_views_on_parent_id_and_parent_type;
DROP INDEX public.index_versions_on_versioned_id_and_versioned_type;
DROP INDEX public.index_versions_on_user_name;
DROP INDEX public.index_versions_on_user_id_and_user_type;
DROP INDEX public.index_versions_on_tag;
DROP INDEX public.index_versions_on_number;
DROP INDEX public.index_versions_on_created_at;
DROP INDEX public.index_users_on_username_lower;
DROP INDEX public.index_users_on_username;
DROP INDEX public.index_users_on_last_posted_at;
DROP INDEX public.index_users_on_email;
DROP INDEX public.index_users_on_auth_token;
DROP INDEX public.index_user_visits_on_user_id_and_visited_at;
DROP INDEX public.index_user_open_ids_on_url;
DROP INDEX public.index_uploads_on_user_id;
DROP INDEX public.index_uploads_on_forum_thread_id;
DROP INDEX public.index_twitter_user_infos_on_user_id;
DROP INDEX public.index_twitter_user_infos_on_twitter_user_id;
DROP INDEX public.index_topic_invites_on_topic_id_and_invite_id;
DROP INDEX public.index_topic_invites_on_invite_id;
DROP INDEX public.index_topic_allowed_users_on_user_id_and_topic_id;
DROP INDEX public.index_topic_allowed_users_on_topic_id_and_user_id;
DROP INDEX public.index_site_customizations_on_key;
DROP INDEX public.index_posts_on_topic_id_and_post_number;
DROP INDEX public.index_posts_on_reply_to_post_number;
DROP INDEX public.index_post_replies_on_post_id_and_reply_id;
DROP INDEX public.index_post_onebox_renders_on_post_id_and_onebox_render_id;
DROP INDEX public.index_post_actions_on_post_id;
DROP INDEX public.index_onebox_renders_on_url;
DROP INDEX public.index_notifications_on_user_id_and_created_at;
DROP INDEX public.index_notifications_on_post_action_id;
DROP INDEX public.index_message_bus_on_created_at;
DROP INDEX public.index_invites_on_invite_key;
DROP INDEX public.index_invites_on_email_and_invited_by_id;
DROP INDEX public.index_github_user_infos_on_user_id;
DROP INDEX public.index_github_user_infos_on_github_user_id;
DROP INDEX public.index_forum_threads_on_bumped_at;
DROP INDEX public.index_forum_thread_users_on_forum_thread_id_and_user_id;
DROP INDEX public.index_forum_thread_links_on_forum_thread_id_and_post_id_and_url;
DROP INDEX public.index_forum_thread_links_on_forum_thread_id;
DROP INDEX public.index_forum_thread_link_clicks_on_forum_thread_link_id;
DROP INDEX public.index_facebook_user_infos_on_user_id;
DROP INDEX public.index_facebook_user_infos_on_facebook_user_id;
DROP INDEX public.index_email_tokens_on_token;
DROP INDEX public.index_email_logs_on_user_id_and_created_at;
DROP INDEX public.index_email_logs_on_created_at;
DROP INDEX public.index_drafts_on_user_id_and_draft_key;
DROP INDEX public.index_draft_sequences_on_user_id_and_draft_key;
DROP INDEX public.index_category_featured_users_on_category_id_and_user_id;
DROP INDEX public.index_categories_on_name;
DROP INDEX public.index_categories_on_forum_thread_count;
DROP INDEX public.index_actions_on_user_id_and_action_type;
DROP INDEX public.index_actions_on_acting_user_id;
DROP INDEX public.incoming_index;
DROP INDEX public.idx_unique_rows;
DROP INDEX public.idx_unique_actions;
DROP INDEX public.idx_topics_user_id_deleted_at;
DROP INDEX public.idx_search_user;
DROP INDEX public.idx_search_post;
DROP INDEX public.idx_search_category;
DROP INDEX public.idx_posts_user_id_deleted_at;
DROP INDEX public.cat_featured_threads;
SET search_path = backup, pg_catalog;

DROP INDEX backup.unique_views;
DROP INDEX backup.post_timings_unique;
DROP INDEX backup.post_timings_summary;
DROP INDEX backup.index_views_on_parent_id_and_parent_type;
DROP INDEX backup.index_versions_on_versioned_id_and_versioned_type;
DROP INDEX backup.index_versions_on_user_name;
DROP INDEX backup.index_versions_on_user_id_and_user_type;
DROP INDEX backup.index_versions_on_tag;
DROP INDEX backup.index_versions_on_number;
DROP INDEX backup.index_versions_on_created_at;
DROP INDEX backup.index_users_on_username_lower;
DROP INDEX backup.index_users_on_username;
DROP INDEX backup.index_users_on_last_posted_at;
DROP INDEX backup.index_users_on_email;
DROP INDEX backup.index_users_on_auth_token;
DROP INDEX backup.index_user_visits_on_user_id_and_visited_at;
DROP INDEX backup.index_user_open_ids_on_url;
DROP INDEX backup.index_uploads_on_user_id;
DROP INDEX backup.index_uploads_on_forum_thread_id;
DROP INDEX backup.index_twitter_user_infos_on_user_id;
DROP INDEX backup.index_twitter_user_infos_on_twitter_user_id;
DROP INDEX backup.index_topic_invites_on_topic_id_and_invite_id;
DROP INDEX backup.index_topic_invites_on_invite_id;
DROP INDEX backup.index_topic_allowed_users_on_user_id_and_topic_id;
DROP INDEX backup.index_topic_allowed_users_on_topic_id_and_user_id;
DROP INDEX backup.index_site_customizations_on_key;
DROP INDEX backup.index_posts_on_topic_id_and_post_number;
DROP INDEX backup.index_posts_on_reply_to_post_number;
DROP INDEX backup.index_post_replies_on_post_id_and_reply_id;
DROP INDEX backup.index_post_onebox_renders_on_post_id_and_onebox_render_id;
DROP INDEX backup.index_post_actions_on_post_id;
DROP INDEX backup.index_onebox_renders_on_url;
DROP INDEX backup.index_notifications_on_user_id_and_created_at;
DROP INDEX backup.index_notifications_on_post_action_id;
DROP INDEX backup.index_invites_on_invite_key;
DROP INDEX backup.index_invites_on_email_and_invited_by_id;
DROP INDEX backup.index_forum_threads_on_category_id_and_sub_tag_and_bumped_at;
DROP INDEX backup.index_forum_threads_on_bumped_at;
DROP INDEX backup.index_forum_thread_users_on_forum_thread_id_and_user_id;
DROP INDEX backup.index_forum_thread_links_on_forum_thread_id_and_post_id_and_url;
DROP INDEX backup.index_forum_thread_links_on_forum_thread_id;
DROP INDEX backup.index_forum_thread_link_clicks_on_forum_thread_link_id;
DROP INDEX backup.index_facebook_user_infos_on_user_id;
DROP INDEX backup.index_facebook_user_infos_on_facebook_user_id;
DROP INDEX backup.index_email_tokens_on_token;
DROP INDEX backup.index_email_logs_on_user_id_and_created_at;
DROP INDEX backup.index_email_logs_on_created_at;
DROP INDEX backup.index_drafts_on_user_id_and_draft_key;
DROP INDEX backup.index_draft_sequences_on_user_id_and_draft_key;
DROP INDEX backup.index_category_featured_users_on_category_id_and_user_id;
DROP INDEX backup.index_categories_on_name;
DROP INDEX backup.index_categories_on_forum_thread_count;
DROP INDEX backup.index_actions_on_user_id_and_action_type;
DROP INDEX backup.index_actions_on_acting_user_id;
DROP INDEX backup.incoming_index;
DROP INDEX backup.idx_unique_rows;
DROP INDEX backup.idx_unique_actions;
DROP INDEX backup.idx_search_user;
DROP INDEX backup.idx_search_thread;
DROP INDEX backup.cat_featured_threads;
SET search_path = public, pg_catalog;

ALTER TABLE ONLY public.versions DROP CONSTRAINT versions_pkey;
ALTER TABLE ONLY public.users_search DROP CONSTRAINT users_search_pkey;
ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
ALTER TABLE ONLY public.user_visits DROP CONSTRAINT user_visits_pkey;
ALTER TABLE ONLY public.user_open_ids DROP CONSTRAINT user_open_ids_pkey;
ALTER TABLE ONLY public.uploads DROP CONSTRAINT uploads_pkey;
ALTER TABLE ONLY public.twitter_user_infos DROP CONSTRAINT twitter_user_infos_pkey;
ALTER TABLE ONLY public.topic_invites DROP CONSTRAINT topic_invites_pkey;
ALTER TABLE ONLY public.topic_allowed_users DROP CONSTRAINT topic_allowed_users_pkey;
ALTER TABLE ONLY public.site_settings DROP CONSTRAINT site_settings_pkey;
ALTER TABLE ONLY public.site_customizations DROP CONSTRAINT site_customizations_pkey;
ALTER TABLE ONLY public.posts_search DROP CONSTRAINT posts_search_pkey;
ALTER TABLE ONLY public.posts DROP CONSTRAINT posts_pkey;
ALTER TABLE ONLY public.post_actions DROP CONSTRAINT post_actions_pkey;
ALTER TABLE ONLY public.post_action_types DROP CONSTRAINT post_action_types_pkey;
ALTER TABLE ONLY public.onebox_renders DROP CONSTRAINT onebox_renders_pkey;
ALTER TABLE ONLY public.notifications DROP CONSTRAINT notifications_pkey;
ALTER TABLE ONLY public.message_bus DROP CONSTRAINT message_bus_pkey;
ALTER TABLE ONLY public.invites DROP CONSTRAINT invites_pkey;
ALTER TABLE ONLY public.incoming_links DROP CONSTRAINT incoming_links_pkey;
ALTER TABLE ONLY public.github_user_infos DROP CONSTRAINT github_user_infos_pkey;
ALTER TABLE ONLY public.topics DROP CONSTRAINT forum_threads_pkey;
ALTER TABLE ONLY public.topic_links DROP CONSTRAINT forum_thread_links_pkey;
ALTER TABLE ONLY public.topic_link_clicks DROP CONSTRAINT forum_thread_link_clicks_pkey;
ALTER TABLE ONLY public.facebook_user_infos DROP CONSTRAINT facebook_user_infos_pkey;
ALTER TABLE ONLY public.email_tokens DROP CONSTRAINT email_tokens_pkey;
ALTER TABLE ONLY public.email_logs DROP CONSTRAINT email_logs_pkey;
ALTER TABLE ONLY public.drafts DROP CONSTRAINT drafts_pkey;
ALTER TABLE ONLY public.draft_sequences DROP CONSTRAINT draft_sequences_pkey;
ALTER TABLE ONLY public.category_featured_users DROP CONSTRAINT category_featured_users_pkey;
ALTER TABLE ONLY public.categories_search DROP CONSTRAINT categories_search_pkey;
ALTER TABLE ONLY public.categories DROP CONSTRAINT categories_pkey;
ALTER TABLE ONLY public.user_actions DROP CONSTRAINT actions_pkey;
SET search_path = backup, pg_catalog;

ALTER TABLE ONLY backup.versions DROP CONSTRAINT versions_pkey;
ALTER TABLE ONLY backup.users DROP CONSTRAINT users_pkey;
ALTER TABLE ONLY backup.user_visits DROP CONSTRAINT user_visits_pkey;
ALTER TABLE ONLY backup.user_open_ids DROP CONSTRAINT user_open_ids_pkey;
ALTER TABLE ONLY backup.uploads DROP CONSTRAINT uploads_pkey;
ALTER TABLE ONLY backup.twitter_user_infos DROP CONSTRAINT twitter_user_infos_pkey;
ALTER TABLE ONLY backup.trust_levels DROP CONSTRAINT trust_levels_pkey;
ALTER TABLE ONLY backup.topic_invites DROP CONSTRAINT topic_invites_pkey;
ALTER TABLE ONLY backup.topic_allowed_users DROP CONSTRAINT topic_allowed_users_pkey;
ALTER TABLE ONLY backup.site_settings DROP CONSTRAINT site_settings_pkey;
ALTER TABLE ONLY backup.site_customizations DROP CONSTRAINT site_customizations_pkey;
ALTER TABLE ONLY backup.posts DROP CONSTRAINT posts_pkey;
ALTER TABLE ONLY backup.post_actions DROP CONSTRAINT post_actions_pkey;
ALTER TABLE ONLY backup.post_action_types DROP CONSTRAINT post_action_types_pkey;
ALTER TABLE ONLY backup.onebox_renders DROP CONSTRAINT onebox_renders_pkey;
ALTER TABLE ONLY backup.notifications DROP CONSTRAINT notifications_pkey;
ALTER TABLE ONLY backup.invites DROP CONSTRAINT invites_pkey;
ALTER TABLE ONLY backup.incoming_links DROP CONSTRAINT incoming_links_pkey;
ALTER TABLE ONLY backup.topics DROP CONSTRAINT forum_threads_pkey;
ALTER TABLE ONLY backup.topic_links DROP CONSTRAINT forum_thread_links_pkey;
ALTER TABLE ONLY backup.topic_link_clicks DROP CONSTRAINT forum_thread_link_clicks_pkey;
ALTER TABLE ONLY backup.facebook_user_infos DROP CONSTRAINT facebook_user_infos_pkey;
ALTER TABLE ONLY backup.email_tokens DROP CONSTRAINT email_tokens_pkey;
ALTER TABLE ONLY backup.email_logs DROP CONSTRAINT email_logs_pkey;
ALTER TABLE ONLY backup.drafts DROP CONSTRAINT drafts_pkey;
ALTER TABLE ONLY backup.draft_sequences DROP CONSTRAINT draft_sequences_pkey;
ALTER TABLE ONLY backup.category_featured_users DROP CONSTRAINT category_featured_users_pkey;
ALTER TABLE ONLY backup.categories DROP CONSTRAINT categories_pkey;
ALTER TABLE ONLY backup.user_actions DROP CONSTRAINT actions_pkey;
SET search_path = public, pg_catalog;

SET search_path = backup, pg_catalog;

SET search_path = public, pg_catalog;

ALTER TABLE public.versions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.user_visits ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.user_open_ids ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.user_actions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.uploads ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.twitter_user_infos ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.topics ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.topic_links ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.topic_link_clicks ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.topic_invites ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.topic_allowed_users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.site_settings ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.site_customizations ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.posts ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.post_actions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.post_action_types ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.onebox_renders ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.notifications ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.message_bus ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.invites ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.incoming_links ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.github_user_infos ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.facebook_user_infos ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.email_tokens ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.email_logs ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.drafts ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.draft_sequences ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.category_featured_users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.categories ALTER COLUMN id DROP DEFAULT;
SET search_path = backup, pg_catalog;

ALTER TABLE backup.versions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.user_visits ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.user_open_ids ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.user_actions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.uploads ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.twitter_user_infos ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.trust_levels ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.topics ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.topic_links ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.topic_link_clicks ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.topic_invites ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.topic_allowed_users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.site_settings ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.site_customizations ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.posts ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.post_actions ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.post_action_types ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.onebox_renders ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.notifications ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.invites ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.incoming_links ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.facebook_user_infos ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.email_tokens ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.email_logs ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.drafts ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.draft_sequences ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.category_featured_users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE backup.categories ALTER COLUMN id DROP DEFAULT;
SET search_path = public, pg_catalog;

DROP TABLE public.views;
DROP SEQUENCE public.versions_id_seq;
DROP TABLE public.versions;
DROP TABLE public.users_search;
DROP SEQUENCE public.users_id_seq;
DROP TABLE public.users;
DROP SEQUENCE public.user_visits_id_seq;
DROP TABLE public.user_visits;
DROP SEQUENCE public.user_open_ids_id_seq;
DROP TABLE public.user_open_ids;
DROP SEQUENCE public.user_actions_id_seq;
DROP TABLE public.user_actions;
DROP SEQUENCE public.uploads_id_seq;
DROP TABLE public.uploads;
DROP SEQUENCE public.twitter_user_infos_id_seq;
DROP TABLE public.twitter_user_infos;
DROP SEQUENCE public.topics_id_seq;
DROP TABLE public.topics;
DROP TABLE public.topic_users;
DROP SEQUENCE public.topic_links_id_seq;
DROP TABLE public.topic_links;
DROP SEQUENCE public.topic_link_clicks_id_seq;
DROP TABLE public.topic_link_clicks;
DROP SEQUENCE public.topic_invites_id_seq;
DROP TABLE public.topic_invites;
DROP SEQUENCE public.topic_allowed_users_id_seq;
DROP TABLE public.topic_allowed_users;
DROP SEQUENCE public.site_settings_id_seq;
DROP TABLE public.site_settings;
DROP SEQUENCE public.site_customizations_id_seq;
DROP TABLE public.site_customizations;
DROP TABLE public.schema_migrations;
DROP TABLE public.posts_search;
DROP SEQUENCE public.posts_id_seq;
DROP TABLE public.posts;
DROP TABLE public.post_timings;
DROP TABLE public.post_replies;
DROP TABLE public.post_onebox_renders;
DROP SEQUENCE public.post_actions_id_seq;
DROP TABLE public.post_actions;
DROP SEQUENCE public.post_action_types_id_seq;
DROP TABLE public.post_action_types;
DROP SEQUENCE public.onebox_renders_id_seq;
DROP TABLE public.onebox_renders;
DROP SEQUENCE public.notifications_id_seq;
DROP TABLE public.notifications;
DROP SEQUENCE public.message_bus_id_seq;
DROP TABLE public.message_bus;
DROP SEQUENCE public.invites_id_seq;
DROP TABLE public.invites;
DROP SEQUENCE public.incoming_links_id_seq;
DROP TABLE public.incoming_links;
DROP SEQUENCE public.github_user_infos_id_seq;
DROP TABLE public.github_user_infos;
DROP SEQUENCE public.facebook_user_infos_id_seq;
DROP TABLE public.facebook_user_infos;
DROP SEQUENCE public.email_tokens_id_seq;
DROP TABLE public.email_tokens;
DROP SEQUENCE public.email_logs_id_seq;
DROP TABLE public.email_logs;
DROP SEQUENCE public.drafts_id_seq;
DROP TABLE public.drafts;
DROP SEQUENCE public.draft_sequences_id_seq;
DROP TABLE public.draft_sequences;
DROP SEQUENCE public.category_featured_users_id_seq;
DROP TABLE public.category_featured_users;
DROP TABLE public.category_featured_topics;
DROP TABLE public.categories_search;
DROP SEQUENCE public.categories_id_seq;
DROP TABLE public.categories;
SET search_path = backup, pg_catalog;

DROP TABLE backup.views;
DROP SEQUENCE backup.versions_id_seq;
DROP TABLE backup.versions;
DROP SEQUENCE backup.users_id_seq;
DROP TABLE backup.users;
DROP SEQUENCE backup.user_visits_id_seq;
DROP TABLE backup.user_visits;
DROP SEQUENCE backup.user_open_ids_id_seq;
DROP TABLE backup.user_open_ids;
DROP SEQUENCE backup.user_actions_id_seq;
DROP TABLE backup.user_actions;
DROP SEQUENCE backup.uploads_id_seq;
DROP TABLE backup.uploads;
DROP SEQUENCE backup.twitter_user_infos_id_seq;
DROP TABLE backup.twitter_user_infos;
DROP SEQUENCE backup.trust_levels_id_seq;
DROP TABLE backup.trust_levels;
DROP SEQUENCE backup.topics_id_seq;
DROP TABLE backup.topics;
DROP TABLE backup.topic_users;
DROP SEQUENCE backup.topic_links_id_seq;
DROP TABLE backup.topic_links;
DROP SEQUENCE backup.topic_link_clicks_id_seq;
DROP TABLE backup.topic_link_clicks;
DROP SEQUENCE backup.topic_invites_id_seq;
DROP TABLE backup.topic_invites;
DROP SEQUENCE backup.topic_allowed_users_id_seq;
DROP TABLE backup.topic_allowed_users;
DROP SEQUENCE backup.site_settings_id_seq;
DROP TABLE backup.site_settings;
DROP SEQUENCE backup.site_customizations_id_seq;
DROP TABLE backup.site_customizations;
DROP SEQUENCE backup.posts_id_seq;
DROP TABLE backup.posts;
DROP TABLE backup.post_timings;
DROP TABLE backup.post_replies;
DROP TABLE backup.post_onebox_renders;
DROP SEQUENCE backup.post_actions_id_seq;
DROP TABLE backup.post_actions;
DROP SEQUENCE backup.post_action_types_id_seq;
DROP TABLE backup.post_action_types;
DROP SEQUENCE backup.onebox_renders_id_seq;
DROP TABLE backup.onebox_renders;
DROP SEQUENCE backup.notifications_id_seq;
DROP TABLE backup.notifications;
DROP SEQUENCE backup.invites_id_seq;
DROP TABLE backup.invites;
DROP SEQUENCE backup.incoming_links_id_seq;
DROP TABLE backup.incoming_links;
DROP SEQUENCE backup.facebook_user_infos_id_seq;
DROP TABLE backup.facebook_user_infos;
DROP SEQUENCE backup.email_tokens_id_seq;
DROP TABLE backup.email_tokens;
DROP SEQUENCE backup.email_logs_id_seq;
DROP TABLE backup.email_logs;
DROP SEQUENCE backup.drafts_id_seq;
DROP TABLE backup.drafts;
DROP SEQUENCE backup.draft_sequences_id_seq;
DROP TABLE backup.draft_sequences;
DROP SEQUENCE backup.category_featured_users_id_seq;
DROP TABLE backup.category_featured_users;
DROP TABLE backup.category_featured_topics;
DROP SEQUENCE backup.categories_id_seq;
DROP TABLE backup.categories;
DROP EXTENSION pg_trgm;
DROP EXTENSION hstore;
DROP EXTENSION plpgsql;
DROP SCHEMA public;
DROP SCHEMA backup;
--
-- Name: backup; Type: SCHEMA; Schema: -; Owner: vagrant
--

CREATE SCHEMA backup;


ALTER SCHEMA backup OWNER TO vagrant;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


SET search_path = backup, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: categories; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    color character varying(6) DEFAULT 'AB9364'::character varying NOT NULL,
    topic_id integer,
    top1_topic_id integer,
    top2_topic_id integer,
    top1_user_id integer,
    top2_user_id integer,
    topic_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    topics_year integer,
    topics_month integer,
    topics_week integer,
    slug character varying(255) NOT NULL
);


ALTER TABLE backup.categories OWNER TO vagrant;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE categories_id_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.categories_id_seq OWNER TO vagrant;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE categories_id_seq OWNED BY categories.id;


--
-- Name: category_featured_topics; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE category_featured_topics (
    category_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.category_featured_topics OWNER TO vagrant;

--
-- Name: category_featured_users; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE category_featured_users (
    id integer NOT NULL,
    category_id integer,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.category_featured_users OWNER TO vagrant;

--
-- Name: category_featured_users_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE category_featured_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.category_featured_users_id_seq OWNER TO vagrant;

--
-- Name: category_featured_users_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE category_featured_users_id_seq OWNED BY category_featured_users.id;


--
-- Name: draft_sequences; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE draft_sequences (
    id integer NOT NULL,
    user_id integer NOT NULL,
    draft_key character varying(255) NOT NULL,
    sequence integer NOT NULL
);


ALTER TABLE backup.draft_sequences OWNER TO vagrant;

--
-- Name: draft_sequences_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE draft_sequences_id_seq
    START WITH 20
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.draft_sequences_id_seq OWNER TO vagrant;

--
-- Name: draft_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE draft_sequences_id_seq OWNED BY draft_sequences.id;


--
-- Name: drafts; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE drafts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    draft_key character varying(255) NOT NULL,
    data text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    sequence integer DEFAULT 0 NOT NULL
);


ALTER TABLE backup.drafts OWNER TO vagrant;

--
-- Name: drafts_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE drafts_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.drafts_id_seq OWNER TO vagrant;

--
-- Name: drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE drafts_id_seq OWNED BY drafts.id;


--
-- Name: email_logs; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE email_logs (
    id integer NOT NULL,
    to_address character varying(255) NOT NULL,
    email_type character varying(255) NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.email_logs OWNER TO vagrant;

--
-- Name: email_logs_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE email_logs_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.email_logs_id_seq OWNER TO vagrant;

--
-- Name: email_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE email_logs_id_seq OWNED BY email_logs.id;


--
-- Name: email_tokens; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE email_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    expired boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.email_tokens OWNER TO vagrant;

--
-- Name: email_tokens_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE email_tokens_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.email_tokens_id_seq OWNER TO vagrant;

--
-- Name: email_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE email_tokens_id_seq OWNED BY email_tokens.id;


--
-- Name: facebook_user_infos; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE facebook_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    facebook_user_id integer NOT NULL,
    username character varying(255) NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    email character varying(255),
    gender character varying(255),
    name character varying(255),
    link character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.facebook_user_infos OWNER TO vagrant;

--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE facebook_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.facebook_user_infos_id_seq OWNER TO vagrant;

--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE facebook_user_infos_id_seq OWNED BY facebook_user_infos.id;


--
-- Name: incoming_links; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE incoming_links (
    id integer NOT NULL,
    url character varying(1000) NOT NULL,
    referer character varying(1000) NOT NULL,
    domain character varying(100) NOT NULL,
    topic_id integer,
    post_number integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.incoming_links OWNER TO vagrant;

--
-- Name: incoming_links_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE incoming_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.incoming_links_id_seq OWNER TO vagrant;

--
-- Name: incoming_links_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE incoming_links_id_seq OWNED BY incoming_links.id;


--
-- Name: invites; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE invites (
    id integer NOT NULL,
    invite_key character varying(32) NOT NULL,
    email character varying(255) NOT NULL,
    invited_by_id integer NOT NULL,
    user_id integer,
    redeemed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


ALTER TABLE backup.invites OWNER TO vagrant;

--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.invites_id_seq OWNER TO vagrant;

--
-- Name: invites_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE invites_id_seq OWNED BY invites.id;


--
-- Name: notifications; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE notifications (
    id integer NOT NULL,
    notification_type integer NOT NULL,
    user_id integer NOT NULL,
    data character varying(255) NOT NULL,
    read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    topic_id integer,
    post_number integer,
    post_action_id integer
);


ALTER TABLE backup.notifications OWNER TO vagrant;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.notifications_id_seq OWNER TO vagrant;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id;


--
-- Name: onebox_renders; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE onebox_renders (
    id integer NOT NULL,
    url character varying(255) NOT NULL,
    cooked text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    preview text
);


ALTER TABLE backup.onebox_renders OWNER TO vagrant;

--
-- Name: onebox_renders_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE onebox_renders_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.onebox_renders_id_seq OWNER TO vagrant;

--
-- Name: onebox_renders_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE onebox_renders_id_seq OWNED BY onebox_renders.id;


--
-- Name: post_action_types; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_action_types (
    name_key character varying(50) NOT NULL,
    is_flag boolean DEFAULT false NOT NULL,
    icon character varying(20),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id integer NOT NULL
);


ALTER TABLE backup.post_action_types OWNER TO vagrant;

--
-- Name: post_action_types_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE post_action_types_id_seq
    START WITH 6
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.post_action_types_id_seq OWNER TO vagrant;

--
-- Name: post_action_types_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE post_action_types_id_seq OWNED BY post_action_types.id;


--
-- Name: post_actions; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_actions (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    post_action_type_id integer NOT NULL,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.post_actions OWNER TO vagrant;

--
-- Name: post_actions_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE post_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.post_actions_id_seq OWNER TO vagrant;

--
-- Name: post_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE post_actions_id_seq OWNED BY post_actions.id;


--
-- Name: post_onebox_renders; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_onebox_renders (
    post_id integer NOT NULL,
    onebox_render_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.post_onebox_renders OWNER TO vagrant;

--
-- Name: post_replies; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_replies (
    post_id integer,
    reply_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.post_replies OWNER TO vagrant;

--
-- Name: post_timings; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_timings (
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    user_id integer NOT NULL,
    msecs integer NOT NULL
);


ALTER TABLE backup.post_timings OWNER TO vagrant;

--
-- Name: posts; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE posts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    raw text NOT NULL,
    cooked text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reply_to_post_number integer,
    cached_version integer DEFAULT 1 NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    quote_count integer DEFAULT 0 NOT NULL,
    reply_below_post_number integer,
    deleted_at timestamp without time zone,
    off_topic_count integer DEFAULT 0 NOT NULL,
    offensive_count integer DEFAULT 0 NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    bookmark_count integer DEFAULT 0 NOT NULL,
    avg_time integer,
    score double precision,
    reads integer DEFAULT 0 NOT NULL,
    post_type integer DEFAULT 1 NOT NULL,
    vote_count integer DEFAULT 0 NOT NULL,
    sort_order integer,
    last_editor_id integer
);


ALTER TABLE backup.posts OWNER TO vagrant;

--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE posts_id_seq
    START WITH 16
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.posts_id_seq OWNER TO vagrant;

--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE posts_id_seq OWNED BY posts.id;


--
-- Name: site_customizations; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE site_customizations (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    stylesheet text,
    header text,
    "position" integer NOT NULL,
    user_id integer NOT NULL,
    enabled boolean NOT NULL,
    key character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    override_default_style boolean DEFAULT false NOT NULL,
    stylesheet_baked text DEFAULT ''::text NOT NULL
);


ALTER TABLE backup.site_customizations OWNER TO vagrant;

--
-- Name: site_customizations_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE site_customizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.site_customizations_id_seq OWNER TO vagrant;

--
-- Name: site_customizations_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE site_customizations_id_seq OWNED BY site_customizations.id;


--
-- Name: site_settings; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE site_settings (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    data_type integer NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.site_settings OWNER TO vagrant;

--
-- Name: site_settings_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE site_settings_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.site_settings_id_seq OWNER TO vagrant;

--
-- Name: site_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE site_settings_id_seq OWNED BY site_settings.id;


--
-- Name: topic_allowed_users; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_allowed_users (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.topic_allowed_users OWNER TO vagrant;

--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE topic_allowed_users_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.topic_allowed_users_id_seq OWNER TO vagrant;

--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE topic_allowed_users_id_seq OWNED BY topic_allowed_users.id;


--
-- Name: topic_invites; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_invites (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    invite_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.topic_invites OWNER TO vagrant;

--
-- Name: topic_invites_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE topic_invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.topic_invites_id_seq OWNER TO vagrant;

--
-- Name: topic_invites_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE topic_invites_id_seq OWNED BY topic_invites.id;


--
-- Name: topic_link_clicks; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_link_clicks (
    id integer NOT NULL,
    topic_link_id integer NOT NULL,
    user_id integer,
    ip bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.topic_link_clicks OWNER TO vagrant;

--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE topic_link_clicks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.topic_link_clicks_id_seq OWNER TO vagrant;

--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE topic_link_clicks_id_seq OWNED BY topic_link_clicks.id;


--
-- Name: topic_links; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_links (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    post_id integer,
    user_id integer NOT NULL,
    url character varying(500) NOT NULL,
    domain character varying(100) NOT NULL,
    internal boolean DEFAULT false NOT NULL,
    link_topic_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reflection boolean DEFAULT false,
    clicks integer DEFAULT 0 NOT NULL,
    link_post_id integer
);


ALTER TABLE backup.topic_links OWNER TO vagrant;

--
-- Name: topic_links_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE topic_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.topic_links_id_seq OWNER TO vagrant;

--
-- Name: topic_links_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE topic_links_id_seq OWNED BY topic_links.id;


--
-- Name: topic_users; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_users (
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    starred boolean DEFAULT false NOT NULL,
    posted boolean DEFAULT false NOT NULL,
    last_read_post_number integer,
    seen_post_count integer,
    starred_at timestamp without time zone,
    muted_at timestamp without time zone,
    last_visited_at timestamp without time zone,
    first_visited_at timestamp without time zone,
    notifications integer DEFAULT 2,
    notifications_changed_at timestamp without time zone,
    notifications_reason_id integer,
    CONSTRAINT test_starred_at CHECK (((starred = false) OR (starred_at IS NOT NULL)))
);


ALTER TABLE backup.topic_users OWNER TO vagrant;

--
-- Name: topics; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE topics (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    last_posted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    user_id integer NOT NULL,
    last_post_user_id integer NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    featured_user1_id integer,
    featured_user2_id integer,
    featured_user3_id integer,
    avg_time integer,
    deleted_at timestamp without time zone,
    highest_post_number integer DEFAULT 0 NOT NULL,
    image_url character varying(255),
    off_topic_count integer DEFAULT 0 NOT NULL,
    offensive_count integer DEFAULT 0 NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    bookmark_count integer DEFAULT 0 NOT NULL,
    star_count integer DEFAULT 0 NOT NULL,
    category_id integer,
    visible boolean DEFAULT true NOT NULL,
    moderator_posts_count integer DEFAULT 0 NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    pinned boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    bumped_at timestamp without time zone NOT NULL,
    sub_tag character varying(255),
    has_best_of boolean DEFAULT false NOT NULL,
    meta_data public.hstore,
    vote_count integer DEFAULT 0 NOT NULL,
    archetype character varying(255) DEFAULT 'regular'::character varying NOT NULL,
    featured_user4_id integer
);


ALTER TABLE backup.topics OWNER TO vagrant;

--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE topics_id_seq
    START WITH 16
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.topics_id_seq OWNER TO vagrant;

--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE topics_id_seq OWNED BY topics.id;


--
-- Name: trust_levels; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE trust_levels (
    id integer NOT NULL,
    name_key character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.trust_levels OWNER TO vagrant;

--
-- Name: trust_levels_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE trust_levels_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.trust_levels_id_seq OWNER TO vagrant;

--
-- Name: trust_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE trust_levels_id_seq OWNED BY trust_levels.id;


--
-- Name: twitter_user_infos; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE twitter_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    screen_name character varying(255) NOT NULL,
    twitter_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.twitter_user_infos OWNER TO vagrant;

--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE twitter_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.twitter_user_infos_id_seq OWNER TO vagrant;

--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE twitter_user_infos_id_seq OWNED BY twitter_user_infos.id;


--
-- Name: uploads; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE uploads (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    original_filename character varying(255) NOT NULL,
    filesize integer NOT NULL,
    width integer,
    height integer,
    url character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.uploads OWNER TO vagrant;

--
-- Name: uploads_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.uploads_id_seq OWNER TO vagrant;

--
-- Name: uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE uploads_id_seq OWNED BY uploads.id;


--
-- Name: user_actions; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE user_actions (
    id integer NOT NULL,
    action_type integer NOT NULL,
    user_id integer NOT NULL,
    target_topic_id integer,
    target_post_id integer,
    target_user_id integer,
    acting_user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.user_actions OWNER TO vagrant;

--
-- Name: user_actions_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE user_actions_id_seq
    START WITH 40
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.user_actions_id_seq OWNER TO vagrant;

--
-- Name: user_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE user_actions_id_seq OWNED BY user_actions.id;


--
-- Name: user_open_ids; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE user_open_ids (
    id integer NOT NULL,
    user_id integer NOT NULL,
    email character varying(255) NOT NULL,
    url character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    active boolean NOT NULL
);


ALTER TABLE backup.user_open_ids OWNER TO vagrant;

--
-- Name: user_open_ids_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE user_open_ids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.user_open_ids_id_seq OWNER TO vagrant;

--
-- Name: user_open_ids_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE user_open_ids_id_seq OWNED BY user_open_ids.id;


--
-- Name: user_visits; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE user_visits (
    id integer NOT NULL,
    user_id integer NOT NULL,
    visited_at date NOT NULL
);


ALTER TABLE backup.user_visits OWNER TO vagrant;

--
-- Name: user_visits_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE user_visits_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.user_visits_id_seq OWNER TO vagrant;

--
-- Name: user_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE user_visits_id_seq OWNED BY user_visits.id;


--
-- Name: users; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    username character varying(20) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying(255),
    bio_raw text,
    seen_notification_id integer DEFAULT 0 NOT NULL,
    last_posted_at timestamp without time zone,
    email character varying(256) NOT NULL,
    password_hash character varying(64),
    salt character varying(32),
    active boolean,
    username_lower character varying(20) NOT NULL,
    auth_token character varying(32),
    last_seen_at timestamp without time zone,
    website character varying(255),
    admin boolean DEFAULT false NOT NULL,
    moderator boolean DEFAULT false NOT NULL,
    last_emailed_at timestamp without time zone,
    email_digests boolean DEFAULT true NOT NULL,
    trust_level_id integer DEFAULT 1 NOT NULL,
    bio_cooked text,
    email_private_messages boolean DEFAULT true,
    email_direct boolean DEFAULT true NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    approved_by_id integer,
    approved_at timestamp without time zone,
    topics_entered integer DEFAULT 0 NOT NULL,
    posts_read_count integer DEFAULT 0 NOT NULL,
    digest_after_days integer DEFAULT 7 NOT NULL,
    previous_visit_at timestamp without time zone
);


ALTER TABLE backup.users OWNER TO vagrant;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE users_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.users_id_seq OWNER TO vagrant;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: versions; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE versions (
    id integer NOT NULL,
    versioned_id integer,
    versioned_type character varying(255),
    user_id integer,
    user_type character varying(255),
    user_name character varying(255),
    modifications text,
    number integer,
    reverted_from integer,
    tag character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE backup.versions OWNER TO vagrant;

--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: backup; Owner: vagrant
--

CREATE SEQUENCE versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE backup.versions_id_seq OWNER TO vagrant;

--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: vagrant
--

ALTER SEQUENCE versions_id_seq OWNED BY versions.id;


--
-- Name: views; Type: TABLE; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE TABLE views (
    parent_id integer NOT NULL,
    parent_type character varying(50) NOT NULL,
    ip bigint NOT NULL,
    viewed_at timestamp without time zone NOT NULL,
    user_id integer
);


ALTER TABLE backup.views OWNER TO vagrant;

SET search_path = public, pg_catalog;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    color character varying(6) DEFAULT 'AB9364'::character varying NOT NULL,
    topic_id integer,
    topic_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    topics_year integer,
    topics_month integer,
    topics_week integer,
    slug character varying(255) NOT NULL,
    description text,
    text_color character varying(6) DEFAULT 'FFFFFF'::character varying NOT NULL
);


ALTER TABLE public.categories OWNER TO vagrant;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE categories_id_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.categories_id_seq OWNER TO vagrant;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE categories_id_seq OWNED BY categories.id;


--
-- Name: categories_search; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE categories_search (
    id integer NOT NULL,
    search_data tsvector
);


ALTER TABLE public.categories_search OWNER TO vagrant;

--
-- Name: category_featured_topics; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE category_featured_topics (
    category_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.category_featured_topics OWNER TO vagrant;

--
-- Name: category_featured_users; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE category_featured_users (
    id integer NOT NULL,
    category_id integer,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.category_featured_users OWNER TO vagrant;

--
-- Name: category_featured_users_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE category_featured_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.category_featured_users_id_seq OWNER TO vagrant;

--
-- Name: category_featured_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE category_featured_users_id_seq OWNED BY category_featured_users.id;


--
-- Name: draft_sequences; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE draft_sequences (
    id integer NOT NULL,
    user_id integer NOT NULL,
    draft_key character varying(255) NOT NULL,
    sequence integer NOT NULL
);


ALTER TABLE public.draft_sequences OWNER TO vagrant;

--
-- Name: draft_sequences_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE draft_sequences_id_seq
    START WITH 20
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.draft_sequences_id_seq OWNER TO vagrant;

--
-- Name: draft_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE draft_sequences_id_seq OWNED BY draft_sequences.id;


--
-- Name: drafts; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE drafts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    draft_key character varying(255) NOT NULL,
    data text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    sequence integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.drafts OWNER TO vagrant;

--
-- Name: drafts_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE drafts_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.drafts_id_seq OWNER TO vagrant;

--
-- Name: drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE drafts_id_seq OWNED BY drafts.id;


--
-- Name: email_logs; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE email_logs (
    id integer NOT NULL,
    to_address character varying(255) NOT NULL,
    email_type character varying(255) NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.email_logs OWNER TO vagrant;

--
-- Name: email_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE email_logs_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_logs_id_seq OWNER TO vagrant;

--
-- Name: email_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE email_logs_id_seq OWNED BY email_logs.id;


--
-- Name: email_tokens; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE email_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    expired boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.email_tokens OWNER TO vagrant;

--
-- Name: email_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE email_tokens_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.email_tokens_id_seq OWNER TO vagrant;

--
-- Name: email_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE email_tokens_id_seq OWNED BY email_tokens.id;


--
-- Name: facebook_user_infos; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE facebook_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    facebook_user_id bigint NOT NULL,
    username character varying(255) NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    email character varying(255),
    gender character varying(255),
    name character varying(255),
    link character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.facebook_user_infos OWNER TO vagrant;

--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE facebook_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facebook_user_infos_id_seq OWNER TO vagrant;

--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE facebook_user_infos_id_seq OWNED BY facebook_user_infos.id;


--
-- Name: github_user_infos; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE github_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    screen_name character varying(255) NOT NULL,
    github_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.github_user_infos OWNER TO vagrant;

--
-- Name: github_user_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE github_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.github_user_infos_id_seq OWNER TO vagrant;

--
-- Name: github_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE github_user_infos_id_seq OWNED BY github_user_infos.id;


--
-- Name: incoming_links; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE incoming_links (
    id integer NOT NULL,
    url character varying(1000) NOT NULL,
    referer character varying(1000) NOT NULL,
    domain character varying(100) NOT NULL,
    topic_id integer,
    post_number integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.incoming_links OWNER TO vagrant;

--
-- Name: incoming_links_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE incoming_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.incoming_links_id_seq OWNER TO vagrant;

--
-- Name: incoming_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE incoming_links_id_seq OWNED BY incoming_links.id;


--
-- Name: invites; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE invites (
    id integer NOT NULL,
    invite_key character varying(32) NOT NULL,
    email character varying(255) NOT NULL,
    invited_by_id integer NOT NULL,
    user_id integer,
    redeemed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone
);


ALTER TABLE public.invites OWNER TO vagrant;

--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.invites_id_seq OWNER TO vagrant;

--
-- Name: invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE invites_id_seq OWNED BY invites.id;


--
-- Name: message_bus; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE message_bus (
    id integer NOT NULL,
    name character varying(255),
    context character varying(255),
    data text,
    created_at timestamp without time zone
);


ALTER TABLE public.message_bus OWNER TO vagrant;

--
-- Name: message_bus_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE message_bus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.message_bus_id_seq OWNER TO vagrant;

--
-- Name: message_bus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE message_bus_id_seq OWNED BY message_bus.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE notifications (
    id integer NOT NULL,
    notification_type integer NOT NULL,
    user_id integer NOT NULL,
    data character varying(255) NOT NULL,
    read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    topic_id integer,
    post_number integer,
    post_action_id integer
);


ALTER TABLE public.notifications OWNER TO vagrant;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.notifications_id_seq OWNER TO vagrant;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id;


--
-- Name: onebox_renders; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE onebox_renders (
    id integer NOT NULL,
    url character varying(255) NOT NULL,
    cooked text NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    preview text
);


ALTER TABLE public.onebox_renders OWNER TO vagrant;

--
-- Name: onebox_renders_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE onebox_renders_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.onebox_renders_id_seq OWNER TO vagrant;

--
-- Name: onebox_renders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE onebox_renders_id_seq OWNED BY onebox_renders.id;


--
-- Name: post_action_types; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_action_types (
    name_key character varying(50) NOT NULL,
    is_flag boolean DEFAULT false NOT NULL,
    icon character varying(20),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id integer NOT NULL,
    "position" integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.post_action_types OWNER TO vagrant;

--
-- Name: post_action_types_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE post_action_types_id_seq
    START WITH 6
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.post_action_types_id_seq OWNER TO vagrant;

--
-- Name: post_action_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE post_action_types_id_seq OWNED BY post_action_types.id;


--
-- Name: post_actions; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_actions (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    post_action_type_id integer NOT NULL,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_by integer,
    message text
);


ALTER TABLE public.post_actions OWNER TO vagrant;

--
-- Name: post_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE post_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.post_actions_id_seq OWNER TO vagrant;

--
-- Name: post_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE post_actions_id_seq OWNED BY post_actions.id;


--
-- Name: post_onebox_renders; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_onebox_renders (
    post_id integer NOT NULL,
    onebox_render_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.post_onebox_renders OWNER TO vagrant;

--
-- Name: post_replies; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_replies (
    post_id integer,
    reply_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.post_replies OWNER TO vagrant;

--
-- Name: post_timings; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE post_timings (
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    user_id integer NOT NULL,
    msecs integer NOT NULL
);


ALTER TABLE public.post_timings OWNER TO vagrant;

--
-- Name: posts; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE posts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    raw text NOT NULL,
    cooked text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reply_to_post_number integer,
    cached_version integer DEFAULT 1 NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    quote_count integer DEFAULT 0 NOT NULL,
    deleted_at timestamp without time zone,
    off_topic_count integer DEFAULT 0 NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    bookmark_count integer DEFAULT 0 NOT NULL,
    avg_time integer,
    score double precision,
    reads integer DEFAULT 0 NOT NULL,
    post_type integer DEFAULT 1 NOT NULL,
    vote_count integer DEFAULT 0 NOT NULL,
    sort_order integer,
    last_editor_id integer,
    hidden boolean DEFAULT false NOT NULL,
    hidden_reason_id integer,
    custom_flag_count integer DEFAULT 0 NOT NULL,
    spam_count integer DEFAULT 0 NOT NULL,
    illegal_count integer DEFAULT 0 NOT NULL,
    inappropriate_count integer DEFAULT 0 NOT NULL,
    last_version_at timestamp without time zone NOT NULL,
    user_deleted boolean DEFAULT false NOT NULL,
    reply_to_user_id integer
);


ALTER TABLE public.posts OWNER TO vagrant;

--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE posts_id_seq
    START WITH 16
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.posts_id_seq OWNER TO vagrant;

--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE posts_id_seq OWNED BY posts.id;


--
-- Name: posts_search; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE posts_search (
    id integer NOT NULL,
    search_data tsvector
);


ALTER TABLE public.posts_search OWNER TO vagrant;

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


ALTER TABLE public.schema_migrations OWNER TO vagrant;

--
-- Name: site_customizations; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE site_customizations (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    stylesheet text,
    header text,
    "position" integer NOT NULL,
    user_id integer NOT NULL,
    enabled boolean NOT NULL,
    key character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    override_default_style boolean DEFAULT false NOT NULL,
    stylesheet_baked text DEFAULT ''::text NOT NULL
);


ALTER TABLE public.site_customizations OWNER TO vagrant;

--
-- Name: site_customizations_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE site_customizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.site_customizations_id_seq OWNER TO vagrant;

--
-- Name: site_customizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE site_customizations_id_seq OWNED BY site_customizations.id;


--
-- Name: site_settings; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE site_settings (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    data_type integer NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.site_settings OWNER TO vagrant;

--
-- Name: site_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE site_settings_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.site_settings_id_seq OWNER TO vagrant;

--
-- Name: site_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE site_settings_id_seq OWNED BY site_settings.id;


--
-- Name: topic_allowed_users; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_allowed_users (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.topic_allowed_users OWNER TO vagrant;

--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE topic_allowed_users_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.topic_allowed_users_id_seq OWNER TO vagrant;

--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE topic_allowed_users_id_seq OWNED BY topic_allowed_users.id;


--
-- Name: topic_invites; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_invites (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    invite_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.topic_invites OWNER TO vagrant;

--
-- Name: topic_invites_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE topic_invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.topic_invites_id_seq OWNER TO vagrant;

--
-- Name: topic_invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE topic_invites_id_seq OWNED BY topic_invites.id;


--
-- Name: topic_link_clicks; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_link_clicks (
    id integer NOT NULL,
    topic_link_id integer NOT NULL,
    user_id integer,
    ip bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.topic_link_clicks OWNER TO vagrant;

--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE topic_link_clicks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.topic_link_clicks_id_seq OWNER TO vagrant;

--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE topic_link_clicks_id_seq OWNED BY topic_link_clicks.id;


--
-- Name: topic_links; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_links (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    post_id integer,
    user_id integer NOT NULL,
    url character varying(500) NOT NULL,
    domain character varying(100) NOT NULL,
    internal boolean DEFAULT false NOT NULL,
    link_topic_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reflection boolean DEFAULT false,
    clicks integer DEFAULT 0 NOT NULL,
    link_post_id integer
);


ALTER TABLE public.topic_links OWNER TO vagrant;

--
-- Name: topic_links_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE topic_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.topic_links_id_seq OWNER TO vagrant;

--
-- Name: topic_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE topic_links_id_seq OWNED BY topic_links.id;


--
-- Name: topic_users; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE topic_users (
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    starred boolean DEFAULT false NOT NULL,
    posted boolean DEFAULT false NOT NULL,
    last_read_post_number integer,
    seen_post_count integer,
    starred_at timestamp without time zone,
    last_visited_at timestamp without time zone,
    first_visited_at timestamp without time zone,
    notification_level integer DEFAULT 1 NOT NULL,
    notifications_changed_at timestamp without time zone,
    notifications_reason_id integer,
    total_msecs_viewed integer DEFAULT 0 NOT NULL,
    cleared_pinned_at timestamp without time zone,
    CONSTRAINT test_starred_at CHECK (((starred = false) OR (starred_at IS NOT NULL)))
);


ALTER TABLE public.topic_users OWNER TO vagrant;

--
-- Name: topics; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE topics (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    last_posted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    user_id integer NOT NULL,
    last_post_user_id integer NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    featured_user1_id integer,
    featured_user2_id integer,
    featured_user3_id integer,
    avg_time integer,
    deleted_at timestamp without time zone,
    highest_post_number integer DEFAULT 0 NOT NULL,
    image_url character varying(255),
    off_topic_count integer DEFAULT 0 NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    bookmark_count integer DEFAULT 0 NOT NULL,
    star_count integer DEFAULT 0 NOT NULL,
    category_id integer,
    visible boolean DEFAULT true NOT NULL,
    moderator_posts_count integer DEFAULT 0 NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    bumped_at timestamp without time zone NOT NULL,
    has_best_of boolean DEFAULT false NOT NULL,
    meta_data hstore,
    vote_count integer DEFAULT 0 NOT NULL,
    archetype character varying(255) DEFAULT 'regular'::character varying NOT NULL,
    featured_user4_id integer,
    custom_flag_count integer DEFAULT 0 NOT NULL,
    spam_count integer DEFAULT 0 NOT NULL,
    illegal_count integer DEFAULT 0 NOT NULL,
    inappropriate_count integer DEFAULT 0 NOT NULL,
    pinned_at timestamp without time zone
);


ALTER TABLE public.topics OWNER TO vagrant;

--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE topics_id_seq
    START WITH 16
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.topics_id_seq OWNER TO vagrant;

--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE topics_id_seq OWNED BY topics.id;


--
-- Name: twitter_user_infos; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE twitter_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    screen_name character varying(255) NOT NULL,
    twitter_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.twitter_user_infos OWNER TO vagrant;

--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE twitter_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.twitter_user_infos_id_seq OWNER TO vagrant;

--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE twitter_user_infos_id_seq OWNED BY twitter_user_infos.id;


--
-- Name: uploads; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE uploads (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    original_filename character varying(255) NOT NULL,
    filesize integer NOT NULL,
    width integer,
    height integer,
    url character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.uploads OWNER TO vagrant;

--
-- Name: uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.uploads_id_seq OWNER TO vagrant;

--
-- Name: uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE uploads_id_seq OWNED BY uploads.id;


--
-- Name: user_actions; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE user_actions (
    id integer NOT NULL,
    action_type integer NOT NULL,
    user_id integer NOT NULL,
    target_topic_id integer,
    target_post_id integer,
    target_user_id integer,
    acting_user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.user_actions OWNER TO vagrant;

--
-- Name: user_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE user_actions_id_seq
    START WITH 40
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_actions_id_seq OWNER TO vagrant;

--
-- Name: user_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE user_actions_id_seq OWNED BY user_actions.id;


--
-- Name: user_open_ids; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE user_open_ids (
    id integer NOT NULL,
    user_id integer NOT NULL,
    email character varying(255) NOT NULL,
    url character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    active boolean NOT NULL
);


ALTER TABLE public.user_open_ids OWNER TO vagrant;

--
-- Name: user_open_ids_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE user_open_ids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_open_ids_id_seq OWNER TO vagrant;

--
-- Name: user_open_ids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE user_open_ids_id_seq OWNED BY user_open_ids.id;


--
-- Name: user_visits; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE user_visits (
    id integer NOT NULL,
    user_id integer NOT NULL,
    visited_at date NOT NULL
);


ALTER TABLE public.user_visits OWNER TO vagrant;

--
-- Name: user_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE user_visits_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_visits_id_seq OWNER TO vagrant;

--
-- Name: user_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE user_visits_id_seq OWNED BY user_visits.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE users (
    id integer NOT NULL,
    username character varying(20) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying(255),
    bio_raw text,
    seen_notification_id integer DEFAULT 0 NOT NULL,
    last_posted_at timestamp without time zone,
    email character varying(256) NOT NULL,
    password_hash character varying(64),
    salt character varying(32),
    active boolean,
    username_lower character varying(20) NOT NULL,
    auth_token character varying(32),
    last_seen_at timestamp without time zone,
    website character varying(255),
    admin boolean DEFAULT false NOT NULL,
    last_emailed_at timestamp without time zone,
    email_digests boolean DEFAULT true NOT NULL,
    trust_level integer NOT NULL,
    bio_cooked text,
    email_private_messages boolean DEFAULT true,
    email_direct boolean DEFAULT true NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    approved_by_id integer,
    approved_at timestamp without time zone,
    topics_entered integer DEFAULT 0 NOT NULL,
    posts_read_count integer DEFAULT 0 NOT NULL,
    digest_after_days integer DEFAULT 7 NOT NULL,
    previous_visit_at timestamp without time zone,
    banned_at timestamp without time zone,
    banned_till timestamp without time zone,
    date_of_birth date,
    auto_track_topics_after_msecs integer,
    views integer DEFAULT 0 NOT NULL,
    flag_level integer DEFAULT 0 NOT NULL,
    time_read integer DEFAULT 0 NOT NULL,
    days_visited integer DEFAULT 0 NOT NULL,
    ip_address inet,
    new_topic_duration_minutes integer,
    external_links_in_new_tab boolean DEFAULT false NOT NULL,
    enable_quoting boolean DEFAULT true NOT NULL,
    moderator boolean DEFAULT false
);


ALTER TABLE public.users OWNER TO vagrant;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE users_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO vagrant;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: users_search; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE users_search (
    id integer NOT NULL,
    search_data tsvector
);


ALTER TABLE public.users_search OWNER TO vagrant;

--
-- Name: versions; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE versions (
    id integer NOT NULL,
    versioned_id integer,
    versioned_type character varying(255),
    user_id integer,
    user_type character varying(255),
    user_name character varying(255),
    modifications text,
    number integer,
    reverted_from integer,
    tag character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


ALTER TABLE public.versions OWNER TO vagrant;

--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: vagrant
--

CREATE SEQUENCE versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.versions_id_seq OWNER TO vagrant;

--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: vagrant
--

ALTER SEQUENCE versions_id_seq OWNED BY versions.id;


--
-- Name: views; Type: TABLE; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE TABLE views (
    parent_id integer NOT NULL,
    parent_type character varying(50) NOT NULL,
    ip bigint NOT NULL,
    viewed_at date NOT NULL,
    user_id integer
);


ALTER TABLE public.views OWNER TO vagrant;

SET search_path = backup, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY categories ALTER COLUMN id SET DEFAULT nextval('categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY category_featured_users ALTER COLUMN id SET DEFAULT nextval('category_featured_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY draft_sequences ALTER COLUMN id SET DEFAULT nextval('draft_sequences_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY drafts ALTER COLUMN id SET DEFAULT nextval('drafts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY email_logs ALTER COLUMN id SET DEFAULT nextval('email_logs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY email_tokens ALTER COLUMN id SET DEFAULT nextval('email_tokens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY facebook_user_infos ALTER COLUMN id SET DEFAULT nextval('facebook_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY incoming_links ALTER COLUMN id SET DEFAULT nextval('incoming_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY invites ALTER COLUMN id SET DEFAULT nextval('invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY onebox_renders ALTER COLUMN id SET DEFAULT nextval('onebox_renders_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY post_action_types ALTER COLUMN id SET DEFAULT nextval('post_action_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY post_actions ALTER COLUMN id SET DEFAULT nextval('post_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY posts ALTER COLUMN id SET DEFAULT nextval('posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY site_customizations ALTER COLUMN id SET DEFAULT nextval('site_customizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY site_settings ALTER COLUMN id SET DEFAULT nextval('site_settings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY topic_allowed_users ALTER COLUMN id SET DEFAULT nextval('topic_allowed_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY topic_invites ALTER COLUMN id SET DEFAULT nextval('topic_invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY topic_link_clicks ALTER COLUMN id SET DEFAULT nextval('topic_link_clicks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY topic_links ALTER COLUMN id SET DEFAULT nextval('topic_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY topics ALTER COLUMN id SET DEFAULT nextval('topics_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY trust_levels ALTER COLUMN id SET DEFAULT nextval('trust_levels_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY twitter_user_infos ALTER COLUMN id SET DEFAULT nextval('twitter_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY uploads ALTER COLUMN id SET DEFAULT nextval('uploads_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY user_actions ALTER COLUMN id SET DEFAULT nextval('user_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY user_open_ids ALTER COLUMN id SET DEFAULT nextval('user_open_ids_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY user_visits ALTER COLUMN id SET DEFAULT nextval('user_visits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: vagrant
--

ALTER TABLE ONLY versions ALTER COLUMN id SET DEFAULT nextval('versions_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY categories ALTER COLUMN id SET DEFAULT nextval('categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY category_featured_users ALTER COLUMN id SET DEFAULT nextval('category_featured_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY draft_sequences ALTER COLUMN id SET DEFAULT nextval('draft_sequences_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY drafts ALTER COLUMN id SET DEFAULT nextval('drafts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY email_logs ALTER COLUMN id SET DEFAULT nextval('email_logs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY email_tokens ALTER COLUMN id SET DEFAULT nextval('email_tokens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY facebook_user_infos ALTER COLUMN id SET DEFAULT nextval('facebook_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY github_user_infos ALTER COLUMN id SET DEFAULT nextval('github_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY incoming_links ALTER COLUMN id SET DEFAULT nextval('incoming_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY invites ALTER COLUMN id SET DEFAULT nextval('invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY message_bus ALTER COLUMN id SET DEFAULT nextval('message_bus_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY onebox_renders ALTER COLUMN id SET DEFAULT nextval('onebox_renders_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY post_action_types ALTER COLUMN id SET DEFAULT nextval('post_action_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY post_actions ALTER COLUMN id SET DEFAULT nextval('post_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY posts ALTER COLUMN id SET DEFAULT nextval('posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY site_customizations ALTER COLUMN id SET DEFAULT nextval('site_customizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY site_settings ALTER COLUMN id SET DEFAULT nextval('site_settings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY topic_allowed_users ALTER COLUMN id SET DEFAULT nextval('topic_allowed_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY topic_invites ALTER COLUMN id SET DEFAULT nextval('topic_invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY topic_link_clicks ALTER COLUMN id SET DEFAULT nextval('topic_link_clicks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY topic_links ALTER COLUMN id SET DEFAULT nextval('topic_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY topics ALTER COLUMN id SET DEFAULT nextval('topics_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY twitter_user_infos ALTER COLUMN id SET DEFAULT nextval('twitter_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY uploads ALTER COLUMN id SET DEFAULT nextval('uploads_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY user_actions ALTER COLUMN id SET DEFAULT nextval('user_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY user_open_ids ALTER COLUMN id SET DEFAULT nextval('user_open_ids_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY user_visits ALTER COLUMN id SET DEFAULT nextval('user_visits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: vagrant
--

ALTER TABLE ONLY versions ALTER COLUMN id SET DEFAULT nextval('versions_id_seq'::regclass);


SET search_path = backup, pg_catalog;

--
-- Data for Name: categories; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY categories (id, name, color, topic_id, top1_topic_id, top2_topic_id, top1_user_id, top2_user_id, topic_count, created_at, updated_at, user_id, topics_year, topics_month, topics_week, slug) FROM stdin;
1	Discourse	00B355	10	\N	\N	\N	\N	1	2013-01-07 22:01:32.086478	2013-01-07 22:01:32.086478	2	\N	\N	\N	discourse
2	Tech	444	11	\N	\N	\N	\N	0	2013-01-07 22:01:53.670029	2013-01-07 22:01:53.670029	2	\N	\N	\N	tech
3	Pics	FF69B4	12	\N	\N	\N	\N	0	2013-01-07 22:03:02.760975	2013-01-07 22:03:02.760975	2	\N	\N	\N	pics
4	Videos	25aae1	13	\N	\N	\N	\N	1	2013-01-07 22:03:53.820852	2013-01-07 22:03:53.820852	2	\N	\N	\N	videos
\.


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('categories_id_seq', 5, false);


--
-- Data for Name: category_featured_topics; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY category_featured_topics (category_id, topic_id, created_at, updated_at) FROM stdin;
1	14	2013-01-08 21:40:34.69259	2013-01-08 21:40:34.69259
4	15	2013-01-08 21:40:34.69259	2013-01-08 21:40:34.69259
\.


--
-- Data for Name: category_featured_users; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY category_featured_users (id, category_id, user_id, created_at, updated_at) FROM stdin;
33	1	2	2013-01-08 21:40:34.698676	2013-01-08 21:40:34.698676
34	2	2	2013-01-08 21:40:34.70283	2013-01-08 21:40:34.70283
35	3	2	2013-01-08 21:40:34.705954	2013-01-08 21:40:34.705954
36	4	2	2013-01-08 21:40:34.70922	2013-01-08 21:40:34.70922
\.


--
-- Name: category_featured_users_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('category_featured_users_id_seq', 36, true);


--
-- Data for Name: draft_sequences; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY draft_sequences (id, user_id, draft_key, sequence) FROM stdin;
11	2	new_private_message	1
12	2	topic_9	1
14	2	topic_10	1
15	2	topic_11	1
16	2	topic_12	1
17	2	topic_13	1
18	2	topic_14	1
19	2	topic_15	1
20	2	topic_16	1
13	2	new_topic	8
21	2	topic_17	1
\.


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('draft_sequences_id_seq', 21, true);


--
-- Data for Name: drafts; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY drafts (id, user_id, draft_key, data, created_at, updated_at, sequence) FROM stdin;
1	2	new_topic	{"reply":"","action":"createTopic","title":"12345","archetypeId":"regular","metaData":null}	2013-01-07 22:04:20.466975	2013-01-08 21:42:23.32707	7
\.


--
-- Name: drafts_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('drafts_id_seq', 2, false);


--
-- Data for Name: email_logs; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY email_logs (id, to_address, email_type, user_id, created_at, updated_at) FROM stdin;
2	neil.lalonde+admin@gmail.com	signup	2	2013-01-07 21:56:05.125091	2013-01-07 21:56:05.125091
\.


--
-- Name: email_logs_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('email_logs_id_seq', 3, false);


--
-- Data for Name: email_tokens; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY email_tokens (id, user_id, email, token, confirmed, expired, created_at, updated_at) FROM stdin;
2	2	neil.lalonde+admin@gmail.com	c7b41d0779e2c534bd0eae08a30fd551	t	f	2013-01-07 21:55:41.939804	2013-01-07 21:55:41.939804
\.


--
-- Name: email_tokens_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('email_tokens_id_seq', 3, false);


--
-- Data for Name: facebook_user_infos; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY facebook_user_infos (id, user_id, facebook_user_id, username, first_name, last_name, email, gender, name, link, created_at, updated_at) FROM stdin;
\.


--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('facebook_user_infos_id_seq', 1, false);


--
-- Data for Name: incoming_links; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY incoming_links (id, url, referer, domain, topic_id, post_number, created_at, updated_at) FROM stdin;
\.


--
-- Name: incoming_links_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('incoming_links_id_seq', 1, false);


--
-- Data for Name: invites; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY invites (id, invite_key, email, invited_by_id, user_id, redeemed_at, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Name: invites_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('invites_id_seq', 1, false);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY notifications (id, notification_type, user_id, data, read, created_at, updated_at, topic_id, post_number, post_action_id) FROM stdin;
\.


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('notifications_id_seq', 1, false);


--
-- Data for Name: onebox_renders; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY onebox_renders (id, url, cooked, expires_at, created_at, updated_at, preview) FROM stdin;
1	http://www.youtube.com/watch?v=wbF9nLhOqLU	<iframe width="480" height="270" src="http://www.youtube.com/embed/wbF9nLhOqLU?feature=oembed" frameborder="0" allowfullscreen></iframe>	2013-02-07 22:05:59.476184	2013-01-07 22:05:59.483462	2013-01-07 22:05:59.483462	<img src='http://i4.ytimg.com/vi/wbF9nLhOqLU/hqdefault.jpg'>
\.


--
-- Name: onebox_renders_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('onebox_renders_id_seq', 2, false);


--
-- Data for Name: post_action_types; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY post_action_types (name_key, is_flag, icon, created_at, updated_at, id) FROM stdin;
bookmark	f	\N	2013-01-07 21:57:50.153539	2013-01-07 21:57:50.153539	1
like	f	heart	2013-01-07 21:57:50.164792	2013-01-07 21:57:50.164792	2
off_topic	t	\N	2013-01-07 21:57:50.168544	2013-01-07 21:57:50.168544	3
offensive	t	\N	2013-01-07 21:57:50.172436	2013-01-07 21:57:50.172436	4
vote	f	\N	2013-01-07 21:57:50.177984	2013-01-07 21:57:50.177984	5
\.


--
-- Name: post_action_types_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('post_action_types_id_seq', 6, true);


--
-- Data for Name: post_actions; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY post_actions (id, post_id, user_id, post_action_type_id, deleted_at, created_at, updated_at) FROM stdin;
\.


--
-- Name: post_actions_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('post_actions_id_seq', 1, false);


--
-- Data for Name: post_onebox_renders; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY post_onebox_renders (post_id, onebox_render_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: post_replies; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY post_replies (post_id, reply_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: post_timings; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY post_timings (topic_id, post_number, user_id, msecs) FROM stdin;
10	1	2	27077
14	1	2	2001
15	1	2	1003
16	1	2	2000
17	1	2	1003
\.


--
-- Data for Name: posts; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY posts (id, user_id, topic_id, post_number, raw, cooked, created_at, updated_at, reply_to_post_number, cached_version, reply_count, quote_count, reply_below_post_number, deleted_at, off_topic_count, offensive_count, like_count, incoming_link_count, bookmark_count, avg_time, score, reads, post_type, vote_count, sort_order, last_editor_id) FROM stdin;
17	2	17	1	Import already.  I'm waiting!	<p>Import already.  I'm waiting!</p>	2013-01-08 21:42:30.831037	2013-01-08 21:42:30.831037	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0.200000000000000011	1	1	0	1	2
9	2	9	1	Hi there!\n\nWelcome to Discourse. \n\nEnjoy your stay. Let us know if you need anything.\n	<p>Hi there!</p>\n\n<p>Welcome to Discourse. </p>\n\n<p>Enjoy your stay. Let us know if you need anything.  </p>	2013-01-07 21:56:54.616967	2013-01-07 21:56:54.616967	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0	0	1	0	1	2
10	2	10	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-01-07 22:01:32.173703	2013-01-07 22:01:32.173703	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0	0	1	0	1	2
11	2	11	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-01-07 22:01:53.720331	2013-01-07 22:01:53.720331	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0	0	1	0	1	2
12	2	12	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-01-07 22:03:02.816133	2013-01-07 22:03:02.816133	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0	0	1	0	1	2
14	2	14	1	Welcome to the Discourse sandbox!  Play around and try all the features.	<p>Welcome to the Discourse sandbox!  Play around and try all the features.</p>	2013-01-07 22:04:47.515687	2013-01-07 22:04:47.515687	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0.200000000000000011	1	1	0	1	2
13	2	13	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-01-07 22:03:53.869432	2013-01-07 22:03:53.869432	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0	0	1	0	1	2
15	2	15	1	Poor Charlie:\n\nhttp://www.youtube.com/watch?v=wbF9nLhOqLU\n	<p>Poor Charlie:</p>\n\n<p><iframe width="480" height="270" src="http://www.youtube.com/embed/wbF9nLhOqLU?feature=oembed" frameborder="0" allowfullscreen></iframe>  </p>	2013-01-07 22:06:26.929342	2013-01-07 22:06:26.929342	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0.200000000000000011	1	1	0	1	2
16	2	16	1	asf asfas fas fsadf	<p>asf asfas fas fsadf</p>	2013-01-08 20:48:59.869197	2013-01-08 20:48:59.869197	\N	1	0	0	\N	\N	0	0	0	0	0	\N	0.200000000000000011	1	1	0	1	2
\.


--
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('posts_id_seq', 17, true);


--
-- Data for Name: site_customizations; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY site_customizations (id, name, stylesheet, header, "position", user_id, enabled, key, created_at, updated_at, override_default_style, stylesheet_baked) FROM stdin;
\.


--
-- Name: site_customizations_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('site_customizations_id_seq', 1, false);


--
-- Data for Name: site_settings; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY site_settings (id, name, data_type, value, created_at, updated_at) FROM stdin;
1	system_username	1	admin	2013-01-07 21:57:34.992013	2013-01-07 21:57:34.992013
2	title	1	Try Discourse	2013-01-07 21:58:44.645732	2013-01-07 21:58:44.645732
3	allow_import	5	t	2013-01-08 19:12:11.048611	2013-01-08 19:12:11.048611
\.


--
-- Name: site_settings_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('site_settings_id_seq', 4, false);


--
-- Data for Name: topic_allowed_users; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY topic_allowed_users (id, user_id, topic_id, created_at, updated_at) FROM stdin;
2	2	9	2013-01-07 21:56:54.295319	2013-01-07 21:56:54.295319
\.


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('topic_allowed_users_id_seq', 3, false);


--
-- Data for Name: topic_invites; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY topic_invites (id, topic_id, invite_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: topic_invites_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('topic_invites_id_seq', 1, false);


--
-- Data for Name: topic_link_clicks; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY topic_link_clicks (id, topic_link_id, user_id, ip, created_at, updated_at) FROM stdin;
\.


--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('topic_link_clicks_id_seq', 1, false);


--
-- Data for Name: topic_links; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY topic_links (id, topic_id, post_id, user_id, url, domain, internal, link_topic_id, created_at, updated_at, reflection, clicks, link_post_id) FROM stdin;
\.


--
-- Name: topic_links_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('topic_links_id_seq', 1, false);


--
-- Data for Name: topic_users; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY topic_users (user_id, topic_id, starred, posted, last_read_post_number, seen_post_count, starred_at, muted_at, last_visited_at, first_visited_at, notifications, notifications_changed_at, notifications_reason_id) FROM stdin;
2	9	f	t	1	1	\N	\N	2013-01-07 21:56:54	2013-01-07 21:56:54	1	2013-01-07 21:56:54	1
2	10	f	t	1	1	\N	\N	2013-01-07 22:01:32	2013-01-07 22:01:32	1	2013-01-07 22:01:32	1
2	11	f	t	1	1	\N	\N	2013-01-07 22:01:53	2013-01-07 22:01:53	1	2013-01-07 22:01:53	1
2	12	f	t	1	1	\N	\N	2013-01-07 22:03:02	2013-01-07 22:03:02	1	2013-01-07 22:03:02	1
2	13	f	t	1	1	\N	\N	2013-01-07 22:03:53	2013-01-07 22:03:53	1	2013-01-07 22:03:53	1
2	14	f	t	1	1	\N	\N	2013-01-07 22:04:47	2013-01-07 22:04:47	1	2013-01-07 22:04:47	1
2	15	f	t	1	1	\N	\N	2013-01-07 22:06:27	2013-01-07 22:06:26	1	2013-01-07 22:06:26	1
2	16	f	t	1	1	\N	\N	2013-01-08 20:49:00	2013-01-08 20:48:59	1	2013-01-08 20:48:59	1
2	17	f	t	1	1	\N	\N	2013-01-08 21:42:31	2013-01-08 21:42:30	1	2013-01-08 21:42:30	1
\.


--
-- Data for Name: topics; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY topics (id, title, last_posted_at, created_at, updated_at, views, posts_count, user_id, last_post_user_id, reply_count, featured_user1_id, featured_user2_id, featured_user3_id, avg_time, deleted_at, highest_post_number, image_url, off_topic_count, offensive_count, like_count, incoming_link_count, bookmark_count, star_count, category_id, visible, moderator_posts_count, closed, pinned, archived, bumped_at, sub_tag, has_best_of, meta_data, vote_count, archetype, featured_user4_id) FROM stdin;
14	Try All The Things!	2013-01-07 22:04:47.515687	2013-01-07 22:04:47.403684	2013-01-07 22:04:47.77737	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	1	t	0	f	f	f	2013-01-07 22:04:47.403364	\N	f	\N	0	regular	\N
12	Pics	2013-01-07 22:03:02.816133	2013-01-07 22:03:02.765939	2013-01-07 22:03:03.014387	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	3	f	0	f	f	f	2013-01-07 22:03:02.765539	\N	f	\N	0	regular	\N
15	Charlie The Unicorn 4	2013-01-07 22:06:26.929342	2013-01-07 22:06:26.856165	2013-01-07 22:06:27.152654	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	4	t	0	f	f	f	2013-01-07 22:06:26.855845	\N	f	\N	0	regular	\N
10	Discourse	2013-01-07 22:01:32.173703	2013-01-07 22:01:32.091105	2013-01-07 22:01:32.286535	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	1	f	0	f	f	f	2013-01-07 22:01:32.09083	\N	f	\N	0	regular	\N
11	Tech	2013-01-07 22:01:53.720331	2013-01-07 22:01:53.673426	2013-01-07 22:01:53.928507	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	2	f	0	f	f	f	2013-01-07 22:01:53.673177	\N	f	\N	0	regular	\N
13	Videos	2013-01-07 22:03:53.869432	2013-01-07 22:03:53.824692	2013-01-07 22:03:54.107101	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	4	f	0	f	f	f	2013-01-07 22:03:53.824403	\N	f	\N	0	regular	\N
9	Welcome to Discourse!	2013-01-07 21:56:54.616967	2013-01-07 21:56:54.281529	2013-01-07 21:56:54.81107	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	\N	t	0	f	f	f	2013-01-07 21:56:54.280898	\N	f	\N	0	private_message	\N
16	Import THIS!	2013-01-08 20:48:59.869197	2013-01-08 20:48:59.434023	2013-01-08 20:49:00.07296	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	\N	t	0	f	f	f	2013-01-08 20:48:59.431235	\N	f	\N	0	regular	\N
17	12345	2013-01-08 21:42:30.831037	2013-01-08 21:42:30.500599	2013-01-08 21:42:31.097416	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	0	\N	t	0	f	f	f	2013-01-08 21:42:30.500425	\N	f	\N	0	regular	\N
\.


--
-- Name: topics_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('topics_id_seq', 17, true);


--
-- Data for Name: trust_levels; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY trust_levels (id, name_key, created_at, updated_at) FROM stdin;
1	none	2013-01-07 21:57:50.20362	2013-01-07 21:57:50.20362
2	basic	2013-01-07 21:57:50.209007	2013-01-07 21:57:50.209007
\.


--
-- Name: trust_levels_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('trust_levels_id_seq', 3, true);


--
-- Data for Name: twitter_user_infos; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY twitter_user_infos (id, user_id, screen_name, twitter_user_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('twitter_user_infos_id_seq', 1, false);


--
-- Data for Name: uploads; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY uploads (id, user_id, topic_id, original_filename, filesize, width, height, url, created_at, updated_at) FROM stdin;
\.


--
-- Name: uploads_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('uploads_id_seq', 1, false);


--
-- Data for Name: user_actions; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY user_actions (id, action_type, user_id, target_topic_id, target_post_id, target_user_id, acting_user_id, created_at, updated_at) FROM stdin;
23	12	2	9	-1	\N	2	2013-01-07 21:56:54.281529	2013-01-07 21:56:54.436811
24	4	2	10	-1	\N	2	2013-01-07 22:01:32.091105	2013-01-07 22:01:32.114801
27	4	2	11	-1	\N	2	2013-01-07 22:01:53.673426	2013-01-07 22:01:53.696275
30	4	2	12	-1	\N	2	2013-01-07 22:03:02.765939	2013-01-07 22:03:02.790958
33	4	2	13	-1	\N	2	2013-01-07 22:03:53.824692	2013-01-07 22:03:53.848021
36	4	2	14	-1	\N	2	2013-01-07 22:04:47.403684	2013-01-07 22:04:47.464741
39	4	2	15	-1	\N	2	2013-01-07 22:06:26.856165	2013-01-07 22:06:26.902676
40	4	2	16	-1	\N	2	2013-01-08 20:48:59.434023	2013-01-08 20:48:59.575729
43	4	2	17	-1	\N	2	2013-01-08 21:42:30.500599	2013-01-08 21:42:30.591186
\.


--
-- Name: user_actions_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('user_actions_id_seq', 45, true);


--
-- Data for Name: user_open_ids; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY user_open_ids (id, user_id, email, url, created_at, updated_at, active) FROM stdin;
\.


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('user_open_ids_id_seq', 1, false);


--
-- Data for Name: user_visits; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY user_visits (id, user_id, visited_at) FROM stdin;
2	2	2013-01-07
3	2	2013-01-08
\.


--
-- Name: user_visits_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('user_visits_id_seq', 4, false);


--
-- Data for Name: users; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY users (id, username, created_at, updated_at, name, bio_raw, seen_notification_id, last_posted_at, email, password_hash, salt, active, username_lower, auth_token, last_seen_at, website, admin, moderator, last_emailed_at, email_digests, trust_level_id, bio_cooked, email_private_messages, email_direct, approved, approved_by_id, approved_at, topics_entered, posts_read_count, digest_after_days, previous_visit_at) FROM stdin;
2	admin	2013-01-07 21:55:41.905352	2013-01-08 21:42:30.482177	Admin	\N	0	2013-01-08 21:42:30.831037	neil.lalonde+admin@gmail.com	d709cbd1fc4b9a3fe0052606fc84ff3c32af55a94442e5df26f10697c5e03f1c	1cdd5f082f3c576787addad76b65fb21	t	admin	87610f67099c5a6d71c6a7b1551389a7	2013-01-08 21:42:30	\N	t	f	2013-01-07 21:56:05.123178	t	1	\N	t	t	f	\N	\N	3	4	7	2013-01-08 20:48:47
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('users_id_seq', 3, false);


--
-- Data for Name: versions; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY versions (id, versioned_id, versioned_type, user_id, user_type, user_name, modifications, number, reverted_from, tag, created_at, updated_at) FROM stdin;
\.


--
-- Name: versions_id_seq; Type: SEQUENCE SET; Schema: backup; Owner: vagrant
--

SELECT pg_catalog.setval('versions_id_seq', 1, false);


--
-- Data for Name: views; Type: TABLE DATA; Schema: backup; Owner: vagrant
--

COPY views (parent_id, parent_type, ip, viewed_at, user_id) FROM stdin;
14	Topic	167772674	2013-01-07 22:00:00	2
15	Topic	167772674	2013-01-07 22:00:00	2
16	Topic	1677705620	2013-01-09 01:00:00	2
17	Topic	1677705620	2013-01-09 02:00:00	2
\.


SET search_path = public, pg_catalog;

--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY categories (id, name, color, topic_id, topic_count, created_at, updated_at, user_id, topics_year, topics_month, topics_week, slug, description, text_color) FROM stdin;
4	videos	25aae1	13	2	2013-01-07 22:03:53.820852	2013-02-04 19:55:55.364368	2	2	2	1	videos	\N	FFFFFF
3	pics	FF69B4	12	0	2013-01-07 22:03:02.760975	2013-02-04 19:55:55.387911	2	0	0	0	pics	\N	FFFFFF
2	tech	444	11	2	2013-01-07 22:01:53.670029	2013-02-04 19:55:55.398705	2	1	1	1	tech	\N	FFFFFF
5	general	C0C0C0	41	0	2013-02-04 19:28:30.805162	2013-02-04 19:55:55.406562	2	\N	\N	\N	general	\N	FFFFFF
6	gaming	800080	42	0	2013-02-04 19:29:11.272227	2013-02-04 19:55:55.414732	2	\N	\N	\N	gaming	\N	FFFFFF
7	music	DAA520	43	0	2013-02-04 19:29:52.518789	2013-02-04 19:55:55.423767	2	\N	\N	\N	music	\N	FFFFFF
8	movies	B22222	44	0	2013-02-04 19:30:35.904928	2013-02-04 19:55:55.433655	2	\N	\N	\N	movies	\N	FFFFFF
9	sports	0000FF	45	0	2013-02-04 19:31:27.093797	2013-02-04 19:55:55.442462	2	\N	\N	\N	sports	\N	FFFFFF
10	school	D2691E	46	0	2013-02-04 19:32:14.568831	2013-02-04 19:55:55.449591	2	\N	\N	\N	school	\N	FFFFFF
11	pets	F08080	47	0	2013-02-04 19:34:04.660953	2013-02-04 19:55:55.456745	2	\N	\N	\N	pets	\N	FFFFFF
1	discourse	00B355	10	4	2013-01-07 22:01:32.086478	2013-02-04 19:55:55.463953	2	2	2	1	discourse	\N	FFFFFF
\.


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('categories_id_seq', 11, true);


--
-- Data for Name: categories_search; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY categories_search (id, search_data) FROM stdin;
4	'video':1
3	'pic':1
2	'tech':1
5	'general':1
6	'game':1
7	'music':1
8	'movi':1
9	'sport':1
10	'school':1
11	'pet':1
1	'discours':1
\.


--
-- Data for Name: category_featured_topics; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY category_featured_topics (category_id, topic_id, created_at, updated_at) FROM stdin;
4	15	2013-02-04 19:54:38.543905	2013-02-04 19:54:38.543905
4	27	2013-02-04 19:54:38.543905	2013-02-04 19:54:38.543905
2	39	2013-02-04 19:54:38.543905	2013-02-04 19:54:38.543905
2	25	2013-02-04 19:54:38.543905	2013-02-04 19:54:38.543905
1	52	2013-02-04 20:03:21.670448	2013-02-04 20:03:21.670448
1	49	2013-02-04 20:03:21.670448	2013-02-04 20:03:21.670448
1	14	2013-02-04 20:03:21.670448	2013-02-04 20:03:21.670448
\.


--
-- Data for Name: category_featured_users; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY category_featured_users (id, category_id, user_id, created_at, updated_at) FROM stdin;
22837	4	20	2013-02-04 19:54:38.548574	2013-02-04 19:54:38.548574
22838	4	2	2013-02-04 19:54:38.549876	2013-02-04 19:54:38.549876
22839	4	9	2013-02-04 19:54:38.55058	2013-02-04 19:54:38.55058
22840	4	22	2013-02-04 19:54:38.551293	2013-02-04 19:54:38.551293
22841	4	12	2013-02-04 19:54:38.552014	2013-02-04 19:54:38.552014
22842	3	2	2013-02-04 19:54:38.553827	2013-02-04 19:54:38.553827
22843	2	11	2013-02-04 19:54:38.555747	2013-02-04 19:54:38.555747
22844	2	19	2013-02-04 19:54:38.556461	2013-02-04 19:54:38.556461
22845	2	22	2013-02-04 19:54:38.557145	2013-02-04 19:54:38.557145
22846	2	2	2013-02-04 19:54:38.557854	2013-02-04 19:54:38.557854
22847	5	2	2013-02-04 19:54:38.559602	2013-02-04 19:54:38.559602
22848	6	2	2013-02-04 19:54:38.561385	2013-02-04 19:54:38.561385
22849	7	2	2013-02-04 19:54:38.562963	2013-02-04 19:54:38.562963
22850	8	2	2013-02-04 19:54:38.564598	2013-02-04 19:54:38.564598
22851	9	2	2013-02-04 19:54:38.566183	2013-02-04 19:54:38.566183
22852	10	2	2013-02-04 19:54:38.568043	2013-02-04 19:54:38.568043
22853	11	2	2013-02-04 19:54:38.569723	2013-02-04 19:54:38.569723
22854	1	2	2013-02-04 19:54:38.571419	2013-02-04 19:54:38.571419
22855	1	20	2013-02-04 19:54:38.572145	2013-02-04 19:54:38.572145
22856	1	7	2013-02-04 19:54:38.572782	2013-02-04 19:54:38.572782
\.


--
-- Name: category_featured_users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('category_featured_users_id_seq', 22856, true);


--
-- Data for Name: draft_sequences; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY draft_sequences (id, user_id, draft_key, sequence) FROM stdin;
12	2	topic_9	1
14	2	topic_10	1
15	2	topic_11	1
16	2	topic_12	1
17	2	topic_13	1
18	2	topic_14	1
19	2	topic_15	1
20	2	topic_16	1
21	2	topic_17	1
22	2	topic_18	1
23	2	topic_19	1
24	2	topic_20	1
25	2	topic_21	1
26	2	topic_22	1
43	19	topic_34	34
29	11	new_topic	2
44	2	topic_35	1
45	20	topic_15	1
31	11	topic_26	7
32	9	new_topic	1
47	11	topic_27	3
34	2	topic_28	1
35	2	topic_29	1
46	20	topic_27	7
33	9	topic_27	7
36	14	topic_26	1
37	12	topic_27	1
48	20	topic_26	1
38	2	topic_30	1
49	20	new_topic	1
39	2	topic_31	1
51	7	topic_36	1
30	11	topic_25	9
40	2	topic_32	1
52	2	topic_36	1
42	19	new_topic	1
50	20	topic_36	2
53	2	topic_37	1
54	22	topic_27	1
55	2	topic_38	1
56	22	new_topic	1
57	22	topic_39	1
11	2	new_private_message	17
58	2	topic_40	1
59	23	topic_26	3
60	2	topic_41	1
61	2	topic_42	1
62	2	topic_43	1
63	2	topic_44	1
64	2	topic_45	1
65	2	topic_46	1
13	2	new_topic	13
66	2	topic_47	1
67	23	new_topic	1
68	23	topic_48	1
69	19	topic_39	1
70	22	topic_48	1
71	19	topic_15	1
73	7	topic_49	1
74	19	topic_48	1
75	7	topic_50	1
76	7	topic_51	1
72	7	new_topic	4
77	7	topic_52	1
78	24	new_topic	1
79	24	topic_53	4
\.


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('draft_sequences_id_seq', 79, true);


--
-- Data for Name: drafts; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY drafts (id, user_id, draft_key, data, created_at, updated_at, sequence) FROM stdin;
41	24	topic_53	{"reply":"If you can see this, you've successfully set up a vagrant environment for discourse. By default this install includes a few topics and accounts to play around with.\\n\\nIf you're looking for an account to test out, you can create one or log in as one of the following with the password: `password`.\\n\\n- eviltrout **an admin**\\n- jatwood **regular user**\\n\\nFor the latest info, please check the [README.md](https://github.com/discourse/discourse/blob/master/README.md) in the project. Thanks for checking out Discourse!\\n\\n---\\n\\n### The Production Dataset\\n\\nIf you want to get started without the test topics, this install also includes a base production database image. To install it execute the following commands:\\n\\n```bash\\nvagrant ssh\\ncd /vagrant\\npsql discourse_development < pg_dumps/production-image.sql\\nrake db:migrate\\n```\\n\\nIf you change your mind and want to use the test data again, just execute the above but using `pg_dumps/development-image.sql` instead.\\n","action":"edit","title":"Congratulations on getting Vagrant up!","postId":77,"archetypeId":"regular","metaData":null}	2013-03-20 22:54:39.745896	2013-03-20 22:59:05.812297	3
\.


--
-- Name: drafts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('drafts_id_seq', 41, true);


--
-- Data for Name: email_logs; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY email_logs (id, to_address, email_type, user_id, created_at, updated_at) FROM stdin;
2	fake@mailinator.com	signup	2	2013-01-07 21:56:05.125091	2013-01-07 21:56:05.125091
3	fake@mailinator.com	signup	3	2013-01-24 08:55:35.312751	2013-01-24 08:55:35.312751
4	fake@mailinator.com	private_message	3	2013-01-24 09:00:43.915756	2013-01-24 09:00:43.915756
5	fake@mailinator.com	signup	4	2013-01-24 09:49:19.157949	2013-01-24 09:49:19.157949
6	fake@mailinator.com	forgot_password	4	2013-01-24 10:08:09.42342	2013-01-24 10:08:09.42342
7	fake@mailinator.com	forgot_password	4	2013-01-24 23:57:01.900583	2013-01-24 23:57:01.900583
8	fake@mailinator.com	private_message	5	2013-01-29 05:15:32.651942	2013-01-29 05:15:32.651942
9	fake@mailinator.com	private_message	6	2013-01-29 05:25:59.676633	2013-01-29 05:25:59.676633
10	fake@mailinator.com	signup	7	2013-01-31 19:43:10.998018	2013-01-31 19:43:10.998018
11	fake@mailinator.com	private_message	7	2013-01-31 19:46:05.422548	2013-01-31 19:46:05.422548
12	fake@mailinator.com	signup	8	2013-01-31 20:11:44.754207	2013-01-31 20:11:44.754207
13	fake@mailinator.com	signup	9	2013-01-31 20:15:03.412425	2013-01-31 20:15:03.412425
14	fake@mailinator.com	private_message	9	2013-01-31 20:15:19.687282	2013-01-31 20:15:19.687282
15	fake@mailinator.com	signup	10	2013-01-31 20:24:22.41527	2013-01-31 20:24:22.41527
16	fake@mailinator.com	signup	11	2013-01-31 20:25:26.381932	2013-01-31 20:25:26.381932
17	fake@mailinator.com	private_message	11	2013-01-31 20:25:34.115718	2013-01-31 20:25:34.115718
18	fake@mailinator.com	signup	12	2013-01-31 20:38:34.401339	2013-01-31 20:38:34.401339
19	fake@mailinator.com	private_message	12	2013-01-31 20:38:44.606192	2013-01-31 20:38:44.606192
20	fake@mailinator.com	signup	13	2013-01-31 21:51:14.651664	2013-01-31 21:51:14.651664
21	fake@mailinator.com	private_message	13	2013-01-31 21:51:25.424999	2013-01-31 21:51:25.424999
22	fake@mailinator.com	signup	14	2013-01-31 21:54:31.794194	2013-01-31 21:54:31.794194
23	fake@mailinator.com	private_message	14	2013-01-31 21:54:38.897883	2013-01-31 21:54:38.897883
24	fake@mailinator.com	forgot_password	14	2013-01-31 21:59:40.781187	2013-01-31 21:59:40.781187
25	fake@mailinator.com	private_message	15	2013-01-31 22:19:00.664831	2013-01-31 22:19:00.664831
26	fake@mailinator.com	signup	16	2013-01-31 23:45:18.330603	2013-01-31 23:45:18.330603
27	fake@mailinator.com	private_message	16	2013-01-31 23:45:28.247846	2013-01-31 23:45:28.247846
28	fake@mailinator.com	signup	19	2013-02-01 01:28:51.946626	2013-02-01 01:28:51.946626
29	fake@mailinator.com	private_message	19	2013-02-01 01:29:41.614969	2013-02-01 01:29:41.614969
30	fake@mailinator.com	forgot_password	19	2013-02-01 02:34:38.681271	2013-02-01 02:34:38.681271
31	fake@mailinator.com	signup	20	2013-02-01 04:35:16.348167	2013-02-01 04:35:16.348167
32	fake@mailinator.com	private_message	20	2013-02-01 04:37:19.41906	2013-02-01 04:37:19.41906
33	fake@mailinator.com	digest	3	2013-02-01 06:00:01.280545	2013-02-01 06:00:01.280545
34	fake@mailinator.com	digest	4	2013-02-01 06:00:01.289638	2013-02-01 06:00:01.289638
35	fake@mailinator.com	user_replied	20	2013-02-01 14:07:05.062503	2013-02-01 14:07:05.062503
36	fake@mailinator.com	user_replied	11	2013-02-01 14:13:35.357924	2013-02-01 14:13:35.357924
37	fake@mailinator.com	signup	21	2013-02-04 18:10:15.548944	2013-02-04 18:10:15.548944
38	fake@mailinator.com	signup	22	2013-02-04 18:20:34.08452	2013-02-04 18:20:34.08452
39	fake@mailinator.com	user_replied	20	2013-02-04 18:26:15.8286	2013-02-04 18:26:15.8286
40	fake@mailinator.com	authorize_email	22	2013-02-04 19:36:52.351034	2013-02-04 19:36:52.351034
41	fake@mailinator.com	authorize_email	19	2013-02-04 19:46:59.280597	2013-02-04 19:46:59.280597
\.


--
-- Name: email_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('email_logs_id_seq', 41, true);


--
-- Data for Name: email_tokens; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY email_tokens (id, user_id, email, token, confirmed, expired, created_at, updated_at) FROM stdin;
\.


--
-- Name: email_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('email_tokens_id_seq', 28, true);


--
-- Data for Name: facebook_user_infos; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY facebook_user_infos (id, user_id, facebook_user_id, username, first_name, last_name, email, gender, name, link, created_at, updated_at) FROM stdin;
\.


--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('facebook_user_infos_id_seq', 1, true);


--
-- Data for Name: github_user_infos; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY github_user_infos (id, user_id, screen_name, github_user_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: github_user_infos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('github_user_infos_id_seq', 1, false);


--
-- Data for Name: incoming_links; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY incoming_links (id, url, referer, domain, topic_id, post_number, created_at, updated_at) FROM stdin;
1	http://localhost:4000/	http://localhost:4000/t/making-localhost:4000-a-staged-forum/318/7	localhost:4000	\N	\N	2013-01-24 10:00:54.698723	2013-01-24 10:00:54.698723
2	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/9	localhost:4000	\N	\N	2013-01-31 20:06:37.820675	2013-01-31 20:06:37.820675
3	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/8	localhost:4000	\N	\N	2013-01-31 20:34:50.903946	2013-01-31 20:34:50.903946
4	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/8	localhost:4000	\N	\N	2013-01-31 20:35:08.226199	2013-01-31 20:35:08.226199
5	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/9	localhost:4000	\N	\N	2013-01-31 21:08:03.601227	2013-01-31 21:08:03.601227
6	http://localhost:4000/t/are-there-people-here-who-use-a-mobile-device-for-all-their-work/25	http://localhost:4000/t/testing-needed-before-launch/706/9	localhost:4000	25	\N	2013-01-31 21:08:42.545586	2013-01-31 21:08:42.545586
7	http://localhost:4000/t/why-is-uninhabited-land-in-the-us-at-least-in-ca-so-closed-off/26	http://localhost:4000/t/testing-needed-before-launch/706/18	localhost:4000	26	\N	2013-01-31 21:36:16.970567	2013-01-31 21:36:16.970567
8	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/6	localhost:4000	\N	\N	2013-01-31 21:50:08.062481	2013-01-31 21:50:08.062481
9	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/9	localhost:4000	\N	\N	2013-01-31 22:52:12.149477	2013-01-31 22:52:12.149477
10	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/8	localhost:4000	\N	\N	2013-01-31 23:39:12.106416	2013-01-31 23:39:12.106416
11	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/8	localhost:4000	\N	\N	2013-01-31 23:44:10.725061	2013-01-31 23:44:10.725061
12	http://localhost:4000/	http://localhost:4000/t/testing-needed-before-launch/706/7	localhost:4000	\N	\N	2013-02-01 06:27:39.53889	2013-02-01 06:27:39.53889
13	http://localhost:4000/t/most-important-sci-fi-movie-of-the-2000s/27/2	http://localhost:4000/t/localhost:4000/772/4	localhost:4000	27	2	2013-02-04 18:19:39.61862	2013-02-04 18:19:39.61862
14	http://localhost:4000/t/most-important-sci-fi-movie-of-the-2000s/27/2	http://localhost:4000/t/localhost:4000/772/4	localhost:4000	27	2	2013-02-04 18:22:34.943688	2013-02-04 18:22:34.943688
15	http://localhost:4000/t/most-important-sci-fi-movie-of-the-2000s/27/2	http://localhost:4000/t/localhost:4000/772/2	localhost:4000	27	2	2013-02-04 18:44:58.243921	2013-02-04 18:44:58.243921
16	http://localhost:4000/t/most-important-sci-fi-movie-of-the-2000s/27/2	http://localhost:4000/t/localhost:4000/772/3	localhost:4000	27	2	2013-02-04 19:53:53.953557	2013-02-04 19:53:53.953557
\.


--
-- Name: incoming_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('incoming_links_id_seq', 16, true);


--
-- Data for Name: invites; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY invites (id, invite_key, email, invited_by_id, user_id, redeemed_at, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Name: invites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('invites_id_seq', 1, false);


--
-- Data for Name: message_bus; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY message_bus (id, name, context, data, created_at) FROM stdin;
\.


--
-- Name: message_bus_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('message_bus_id_seq', 12501, true);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY notifications (id, notification_type, user_id, data, read, created_at, updated_at, topic_id, post_number, post_action_id) FROM stdin;
1	6	3	{"topic_title":"Welcome to Try Discourse!","display_username":"Admin"}	f	2013-01-24 09:00:43.534708	2013-01-24 09:00:43.534708	16	1	\N
20	9	9	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"pekka.gaiser"}	f	2013-02-01 14:06:39.112849	2013-02-01 14:06:39.112849	27	5	\N
46	5	22	{"topic_title":"A bear, however hard he tries, grows tubby without exercise.","display_username":"stienman"}	f	2013-02-04 19:49:56.553679	2013-02-04 19:49:56.553679	48	2	8
3	6	6	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-01-29 05:25:59.498576	2013-01-29 05:25:59.498576	18	1	\N
10	9	11	{"topic_title":"Why is uninhabited land in the US so closed off?","display_username":"jessamyn"}	t	2013-01-31 22:10:16.621595	2013-01-31 22:10:16.621595	26	2	\N
24	9	11	{"topic_title":"Why is uninhabited land in the US so closed off?","display_username":"Clay"}	t	2013-02-01 14:17:38.376739	2013-02-01 14:17:38.376739	26	3	\N
40	6	21	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-02-04 18:27:44.290551	2013-02-04 18:27:44.290551	38	1	\N
21	2	11	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"Clay"}	t	2013-02-01 14:12:42.263558	2013-02-01 14:12:42.263558	27	6	\N
33	5	9	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"johnsmith"}	f	2013-02-01 18:57:00.249856	2013-02-01 18:57:00.249856	27	2	5
22	9	9	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"Clay"}	f	2013-02-01 14:12:42.28522	2013-02-01 14:12:42.28522	27	6	\N
48	5	19	{"topic_title":"A bear, however hard he tries, grows tubby without exercise.","display_username":"stienman"}	f	2013-02-04 19:57:43.092899	2013-02-04 19:57:43.092899	48	3	9
19	2	20	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"pekka.gaiser"}	t	2013-02-01 14:06:39.085218	2013-02-01 14:06:39.085218	27	5	\N
41	6	23	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	f	2013-02-04 18:41:40.787865	2013-02-04 18:41:40.787865	40	1	\N
23	9	9	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"Clay"}	f	2013-02-01 14:14:08.619739	2013-02-01 14:14:08.619739	27	7	\N
4	6	7	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-01-31 19:46:05.00192	2013-01-31 19:46:05.00192	19	1	\N
5	6	9	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	f	2013-01-31 20:15:19.279428	2013-01-31 20:15:19.279428	20	1	\N
6	6	11	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	f	2013-01-31 20:25:33.810593	2013-01-31 20:25:33.810593	21	1	\N
7	6	12	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-01-31 20:38:43.759198	2013-01-31 20:38:43.759198	22	1	\N
8	6	13	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	f	2013-01-31 21:51:25.11693	2013-01-31 21:51:25.11693	28	1	\N
9	6	14	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	f	2013-01-31 21:54:37.826378	2013-01-31 21:54:37.826378	29	1	\N
11	9	9	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"lowell"}	f	2013-01-31 22:11:11.139251	2013-01-31 22:11:11.139251	27	3	\N
12	5	14	{"topic_title":"Why is uninhabited land in the US so closed off?","display_username":"Gnoggo"}	f	2013-01-31 22:16:50.641091	2013-01-31 22:16:50.641091	26	2	1
13	6	15	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-01-31 22:18:59.469914	2013-01-31 22:18:59.469914	30	1	\N
32	9	20	{"topic_title":"I have come to the conclusion that try2 is running old Discourse software","display_username":"johnsmith"}	t	2013-02-01 18:56:27.414056	2013-02-01 18:56:27.414056	36	2	\N
25	5	20	{"topic_title":"Why is uninhabited land in the US so closed off?","display_username":"pekka.gaiser"}	f	2013-02-01 16:56:34.167594	2013-02-01 16:56:34.167594	26	3	4
34	9	20	{"topic_title":"I have come to the conclusion that try2 is running old Discourse software","display_username":"admin"}	t	2013-02-04 15:17:53.639883	2013-02-04 15:17:53.639883	36	3	\N
42	9	11	{"topic_title":"Why is uninhabited land in the US so closed off?","display_username":"stienman"}	f	2013-02-04 18:56:50.053648	2013-02-04 18:56:50.053648	26	4	\N
35	5	2	{"topic_title":"I have come to the conclusion that try2 is running old Discourse software","display_username":"Clay"}	t	2013-02-04 18:00:35.895172	2013-02-04 18:00:35.895172	36	3	6
14	6	16	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-01-31 23:45:27.97688	2013-01-31 23:45:27.97688	31	1	\N
15	6	19	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	f	2013-02-01 01:29:40.649454	2013-02-01 01:29:40.649454	32	1	\N
16	6	20	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-02-01 04:37:18.178938	2013-02-01 04:37:18.178938	35	1	\N
18	9	9	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"Clay"}	f	2013-02-01 04:38:45.49317	2013-02-01 04:38:45.49317	27	4	\N
36	6	22	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-02-04 18:20:43.035809	2013-02-04 18:20:43.035809	37	1	\N
37	5	20	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"clay_7"}	f	2013-02-04 18:21:02.644953	2013-02-04 18:21:02.644953	27	7	7
38	2	20	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"clay_7"}	f	2013-02-04 18:21:14.442755	2013-02-04 18:21:14.442755	27	8	\N
47	2	23	{"topic_title":"A bear, however hard he tries, grows tubby without exercise.","display_username":"gknauss"}	t	2013-02-04 19:51:59.988748	2013-02-04 19:51:59.988748	48	3	\N
39	9	9	{"topic_title":"Most important Sci-Fi movie of the 2000's?","display_username":"clay_7"}	f	2013-02-04 18:21:14.468819	2013-02-04 18:21:14.468819	27	8	\N
17	9	2	{"topic_title":"Charlie The Unicorn 4","display_username":"Clay"}	t	2013-02-01 04:37:48.682511	2013-02-01 04:37:48.682511	15	2	\N
44	9	23	{"topic_title":"A bear, however hard he tries, grows tubby without exercise.","display_username":"clay_7"}	t	2013-02-04 19:43:40.589108	2013-02-04 19:43:40.589108	48	2	\N
43	2	22	{"topic_title":"MAC vs. Mac and the misuse of words","display_username":"gknauss1"}	t	2013-02-04 19:40:13.769063	2013-02-04 19:40:13.769063	39	2	\N
45	2	2	{"topic_title":"Charlie The Unicorn 4","display_username":"gknauss"}	t	2013-02-04 19:44:27.383482	2013-02-04 19:44:27.383482	15	3	\N
2	6	5	{"topic_title":"Welcome to Try Discourse!","display_username":"admin"}	t	2013-01-29 05:15:31.825578	2013-01-29 05:15:31.825578	17	1	\N
\.


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('notifications_id_seq', 48, true);


--
-- Data for Name: onebox_renders; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY onebox_renders (id, url, cooked, expires_at, created_at, updated_at, preview) FROM stdin;
1	http://www.youtube.com/watch?v=wbF9nLhOqLU	<iframe width="480" height="270" src="http://www.youtube.com/embed/wbF9nLhOqLU?feature=oembed" frameborder="0" allowfullscreen></iframe>	2013-02-07 22:05:59.476184	2013-01-07 22:05:59.483462	2013-01-07 22:05:59.483462	<img src='http://i4.ytimg.com/vi/wbF9nLhOqLU/hqdefault.jpg'>
4	http://www.youtube.com/watch?feature=player_embedded&v=qBjLW5_dGAM	<iframe width="459" height="344" src="http://www.youtube.com/embed/qBjLW5_dGAM?feature=oembed" frameborder="0" allowfullscreen></iframe>	2013-02-25 02:42:46.763795	2013-01-25 02:42:46.765326	2013-01-25 02:42:46.765326	<img src='http://i2.ytimg.com/vi/qBjLW5_dGAM/hqdefault.jpg'>
6	http://youtu.be/2VT2apoX90o	<iframe width="480" height="270" src="http://www.youtube.com/embed/2VT2apoX90o?feature=oembed" frameborder="0" allowfullscreen></iframe>	2013-02-28 21:47:21.159066	2013-01-31 21:47:21.167985	2013-01-31 21:47:21.167985	<img src='http://i3.ytimg.com/vi/2VT2apoX90o/hqdefault.jpg'>
7	http://windmillnetworking.wpengine.netdna-cdn.com/wp-content/uploads/2009/03/Private-Property-Keep-Out1.jpg	<a href='http://windmillnetworking.wpengine.netdna-cdn.com/wp-content/uploads/2009/03/Private-Property-Keep-Out1.jpg' target='_blank'><img src='http://windmillnetworking.wpengine.netdna-cdn.com/wp-content/uploads/2009/03/Private-Property-Keep-Out1.jpg'></a>	2013-02-28 22:01:32.196201	2013-01-31 22:01:32.198697	2013-01-31 22:01:32.198697	\N
8	http://www.imdb.com/title/tt1182345/?ref_=fn_al_tt_1	<div class='onebox-result'>\n    <div class='source'>\n      <div class='info'>\n        <a href='http://www.imdb.com/title/tt1182345/?ref_=fn_al_tt_1' target="_blank">\n          imdb.com\n        </a>\n      </div>\n    </div>\n  <div class='onebox-result-body'>\n    <img src="http://ia.media-imdb.com/images/M/MV5BMTgzODgyNTQwOV5BMl5BanBnXkFtZTcwNzc0NTc0Mg@@._V1_SX32_CR0,0,32,44_.jpg" class="thumbnail">\n    <h3><a href="http://www.imdb.com/title/tt1182345/?ref_=fn_al_tt_1" target="_blank">Moon (2009)</a></h3>\n    \n    \n  </div>\n  <div class='clearfix'></div>\n</div>\n	2013-03-01 04:38:21.100476	2013-02-01 04:38:21.142913	2013-02-01 04:38:21.142913	\N
10	http://www.imdb.com/title/tt1182345/?ref_=sr_3	<div class='onebox-result'>\n    <div class='source'>\n      <div class='info'>\n        <a href='http://www.imdb.com/title/tt1182345/?ref_=sr_3' target="_blank">\n          imdb.com\n        </a>\n      </div>\n    </div>\n  <div class='onebox-result-body'>\n    <img src="http://ia.media-imdb.com/images/M/MV5BMTgzODgyNTQwOV5BMl5BanBnXkFtZTcwNzc0NTc0Mg@@._V1_SX32_CR0,0,32,44_.jpg" class="thumbnail">\n    <h3><a href="http://www.imdb.com/title/tt1182345/?ref_=sr_3" target="_blank">Moon (2009)</a></h3>\n    \n    \n  </div>\n  <div class='clearfix'></div>\n</div>\n	2013-03-01 14:12:58.280395	2013-02-01 14:12:58.281973	2013-02-01 14:12:58.281973	\N
11	http://en.wikipedia.org/wiki/Freedom_to_roam	<div class='onebox-result'>\n    <div class='source'>\n      <div class='info'>\n        <a href='http://en.wikipedia.org/wiki/Freedom_to_roam' target="_blank">\n          <img class='favicon' src="/assets/favicons/wikipedia-9450de5258defc03f2fc1312f4d81e53.png"> wikipedia.org\n        </a>\n      </div>\n    </div>\n  <div class='onebox-result-body'>\n    \n    <h3><a href="http://en.wikipedia.org/wiki/Freedom_to_roam" target="_blank">Freedom to roam</a></h3>\n    \n    The freedom to roam, or everyman's right is the general public's right to access certain public or privately owned land for recreation and exercise. The right is sometimes called the right of public access to the wilderness or the right to roam. In England and Wales public access rights apply to certain categories of mainly uncultivated land—specifically "mountain, moor, heath, down and registered common land." Developed land, gardens and certain other areas are specifically excluded from the rig...\n  </div>\n  <div class='clearfix'></div>\n</div>\n	2013-03-01 14:16:11.791767	2013-02-01 14:16:11.792415	2013-02-01 14:16:11.792415	\N
12	http://www.youtube.com/watch?v=1RJPaj97H24	<iframe width="459" height="344" src="http://www.youtube.com/embed/1RJPaj97H24?feature=oembed" frameborder="0" allowfullscreen></iframe>	2013-03-04 20:03:25.024956	2013-02-04 20:03:25.036036	2013-02-04 20:03:25.036036	<img src='http://i2.ytimg.com/vi/1RJPaj97H24/hqdefault.jpg'>
\.


--
-- Name: onebox_renders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('onebox_renders_id_seq', 12, true);


--
-- Data for Name: post_action_types; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_action_types (name_key, is_flag, icon, created_at, updated_at, id, "position") FROM stdin;
vote	f	\N	2013-01-07 21:57:50.177984	2013-01-07 21:57:50.177984	5	0
bookmark	f	\N	2013-01-07 21:57:50.153539	2013-02-01 02:54:58.299504	1	1
like	f	heart	2013-01-07 21:57:50.164792	2013-02-01 02:54:58.302648	2	2
off_topic	t	\N	2013-01-07 21:57:50.168544	2013-02-01 02:54:58.305186	3	3
inappropriate	t	\N	2013-01-07 21:57:50.172436	2013-02-01 02:54:58.30795	4	4
illegal	t	\N	2013-02-01 02:54:58.310885	2013-02-01 02:54:58.310885	7	5
custom_flag	t	\N	2013-01-31 07:32:33.35358	2013-02-01 02:54:58.318088	6	7
\.


--
-- Name: post_action_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('post_action_types_id_seq', 9, true);


--
-- Data for Name: post_actions; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_actions (id, post_id, user_id, post_action_type_id, deleted_at, created_at, updated_at, deleted_by, message) FROM stdin;
1	29	9	2	\N	2013-01-31 22:16:50.569085	2013-01-31 22:16:50.569085	\N	
2	36	19	1	2013-02-01 02:03:52	2013-02-01 02:03:50.868391	2013-02-01 02:03:50.868391	\N	\N
3	37	19	1	\N	2013-02-01 02:18:22.472302	2013-02-01 02:18:22.472302	\N	\N
4	44	11	2	\N	2013-02-01 16:56:34.134477	2013-02-01 16:56:34.134477	\N	
5	28	7	2	\N	2013-02-01 18:57:00.235727	2013-02-01 18:57:00.235727	\N	
6	53	20	2	\N	2013-02-04 18:00:35.847315	2013-02-04 18:00:35.847315	\N	
7	43	22	2	\N	2013-02-04 18:21:02.611043	2013-02-04 18:21:02.611043	\N	
8	70	23	2	\N	2013-02-04 19:49:56.52356	2013-02-04 19:49:56.52356	\N	
9	73	23	2	\N	2013-02-04 19:57:43.066756	2013-02-04 19:57:43.066756	\N	
\.


--
-- Name: post_actions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('post_actions_id_seq', 9, true);


--
-- Data for Name: post_onebox_renders; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_onebox_renders (post_id, onebox_render_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: post_replies; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_replies (post_id, reply_id, created_at, updated_at) FROM stdin;
35	36	2013-02-01 02:03:13.412144	2013-02-01 02:03:13.412144
36	37	2013-02-01 02:08:39.694969	2013-02-01 02:08:39.694969
40	41	2013-02-01 14:06:39.178863	2013-02-01 14:06:39.178863
41	42	2013-02-01 14:12:42.302386	2013-02-01 14:12:42.302386
43	56	2013-02-04 18:21:14.521951	2013-02-04 18:21:14.521951
58	69	2013-02-04 19:40:13.838843	2013-02-04 19:40:13.838843
15	71	2013-02-04 19:44:27.435224	2013-02-04 19:44:27.435224
68	73	2013-02-04 19:52:00.149059	2013-02-04 19:52:00.149059
\.


--
-- Data for Name: post_timings; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_timings (topic_id, post_number, user_id, msecs) FROM stdin;
10	1	2	27077
26	4	22	101129
14	1	19	7009
19	1	7	67074
15	1	9	8145
14	1	9	2002
15	1	12	2017
14	1	12	1001
22	1	12	4020
27	6	11	34057
25	1	12	2003
34	2	15	4046
34	3	15	3022
34	1	15	5029
26	1	14	184005
26	2	14	4000
27	6	2	7316
15	1	4	180093
14	1	4	3002
27	7	2	4024
14	1	5	7006
15	1	5	6002
15	1	11	28133
18	1	6	36039
36	1	11	22018
34	1	19	444735
34	3	19	716377
25	1	11	420517
27	8	2	1000
26	1	9	52049
26	2	9	41040
30	1	15	3001
27	1	12	12022
27	1	2	12095
15	2	2	36883
36	1	7	36024
36	2	7	8005
27	5	20	85312
26	1	7	9007
26	1	19	17020
31	1	16	33090
26	2	19	19025
27	1	9	394473
27	2	9	199369
27	3	9	17012
25	1	9	10007
27	2	2	17387
34	2	19	497922
26	2	7	10009
26	3	7	10009
14	1	23	5010
15	1	20	52110
15	2	20	40095
27	6	20	80259
25	1	19	468700
27	7	20	17037
34	4	11	5001
35	1	20	4010
34	5	11	2003
27	1	20	12084
27	2	20	85284
27	3	20	86285
27	4	20	83337
34	3	11	131156
27	1	15	21012
34	2	2	2044
34	3	2	1001
26	1	20	153147
26	2	20	182197
26	3	20	43081
34	1	2	15147
27	2	15	32103
27	3	15	32103
27	4	15	32103
27	3	2	10336
27	3	19	38061
27	1	19	249343
27	2	19	269370
27	4	2	11352
27	5	2	11352
34	3	7	9014
27	7	11	48071
37	1	22	3009
27	1	22	1001
27	2	22	1001
27	3	22	1001
27	4	22	1001
27	5	22	1000
27	1	7	11008
27	2	7	18011
27	3	7	18011
27	4	7	19012
34	1	7	32035
48	1	7	19017
38	1	21	15010
13	1	2	17012
39	2	19	11013
34	1	11	2001
34	2	11	4014
27	5	7	19012
34	2	7	29023
27	6	7	20013
27	7	7	2002
36	1	20	39126
36	2	20	31113
36	3	20	31113
36	4	20	5009
14	1	2	169054
26	3	23	48015
39	1	21	24032
27	6	22	27071
36	1	2	312211
36	2	2	312211
36	3	2	193146
26	1	11	292439
26	2	11	48057
26	3	11	44069
36	4	2	8003
27	1	11	68088
27	7	22	28138
27	8	22	13125
27	2	12	45069
27	3	12	36039
27	4	12	5005
27	2	11	136173
27	3	11	74089
27	4	11	79466
27	5	11	62434
25	1	22	36030
40	1	23	999
27	4	19	22033
15	1	23	8999
15	2	23	8999
27	5	12	2000
15	1	22	13046
15	2	22	13046
25	1	23	92006
26	1	22	9135
26	1	12	2000
26	2	12	1000
26	4	23	109977
26	1	23	51994
39	1	2	12006
14	1	22	3001
26	2	23	84977
48	1	23	63060
26	2	22	20170
26	3	22	112117
39	1	19	81108
15	2	19	272341
27	5	19	3007
27	6	19	5009
27	8	19	5039
39	2	22	18052
39	1	22	46092
49	1	19	7010
15	1	19	276324
15	3	19	130209
48	3	19	9015
48	1	19	262326
48	2	19	262326
32	1	19	6016
27	7	19	7041
49	1	7	21017
49	1	2	8001
48	1	2	2006
48	2	2	2006
48	3	2	2006
48	1	22	126248
48	2	22	10017
48	2	23	57038
48	3	23	38013
49	1	23	7997
51	1	7	2002
50	1	7	21015
52	1	7	5000
15	1	2	40890
15	3	2	32695
17	1	5	1001
53	2	24	245242
46	1	24	2003
47	1	24	7006
45	1	24	1001
44	1	24	1002
43	1	24	1001
42	1	24	1002
41	1	24	1001
13	1	24	1001
12	1	24	1001
11	1	24	1001
10	1	24	1000
53	1	24	253249
\.


--
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY posts (id, user_id, topic_id, post_number, raw, cooked, created_at, updated_at, reply_to_post_number, cached_version, reply_count, quote_count, deleted_at, off_topic_count, like_count, incoming_link_count, bookmark_count, avg_time, score, reads, post_type, vote_count, sort_order, last_editor_id, hidden, hidden_reason_id, custom_flag_count, spam_count, illegal_count, inappropriate_count, last_version_at, user_deleted, reply_to_user_id) FROM stdin;
36	19	34	2	Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc malesuada diam sed lacus rutrum iaculis. Donec pharetra eros id eros mollis vel malesuada lectus egestas. Suspendisse potenti. Morbi vitae urna vestibulum tortor ultrices bibendum vitae sed nunc. Phasellus blandit dignissim magna dignissim accumsan. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Sed scelerisque vestibulum lorem, ac lacinia erat pellentesque ut. Cras cursus varius sem, sed elementum neque fringilla ut. In at eros ante, non tristique velit.\n=======\nVivamus eget ultricies mi. Proin ac magna sem. Sed vitae tellus ut sem rhoncus mollis. Nunc ac velit lacus. Aenean tincidunt tempus lorem et posuere. In hac habitasse platea dictumst. Pellentesque ultricies lacinia quam, ut convallis ante interdum sit amet. In sed lacus id purus rutrum gravida et ac elit.\n=======\nMaecenas ut rutrum metus. Mauris sem augue, tempor sit amet consectetur rutrum, eleifend id urna. Sed eget mauris ut diam lacinia posuere porta in dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam laoreet lacinia leo, nec laoreet eros blandit quis. Phasellus scelerisque vulputate ipsum, eget vehicula nulla dignissim nec. Cras suscipit tempus porttitor. Aenean sed lorem massa. Nulla facilisi. Nullam vel velit metus, at consectetur urna. Vivamus eu erat metus. Aliquam adipiscing, turpis ut convallis ultrices, lorem ipsum rutrum nibh, at vulputate eros libero et felis. Proin vel ullamcorper neque. Maecenas suscipit, mauris sed egestas cursus, urna enim molestie sapien, ornare venenatis magna risus sed tortor. Donec varius, arcu ut interdum pulvinar, ipsum justo vehicula lorem, ac adipiscing lacus orci id dolor. Quisque auctor arcu nec nibh fringilla consectetur.\n=======\nMaecenas ornare lacinia libero, sit amet adipiscing sem feugiat at. Curabitur imperdiet mauris sit amet sapien dictum tincidunt. Ut metus augue, rutrum eu molestie ut, imperdiet vel dui. Cras fermentum dolor vitae ligula vehicula sit amet pretium tellus tempor. Nunc ut nulla dolor, quis sagittis erat. Etiam a faucibus metus. Duis laoreet posuere congue.\n=======\nEtiam fringilla massa vitae nisi pulvinar et gravida arcu interdum. Mauris ac libero vel elit molestie blandit. Morbi bibendum blandit nulla, eget dapibus tortor porta non. Nulla facilisi. Nulla felis orci, eleifend sit amet pulvinar at, hendrerit ut mi. Morbi elementum neque ac est blandit quis bibendum diam gravida. Sed id tortor dui, sed sollicitudin nulla. Phasellus id odio eget neque semper sollicitudin. Suspendisse accumsan libero in nulla tristique volutpat. Cras odio dolor, euismod eget aliquam in, viverra eget purus. Integer egestas sodales justo, molestie luctus eros faucibus ac. Ut vitae massa purus, a faucibus tortor. Sed feugiat justo et sem varius dapibus ultricies nunc auctor. Donec vestibulum ipsum sit amet felis pellentesque pretium. Donec arcu sem, viverra eget ullamcorper eu, pulvinar quis libero. Donec fermentum ornare velit, a auctor odio lobortis gravida.\n=======\nProin eros magna, semper nec elementum quis, faucibus a nisl. Nullam libero massa, pulvinar convallis volutpat quis, malesuada in metus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Nulla blandit sollicitudin lorem eget aliquam. Cras in urna neque. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nullam eu augue quam, in varius ligula. Fusce ac neque at leo porta volutpat nec quis risus. Integer neque erat, aliquam ut accumsan at, posuere eget orci. Maecenas euismod, odio eget accumsan mattis, neque velit adipiscing lacus, id iaculis dui orci ac massa. Sed viverra, ipsum vitae ornare facilisis, dolor risus facilisis odio, eget ullamcorper quam lectus id est. Integer laoreet dolor sit amet felis gravida adipiscing. Nunc dui eros, tristique fringilla dignissim ac, gravida et justo.\n=======\nInteger non justo a lacus tempus consequat vel non neque. Aliquam adipiscing, metus a mattis cursus, sem elit luctus diam, a mattis est nulla sed nulla. Duis ultricies gravida ante et semper. Sed ornare metus quis enim auctor consectetur in et ipsum. Nunc aliquet, augue at molestie eleifend, urna metus imperdiet nunc, eu vehicula mauris erat sed enim. In diam nunc, malesuada ac laoreet id, tristique id orci. Nullam non magna dui. Fusce sapien quam, accumsan vulputate venenatis non, faucibus eu sapien. Nullam elementum accumsan ligula in sagittis. Nulla at augue mauris.\n=======\nNulla tristique, dui eget aliquam rutrum, erat lectus porta velit, eu hendrerit justo nibh commodo nunc. Curabitur imperdiet vulputate lectus vel porttitor. In id est quis dolor congue rhoncus. Donec mattis aliquet diam, sit amet pretium purus viverra ut. Vestibulum sit amet arcu metus, a sollicitudin enim. Sed gravida ante nec nisl lobortis quis cursus eros molestie. Sed semper, felis posuere pulvinar aliquet, leo neque blandit diam, eu elementum risus diam sit amet libero. Etiam pharetra turpis vel dui tempor viverra. Aliquam eu tellus diam. Aliquam venenatis pretium vulputate. Cras eget eros metus, ut eleifend sem. Aliquam in ipsum tortor. Sed sed pretium neque.\n=======\nFusce tempus placerat lacus. Vestibulum ac nibh purus. Integer facilisis tincidunt lacinia. Mauris volutpat, nibh condimentum placerat rutrum, magna enim malesuada ligula, eget tristique erat lectus eget massa. Nam nibh lacus, dictum vitae faucibus nec, lobortis id massa. Nulla ac massa nibh. Donec erat erat, euismod eu sollicitudin sit amet, ultrices sit amet leo. Sed molestie tincidunt est, vel blandit orci suscipit cursus. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean vel sem lacus. Vivamus elementum ipsum eget velit elementum blandit. Etiam ullamcorper odio ornare diam pretium non congue risus venenatis. Nam nec pellentesque purus. Fusce eu lorem velit, elementum ultricies velit. Pellentesque vel purus id dolor convallis ullamcorper sit amet nec felis.\n=======\nPraesent fermentum dapibus interdum. Ut scelerisque, nisi id mollis adipiscing, urna nibh sagittis metus, at facilisis erat urna non nisl. Duis id leo sed purus scelerisque blandit non a lorem. Nulla blandit leo sed erat elementum non pulvinar eros adipiscing. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nam vitae sem a neque vulputate porta. Cras vulputate aliquam vehicula. Ut id volutpat urna. Donec fringilla molestie lacus. Etiam est nunc, lacinia vitae aliquet nec, semper at felis.\n=======\nInteger at neque et arcu venenatis convallis ac eget neque. Fusce sit amet arcu erat, nec sodales risus. Phasellus dictum sollicitudin adipiscing. Aliquam erat volutpat. Donec sapien odio, fringilla a dignissim vel, condimentum nec massa. Nam sagittis tincidunt felis nec vulputate. Mauris egestas, libero eu accumsan vestibulum, orci urna ultricies tortor, nec venenatis lorem turpis sed risus. Aliquam convallis neque sit amet felis sollicitudin ac auctor nibh rutrum. Nulla sodales, justo eget interdum cursus, enim erat lacinia massa, id dignissim ipsum nibh et leo. Vivamus quis massa quis diam lacinia pharetra at nec orci. Nullam vehicula neque in orci varius pretium. Cras dapibus, felis sed eleifend sollicitudin, felis nulla placerat libero, nec commodo odio risus ornare risus. Etiam gravida dignissim erat, eget malesuada nisi rhoncus at.\n=======\nPhasellus mollis tincidunt faucibus. Proin nulla dui, vulputate a sodales eu, gravida non eros. Nunc consectetur nisi sed felis accumsan at feugiat nibh tincidunt. Phasellus ullamcorper fringilla imperdiet. Cras tincidunt neque vitae nibh eleifend placerat. Quisque id dui metus, ut viverra purus. Donec viverra lectus sapien, varius porta tellus. Aliquam volutpat mi a justo blandit ut dapibus justo vulputate. Phasellus sed malesuada erat. Pellentesque vitae ligula a eros pharetra lacinia. Ut nisl justo, bibendum vitae vehicula quis, commodo venenatis risus. Phasellus convallis odio a sapien posuere commodo. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Curabitur at sem lorem, nec suscipit metus.\n=======\nVestibulum cursus varius urna, eget porttitor nisl lobortis in. Donec eget urna sed massa ornare mattis sit amet eu tellus. Integer elit sem, faucibus sit amet suscipit vitae, accumsan aliquet neque. Vivamus in risus non odio pretium congue eget a metus. Donec euismod lorem et libero posuere non placerat massa vehicula. Curabitur rhoncus diam quis ligula varius nec bibendum lacus pulvinar. Suspendisse porttitor erat nec nibh adipiscing ultrices sed nec risus. Fusce volutpat libero ornare erat adipiscing fringilla vehicula justo faucibus. Nunc eu justo velit, non viverra ante. Nulla vestibulum tempus ante ac molestie. Vivamus convallis ultrices nibh, a imperdiet orci commodo vel.\n=======\nDonec elementum turpis sit amet sapien luctus scelerisque venenatis leo aliquam. Vestibulum nisi nisi, ullamcorper vel pharetra et, rutrum sed magna. Aliquam dignissim arcu sit amet nunc tempus eget congue lorem eleifend. Donec vehicula dui et turpis tincidunt tempor. Fusce ut enim augue. Vestibulum vel pretium leo. Nunc luctus auctor quam, in sollicitudin augue fringilla vulputate. Etiam nibh tortor, vulputate vitae vulputate vel, tempus ut purus. Mauris nibh est, molestie et scelerisque vitae, iaculis id mi. Praesent et leo neque. Proin tincidunt vehicula sagittis. Pellentesque ac nisi urna, at mattis lectus. Nam lacinia justo quis sapien facilisis posuere. Proin euismod, tortor blandit faucibus malesuada, lorem nisi tristique lacus, a imperdiet dolor tortor et mauris. Integer tortor enim, sollicitudin convallis rutrum a, tempor quis mauris. Suspendisse porttitor urna id mauris euismod ornare.\n=======\nAliquam pulvinar viverra luctus. Nunc sed lorem nibh, eu dignissim tortor. Proin pellentesque augue eget metus vestibulum dapibus at quis felis. Nulla tincidunt pellentesque neque quis fringilla. Proin condimentum ornare dui, nec commodo eros elementum eu. Fusce laoreet purus vel dolor ultrices malesuada eu quis arcu. Sed pretium eleifend adipiscing. Ut urna sapien, hendrerit et congue sit amet, placerat sit amet arcu. Aenean vestibulum dolor sed turpis pretium mattis. Morbi eget fermentum felis. Cras scelerisque, quam eu adipiscing placerat, purus lorem lobortis arcu, sit amet condimentum augue metus vitae ipsum. Vestibulum lorem arcu, pulvinar et tristique ut, fermentum in quam. Donec venenatis fermentum ullamcorper.\n=======\nSuspendisse potenti. Integer et tellus at orci pretium rhoncus non in nisi. Aenean in enim enim. Suspendisse elit felis, pretium vitae sollicitudin eget, ultrices ut mauris. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean vestibulum dui nec nisi iaculis ullamcorper. Donec imperdiet pretium tellus, a malesuada justo dignissim quis. Donec eleifend luctus magna at gravida. Donec blandit interdum nibh, id pretium sapien ultricies in. Sed consequat, augue semper aliquam hendrerit, purus sapien condimentum erat, quis tempus nisi eros vitae tellus.\n=======\nQuisque eleifend aliquam pulvinar. Fusce luctus tellus elit. Pellentesque ullamcorper accumsan quam ut tristique. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Etiam nec cursus lectus. Quisque risus sem, lobortis vel facilisis in, commodo ac nisl. Ut quis mauris et diam ultricies consectetur a eu sem. Etiam nec massa purus. Donec urna tortor, congue non tincidunt sed, ullamcorper scelerisque tortor. Aliquam eu risus sapien. Morbi in ligula et elit facilisis rhoncus. Suspendisse potenti. Vivamus elementum nisl vel turpis aliquet sit amet scelerisque enim facilisis. Proin laoreet facilisis metus nec vulputate. Vivamus ac nibh at turpis consequat laoreet.\n=======\nAliquam ultricies, nunc eu eleifend bibendum, justo arcu lobortis mauris, vitae cursus nunc leo in velit. Sed eu odio at velit varius bibendum. Nunc ut enim sit amet sapien aliquet ultrices. Phasellus non lacus sit amet ante bibendum auctor convallis a augue. Etiam pellentesque suscipit quam, vitae dictum ante feugiat pellentesque. Sed tempor volutpat sapien, id bibendum dolor elementum nec. Sed auctor ultrices dolor in dictum. Vestibulum sed ipsum urna, sollicitudin pellentesque erat. Vivamus at massa urna. Sed facilisis mattis magna, id euismod erat pulvinar suscipit.\n=======\nAliquam et molestie velit. Nunc nec libero quis metus accumsan volutpat et a libero. Nullam ut neque eu est euismod mollis quis nec lorem. Donec vulputate justo ligula, non varius neque. Aliquam rutrum, diam a faucibus elementum, libero est blandit eros, sit amet ullamcorper urna velit egestas purus. Nunc et nisi sapien. Vivamus sagittis tempus malesuada. Integer a venenatis justo.\n=======\nMauris justo est, blandit pellentesque placerat eget, auctor nec tortor. Fusce viverra risus at odio molestie vestibulum. Suspendisse urna justo, eleifend in adipiscing ac, lacinia vitae arcu. Duis mattis, sem sed rhoncus interdum, neque dolor tristique urna, tristique ornare turpis magna eget tortor. Nullam ultrices justo vel lectus sagittis interdum. Maecenas et magna id augue tempus ultrices et id justo. Proin gravida sagittis pellentesque. Proin dignissim ipsum et nunc pulvinar quis ornare enim posuere. Proin mi mauris, accumsan a iaculis ac, aliquet ac nulla. Fusce quis purus in arcu venenatis tincidunt. Quisque tempor libero vel lectus gravida auctor feugiat diam pulvinar. Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n=======	<h1>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc malesuada diam sed lacus rutrum iaculis. Donec pharetra eros id eros mollis vel malesuada lectus egestas. Suspendisse potenti. Morbi vitae urna vestibulum tortor ultrices bibendum vitae sed nunc. Phasellus blandit dignissim magna dignissim accumsan. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Sed scelerisque vestibulum lorem, ac lacinia erat pellentesque ut. Cras cursus varius sem, sed elementum neque fringilla ut. In at eros ante, non tristique velit.  </h1>\n\n<h1>Vivamus eget ultricies mi. Proin ac magna sem. Sed vitae tellus ut sem rhoncus mollis. Nunc ac velit lacus. Aenean tincidunt tempus lorem et posuere. In hac habitasse platea dictumst. Pellentesque ultricies lacinia quam, ut convallis ante interdum sit amet. In sed lacus id purus rutrum gravida et ac elit.  </h1>\n\n<h1>Maecenas ut rutrum metus. Mauris sem augue, tempor sit amet consectetur rutrum, eleifend id urna. Sed eget mauris ut diam lacinia posuere porta in dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam laoreet lacinia leo, nec laoreet eros blandit quis. Phasellus scelerisque vulputate ipsum, eget vehicula nulla dignissim nec. Cras suscipit tempus porttitor. Aenean sed lorem massa. Nulla facilisi. Nullam vel velit metus, at consectetur urna. Vivamus eu erat metus. Aliquam adipiscing, turpis ut convallis ultrices, lorem ipsum rutrum nibh, at vulputate eros libero et felis. Proin vel ullamcorper neque. Maecenas suscipit, mauris sed egestas cursus, urna enim molestie sapien, ornare venenatis magna risus sed tortor. Donec varius, arcu ut interdum pulvinar, ipsum justo vehicula lorem, ac adipiscing lacus orci id dolor. Quisque auctor arcu nec nibh fringilla consectetur.  </h1>\n\n<h1>Maecenas ornare lacinia libero, sit amet adipiscing sem feugiat at. Curabitur imperdiet mauris sit amet sapien dictum tincidunt. Ut metus augue, rutrum eu molestie ut, imperdiet vel dui. Cras fermentum dolor vitae ligula vehicula sit amet pretium tellus tempor. Nunc ut nulla dolor, quis sagittis erat. Etiam a faucibus metus. Duis laoreet posuere congue.  </h1>\n\n<h1>Etiam fringilla massa vitae nisi pulvinar et gravida arcu interdum. Mauris ac libero vel elit molestie blandit. Morbi bibendum blandit nulla, eget dapibus tortor porta non. Nulla facilisi. Nulla felis orci, eleifend sit amet pulvinar at, hendrerit ut mi. Morbi elementum neque ac est blandit quis bibendum diam gravida. Sed id tortor dui, sed sollicitudin nulla. Phasellus id odio eget neque semper sollicitudin. Suspendisse accumsan libero in nulla tristique volutpat. Cras odio dolor, euismod eget aliquam in, viverra eget purus. Integer egestas sodales justo, molestie luctus eros faucibus ac. Ut vitae massa purus, a faucibus tortor. Sed feugiat justo et sem varius dapibus ultricies nunc auctor. Donec vestibulum ipsum sit amet felis pellentesque pretium. Donec arcu sem, viverra eget ullamcorper eu, pulvinar quis libero. Donec fermentum ornare velit, a auctor odio lobortis gravida.  </h1>\n\n<h1>Proin eros magna, semper nec elementum quis, faucibus a nisl. Nullam libero massa, pulvinar convallis volutpat quis, malesuada in metus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Nulla blandit sollicitudin lorem eget aliquam. Cras in urna neque. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nullam eu augue quam, in varius ligula. Fusce ac neque at leo porta volutpat nec quis risus. Integer neque erat, aliquam ut accumsan at, posuere eget orci. Maecenas euismod, odio eget accumsan mattis, neque velit adipiscing lacus, id iaculis dui orci ac massa. Sed viverra, ipsum vitae ornare facilisis, dolor risus facilisis odio, eget ullamcorper quam lectus id est. Integer laoreet dolor sit amet felis gravida adipiscing. Nunc dui eros, tristique fringilla dignissim ac, gravida et justo.  </h1>\n\n<h1>Integer non justo a lacus tempus consequat vel non neque. Aliquam adipiscing, metus a mattis cursus, sem elit luctus diam, a mattis est nulla sed nulla. Duis ultricies gravida ante et semper. Sed ornare metus quis enim auctor consectetur in et ipsum. Nunc aliquet, augue at molestie eleifend, urna metus imperdiet nunc, eu vehicula mauris erat sed enim. In diam nunc, malesuada ac laoreet id, tristique id orci. Nullam non magna dui. Fusce sapien quam, accumsan vulputate venenatis non, faucibus eu sapien. Nullam elementum accumsan ligula in sagittis. Nulla at augue mauris.  </h1>\n\n<h1>Nulla tristique, dui eget aliquam rutrum, erat lectus porta velit, eu hendrerit justo nibh commodo nunc. Curabitur imperdiet vulputate lectus vel porttitor. In id est quis dolor congue rhoncus. Donec mattis aliquet diam, sit amet pretium purus viverra ut. Vestibulum sit amet arcu metus, a sollicitudin enim. Sed gravida ante nec nisl lobortis quis cursus eros molestie. Sed semper, felis posuere pulvinar aliquet, leo neque blandit diam, eu elementum risus diam sit amet libero. Etiam pharetra turpis vel dui tempor viverra. Aliquam eu tellus diam. Aliquam venenatis pretium vulputate. Cras eget eros metus, ut eleifend sem. Aliquam in ipsum tortor. Sed sed pretium neque.  </h1>\n\n<h1>Fusce tempus placerat lacus. Vestibulum ac nibh purus. Integer facilisis tincidunt lacinia. Mauris volutpat, nibh condimentum placerat rutrum, magna enim malesuada ligula, eget tristique erat lectus eget massa. Nam nibh lacus, dictum vitae faucibus nec, lobortis id massa. Nulla ac massa nibh. Donec erat erat, euismod eu sollicitudin sit amet, ultrices sit amet leo. Sed molestie tincidunt est, vel blandit orci suscipit cursus. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean vel sem lacus. Vivamus elementum ipsum eget velit elementum blandit. Etiam ullamcorper odio ornare diam pretium non congue risus venenatis. Nam nec pellentesque purus. Fusce eu lorem velit, elementum ultricies velit. Pellentesque vel purus id dolor convallis ullamcorper sit amet nec felis.  </h1>\n\n<h1>Praesent fermentum dapibus interdum. Ut scelerisque, nisi id mollis adipiscing, urna nibh sagittis metus, at facilisis erat urna non nisl. Duis id leo sed purus scelerisque blandit non a lorem. Nulla blandit leo sed erat elementum non pulvinar eros adipiscing. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nam vitae sem a neque vulputate porta. Cras vulputate aliquam vehicula. Ut id volutpat urna. Donec fringilla molestie lacus. Etiam est nunc, lacinia vitae aliquet nec, semper at felis.  </h1>\n\n<h1>Integer at neque et arcu venenatis convallis ac eget neque. Fusce sit amet arcu erat, nec sodales risus. Phasellus dictum sollicitudin adipiscing. Aliquam erat volutpat. Donec sapien odio, fringilla a dignissim vel, condimentum nec massa. Nam sagittis tincidunt felis nec vulputate. Mauris egestas, libero eu accumsan vestibulum, orci urna ultricies tortor, nec venenatis lorem turpis sed risus. Aliquam convallis neque sit amet felis sollicitudin ac auctor nibh rutrum. Nulla sodales, justo eget interdum cursus, enim erat lacinia massa, id dignissim ipsum nibh et leo. Vivamus quis massa quis diam lacinia pharetra at nec orci. Nullam vehicula neque in orci varius pretium. Cras dapibus, felis sed eleifend sollicitudin, felis nulla placerat libero, nec commodo odio risus ornare risus. Etiam gravida dignissim erat, eget malesuada nisi rhoncus at.  </h1>\n\n<h1>Phasellus mollis tincidunt faucibus. Proin nulla dui, vulputate a sodales eu, gravida non eros. Nunc consectetur nisi sed felis accumsan at feugiat nibh tincidunt. Phasellus ullamcorper fringilla imperdiet. Cras tincidunt neque vitae nibh eleifend placerat. Quisque id dui metus, ut viverra purus. Donec viverra lectus sapien, varius porta tellus. Aliquam volutpat mi a justo blandit ut dapibus justo vulputate. Phasellus sed malesuada erat. Pellentesque vitae ligula a eros pharetra lacinia. Ut nisl justo, bibendum vitae vehicula quis, commodo venenatis risus. Phasellus convallis odio a sapien posuere commodo. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Curabitur at sem lorem, nec suscipit metus.  </h1>\n\n<h1>Vestibulum cursus varius urna, eget porttitor nisl lobortis in. Donec eget urna sed massa ornare mattis sit amet eu tellus. Integer elit sem, faucibus sit amet suscipit vitae, accumsan aliquet neque. Vivamus in risus non odio pretium congue eget a metus. Donec euismod lorem et libero posuere non placerat massa vehicula. Curabitur rhoncus diam quis ligula varius nec bibendum lacus pulvinar. Suspendisse porttitor erat nec nibh adipiscing ultrices sed nec risus. Fusce volutpat libero ornare erat adipiscing fringilla vehicula justo faucibus. Nunc eu justo velit, non viverra ante. Nulla vestibulum tempus ante ac molestie. Vivamus convallis ultrices nibh, a imperdiet orci commodo vel.  </h1>\n\n<h1>Donec elementum turpis sit amet sapien luctus scelerisque venenatis leo aliquam. Vestibulum nisi nisi, ullamcorper vel pharetra et, rutrum sed magna. Aliquam dignissim arcu sit amet nunc tempus eget congue lorem eleifend. Donec vehicula dui et turpis tincidunt tempor. Fusce ut enim augue. Vestibulum vel pretium leo. Nunc luctus auctor quam, in sollicitudin augue fringilla vulputate. Etiam nibh tortor, vulputate vitae vulputate vel, tempus ut purus. Mauris nibh est, molestie et scelerisque vitae, iaculis id mi. Praesent et leo neque. Proin tincidunt vehicula sagittis. Pellentesque ac nisi urna, at mattis lectus. Nam lacinia justo quis sapien facilisis posuere. Proin euismod, tortor blandit faucibus malesuada, lorem nisi tristique lacus, a imperdiet dolor tortor et mauris. Integer tortor enim, sollicitudin convallis rutrum a, tempor quis mauris. Suspendisse porttitor urna id mauris euismod ornare.  </h1>\n\n<h1>Aliquam pulvinar viverra luctus. Nunc sed lorem nibh, eu dignissim tortor. Proin pellentesque augue eget metus vestibulum dapibus at quis felis. Nulla tincidunt pellentesque neque quis fringilla. Proin condimentum ornare dui, nec commodo eros elementum eu. Fusce laoreet purus vel dolor ultrices malesuada eu quis arcu. Sed pretium eleifend adipiscing. Ut urna sapien, hendrerit et congue sit amet, placerat sit amet arcu. Aenean vestibulum dolor sed turpis pretium mattis. Morbi eget fermentum felis. Cras scelerisque, quam eu adipiscing placerat, purus lorem lobortis arcu, sit amet condimentum augue metus vitae ipsum. Vestibulum lorem arcu, pulvinar et tristique ut, fermentum in quam. Donec venenatis fermentum ullamcorper.  </h1>\n\n<h1>Suspendisse potenti. Integer et tellus at orci pretium rhoncus non in nisi. Aenean in enim enim. Suspendisse elit felis, pretium vitae sollicitudin eget, ultrices ut mauris. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean vestibulum dui nec nisi iaculis ullamcorper. Donec imperdiet pretium tellus, a malesuada justo dignissim quis. Donec eleifend luctus magna at gravida. Donec blandit interdum nibh, id pretium sapien ultricies in. Sed consequat, augue semper aliquam hendrerit, purus sapien condimentum erat, quis tempus nisi eros vitae tellus.  </h1>\n\n<h1>Quisque eleifend aliquam pulvinar. Fusce luctus tellus elit. Pellentesque ullamcorper accumsan quam ut tristique. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Etiam nec cursus lectus. Quisque risus sem, lobortis vel facilisis in, commodo ac nisl. Ut quis mauris et diam ultricies consectetur a eu sem. Etiam nec massa purus. Donec urna tortor, congue non tincidunt sed, ullamcorper scelerisque tortor. Aliquam eu risus sapien. Morbi in ligula et elit facilisis rhoncus. Suspendisse potenti. Vivamus elementum nisl vel turpis aliquet sit amet scelerisque enim facilisis. Proin laoreet facilisis metus nec vulputate. Vivamus ac nibh at turpis consequat laoreet.  </h1>\n\n<h1>Aliquam ultricies, nunc eu eleifend bibendum, justo arcu lobortis mauris, vitae cursus nunc leo in velit. Sed eu odio at velit varius bibendum. Nunc ut enim sit amet sapien aliquet ultrices. Phasellus non lacus sit amet ante bibendum auctor convallis a augue. Etiam pellentesque suscipit quam, vitae dictum ante feugiat pellentesque. Sed tempor volutpat sapien, id bibendum dolor elementum nec. Sed auctor ultrices dolor in dictum. Vestibulum sed ipsum urna, sollicitudin pellentesque erat. Vivamus at massa urna. Sed facilisis mattis magna, id euismod erat pulvinar suscipit.  </h1>\n\n<h1>Aliquam et molestie velit. Nunc nec libero quis metus accumsan volutpat et a libero. Nullam ut neque eu est euismod mollis quis nec lorem. Donec vulputate justo ligula, non varius neque. Aliquam rutrum, diam a faucibus elementum, libero est blandit eros, sit amet ullamcorper urna velit egestas purus. Nunc et nisi sapien. Vivamus sagittis tempus malesuada. Integer a venenatis justo.  </h1>\n\n<h1>Mauris justo est, blandit pellentesque placerat eget, auctor nec tortor. Fusce viverra risus at odio molestie vestibulum. Suspendisse urna justo, eleifend in adipiscing ac, lacinia vitae arcu. Duis mattis, sem sed rhoncus interdum, neque dolor tristique urna, tristique ornare turpis magna eget tortor. Nullam ultrices justo vel lectus sagittis interdum. Maecenas et magna id augue tempus ultrices et id justo. Proin gravida sagittis pellentesque. Proin dignissim ipsum et nunc pulvinar quis ornare enim posuere. Proin mi mauris, accumsan a iaculis ac, aliquet ac nulla. Fusce quis purus in arcu venenatis tincidunt. Quisque tempor libero vel lectus gravida auctor feugiat diam pulvinar. Lorem ipsum dolor sit amet, consectetur adipiscing elit.  </h1>	2013-02-01 02:03:13.153865	2013-02-01 02:06:56.757234	1	1	1	0	\N	0	0	0	0	6	6.29999999999999982	5	1	0	2	19	f	\N	0	0	0	0	2013-02-01 02:03:13.153865	f	19
16	2	16	1	Hi there!\n\nWelcome to Try Discourse. \n\nEnjoy your stay. Let us know if you need anything.	<p>Hi there!</p>\n\n<p>Welcome to Try Discourse. </p>\n\n<p>Enjoy your stay. Let us know if you need anything.</p>	2013-01-24 09:00:43.26506	2013-01-24 09:00:43.26506	\N	1	0	0	\N	0	0	0	0	\N	0	0	1	0	1	2	f	\N	0	0	0	0	2013-01-24 09:00:43.26506	f	\N
56	22	27	8	Still looks broken. 123	<p>Still looks broken. 123</p>	2013-02-04 18:21:14.309176	2013-02-04 18:21:14.309176	7	1	0	0	\N	0	0	0	0	2	0.699999999999999956	3	1	0	8	22	f	\N	0	0	0	0	2013-02-04 18:21:14.308445	f	20
74	7	50	1	I'm not sure I understand how topics and posts I've read are being accounted for.\n\nWhat are the little ribbon icons on each post. How does that work?\n\nAlso, how does this forum know which topics I'm interested in? Do I have to click on each one somewhere to "subscribe" to topics?	<p>I'm not sure I understand how topics and posts I've read are being accounted for.</p>\n\n<p>What are the little ribbon icons on each post. How does that work?</p>\n\n<p>Also, how does this forum know which topics I'm interested in? Do I have to click on each one somewhere to "subscribe" to topics?</p>	2013-02-04 19:58:33.287182	2013-02-04 19:58:33.287182	\N	1	0	0	\N	0	0	0	0	\N	0.200000000000000011	1	1	0	1	7	f	\N	0	0	0	0	2013-02-04 19:58:33.286802	f	\N
71	19	15	3	The worst part of having kids is having them grow into sentience, start using the Internet and discover memes.  Charlie the Unicorn isn't nearly as funny when you hear it repeated, verbatim, by 13-year-olds over a week of dinners.\n\nDo you think kids in the 1600s did the same thing with the Bible?	<p>The worst part of having kids is having them grow into sentience, start using the Internet and discover memes.  Charlie the Unicorn isn't nearly as funny when you hear it repeated, verbatim, by 13-year-olds over a week of dinners.</p>\n\n<p>Do you think kids in the 1600s did the same thing with the Bible?</p>	2013-02-04 19:44:27.276622	2013-02-04 19:44:27.276622	1	1	0	0	\N	0	0	0	0	33	2.04999999999999982	2	1	0	3	19	f	\N	0	0	0	0	2013-02-04 19:44:27.276264	f	2
19	2	19	1	Hi there!\n\nThanks for joining Try Discourse. Welcome to our discussion forum!\n\nHere are a few quick tips:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\nWe believe in [civilized community behavior](/faq) at all times.\n\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse. Welcome to our discussion forum!</p>\n\n<p>Here are a few quick tips:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-31 19:46:04.965622	2013-01-31 19:46:04.965622	\N	1	0	0	\N	0	0	0	0	67	3.54999999999999982	1	1	0	1	2	f	\N	0	0	0	0	2013-01-31 19:46:04.965622	f	\N
57	2	38	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\n- To get back to the home page at any time, **click the icon at the upper left.**\n\n- To search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n- While reading a topic, you can move to the top by clicking its title at the top of the page. To reach the *bottom*, click the down arrow on the topic progress indicator at the bottom of the page, or click the last post field on the topic summary under the first post.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<ul>\n<li><p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p></li>\n<li><p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p></li>\n<li>While reading a topic, you can move to the top by clicking its title at the top of the page. To reach the <em>bottom</em>, click the down arrow on the topic progress indicator at the bottom of the page, or click the last post field on the topic summary under the first post.</li>\n</ul><p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-02-04 18:27:44.262101	2013-02-04 18:27:44.262101	\N	1	0	0	\N	0	0	0	0	15	0.949999999999999956	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 18:27:44.261673	f	\N
41	11	27	5	[quote="Clay, post:4, topic:27, full:true"]I'm going to have to go with Moon. I can't post a link to IMDB because the body 'has too many images.'[/quote]\n\nTry again, it should work now.	<p></p><aside class="quote" data-post="4" data-topic="27" data-full="true"><div class="title">\n    <div class="quote-controls"></div>\n  <img width="20" height="20" src="http://www.gravatar.com/avatar/7e75aa963fc927908a38ecede40f6b9d.png?s=40&amp;r=pg&amp;d=identicon" class="avatar " title="">\n  Clay\n  said:\n  </div>\n  <blockquote>I'm going to have to go with Moon. I can't post a link to IMDB because the body 'has too many images.'</blockquote>\n</aside><p></p>\n\n<p>Try again, it should work now.</p>	2013-02-01 14:06:39.027174	2013-02-01 14:07:09.91617	4	1	1	1	\N	0	0	0	0	7	6.54999999999999982	6	1	0	5	11	f	\N	0	0	0	0	2013-02-01 14:06:39.027174	f	20
78	24	53	2	This topic is now pinned. It will appear at the top of its category.	<p>This topic is now pinned. It will appear at the top of its category.</p>	2013-02-04 22:39:55.890904	2013-02-04 22:39:55.890904	\N	1	0	0	\N	0	0	0	0	\N	\N	1	2	0	2	24	f	\N	0	0	0	0	2013-02-04 22:39:55.890178	f	\N
12	2	12	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-01-07 22:03:02.816133	2013-01-07 22:03:02.816133	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-01-07 22:03:02.816133	f	\N
11	2	11	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-01-07 22:01:53.720331	2013-01-07 22:01:53.720331	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-01-07 22:01:53.720331	f	\N
18	2	18	1	Hi there!\n\nThanks for joining Try Discourse. Welcome!\n\nHere are a few quick tips to get the most out of this forum:\n\n**Keep Scrolling**\n\nThere are no next page button or page numbers here. To keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\nWe believe in [civilized community behavior](/faq) at all times.\n\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse. Welcome!</p>\n\n<p>Here are a few quick tips to get the most out of this forum:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There are no next page button or page numbers here. To keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-29 05:25:59.472797	2013-01-29 05:25:59.472797	\N	1	0	0	\N	0	0	0	0	36	2	1	1	0	1	2	f	\N	0	0	0	0	2013-01-29 05:25:59.472797	f	\N
53	2	36	3	Try is run by the same rubies as dev.  Are there still problems only affecting try2?  I'll delete this thread otherwise so that it doesn't get copied to localhost:4000.	<p>Try is run by the same rubies as dev.  Are there still problems only affecting try2?  I'll delete this thread otherwise so that it doesn't get copied to localhost:4000.</p>	2013-02-04 15:17:53.58021	2013-02-04 15:17:53.58021	\N	1	0	0	\N	0	1	0	0	31	16.9499999999999993	2	1	0	3	2	f	\N	0	0	0	0	2013-02-04 15:17:53.579844	f	\N
52	7	36	2	It isn't though, what you are seeing as "regressions" are forum-level config options.	<p>It isn't though, what you are seeing as "regressions" are forum-level config options.</p>	2013-02-01 18:56:27.376407	2013-02-01 18:56:27.376407	\N	1	0	0	\N	0	0	0	0	99	5.54999999999999982	3	1	0	2	7	f	\N	0	0	0	0	2013-02-01 18:56:27.376407	f	\N
54	20	36	4	Delete this thread.    12345	<p>Delete this thread.    12345</p>	2013-02-04 18:00:51.857089	2013-02-04 18:00:51.857089	\N	1	0	0	\N	0	0	0	0	8	0.800000000000000044	2	1	0	4	20	f	\N	0	0	0	0	2013-02-04 18:00:51.856529	f	\N
26	2	28	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\nTo get back to the home page at any time, **click the icon at the upper left.**\n\nTo search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p>\n\n<p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-31 21:51:25.091254	2013-01-31 21:51:25.091254	\N	1	0	0	\N	0	0	0	0	\N	0	0	1	0	1	2	f	\N	0	0	0	0	2013-01-31 21:51:25.091254	f	\N
33	2	31	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\nTo get back to the home page at any time, **click the icon at the upper left.**\n\nTo search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p>\n\n<p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-31 23:45:27.940884	2013-01-31 23:45:27.940884	\N	1	0	0	\N	0	0	0	0	33	1.85000000000000009	1	1	0	1	2	f	\N	0	0	0	0	2013-01-31 23:45:27.940884	f	\N
73	19	48	3	The combination of a treadmill (not a desk, just a treadmill), an iPad and video streaming has been _great_ for me.  It's the only exercise I've been able to sustain for longer than a couple of weeks in the past 20 years.  I walk 3.5 miles every day -- takes an hour -- and while it hasn't helped my weight significantly, I'm very happy with being able to consistent get off my ass and move.  (I am not a doctor, but if you're hugely out of shape, you should have a check-up before beginning any exercise regimen.)  This year, my goal is 875 miles -- 3.5 miles every weekday for 50 weeks.  I'm pretty sure I can do it.\n\nBonus upside: I'm catching up on all the cultural milestones -- well, video-based cultural milestones -- that I never had time for.	<p>The combination of a treadmill (not a desk, just a treadmill), an iPad and video streaming has been <em>great</em> for me.  It's the only exercise I've been able to sustain for longer than a couple of weeks in the past 20 years.  I walk 3.5 miles every day -- takes an hour -- and while it hasn't helped my weight significantly, I'm very happy with being able to consistent get off my ass and move.  (I am not a doctor, but if you're hugely out of shape, you should have a check-up before beginning any exercise regimen.)  This year, my goal is 875 miles -- 3.5 miles every weekday for 50 weeks.  I'm pretty sure I can do it.</p>\n\n<p>Bonus upside: I'm catching up on all the cultural milestones -- well, video-based cultural milestones -- that I never had time for.</p>	2013-02-04 19:51:59.86907	2013-02-04 19:51:59.86907	1	1	0	0	\N	0	1	0	0	\N	15.5999999999999996	3	1	0	3	19	f	\N	0	0	0	0	2013-02-04 19:51:59.868704	f	23
9	2	9	1	Hi there!\n\nWelcome to Discourse. \n\nEnjoy your stay. Let us know if you need anything.\n	<p>Hi there!</p>\n\n<p>Welcome to Discourse. </p>\n\n<p>Enjoy your stay. Let us know if you need anything.  </p>	2013-01-07 21:56:54.616967	2013-01-07 21:56:54.616967	\N	1	0	0	\N	0	0	0	0	\N	0	0	1	0	1	2	f	\N	0	0	0	0	2013-01-07 21:56:54.616967	f	\N
43	20	27	7	Hello. Does this work? The image appears broken to me.\n\n<img src='/uploads/try2_discourse/11/mv5bmtgzodgyntqwov5bml5banbnxkftztcwnzc0ntc0mg__v1_sy317_cr00214317_.jpeg' width='214' height='317'>	<p>Hello. Does this work? The image appears broken to me.</p>\n\n<p><img src="http://cdn2.discourse.org/uploads/try2_discourse/11/mv5bmtgzodgyntqwov5bml5banbnxkftztcwnzc0ntc0mg__v1_sy317_cr00214317_.jpeg" width="214" height="317"></p>	2013-02-01 14:14:08.52838	2013-02-01 14:14:24.506268	\N	1	1	0	\N	0	1	0	0	9	21.6499999999999986	6	1	0	7	20	f	\N	0	0	0	0	2013-02-01 14:14:08.52838	f	\N
44	20	26	3	Throughout much of Europe, you have what the Scandinavians call "Allmansretten," or the Freedom to Roam:\n\nhttp://en.wikipedia.org/wiki/Freedom_to_roam\n\nHere in the US, <s>we shoot trespassers with glee</s> you aren't allowed to wander onto private property without permission.	<p>Throughout much of Europe, you have what the Scandinavians call "Allmansretten," or the Freedom to Roam:</p>\n\n<p><div class="onebox-result">\n    <div class="source">\n      <div class="info">\n        <a href="http://en.wikipedia.org/wiki/Freedom_to_roam" target="_blank">\n          <img class="favicon" src="/assets/favicons/wikipedia-9450de5258defc03f2fc1312f4d81e53.png" /> wikipedia.org\n        </a>\n      </div>\n    </div>\n  <div class="onebox-result-body">\n    \n    <h3><a href="http://en.wikipedia.org/wiki/Freedom_to_roam" target="_blank">Freedom to roam</a></h3>\n    \n    The freedom to roam, or everyman's right is the general public's right to access certain public or privately owned land for recreation and exercise. The right is sometimes called the right of public access to the wilderness or the right to roam. In England and Wales public access rights apply to certain categories of mainly uncultivated land—specifically "mountain, moor, heath, down and registered common land." Developed land, gardens and certain other areas are specifically excluded from the rig...\n  </div>\n  <div class="clearfix"></div>\n</div>\n</p>\n\n<p>Here in the US, <s>we shoot trespassers with glee</s> you aren't allowed to wander onto private property without permission.</p>	2013-02-01 14:17:38.286098	2013-02-01 14:17:38.286098	\N	1	0	0	\N	0	1	0	0	39	17.9499999999999993	5	1	0	3	20	f	\N	0	0	0	0	2013-02-01 14:17:38.286098	f	\N
21	2	21	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\nTo get back to the home page at any time, **click the icon at the upper left.**\n\nTo search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p>\n\n<p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-31 20:25:33.786175	2013-01-31 20:25:33.786175	\N	1	0	0	\N	0	0	0	0	\N	0	0	1	0	1	2	f	\N	0	0	0	0	2013-01-31 20:25:33.786175	f	\N
70	22	48	2	How about a treadmill desk?\n\nJeff LeMarche, iPhone developer, had a series of blog posts about using a treadmill desk. In the final one that he posted, he included plans for building it. It was an interesting series to read. Have a look!\n\nhttp://iphonedevelopment.blogspot.com/2011/12/brilliantly-simple-idea-treadmill-desk.html\n\nhttp://iphonedevelopment.blogspot.com/2011/12/treadmill-desk-update.html\n\nhttp://iphonedevelopment.blogspot.com/2012/01/treadmill-desk-plans.html	<p>How about a treadmill desk?</p>\n\n<p>Jeff LeMarche, iPhone developer, had a series of blog posts about using a treadmill desk. In the final one that he posted, he included plans for building it. It was an interesting series to read. Have a look!</p>\n\n<p><a href="http://iphonedevelopment.blogspot.com/2011/12/brilliantly-simple-idea-treadmill-desk.html" class="onebox">http://iphonedevelopment.blogspot.com/2011/12/brilliantly-simple-idea-treadmill-desk.html</a></p>\n\n<p><a href="http://iphonedevelopment.blogspot.com/2011/12/treadmill-desk-update.html" class="onebox">http://iphonedevelopment.blogspot.com/2011/12/treadmill-desk-update.html</a></p>\n\n<p><a href="http://iphonedevelopment.blogspot.com/2012/01/treadmill-desk-plans.html" class="onebox">http://iphonedevelopment.blogspot.com/2012/01/treadmill-desk-plans.html</a></p>	2013-02-04 19:43:40.45135	2013-02-04 19:43:40.45135	\N	1	0	0	\N	0	1	0	0	71	19.3500000000000014	4	1	0	2	22	f	\N	0	0	0	0	2013-02-04 19:43:40.450886	f	\N
76	7	52	1	I noticed that replies here are not indented directly under the thing they reply to, as I'm used to in email\n\n> Someone says this\n> > Then I reply with this\n\nHow do I follow conversations when someome is replying to something that someone else wrote, and so forth?	<p>I noticed that replies here are not indented directly under the thing they reply to, as I'm used to in email</p>\n\n<blockquote>\n  <p>Someone says this</p>\n  \n  <blockquote>\n    <p>Then I reply with this</p>\n  </blockquote>\n</blockquote>\n\n<p>How do I follow conversations when someome is replying to something that someone else wrote, and so forth?</p>	2013-02-04 20:03:22.058651	2013-02-04 20:03:22.058651	\N	1	0	0	\N	0	0	0	0	\N	\N	1	1	0	1	7	f	\N	0	0	0	0	2013-02-04 20:03:22.058303	f	\N
72	7	49	1	I've seen a bunch of topics with pictures in them.\n\nHow do I add images to a post? Do I have to upload them somehow?	<p>I've seen a bunch of topics with pictures in them.</p>\n\n<p>How do I add images to a post? Do I have to upload them somehow?</p>	2013-02-04 19:51:47.945822	2013-02-04 19:51:47.945822	\N	1	0	0	\N	0	0	0	0	7	1.14999999999999991	4	1	0	1	7	f	\N	0	0	0	0	2013-02-04 19:51:47.945457	f	\N
68	23	48	1	“A bear, however hard he tries, grows tubby without exercise.”  \n― A.A. Milne, Winnie-the-Pooh \n\nAs a programmer I sit at a desk at work, which means I'm overweight, but worse - I'm out of shape. I wouldn't mind the extra weight if I knew that my heart, kidneys and other internal organs also didn't mind, but given that I do little regular physical activity that gets my heart rate up for 30+ minutes I know that I'm both fat and unfit.\n\nWhat are some suggestions on ways to get myself onto a road and in a set of habits that will, at minimum, keep me in shape so that I don't die of heart disease in my 50's, or succumb to diabetes (as popular as it is, I think I'd like to opt out this lifetime), or attract some other illness that seems invariably drawn to the unfit and overweight.\n\nWhat did you do to break out of your comfort zone?\n\nWas risk of shortened life span enough for you, or are you using other mental tricks to keep yourself motivated?\n\nWhat benefits of regular aerobic exercise can I expect to get that might also motivate me to do so?\n\nDo you even lift, bro?	<p>“A bear, however hard he tries, grows tubby without exercise.” <br>\n― A.A. Milne, Winnie-the-Pooh </p>\n\n<p>As a programmer I sit at a desk at work, which means I'm overweight, but worse - I'm out of shape. I wouldn't mind the extra weight if I knew that my heart, kidneys and other internal organs also didn't mind, but given that I do little regular physical activity that gets my heart rate up for 30+ minutes I know that I'm both fat and unfit.</p>\n\n<p>What are some suggestions on ways to get myself onto a road and in a set of habits that will, at minimum, keep me in shape so that I don't die of heart disease in my 50's, or succumb to diabetes (as popular as it is, I think I'd like to opt out this lifetime), or attract some other illness that seems invariably drawn to the unfit and overweight.</p>\n\n<p>What did you do to break out of your comfort zone?</p>\n\n<p>Was risk of shortened life span enough for you, or are you using other mental tricks to keep yourself motivated?</p>\n\n<p>What benefits of regular aerobic exercise can I expect to get that might also motivate me to do so?</p>\n\n<p>Do you even lift, bro?</p>	2013-02-04 19:38:46.835615	2013-02-04 19:38:46.835615	\N	1	1	0	\N	0	0	0	0	86	10.3000000000000007	5	1	0	1	23	f	\N	0	0	0	0	2013-02-04 19:38:46.835257	f	\N
45	20	36	1	Many bugs that were eradicated a week ago from localhost:4000 are present here. Can somebody confirm whether this will be upgraded prior to launch?	<p>Many bugs that were eradicated a week ago from localhost:4000 are present here. Can somebody confirm whether this will be upgraded prior to launch?</p>	2013-02-01 14:21:26.695568	2013-02-01 14:21:26.695568	\N	1	0	0	\N	0	0	0	0	63	3.95000000000000018	4	1	0	1	20	f	\N	0	0	0	0	2013-02-01 14:21:26.695568	f	\N
55	2	37	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\n- To get back to the home page at any time, **click the icon at the upper left.**\n\n- To search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n- While reading a topic, you can move to the top by clicking its title at the top of the page. To reach the *bottom*, click the down arrow on the topic progress indicator at the bottom of the page, or click the last post field on the topic summary under the first post.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<ul>\n<li><p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p></li>\n<li><p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p></li>\n<li>While reading a topic, you can move to the top by clicking its title at the top of the page. To reach the <em>bottom</em>, click the down arrow on the topic progress indicator at the bottom of the page, or click the last post field on the topic summary under the first post.</li>\n</ul><p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-02-04 18:20:43.015643	2013-02-04 18:20:43.015643	\N	1	0	0	\N	0	0	0	0	3	0.349999999999999978	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 18:20:43.015263	f	\N
39	20	15	2	My wife and I have had some good laughs with Charlie.	<p>My wife and I have had some good laughs with Charlie.</p>	2013-02-01 04:37:48.575147	2013-02-01 04:37:48.575147	\N	1	0	0	\N	0	0	0	0	33	2.64999999999999991	5	1	0	2	20	f	\N	0	0	0	0	2013-02-01 04:37:48.575147	f	\N
75	7	51	1	I noticed there's a few different ways to reply. \n\nI'm unclear which method of replying I should use, and when. Can anyone clarify this for me?\n\nAlso how do I quote someone else's post, as I have seen others do in replies here?	<p>I noticed there's a few different ways to reply. </p>\n\n<p>I'm unclear which method of replying I should use, and when. Can anyone clarify this for me?</p>\n\n<p>Also how do I quote someone else's post, as I have seen others do in replies here?</p>	2013-02-04 20:00:06.872741	2013-02-04 20:00:06.872741	\N	1	0	0	\N	0	0	0	0	\N	0.200000000000000011	1	1	0	1	7	f	\N	0	0	0	0	2013-02-04 20:00:06.872415	f	\N
34	2	32	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\n- To get back to the home page at any time, **click the icon at the upper left.**\n\n- To search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n- To reach the top of a topic, click the title. To reach the *bottom*, click the arrow on the topic progress indicator at the bottom of the page, the last post field on the topic summary under the first post, or the last post date in the topic list.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<ul>\n<li><p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p></li>\n<li><p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p></li>\n<li>To reach the top of a topic, click the title. To reach the <em>bottom</em>, click the arrow on the topic progress indicator at the bottom of the page, the last post field on the topic summary under the first post, or the last post date in the topic list.</li>\n</ul><p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-02-01 01:29:40.614741	2013-02-01 01:29:40.614741	\N	1	0	0	\N	0	0	0	0	6	0.5	1	1	0	1	2	f	\N	0	0	0	0	2013-02-01 01:29:40.614741	f	\N
22	2	22	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\nTo get back to the home page at any time, **click the icon at the upper left.**\n\nTo search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p>\n\n<p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-31 20:38:43.690107	2013-01-31 20:38:43.690107	\N	1	0	0	\N	0	0	0	0	4	0.400000000000000022	1	1	0	1	2	f	\N	0	0	0	0	2013-01-31 20:38:43.690107	f	\N
14	2	14	1	Welcome to the Discourse sandbox!  Play around and try all the features.	<p>Welcome to the Discourse sandbox!  Play around and try all the features.</p>	2013-01-07 22:04:47.515687	2013-01-07 22:04:47.515687	\N	1	0	0	\N	0	0	0	0	3	1.75	8	1	0	1	2	f	\N	0	0	0	0	2013-01-07 22:04:47.515687	f	\N
69	19	39	2	PERL for Perl or perl.  There's enormous nerd cultural sensitivity around it -- words have _meaning_, dammit! -- but I don't see where the all-caps version came from.  The retconned acronym, maybe?	<p>PERL for Perl or perl.  There's enormous nerd cultural sensitivity around it -- words have <em>meaning</em>, dammit! -- but I don't see where the all-caps version came from.  The retconned acronym, maybe?</p>	2013-02-04 19:40:13.635558	2013-02-04 19:40:13.635558	1	1	0	0	\N	0	0	0	0	18	1.30000000000000004	2	1	0	2	19	f	\N	0	0	0	0	2013-02-04 19:40:13.635213	f	22
30	12	27	3	I'm just testing something else.	<p>I'm just testing something else.</p>	2013-01-31 22:11:11.074018	2013-01-31 22:11:11.074018	\N	1	0	0	\N	0	0	0	0	20	2.60000000000000009	8	1	0	3	12	f	\N	0	0	0	0	2013-01-31 22:11:11.074018	f	\N
13	2	13	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-01-07 22:03:53.869432	2013-01-07 22:03:53.869432	\N	1	0	0	\N	0	0	0	0	\N	0.200000000000000011	2	1	0	1	2	f	\N	0	0	0	0	2013-01-07 22:03:53.869432	f	\N
27	2	29	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\nTo get back to the home page at any time, **click the icon at the upper left.**\n\nTo search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p>\n\n<p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-31 21:54:37.777704	2013-01-31 21:54:37.777704	\N	1	0	0	\N	0	0	0	0	\N	0	0	1	0	1	2	f	\N	0	0	0	0	2013-01-31 21:54:37.777704	f	\N
40	20	27	4	I'm going to have to go with Moon. I can't post a link to IMDB because the body 'has too many images.'	<p>I'm going to have to go with Moon. I can't post a link to IMDB because the body 'has too many images.'</p>	2013-02-01 04:38:45.330664	2013-02-01 04:38:45.330664	\N	1	1	0	\N	0	0	0	0	13	6.84999999999999964	6	1	0	4	20	f	\N	0	0	0	0	2013-02-01 04:38:45.330664	f	\N
15	2	15	1	Poor Charlie:\n\nhttp://www.youtube.com/watch?v=wbF9nLhOqLU\n	<p>Poor Charlie:</p>\n\n<p><iframe width="480" height="270" src="http://www.youtube.com/embed/wbF9nLhOqLU?feature=oembed" frameborder="0" allowfullscreen></iframe>  </p>	2013-01-07 22:06:26.929342	2013-01-07 22:06:26.929342	\N	1	1	0	\N	0	0	0	0	21	8.05000000000000071	10	1	0	1	2	f	\N	0	0	0	0	2013-01-07 22:06:26.929342	f	\N
20	2	20	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\nTo get back to the home page at any time, **click the icon at the upper left.**\n\nTo search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p>\n\n<p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-31 20:15:19.196245	2013-01-31 20:15:19.196245	\N	1	0	0	\N	0	0	0	0	\N	0	0	1	0	1	2	f	\N	0	0	0	0	2013-01-31 20:15:19.196245	f	\N
25	9	27	1	Which Sci-Fi movie (or series) of the 2000's mattered most to you? Which is the one that you think will come to your mind when asked about it in 20, 30, 40 years?	<p>Which Sci-Fi movie (or series) of the 2000's mattered most to you? Which is the one that you think will come to your mind when asked about it in 20, 30, 40 years?</p>	2013-01-31 21:45:18.097462	2013-01-31 22:04:44.604122	\N	2	0	0	\N	0	0	0	0	17	2.64999999999999991	9	1	0	1	9	f	\N	0	0	0	0	2013-01-31 22:04:44.616199	f	\N
29	14	26	2	I've traveled a lot in the US by car and done the same thing. It's possible but it is a little more difficult as you've seen. It's actually easier to sleep in your car the farther off the beaten track you are. A few other things that work\n\n- rest stops in the US specifically allow sleeping in your vehicle overnight unless marked to the contrary. This is usually set up on a state by state basis, so make sure you check per state.\n- Walmart used to let people park RVs in their lots (and travel vans) have not kept up with whether they still do this\n- National forest land is usually okay/lega for this sort of thing\n\nBut yeah I think people in the US are a little more nervy about stranger danger and our relationship to private property. If you do a little googling on the topic of "boondocking" you can read about the way a lot of people deal with this sort of thing.	<p>I've traveled a lot in the US by car and done the same thing. It's possible but it is a little more difficult as you've seen. It's actually easier to sleep in your car the farther off the beaten track you are. A few other things that work</p>\n\n<ul>\n<li>rest stops in the US specifically allow sleeping in your vehicle overnight unless marked to the contrary. This is usually set up on a state by state basis, so make sure you check per state.</li>\n<li>Walmart used to let people park RVs in their lots (and travel vans) have not kept up with whether they still do this</li>\n<li>National forest land is usually okay/lega for this sort of thing</li>\n</ul><p>But yeah I think people in the US are a little more nervy about stranger danger and our relationship to private property. If you do a little googling on the topic of "boondocking" you can read about the way a lot of people deal with this sort of thing.</p>	2013-01-31 22:10:16.460181	2013-01-31 22:10:16.460181	\N	1	0	0	\N	0	1	0	0	24	18	9	1	0	2	14	f	\N	0	0	0	0	2013-01-31 22:10:16.460181	f	\N
63	2	43	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-02-04 19:29:52.839308	2013-02-04 19:29:52.839308	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 19:29:52.838913	f	\N
10	2	10	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-01-07 22:01:32.173703	2013-01-07 22:01:32.173703	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-01-07 22:01:32.173703	f	\N
32	2	30	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\nTo get back to the home page at any time, **click the icon at the upper left.**\n\nTo search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p>\n\n<p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-31 22:18:59.442965	2013-01-31 22:18:59.442965	\N	1	0	0	\N	0	0	0	0	3	0.349999999999999978	1	1	0	1	2	f	\N	0	0	0	0	2013-01-31 22:18:59.442965	f	\N
60	23	26	4	In the 1800's a lot of separate interests competed for land on the American frontier, leading farmers to fence in their land so it could be used in totality for their own interests, and not for fattening up cattle.\n\n> As settlers advanced into cattle country, a conflict was inevitable between the farmers who fenced their land with barbed wire and sought to control water sources and the ranchers whose livelihood depended on keeping the range open. But the so-called range wars also pitted cattlemen against sheepherders (sheep were notorious for eating grasses down to the stubble so that the land was unsuited for cattle grazing) and cattle barons against smaller ranchers. ([source][1])\n\nIn general, land that was not fenced and posted with signs claiming ownership would be exploited, so  the practice of fencing and posting notices is ingrained into the US culture, particularly in the west.\n\nFurthermore, the laws that allow deadly force to be used on trespassers are much more prevalent in the US than other developed parts of the world, making it dangerous to cross fences and posted notices.  These, again, come from a lot of the thieving and cattle wars that occurred in the early days of westward American expansion when there was little to no law enforcement, and one was only as safe as one could make themselves.\n\nEven now, though, there is another compelling reason.  There are countless dangers to adventurous types, such as mines, wells, cliffs, etc, and successful lawsuits have been brought to bear against landowners who did not make their land safe for passers by, nor prevent them from entering the land.  Liability now plays some role in the continued maintenance of those fences today.\n\n  [1]: http://www.cliffsnotes.com/study_guide/The-Cattle-Kingdom.topicArticleId-25238,articleId-25174.html	<p>In the 1800's a lot of separate interests competed for land on the American frontier, leading farmers to fence in their land so it could be used in totality for their own interests, and not for fattening up cattle.</p>\n\n<blockquote>\n  <p>As settlers advanced into cattle country, a conflict was inevitable between the farmers who fenced their land with barbed wire and sought to control water sources and the ranchers whose livelihood depended on keeping the range open. But the so-called range wars also pitted cattlemen against sheepherders (sheep were notorious for eating grasses down to the stubble so that the land was unsuited for cattle grazing) and cattle barons against smaller ranchers. (<a href="http://www.cliffsnotes.com/study_guide/The-Cattle-Kingdom.topicArticleId-25238,articleId-25174.html">source</a>)</p>\n</blockquote>\n\n<p>In general, land that was not fenced and posted with signs claiming ownership would be exploited, so  the practice of fencing and posting notices is ingrained into the US culture, particularly in the west.</p>\n\n<p>Furthermore, the laws that allow deadly force to be used on trespassers are much more prevalent in the US than other developed parts of the world, making it dangerous to cross fences and posted notices.  These, again, come from a lot of the thieving and cattle wars that occurred in the early days of westward American expansion when there was little to no law enforcement, and one was only as safe as one could make themselves.</p>\n\n<p>Even now, though, there is another compelling reason.  There are countless dangers to adventurous types, such as mines, wells, cliffs, etc, and successful lawsuits have been brought to bear against landowners who did not make their land safe for passers by, nor prevent them from entering the land.  Liability now plays some role in the continued maintenance of those fences today.</p>	2013-02-04 18:56:49.789741	2013-02-04 18:58:29.497776	\N	1	0	0	\N	0	0	0	0	101	5.45000000000000018	2	1	0	4	23	f	\N	0	0	0	0	2013-02-04 18:56:49.789349	f	\N
24	11	26	1	I'm a European who had the privilege of travelling California, Nevada, and Arizona for a couple of weeks last fall. It was my first visit to the US. I was travelling by car, hoping to be able to sleep in it (or in a tent next to it) as often as possible to save money. I'm a very quiet, respectful traveler with a "leave nothing behind" approach so I felt that was okay to do. \n\nHowever, that wasn't as easy as I had anticipated! I was virtually unable to find any space off the main roads that wasn't closed off, and marked "private property." I don't feel comfortable sleeping somewhere I'm not supposed to be (even though the risk of getting caught was probably minimal) so I had to limit my free camping mainly to the desert.\n\nThis came as a big surprise to me, I had expected the exact opposite because the country is so vast. Germany is much more densely settled than the US, and much of its uninhabited area is private property, too. However, it's *way* more accessible. You find a huge network of dirt roads everywhere, going through every small forest, taking you far off the main roads. Private property is rarely marked, and rarely impassable (I think it's generally prohibited to block it off). Finding a secure place to stay for the night while traveling by car is really, really easy.\n\nWhy do you think this is?\n\n- Is this a traditional, "keep off my lawn" thing, related to the US's cultural focus on private property?\n- Is it a recent thing, to do with liability / a heightened sense of fear from intruders / massive problems with vandalism and such?\n- Was I just in the wrong places?	<p>I'm a European who had the privilege of travelling California, Nevada, and Arizona for a couple of weeks last fall. It was my first visit to the US. I was travelling by car, hoping to be able to sleep in it (or in a tent next to it) as often as possible to save money. I'm a very quiet, respectful traveler with a "leave nothing behind" approach so I felt that was okay to do. </p>\n\n<p>However, that wasn't as easy as I had anticipated! I was virtually unable to find any space off the main roads that wasn't closed off, and marked "private property." I don't feel comfortable sleeping somewhere I'm not supposed to be (even though the risk of getting caught was probably minimal) so I had to limit my free camping mainly to the desert.</p>\n\n<p>This came as a big surprise to me, I had expected the exact opposite because the country is so vast. Germany is much more densely settled than the US, and much of its uninhabited area is private property, too. However, it's <em>way</em> more accessible. You find a huge network of dirt roads everywhere, going through every small forest, taking you far off the main roads. Private property is rarely marked, and rarely impassable (I think it's generally prohibited to block it off). Finding a secure place to stay for the night while traveling by car is really, really easy.</p>\n\n<p>Why do you think this is?</p>\n\n<ul>\n<li>Is this a traditional, "keep off my lawn" thing, related to the US's cultural focus on private property?</li>\n<li>Is it a recent thing, to do with liability / a heightened sense of fear from intruders / massive problems with vandalism and such?</li>\n<li>Was I just in the wrong places?</li>\n</ul>	2013-01-31 21:34:39.375179	2013-01-31 21:40:29.280896	\N	3	0	0	\N	0	0	0	0	26	3.10000000000000009	9	1	0	1	11	f	\N	0	0	0	0	2013-01-31 21:40:29.300543	f	\N
28	9	27	2	I'm going to say *Children of Men*. I thought it was a complete stunner. The basic premise (mankind becomes infertile) is total Science Fiction of course, but a dystopian 2027 Britain is made utterly believable in so, so many small details, many of which you notice only when viewing it the third or fourth time. A heartbreaking story about a broken man; gripping drama to the end. \n\n... and one of the most goose-bumpy scenes I've ever seen in a movie (you'll know what I'm talking about when you see it.)\n\nhttp://youtu.be/2VT2apoX90o	<p>I'm going to say <em>Children of Men</em>. I thought it was a complete stunner. The basic premise (mankind becomes infertile) is total Science Fiction of course, but a dystopian 2027 Britain is made utterly believable in so, so many small details, many of which you notice only when viewing it the third or fourth time. A heartbreaking story about a broken man; gripping drama to the end. </p>\n\n<p>... and one of the most goose-bumpy scenes I've ever seen in a movie (you'll know what I'm talking about when you see it.)</p>\n\n<p><iframe width="480" height="270" src="http://www.youtube.com/embed/2VT2apoX90o?feature=oembed" frameborder="0" allowfullscreen></iframe></p>	2013-01-31 21:56:35.884318	2013-01-31 21:58:31.282589	\N	1	0	0	\N	0	1	4	0	33	38.4500000000000028	9	1	0	2	9	f	\N	0	0	0	0	2013-01-31 21:56:35.884318	f	\N
17	2	17	1	Hi there!\n\nThanks for joining Try Discourse. Welcome!\n\nHere are a few quick tips to get the most out of this forum:\n\n**Keep Scrolling**\n\nThere are no next page button or page numbers here. To keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\nWe believe in [civilized community behavior](/faq) at all times.\n\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse. Welcome!</p>\n\n<p>Here are a few quick tips to get the most out of this forum:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There are no next page button or page numbers here. To keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-01-29 05:15:31.723979	2013-01-29 05:15:31.723979	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-01-29 05:15:31.723979	f	\N
59	2	40	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\n- To get back to the home page at any time, **click the icon at the upper left.**\n\n- To search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n- While reading a topic, you can move to the top by clicking its title at the top of the page. To reach the *bottom*, click the down arrow on the topic progress indicator at the bottom of the page, or click the last post field on the topic summary under the first post.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<ul>\n<li><p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p></li>\n<li><p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p></li>\n<li>While reading a topic, you can move to the top by clicking its title at the top of the page. To reach the <em>bottom</em>, click the down arrow on the topic progress indicator at the bottom of the page, or click the last post field on the topic summary under the first post.</li>\n</ul><p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-02-04 18:41:40.760571	2013-02-04 18:41:40.760571	\N	1	0	0	\N	0	0	0	0	1	0.25	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 18:41:40.760268	f	\N
58	22	39	1	It drives me crazy when people type MAC when they are referring to Apple Mac computers. The networking nerd in me shakes an angry fist into the angry air. \n\nAre there any other similar misuses of words/abbreviations that bother you?	<p>It drives me crazy when people type MAC when they are referring to Apple Mac computers. The networking nerd in me shakes an angry fist into the angry air. </p>\n\n<p>Are there any other similar misuses of words/abbreviations that bother you?</p>	2013-02-04 18:32:37.638577	2013-02-04 18:32:37.638577	\N	1	1	0	\N	0	0	0	0	29	7.25	4	1	0	1	22	f	\N	0	0	0	0	2013-02-04 18:32:37.637962	f	\N
42	20	27	6	Well, shiver me timbers. Edit: that is a super low-res image from imdb. Should look like the second.\n\nhttp://www.imdb.com/title/tt1182345/?ref_=sr_3\n\n<img src='/uploads/try2_discourse/10/mv5bmtgzodgyntqwov5bml5banbnxkftztcwnzc0ntc0mg__v1_sy317_cr00214317_.jpeg' width='214' height='317'>	<p>Well, shiver me timbers. Edit: that is a super low-res image from imdb. Should look like the second.</p>\n\n<p><div class="onebox-result">\n    <div class="source">\n      <div class="info">\n        <a href="http://www.imdb.com/title/tt1182345/?ref_=sr_3" target="_blank">\n          imdb.com\n        </a>\n      </div>\n    </div>\n  <div class="onebox-result-body">\n    <img src="http://ia.media-imdb.com/images/M/MV5BMTgzODgyNTQwOV5BMl5BanBnXkFtZTcwNzc0NTc0Mg@@._V1_SX32_CR0,0,32,44_.jpg" class="thumbnail" width="126" height="140" />\n    <h3><a href="http://www.imdb.com/title/tt1182345/?ref_=sr_3" target="_blank">Moon (2009)</a></h3>\n    \n    \n  </div>\n  <div class="clearfix"></div>\n</div>\n</p>\n\n<p><img src="http://cdn2.discourse.org/uploads/try2_discourse/10/mv5bmtgzodgyntqwov5bml5banbnxkftztcwnzc0ntc0mg__v1_sy317_cr00214317_.jpeg" width="214" height="317" /></p>	2013-02-01 14:12:42.227156	2013-02-01 14:13:35.182408	5	1	0	0	\N	0	0	0	0	15	1.94999999999999996	6	1	0	6	20	f	\N	0	0	0	0	2013-02-01 14:12:42.227156	f	11
38	2	35	1	Hi there!\n\nThanks for joining Try Discourse, and welcome to our discussion forum!\n\nThis private message has a few quick tips to get you started:\n\n**Keep Scrolling**\n\nThere is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!\n\nAs new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.\n\n**How Do I Reply?**\n\n- To reply to a specific post, use the Reply button at the bottom of that post.\n\n- If you want to reply to the overall *theme* of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.\n\n- If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.\n\n**Who is Talking to Me?**\n\nWhen someone replies to your post, quotes you, or mentions your @username, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!\n\n- To mention someone's name, start typing `@` and an autocompleter will pop up.\n\n- To quote an entire post, use the Import Quote button on the composer toolbar.\n\n- To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.\n\n**Look at That Post!**\n\nTo let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.\n\n**Where am I?**\n\n- To get back to the home page at any time, **click the icon at the upper left.**\n\n- To search, visit your user page, or otherwise navigate, click on the icons at the upper right.\n- While reading a topic, you can move to the top by clicking its title at the top of the page. To reach the *bottom*, click the down arrow on the topic progress indicator at the bottom of the page, or click the last post field on the topic summary under the first post.\n\n\nWe believe in [civilized community behavior](/faq) at all times.\n\nEnjoy your stay!	<p>Hi there!</p>\n\n<p>Thanks for joining Try Discourse, and welcome to our discussion forum!</p>\n\n<p>This private message has a few quick tips to get you started:</p>\n\n<p><strong>Keep Scrolling</strong></p>\n\n<p>There is no next page button or page numbers -- to keep reading, just keep scrolling down, and more content will load!</p>\n\n<p>As new replies come in, they will appear automatically at the bottom of the topic. No need to refresh the page or re-enter the topic to see new posts.</p>\n\n<p><strong>How Do I Reply?</strong></p>\n\n<ul>\n<li><p>To reply to a specific post, use the Reply button at the bottom of that post.</p></li>\n<li><p>If you want to reply to the overall <em>theme</em> of the topic, rather than any specific person in the topic, use the Reply button at the very bottom of the topic.</p></li>\n<li><p>If you want to take the conversation in a different direction, but keep them linked together, use Reply as New Topic to the right of the post.</p></li>\n</ul><p><strong>Who is Talking to Me?</strong></p>\n\n<p>When someone replies to your post, quotes you, or mentions your <span class="mention">@username</span>, a notification will appear at the top of the page. Click or tap the notification number to see who's talking to you, and where. Join the conversation!</p>\n\n<ul>\n<li><p>To mention someone's name, start typing <code>@</code> and an autocompleter will pop up.</p></li>\n<li><p>To quote an entire post, use the Import Quote button on the composer toolbar.</p></li>\n<li><p>To quote just a section of a post, highlight it, then click the Reply button that appears over the highlight.</p></li>\n</ul><p><strong>Look at That Post!</strong></p>\n\n<p>To let someone know that you enjoyed their post, click the like button at the bottom of the post. If you see a problem with a post, don't hesitate to click the flag button and let the moderators -- and your fellow community members -- know about it.</p>\n\n<p><strong>Where am I?</strong></p>\n\n<ul>\n<li><p>To get back to the home page at any time, <strong>click the icon at the upper left.</strong></p></li>\n<li><p>To search, visit your user page, or otherwise navigate, click on the icons at the upper right.</p></li>\n<li>While reading a topic, you can move to the top by clicking its title at the top of the page. To reach the <em>bottom</em>, click the down arrow on the topic progress indicator at the bottom of the page, or click the last post field on the topic summary under the first post.</li>\n</ul><p>We believe in <a href="/faq">civilized community behavior</a> at all times.</p>\n\n<p>Enjoy your stay!</p>	2013-02-01 04:37:18.133193	2013-02-01 04:37:18.133193	\N	1	0	0	\N	0	0	0	0	4	0.400000000000000022	1	1	0	1	2	f	\N	0	0	0	0	2013-02-01 04:37:18.133193	f	\N
35	19	34	1	Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc malesuada diam sed lacus rutrum iaculis. Donec pharetra eros id eros mollis vel malesuada lectus egestas. Suspendisse potenti. Morbi vitae urna vestibulum tortor ultrices bibendum vitae sed nunc. Phasellus blandit dignissim magna dignissim accumsan. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Sed scelerisque vestibulum lorem, ac lacinia erat pellentesque ut. Cras cursus varius sem, sed elementum neque fringilla ut. In at eros ante, non tristique velit.\n\nVivamus eget ultricies mi. Proin ac magna sem. Sed vitae tellus ut sem rhoncus mollis. Nunc ac velit lacus. Aenean tincidunt tempus lorem et posuere. In hac habitasse platea dictumst. Pellentesque ultricies lacinia quam, ut convallis ante interdum sit amet. In sed lacus id purus rutrum gravida et ac elit.\n\nMaecenas ut rutrum metus. Mauris sem augue, tempor sit amet consectetur rutrum, eleifend id urna. Sed eget mauris ut diam lacinia posuere porta in dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam laoreet lacinia leo, nec laoreet eros blandit quis. Phasellus scelerisque vulputate ipsum, eget vehicula nulla dignissim nec. Cras suscipit tempus porttitor. Aenean sed lorem massa. Nulla facilisi. Nullam vel velit metus, at consectetur urna. Vivamus eu erat metus. Aliquam adipiscing, turpis ut convallis ultrices, lorem ipsum rutrum nibh, at vulputate eros libero et felis. Proin vel ullamcorper neque. Maecenas suscipit, mauris sed egestas cursus, urna enim molestie sapien, ornare venenatis magna risus sed tortor. Donec varius, arcu ut interdum pulvinar, ipsum justo vehicula lorem, ac adipiscing lacus orci id dolor. Quisque auctor arcu nec nibh fringilla consectetur.\n\nMaecenas ornare lacinia libero, sit amet adipiscing sem feugiat at. Curabitur imperdiet mauris sit amet sapien dictum tincidunt. Ut metus augue, rutrum eu molestie ut, imperdiet vel dui. Cras fermentum dolor vitae ligula vehicula sit amet pretium tellus tempor. Nunc ut nulla dolor, quis sagittis erat. Etiam a faucibus metus. Duis laoreet posuere congue.\n\nEtiam fringilla massa vitae nisi pulvinar et gravida arcu interdum. Mauris ac libero vel elit molestie blandit. Morbi bibendum blandit nulla, eget dapibus tortor porta non. Nulla facilisi. Nulla felis orci, eleifend sit amet pulvinar at, hendrerit ut mi. Morbi elementum neque ac est blandit quis bibendum diam gravida. Sed id tortor dui, sed sollicitudin nulla. Phasellus id odio eget neque semper sollicitudin. Suspendisse accumsan libero in nulla tristique volutpat. Cras odio dolor, euismod eget aliquam in, viverra eget purus. Integer egestas sodales justo, molestie luctus eros faucibus ac. Ut vitae massa purus, a faucibus tortor. Sed feugiat justo et sem varius dapibus ultricies nunc auctor. Donec vestibulum ipsum sit amet felis pellentesque pretium. Donec arcu sem, viverra eget ullamcorper eu, pulvinar quis libero. Donec fermentum ornare velit, a auctor odio lobortis gravida.\n\nProin eros magna, semper nec elementum quis, faucibus a nisl. Nullam libero massa, pulvinar convallis volutpat quis, malesuada in metus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Nulla blandit sollicitudin lorem eget aliquam. Cras in urna neque. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nullam eu augue quam, in varius ligula. Fusce ac neque at leo porta volutpat nec quis risus. Integer neque erat, aliquam ut accumsan at, posuere eget orci. Maecenas euismod, odio eget accumsan mattis, neque velit adipiscing lacus, id iaculis dui orci ac massa. Sed viverra, ipsum vitae ornare facilisis, dolor risus facilisis odio, eget ullamcorper quam lectus id est. Integer laoreet dolor sit amet felis gravida adipiscing. Nunc dui eros, tristique fringilla dignissim ac, gravida et justo.\n\nInteger non justo a lacus tempus consequat vel non neque. Aliquam adipiscing, metus a mattis cursus, sem elit luctus diam, a mattis est nulla sed nulla. Duis ultricies gravida ante et semper. Sed ornare metus quis enim auctor consectetur in et ipsum. Nunc aliquet, augue at molestie eleifend, urna metus imperdiet nunc, eu vehicula mauris erat sed enim. In diam nunc, malesuada ac laoreet id, tristique id orci. Nullam non magna dui. Fusce sapien quam, accumsan vulputate venenatis non, faucibus eu sapien. Nullam elementum accumsan ligula in sagittis. Nulla at augue mauris.\n\nNulla tristique, dui eget aliquam rutrum, erat lectus porta velit, eu hendrerit justo nibh commodo nunc. Curabitur imperdiet vulputate lectus vel porttitor. In id est quis dolor congue rhoncus. Donec mattis aliquet diam, sit amet pretium purus viverra ut. Vestibulum sit amet arcu metus, a sollicitudin enim. Sed gravida ante nec nisl lobortis quis cursus eros molestie. Sed semper, felis posuere pulvinar aliquet, leo neque blandit diam, eu elementum risus diam sit amet libero. Etiam pharetra turpis vel dui tempor viverra. Aliquam eu tellus diam. Aliquam venenatis pretium vulputate. Cras eget eros metus, ut eleifend sem. Aliquam in ipsum tortor. Sed sed pretium neque.\n\nFusce tempus placerat lacus. Vestibulum ac nibh purus. Integer facilisis tincidunt lacinia. Mauris volutpat, nibh condimentum placerat rutrum, magna enim malesuada ligula, eget tristique erat lectus eget massa. Nam nibh lacus, dictum vitae faucibus nec, lobortis id massa. Nulla ac massa nibh. Donec erat erat, euismod eu sollicitudin sit amet, ultrices sit amet leo. Sed molestie tincidunt est, vel blandit orci suscipit cursus. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean vel sem lacus. Vivamus elementum ipsum eget velit elementum blandit. Etiam ullamcorper odio ornare diam pretium non congue risus venenatis. Nam nec pellentesque purus. Fusce eu lorem velit, elementum ultricies velit. Pellentesque vel purus id dolor convallis ullamcorper sit amet nec felis.\n\nPraesent fermentum dapibus interdum. Ut scelerisque, nisi id mollis adipiscing, urna nibh sagittis metus, at facilisis erat urna non nisl. Duis id leo sed purus scelerisque blandit non a lorem. Nulla blandit leo sed erat elementum non pulvinar eros adipiscing. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nam vitae sem a neque vulputate porta. Cras vulputate aliquam vehicula. Ut id volutpat urna. Donec fringilla molestie lacus. Etiam est nunc, lacinia vitae aliquet nec, semper at felis.\n\nInteger at neque et arcu venenatis convallis ac eget neque. Fusce sit amet arcu erat, nec sodales risus. Phasellus dictum sollicitudin adipiscing. Aliquam erat volutpat. Donec sapien odio, fringilla a dignissim vel, condimentum nec massa. Nam sagittis tincidunt felis nec vulputate. Mauris egestas, libero eu accumsan vestibulum, orci urna ultricies tortor, nec venenatis lorem turpis sed risus. Aliquam convallis neque sit amet felis sollicitudin ac auctor nibh rutrum. Nulla sodales, justo eget interdum cursus, enim erat lacinia massa, id dignissim ipsum nibh et leo. Vivamus quis massa quis diam lacinia pharetra at nec orci. Nullam vehicula neque in orci varius pretium. Cras dapibus, felis sed eleifend sollicitudin, felis nulla placerat libero, nec commodo odio risus ornare risus. Etiam gravida dignissim erat, eget malesuada nisi rhoncus at.\n\nPhasellus mollis tincidunt faucibus. Proin nulla dui, vulputate a sodales eu, gravida non eros. Nunc consectetur nisi sed felis accumsan at feugiat nibh tincidunt. Phasellus ullamcorper fringilla imperdiet. Cras tincidunt neque vitae nibh eleifend placerat. Quisque id dui metus, ut viverra purus. Donec viverra lectus sapien, varius porta tellus. Aliquam volutpat mi a justo blandit ut dapibus justo vulputate. Phasellus sed malesuada erat. Pellentesque vitae ligula a eros pharetra lacinia. Ut nisl justo, bibendum vitae vehicula quis, commodo venenatis risus. Phasellus convallis odio a sapien posuere commodo. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Curabitur at sem lorem, nec suscipit metus.\n\nVestibulum cursus varius urna, eget porttitor nisl lobortis in. Donec eget urna sed massa ornare mattis sit amet eu tellus. Integer elit sem, faucibus sit amet suscipit vitae, accumsan aliquet neque. Vivamus in risus non odio pretium congue eget a metus. Donec euismod lorem et libero posuere non placerat massa vehicula. Curabitur rhoncus diam quis ligula varius nec bibendum lacus pulvinar. Suspendisse porttitor erat nec nibh adipiscing ultrices sed nec risus. Fusce volutpat libero ornare erat adipiscing fringilla vehicula justo faucibus. Nunc eu justo velit, non viverra ante. Nulla vestibulum tempus ante ac molestie. Vivamus convallis ultrices nibh, a imperdiet orci commodo vel.\n\nDonec elementum turpis sit amet sapien luctus scelerisque venenatis leo aliquam. Vestibulum nisi nisi, ullamcorper vel pharetra et, rutrum sed magna. Aliquam dignissim arcu sit amet nunc tempus eget congue lorem eleifend. Donec vehicula dui et turpis tincidunt tempor. Fusce ut enim augue. Vestibulum vel pretium leo. Nunc luctus auctor quam, in sollicitudin augue fringilla vulputate. Etiam nibh tortor, vulputate vitae vulputate vel, tempus ut purus. Mauris nibh est, molestie et scelerisque vitae, iaculis id mi. Praesent et leo neque. Proin tincidunt vehicula sagittis. Pellentesque ac nisi urna, at mattis lectus. Nam lacinia justo quis sapien facilisis posuere. Proin euismod, tortor blandit faucibus malesuada, lorem nisi tristique lacus, a imperdiet dolor tortor et mauris. Integer tortor enim, sollicitudin convallis rutrum a, tempor quis mauris. Suspendisse porttitor urna id mauris euismod ornare.\n\nAliquam pulvinar viverra luctus. Nunc sed lorem nibh, eu dignissim tortor. Proin pellentesque augue eget metus vestibulum dapibus at quis felis. Nulla tincidunt pellentesque neque quis fringilla. Proin condimentum ornare dui, nec commodo eros elementum eu. Fusce laoreet purus vel dolor ultrices malesuada eu quis arcu. Sed pretium eleifend adipiscing. Ut urna sapien, hendrerit et congue sit amet, placerat sit amet arcu. Aenean vestibulum dolor sed turpis pretium mattis. Morbi eget fermentum felis. Cras scelerisque, quam eu adipiscing placerat, purus lorem lobortis arcu, sit amet condimentum augue metus vitae ipsum. Vestibulum lorem arcu, pulvinar et tristique ut, fermentum in quam. Donec venenatis fermentum ullamcorper.\n\nSuspendisse potenti. Integer et tellus at orci pretium rhoncus non in nisi. Aenean in enim enim. Suspendisse elit felis, pretium vitae sollicitudin eget, ultrices ut mauris. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean vestibulum dui nec nisi iaculis ullamcorper. Donec imperdiet pretium tellus, a malesuada justo dignissim quis. Donec eleifend luctus magna at gravida. Donec blandit interdum nibh, id pretium sapien ultricies in. Sed consequat, augue semper aliquam hendrerit, purus sapien condimentum erat, quis tempus nisi eros vitae tellus.\n\nQuisque eleifend aliquam pulvinar. Fusce luctus tellus elit. Pellentesque ullamcorper accumsan quam ut tristique. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Etiam nec cursus lectus. Quisque risus sem, lobortis vel facilisis in, commodo ac nisl. Ut quis mauris et diam ultricies consectetur a eu sem. Etiam nec massa purus. Donec urna tortor, congue non tincidunt sed, ullamcorper scelerisque tortor. Aliquam eu risus sapien. Morbi in ligula et elit facilisis rhoncus. Suspendisse potenti. Vivamus elementum nisl vel turpis aliquet sit amet scelerisque enim facilisis. Proin laoreet facilisis metus nec vulputate. Vivamus ac nibh at turpis consequat laoreet.\n\nAliquam ultricies, nunc eu eleifend bibendum, justo arcu lobortis mauris, vitae cursus nunc leo in velit. Sed eu odio at velit varius bibendum. Nunc ut enim sit amet sapien aliquet ultrices. Phasellus non lacus sit amet ante bibendum auctor convallis a augue. Etiam pellentesque suscipit quam, vitae dictum ante feugiat pellentesque. Sed tempor volutpat sapien, id bibendum dolor elementum nec. Sed auctor ultrices dolor in dictum. Vestibulum sed ipsum urna, sollicitudin pellentesque erat. Vivamus at massa urna. Sed facilisis mattis magna, id euismod erat pulvinar suscipit.\n\nAliquam et molestie velit. Nunc nec libero quis metus accumsan volutpat et a libero. Nullam ut neque eu est euismod mollis quis nec lorem. Donec vulputate justo ligula, non varius neque. Aliquam rutrum, diam a faucibus elementum, libero est blandit eros, sit amet ullamcorper urna velit egestas purus. Nunc et nisi sapien. Vivamus sagittis tempus malesuada. Integer a venenatis justo.\n\nMauris justo est, blandit pellentesque placerat eget, auctor nec tortor. Fusce viverra risus at odio molestie vestibulum. Suspendisse urna justo, eleifend in adipiscing ac, lacinia vitae arcu. Duis mattis, sem sed rhoncus interdum, neque dolor tristique urna, tristique ornare turpis magna eget tortor. Nullam ultrices justo vel lectus sagittis interdum. Maecenas et magna id augue tempus ultrices et id justo. Proin gravida sagittis pellentesque. Proin dignissim ipsum et nunc pulvinar quis ornare enim posuere. Proin mi mauris, accumsan a iaculis ac, aliquet ac nulla. Fusce quis purus in arcu venenatis tincidunt. Quisque tempor libero vel lectus gravida auctor feugiat diam pulvinar. Lorem ipsum dolor sit amet, consectetur adipiscing elit.	<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc malesuada diam sed lacus rutrum iaculis. Donec pharetra eros id eros mollis vel malesuada lectus egestas. Suspendisse potenti. Morbi vitae urna vestibulum tortor ultrices bibendum vitae sed nunc. Phasellus blandit dignissim magna dignissim accumsan. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Sed scelerisque vestibulum lorem, ac lacinia erat pellentesque ut. Cras cursus varius sem, sed elementum neque fringilla ut. In at eros ante, non tristique velit.</p>\n\n<p>Vivamus eget ultricies mi. Proin ac magna sem. Sed vitae tellus ut sem rhoncus mollis. Nunc ac velit lacus. Aenean tincidunt tempus lorem et posuere. In hac habitasse platea dictumst. Pellentesque ultricies lacinia quam, ut convallis ante interdum sit amet. In sed lacus id purus rutrum gravida et ac elit.</p>\n\n<p>Maecenas ut rutrum metus. Mauris sem augue, tempor sit amet consectetur rutrum, eleifend id urna. Sed eget mauris ut diam lacinia posuere porta in dolor. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam laoreet lacinia leo, nec laoreet eros blandit quis. Phasellus scelerisque vulputate ipsum, eget vehicula nulla dignissim nec. Cras suscipit tempus porttitor. Aenean sed lorem massa. Nulla facilisi. Nullam vel velit metus, at consectetur urna. Vivamus eu erat metus. Aliquam adipiscing, turpis ut convallis ultrices, lorem ipsum rutrum nibh, at vulputate eros libero et felis. Proin vel ullamcorper neque. Maecenas suscipit, mauris sed egestas cursus, urna enim molestie sapien, ornare venenatis magna risus sed tortor. Donec varius, arcu ut interdum pulvinar, ipsum justo vehicula lorem, ac adipiscing lacus orci id dolor. Quisque auctor arcu nec nibh fringilla consectetur.</p>\n\n<p>Maecenas ornare lacinia libero, sit amet adipiscing sem feugiat at. Curabitur imperdiet mauris sit amet sapien dictum tincidunt. Ut metus augue, rutrum eu molestie ut, imperdiet vel dui. Cras fermentum dolor vitae ligula vehicula sit amet pretium tellus tempor. Nunc ut nulla dolor, quis sagittis erat. Etiam a faucibus metus. Duis laoreet posuere congue.</p>\n\n<p>Etiam fringilla massa vitae nisi pulvinar et gravida arcu interdum. Mauris ac libero vel elit molestie blandit. Morbi bibendum blandit nulla, eget dapibus tortor porta non. Nulla facilisi. Nulla felis orci, eleifend sit amet pulvinar at, hendrerit ut mi. Morbi elementum neque ac est blandit quis bibendum diam gravida. Sed id tortor dui, sed sollicitudin nulla. Phasellus id odio eget neque semper sollicitudin. Suspendisse accumsan libero in nulla tristique volutpat. Cras odio dolor, euismod eget aliquam in, viverra eget purus. Integer egestas sodales justo, molestie luctus eros faucibus ac. Ut vitae massa purus, a faucibus tortor. Sed feugiat justo et sem varius dapibus ultricies nunc auctor. Donec vestibulum ipsum sit amet felis pellentesque pretium. Donec arcu sem, viverra eget ullamcorper eu, pulvinar quis libero. Donec fermentum ornare velit, a auctor odio lobortis gravida.</p>\n\n<p>Proin eros magna, semper nec elementum quis, faucibus a nisl. Nullam libero massa, pulvinar convallis volutpat quis, malesuada in metus. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Nulla blandit sollicitudin lorem eget aliquam. Cras in urna neque. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nullam eu augue quam, in varius ligula. Fusce ac neque at leo porta volutpat nec quis risus. Integer neque erat, aliquam ut accumsan at, posuere eget orci. Maecenas euismod, odio eget accumsan mattis, neque velit adipiscing lacus, id iaculis dui orci ac massa. Sed viverra, ipsum vitae ornare facilisis, dolor risus facilisis odio, eget ullamcorper quam lectus id est. Integer laoreet dolor sit amet felis gravida adipiscing. Nunc dui eros, tristique fringilla dignissim ac, gravida et justo.</p>\n\n<p>Integer non justo a lacus tempus consequat vel non neque. Aliquam adipiscing, metus a mattis cursus, sem elit luctus diam, a mattis est nulla sed nulla. Duis ultricies gravida ante et semper. Sed ornare metus quis enim auctor consectetur in et ipsum. Nunc aliquet, augue at molestie eleifend, urna metus imperdiet nunc, eu vehicula mauris erat sed enim. In diam nunc, malesuada ac laoreet id, tristique id orci. Nullam non magna dui. Fusce sapien quam, accumsan vulputate venenatis non, faucibus eu sapien. Nullam elementum accumsan ligula in sagittis. Nulla at augue mauris.</p>\n\n<p>Nulla tristique, dui eget aliquam rutrum, erat lectus porta velit, eu hendrerit justo nibh commodo nunc. Curabitur imperdiet vulputate lectus vel porttitor. In id est quis dolor congue rhoncus. Donec mattis aliquet diam, sit amet pretium purus viverra ut. Vestibulum sit amet arcu metus, a sollicitudin enim. Sed gravida ante nec nisl lobortis quis cursus eros molestie. Sed semper, felis posuere pulvinar aliquet, leo neque blandit diam, eu elementum risus diam sit amet libero. Etiam pharetra turpis vel dui tempor viverra. Aliquam eu tellus diam. Aliquam venenatis pretium vulputate. Cras eget eros metus, ut eleifend sem. Aliquam in ipsum tortor. Sed sed pretium neque.</p>\n\n<p>Fusce tempus placerat lacus. Vestibulum ac nibh purus. Integer facilisis tincidunt lacinia. Mauris volutpat, nibh condimentum placerat rutrum, magna enim malesuada ligula, eget tristique erat lectus eget massa. Nam nibh lacus, dictum vitae faucibus nec, lobortis id massa. Nulla ac massa nibh. Donec erat erat, euismod eu sollicitudin sit amet, ultrices sit amet leo. Sed molestie tincidunt est, vel blandit orci suscipit cursus. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean vel sem lacus. Vivamus elementum ipsum eget velit elementum blandit. Etiam ullamcorper odio ornare diam pretium non congue risus venenatis. Nam nec pellentesque purus. Fusce eu lorem velit, elementum ultricies velit. Pellentesque vel purus id dolor convallis ullamcorper sit amet nec felis.</p>\n\n<p>Praesent fermentum dapibus interdum. Ut scelerisque, nisi id mollis adipiscing, urna nibh sagittis metus, at facilisis erat urna non nisl. Duis id leo sed purus scelerisque blandit non a lorem. Nulla blandit leo sed erat elementum non pulvinar eros adipiscing. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Nam vitae sem a neque vulputate porta. Cras vulputate aliquam vehicula. Ut id volutpat urna. Donec fringilla molestie lacus. Etiam est nunc, lacinia vitae aliquet nec, semper at felis.</p>\n\n<p>Integer at neque et arcu venenatis convallis ac eget neque. Fusce sit amet arcu erat, nec sodales risus. Phasellus dictum sollicitudin adipiscing. Aliquam erat volutpat. Donec sapien odio, fringilla a dignissim vel, condimentum nec massa. Nam sagittis tincidunt felis nec vulputate. Mauris egestas, libero eu accumsan vestibulum, orci urna ultricies tortor, nec venenatis lorem turpis sed risus. Aliquam convallis neque sit amet felis sollicitudin ac auctor nibh rutrum. Nulla sodales, justo eget interdum cursus, enim erat lacinia massa, id dignissim ipsum nibh et leo. Vivamus quis massa quis diam lacinia pharetra at nec orci. Nullam vehicula neque in orci varius pretium. Cras dapibus, felis sed eleifend sollicitudin, felis nulla placerat libero, nec commodo odio risus ornare risus. Etiam gravida dignissim erat, eget malesuada nisi rhoncus at.</p>\n\n<p>Phasellus mollis tincidunt faucibus. Proin nulla dui, vulputate a sodales eu, gravida non eros. Nunc consectetur nisi sed felis accumsan at feugiat nibh tincidunt. Phasellus ullamcorper fringilla imperdiet. Cras tincidunt neque vitae nibh eleifend placerat. Quisque id dui metus, ut viverra purus. Donec viverra lectus sapien, varius porta tellus. Aliquam volutpat mi a justo blandit ut dapibus justo vulputate. Phasellus sed malesuada erat. Pellentesque vitae ligula a eros pharetra lacinia. Ut nisl justo, bibendum vitae vehicula quis, commodo venenatis risus. Phasellus convallis odio a sapien posuere commodo. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Curabitur at sem lorem, nec suscipit metus.</p>\n\n<p>Vestibulum cursus varius urna, eget porttitor nisl lobortis in. Donec eget urna sed massa ornare mattis sit amet eu tellus. Integer elit sem, faucibus sit amet suscipit vitae, accumsan aliquet neque. Vivamus in risus non odio pretium congue eget a metus. Donec euismod lorem et libero posuere non placerat massa vehicula. Curabitur rhoncus diam quis ligula varius nec bibendum lacus pulvinar. Suspendisse porttitor erat nec nibh adipiscing ultrices sed nec risus. Fusce volutpat libero ornare erat adipiscing fringilla vehicula justo faucibus. Nunc eu justo velit, non viverra ante. Nulla vestibulum tempus ante ac molestie. Vivamus convallis ultrices nibh, a imperdiet orci commodo vel.</p>\n\n<p>Donec elementum turpis sit amet sapien luctus scelerisque venenatis leo aliquam. Vestibulum nisi nisi, ullamcorper vel pharetra et, rutrum sed magna. Aliquam dignissim arcu sit amet nunc tempus eget congue lorem eleifend. Donec vehicula dui et turpis tincidunt tempor. Fusce ut enim augue. Vestibulum vel pretium leo. Nunc luctus auctor quam, in sollicitudin augue fringilla vulputate. Etiam nibh tortor, vulputate vitae vulputate vel, tempus ut purus. Mauris nibh est, molestie et scelerisque vitae, iaculis id mi. Praesent et leo neque. Proin tincidunt vehicula sagittis. Pellentesque ac nisi urna, at mattis lectus. Nam lacinia justo quis sapien facilisis posuere. Proin euismod, tortor blandit faucibus malesuada, lorem nisi tristique lacus, a imperdiet dolor tortor et mauris. Integer tortor enim, sollicitudin convallis rutrum a, tempor quis mauris. Suspendisse porttitor urna id mauris euismod ornare.</p>\n\n<p>Aliquam pulvinar viverra luctus. Nunc sed lorem nibh, eu dignissim tortor. Proin pellentesque augue eget metus vestibulum dapibus at quis felis. Nulla tincidunt pellentesque neque quis fringilla. Proin condimentum ornare dui, nec commodo eros elementum eu. Fusce laoreet purus vel dolor ultrices malesuada eu quis arcu. Sed pretium eleifend adipiscing. Ut urna sapien, hendrerit et congue sit amet, placerat sit amet arcu. Aenean vestibulum dolor sed turpis pretium mattis. Morbi eget fermentum felis. Cras scelerisque, quam eu adipiscing placerat, purus lorem lobortis arcu, sit amet condimentum augue metus vitae ipsum. Vestibulum lorem arcu, pulvinar et tristique ut, fermentum in quam. Donec venenatis fermentum ullamcorper.</p>\n\n<p>Suspendisse potenti. Integer et tellus at orci pretium rhoncus non in nisi. Aenean in enim enim. Suspendisse elit felis, pretium vitae sollicitudin eget, ultrices ut mauris. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Aenean vestibulum dui nec nisi iaculis ullamcorper. Donec imperdiet pretium tellus, a malesuada justo dignissim quis. Donec eleifend luctus magna at gravida. Donec blandit interdum nibh, id pretium sapien ultricies in. Sed consequat, augue semper aliquam hendrerit, purus sapien condimentum erat, quis tempus nisi eros vitae tellus.</p>\n\n<p>Quisque eleifend aliquam pulvinar. Fusce luctus tellus elit. Pellentesque ullamcorper accumsan quam ut tristique. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Etiam nec cursus lectus. Quisque risus sem, lobortis vel facilisis in, commodo ac nisl. Ut quis mauris et diam ultricies consectetur a eu sem. Etiam nec massa purus. Donec urna tortor, congue non tincidunt sed, ullamcorper scelerisque tortor. Aliquam eu risus sapien. Morbi in ligula et elit facilisis rhoncus. Suspendisse potenti. Vivamus elementum nisl vel turpis aliquet sit amet scelerisque enim facilisis. Proin laoreet facilisis metus nec vulputate. Vivamus ac nibh at turpis consequat laoreet.</p>\n\n<p>Aliquam ultricies, nunc eu eleifend bibendum, justo arcu lobortis mauris, vitae cursus nunc leo in velit. Sed eu odio at velit varius bibendum. Nunc ut enim sit amet sapien aliquet ultrices. Phasellus non lacus sit amet ante bibendum auctor convallis a augue. Etiam pellentesque suscipit quam, vitae dictum ante feugiat pellentesque. Sed tempor volutpat sapien, id bibendum dolor elementum nec. Sed auctor ultrices dolor in dictum. Vestibulum sed ipsum urna, sollicitudin pellentesque erat. Vivamus at massa urna. Sed facilisis mattis magna, id euismod erat pulvinar suscipit.</p>\n\n<p>Aliquam et molestie velit. Nunc nec libero quis metus accumsan volutpat et a libero. Nullam ut neque eu est euismod mollis quis nec lorem. Donec vulputate justo ligula, non varius neque. Aliquam rutrum, diam a faucibus elementum, libero est blandit eros, sit amet ullamcorper urna velit egestas purus. Nunc et nisi sapien. Vivamus sagittis tempus malesuada. Integer a venenatis justo.</p>\n\n<p>Mauris justo est, blandit pellentesque placerat eget, auctor nec tortor. Fusce viverra risus at odio molestie vestibulum. Suspendisse urna justo, eleifend in adipiscing ac, lacinia vitae arcu. Duis mattis, sem sed rhoncus interdum, neque dolor tristique urna, tristique ornare turpis magna eget tortor. Nullam ultrices justo vel lectus sagittis interdum. Maecenas et magna id augue tempus ultrices et id justo. Proin gravida sagittis pellentesque. Proin dignissim ipsum et nunc pulvinar quis ornare enim posuere. Proin mi mauris, accumsan a iaculis ac, aliquet ac nulla. Fusce quis purus in arcu venenatis tincidunt. Quisque tempor libero vel lectus gravida auctor feugiat diam pulvinar. Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>	2013-02-01 01:51:28.618667	2013-02-01 01:51:28.618667	\N	1	1	0	\N	0	0	0	0	8	6.40000000000000036	5	1	0	1	19	f	\N	0	0	0	0	2013-02-01 01:51:28.618667	f	\N
23	11	25	1	I love my iPad, it's been a faithful companion to me for a long time.\n\n Here's a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:\n\n<img src='http://localhost:4000/uploads/try2_discourse/7/blob.png' width='400' height='300'>\n\nHowever, I often hit a wall because of its limited possibilities. I tried to use it as a full-time working tool while traveling and basically, I managed to do everything I needed to - E-Mail, writing some documents, a bit of photography.... but my experience is that no matter how hard I try, it seems never to be a full replacement for my home desktop or laptop, the latest when I have to hand in a term paper. I've never really tried to use Pages on iPad for that because I fear it's too complicated. Which is a shame, because working on the iPad with an external keyboard is my most favourite way of working with a computer **ever!**\n\nI'd like to know whether any of you have experience with working with a Tablet (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only working device, successfully.** You have to be doing something non-trivial on it: just E-Mailing and browsing the web doesn't count.  Has any of you really managed to get rid of the "big machine"? Any writers who manage drafts, research, and their final work, only on a tablet? Educators who manage all their notes and data on one? Anybody from other professional groups? \n\nWhat's your secret. What apps do you use, what does your working setup look like? How do you do things that aren't completely self-explanatory when done from a tablet, like printing or storing to an external device (in the case of iOS devices)? Do you keep a big computer somewhere for emergencies? Are there really people out there who create final versions of important documents using the iOS Pages app or similar?	<p>I love my iPad, it's been a faithful companion to me for a long time.</p>\n\n<p>Here's a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:</p>\n\n<p><img src="http://localhost:4000/uploads/try2_discourse/7/blob.png" width="400" height="300" /></p>\n\n<p>However, I often hit a wall because of its limited possibilities. I tried to use it as a full-time working tool while traveling and basically, I managed to do everything I needed to - E-Mail, writing some documents, a bit of photography.... but my experience is that no matter how hard I try, it seems never to be a full replacement for my home desktop or laptop, the latest when I have to hand in a term paper. I've never really tried to use Pages on iPad for that because I fear it's too complicated. Which is a shame, because working on the iPad with an external keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n<p>I'd like to know whether any of you have experience with working with a Tablet (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it has to be a mobile OS) as <strong>their only working device, successfully.</strong> You have to be doing something non-trivial on it: just E-Mailing and browsing the web doesn't count.  Has any of you really managed to get rid of the "big machine"? Any writers who manage drafts, research, and their final work, only on a tablet? Educators who manage all their notes and data on one? Anybody from other professional groups? </p>\n\n<p>What's your secret. What apps do you use, what does your working setup look like? How do you do things that aren't completely self-explanatory when done from a tablet, like printing or storing to an external device (in the case of iOS devices)? Do you keep a big computer somewhere for emergencies? Are there really people out there who create final versions of important documents using the iOS Pages app or similar?</p>	2013-01-31 21:04:37.636947	2013-02-01 01:13:15.474731	\N	9	0	0	\N	0	0	0	0	32	2.79999999999999982	6	1	0	1	11	f	\N	0	0	0	0	2013-02-01 01:13:15.486068	f	\N
37	19	34	3	&nbsp;\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\n&nbsp;\n\nI am a jackass.	<p> \n </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p> </p>\n\n<p>I am a jackass.</p>	2013-02-01 02:08:39.576351	2013-02-01 02:16:38.099011	2	6	0	0	\N	0	0	0	1	8	3.39999999999999991	5	1	0	3	19	f	\N	0	0	0	0	2013-02-01 02:16:38.113428	f	19
61	2	41	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-02-04 19:28:30.91322	2013-02-04 19:28:30.91322	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 19:28:30.912496	f	\N
77	24	53	1	If you can see this, you've successfully set up a vagrant environment for discourse. By default this install includes a few topics and accounts to play around with.\n\nIf you're looking for an account to test out, you can create one or log in as one of the following with the password: `password`.\n\n- eviltrout **an admin**\n- jatwood **regular user**\n\nFor the latest info, please check the [README.md](https://github.com/discourse/discourse/blob/master/README.md) in the project. Thanks for checking out Discourse!\n\n---\n\n### The Production Dataset\n\nIf you want to get started without the test topics, this install also includes a base production database image. To install it execute the following commands:\n\n```bash\nvagrant ssh\ncd /vagrant\npsql discourse_development < pg_dumps/production-image.sql\nrake db:migrate\nrake db:test:prepare\n```\n\nIf you change your mind and want to use the test data again, just execute the above but using `pg_dumps/development-image.sql` instead.\n	<p>If you can see this, you've successfully set up a vagrant environment for discourse. By default this install includes a few topics and accounts to play around with.</p>\n\n<p>If you're looking for an account to test out, you can create one or log in as one of the following with the password: <code>password</code>.</p>\n\n<ul>\n<li>eviltrout <strong>an admin</strong>\n</li>\n<li>jatwood <strong>regular user</strong>\n</li>\n</ul><p>For the latest info, please check the <a href="https://github.com/discourse/discourse/blob/master/README.md" rel="nofollow">README.md</a> in the project. Thanks for checking out Discourse!</p>\n\n<hr><h3>The Production Dataset</h3>\n\n<p>If you want to get started without the test topics, this install also includes a base production database image. To install it execute the following commands:</p>\n\n<pre><code class="bash">vagrant ssh  \ncd /vagrant  \npsql discourse_development &lt; pg_dumps/production-image.sql  \nrake db:migrate  \nrake db:test:prepare  \n</code></pre>\n\n<p>If you change your mind and want to use the test data again, just execute the above but using <code>pg_dumps/development-image.sql</code> instead.  </p>	2013-02-04 22:39:43.233076	2013-03-20 22:59:11.628399	\N	2	0	0	\N	0	0	0	0	\N	\N	1	1	0	1	24	f	\N	0	0	0	0	2013-03-20 22:58:35.140445	f	\N
67	2	47	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-02-04 19:34:05.121327	2013-02-04 19:34:05.121327	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 19:34:05.120971	f	\N
66	2	46	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-02-04 19:32:14.656467	2013-02-04 19:32:14.656467	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 19:32:14.656062	f	\N
65	2	45	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-02-04 19:31:27.379578	2013-02-04 19:31:27.379578	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 19:31:27.37921	f	\N
64	2	44	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-02-04 19:30:36.2761	2013-02-04 19:30:36.2761	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 19:30:36.235292	f	\N
62	2	42	1	[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]\n\nUse this space below for a longer description, as well as to establish any rules or discussion!	<p>[Replace this first paragraph with a short description of your new category. Try to keep it below 200 characters.]</p>\n\n<p>Use this space below for a longer description, as well as to establish any rules or discussion!</p>	2013-02-04 19:29:11.625953	2013-02-04 19:29:11.625953	\N	1	0	0	\N	0	0	0	0	\N	0	1	1	0	1	2	f	\N	0	0	0	0	2013-02-04 19:29:11.625554	f	\N
\.


--
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('posts_id_seq', 78, true);


--
-- Data for Name: posts_search; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY posts_search (id, search_data) FROM stdin;
9	'anyth':15 'discours':5,18 'enjoy':6 'hi':1 'know':11 'let':9 'need':14 'stay':8 'us':10 'welcom':3,16
10	'200':18 'categori':12 'charact':19 'descript':8,27 'discours':37 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'new':11 'paragraph':4 'replac':1 'rule':34 'short':7 'space':22 'tri':13 'use':20 'well':29
11	'200':18 'categori':12 'charact':19 'descript':8,27 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'new':11 'paragraph':4 'replac':1 'rule':34 'short':7 'space':22 'tech':37 'tri':13 'use':20 'well':29
12	'200':18 'categori':12 'charact':19 'descript':8,27 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'new':11 'paragraph':4 'pic':37 'replac':1 'rule':34 'short':7 'space':22 'tri':13 'use':20 'well':29
14	'around':7 'discours':4 'featur':12 'play':6 'sandbox':5 'thing':16 'tri':9,13 'welcom':1
13	'200':18 'categori':12 'charact':19 'descript':8,27 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'new':11 'paragraph':4 'replac':1 'rule':34 'short':7 'space':22 'tri':13 'use':20 'video':37 'well':29
15	'4':6 'charli':2,3 'poor':1 'unicorn':5
16	'anyth':16 'discours':6,20 'enjoy':7 'hi':1 'know':12 'let':10 'need':15 'stay':9 'tri':5,19 'us':11 'welcom':3,17
17	'appear':54,176,244 'autocomplet':210 'automat':55 'behavior':304 'believ':300 'bottom':58,94,125,267 'button':30,91,121,223,242,264,286 'civil':302 'click':183,239,261,283 'come':50 'communiti':294,303 'compos':226 'content':44 'convers':135,200 'differ':138 'direct':139 'discours':7,314 'enjoy':258,308 'enter':71 'entir':217 'fellow':293 'flag':285 'forum':22 'get':16 'hesit':281 'hi':1 'highlight':236,247 'import':221 'join':5,198 'keep':23,36,39,141 'know':255,296 'let':253,288 'like':263 'link':143 'load':46 'look':248 'member':295 'mention':170,202 'moder':290 'name':205 'need':63 'new':48,76,148 'next':28 'notif':174,187 'number':33,188 'overal':105 'page':29,32,67,182 'person':114 'pop':212 'post':77,87,97,155,166,218,235,251,260,270,278 'problem':275 'quick':13 'quot':167,215,222,229 'rather':110 're':70 're-ent':69 'read':37 'refresh':65 'repli':49,81,83,90,102,120,146,163,241 'right':152 'scroll':24,40 'section':232 'see':75,190,273 'someon':162,203,254 'specif':86,113 'start':206 'stay':310 'take':133 'talk':158,193 'tap':185 'thank':3 'theme':106 'time':307 'tip':14 'togeth':144 'toolbar':227 'top':179 'topic':61,73,109,117,128,149 'tri':6,313 'type':207 'use':88,118,145,219 'usernam':172 'want':100,131 'welcom':8,311
18	'appear':54,176,244 'autocomplet':210 'automat':55 'behavior':304 'believ':300 'bottom':58,94,125,267 'button':30,91,121,223,242,264,286 'civil':302 'click':183,239,261,283 'come':50 'communiti':294,303 'compos':226 'content':44 'convers':135,200 'differ':138 'direct':139 'discours':7,314 'enjoy':258,308 'enter':71 'entir':217 'fellow':293 'flag':285 'forum':22 'get':16 'hesit':281 'hi':1 'highlight':236,247 'import':221 'join':5,198 'keep':23,36,39,141 'know':255,296 'let':253,288 'like':263 'link':143 'load':46 'look':248 'member':295 'mention':170,202 'moder':290 'name':205 'need':63 'new':48,76,148 'next':28 'notif':174,187 'number':33,188 'overal':105 'page':29,32,67,182 'person':114 'pop':212 'post':77,87,97,155,166,218,235,251,260,270,278 'problem':275 'quick':13 'quot':167,215,222,229 'rather':110 're':70 're-ent':69 'read':37 'refresh':65 'repli':49,81,83,90,102,120,146,163,241 'right':152 'scroll':24,40 'section':232 'see':75,190,273 'someon':162,203,254 'specif':86,113 'start':206 'stay':310 'take':133 'talk':158,193 'tap':185 'thank':3 'theme':106 'time':307 'tip':14 'togeth':144 'toolbar':227 'top':179 'topic':61,73,109,117,128,149 'tri':6,313 'type':207 'use':88,118,145,219 'usernam':172 'want':100,131 'welcom':8,311
19	'appear':49,171,239 'autocomplet':205 'automat':50 'behavior':299 'believ':295 'bottom':53,89,120,262 'button':26,86,116,218,237,259,281 'civil':297 'click':178,234,256,278 'come':45 'communiti':289,298 'compos':221 'content':39 'convers':130,195 'differ':133 'direct':134 'discours':7,309 'discuss':11 'enjoy':253,303 'enter':66 'entir':212 'fellow':288 'flag':280 'forum':12 'hesit':276 'hi':1 'highlight':231,242 'import':216 'join':5,193 'keep':19,31,34,136 'know':250,291 'let':248,283 'like':258 'link':138 'load':41 'look':243 'member':290 'mention':165,197 'moder':285 'name':200 'need':58 'new':43,71,143 'next':24 'notif':169,182 'number':29,183 'overal':100 'page':25,28,62,177 'person':109 'pop':207 'post':72,82,92,150,161,213,230,246,255,265,273 'problem':270 'quick':17 'quot':162,210,217,224 'rather':105 're':65 're-ent':64 'read':32 'refresh':60 'repli':44,76,78,85,97,115,141,158,236 'right':147 'scroll':20,35 'section':227 'see':70,185,268 'someon':157,198,249 'specif':81,108 'start':201 'stay':305 'take':128 'talk':153,188 'tap':180 'thank':3 'theme':101 'time':302 'tip':18 'togeth':139 'toolbar':222 'top':174 'topic':56,68,104,112,123,144 'tri':6,308 'type':202 'use':83,113,140,214 'usernam':167 'want':95,126 'welcom':8,306
20	'appear':56,178,246 'autocomplet':212 'automat':57 'back':306 'behavior':343 'believ':339 'bottom':60,96,127,269 'button':33,93,123,225,244,266,288 'civil':341 'click':185,241,263,285,314,330 'come':52 'communiti':296,342 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,353 'discuss':12 'enjoy':260,347 'enter':73 'entir':219 'fellow':295 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'join':5,200 'keep':26,38,41,143 'know':257,298 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280 'privat':15 'problem':277 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'read':39 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':349 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,346 'tip':21 'togeth':146 'toolbar':229 'top':181 'topic':63,75,111,119,130,151 'tri':6,352 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,350
75	'also':29 'anyon':24 'clarifi':25 'differ':7 'els':35 'folk':52 'm':12 'method':15 'notic':2 'other':42 'post':37 'quot':33 'repli':10,17,45,50 'seen':41 'someon':34 'unclear':13 'use':20 'way':8
21	'appear':56,178,246 'autocomplet':212 'automat':57 'back':306 'behavior':343 'believ':339 'bottom':60,96,127,269 'button':33,93,123,225,244,266,288 'civil':341 'click':185,241,263,285,314,330 'come':52 'communiti':296,342 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,353 'discuss':12 'enjoy':260,347 'enter':73 'entir':219 'fellow':295 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'join':5,200 'keep':26,38,41,143 'know':257,298 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280 'privat':15 'problem':277 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'read':39 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':349 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,346 'tip':21 'togeth':146 'toolbar':229 'top':181 'topic':63,75,111,119,130,151 'tri':6,352 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,350
22	'appear':56,178,246 'autocomplet':212 'automat':57 'back':306 'behavior':343 'believ':339 'bottom':60,96,127,269 'button':33,93,123,225,244,266,288 'civil':341 'click':185,241,263,285,314,330 'come':52 'communiti':296,342 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,353 'discuss':12 'enjoy':260,347 'enter':73 'entir':219 'fellow':295 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'join':5,200 'keep':26,38,41,143 'know':257,298 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280 'privat':15 'problem':277 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'read':39 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':349 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,346 'tip':21 'togeth':146 'toolbar':229 'top':181 'topic':63,75,111,119,130,151 'tri':6,352 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,350
32	'appear':56,178,246 'autocomplet':212 'automat':57 'back':306 'behavior':343 'believ':339 'bottom':60,96,127,269 'button':33,93,123,225,244,266,288 'civil':341 'click':185,241,263,285,314,330 'come':52 'communiti':296,342 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,353 'discuss':12 'enjoy':260,347 'enter':73 'entir':219 'fellow':295 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'join':5,200 'keep':26,38,41,143 'know':257,298 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280 'privat':15 'problem':277 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'read':39 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':349 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,346 'tip':21 'togeth':146 'toolbar':229 'top':181 'topic':63,75,111,119,130,151 'tri':6,352 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,350
33	'appear':56,178,246 'autocomplet':212 'automat':57 'back':306 'behavior':343 'believ':339 'bottom':60,96,127,269 'button':33,93,123,225,244,266,288 'civil':341 'click':185,241,263,285,314,330 'come':52 'communiti':296,342 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,353 'discuss':12 'enjoy':260,347 'enter':73 'entir':219 'fellow':295 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'join':5,200 'keep':26,38,41,143 'know':257,298 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280 'privat':15 'problem':277 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'read':39 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':349 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,346 'tip':21 'togeth':146 'toolbar':229 'top':181 'topic':63,75,111,119,130,151 'tri':6,352 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,350
68	'30':77 '50':125 'a.a':11 'activ':69 'aerob':195 'also':57,204 'attract':147 'bear':2,216 'benefit':192 'break':165 'bro':214 'comfort':169 'd':139 'desk':24 'diabet':130 'didn':58 'die':119 'diseas':122 'drawn':154 'enough':177 'even':212 'exercis':10,196,224 'expect':199 'extra':44 'fat':85 'get':71,95,201 'given':62 'grow':7,221 'habit':105 'hard':4,218 'heart':51,73,121 'howev':3,217 'ill':150 'intern':55 'invari':153 'keep':110,188 'kidney':52 'knew':48 'know':80 'life':175 'lifetim':145 'lift':213 'like':140 'littl':66 'm':30,35,83 'mean':28 'mental':185 'might':203 'miln':12 'mind':42,60 'minimum':109 'minut':78 'motiv':190,205 'onto':97 'opt':142 'organ':56 'overweight':31,159 'physic':68 'pooh':16 'popular':132 'programm':19 'rate':74 'regular':67,194 'risk':172 'road':99 'seem':152 'set':103 'shape':38,113 'shorten':174 'sit':21 'span':176 'succumb':128 'suggest':91 'think':137 'tri':6,220 'trick':186 'tubbi':8,222 'unfit':87,157 'use':183 'way':93 'weight':45 'winni':14 'winnie-the-pooh':13 'without':9,223 'work':26 'wors':33 'wouldn':40 'zone':170
74	'account':16 'also':31 'click':47 'forum':35 'icon':23 'interest':41 'know':36 'littl':21 'm':2,40 'one':50 'post':10,26 'qestion':58 'read':13,64 'rememb':60 'ribbon':22 'somewher':51 'subscrib':53 'sure':4 'topic':8,38,55 'understand':6 've':12,63 'work':30
26	'appear':56,178,246 'autocomplet':212 'automat':57 'back':306 'behavior':343 'believ':339 'bottom':60,96,127,269 'button':33,93,123,225,244,266,288 'civil':341 'click':185,241,263,285,314,330 'come':52 'communiti':296,342 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,353 'discuss':12 'enjoy':260,347 'enter':73 'entir':219 'fellow':295 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'join':5,200 'keep':26,38,41,143 'know':257,298 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280 'privat':15 'problem':277 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'read':39 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':349 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,346 'tip':21 'togeth':146 'toolbar':229 'top':181 'topic':63,75,111,119,130,151 'tri':6,352 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,350
27	'appear':56,178,246 'autocomplet':212 'automat':57 'back':306 'behavior':343 'believ':339 'bottom':60,96,127,269 'button':33,93,123,225,244,266,288 'civil':341 'click':185,241,263,285,314,330 'come':52 'communiti':296,342 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,353 'discuss':12 'enjoy':260,347 'enter':73 'entir':219 'fellow':295 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'join':5,200 'keep':26,38,41,143 'know':257,298 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280 'privat':15 'problem':277 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'read':39 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':349 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,346 'tip':21 'togeth':146 'toolbar':229 'top':181 'topic':63,75,111,119,130,151 'tri':6,352 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,350
28	'2000':109 '2027':31 'basic':17 'becom':20 'believ':36 'britain':32 'broken':62 'bumpi':76 'children':6 'complet':14 'cours':27 'detail':42 'drama':65 'dystopian':30 'end':68 'ever':80 'fi':100 'fiction':25 'fourth':55 'go':3 'goos':75 'goose-bumpi':74 'grip':64 'heartbreak':58 'import':105 'infertil':21 'know':87 'll':86 'm':2,90 'made':34 'man':63 'mani':40,43 'mankind':19 'men':8 'movi':84,101 'notic':47 'one':70,106 'premis':18 'say':5 'scene':77 'sci':99 'sci-fi':98 'scienc':24 'see':95 'seen':81 'small':41 'stori':59 'stunner':15 'talk':91 'third':53 'thought':10 'time':56 'total':23 'utter':35 've':79 'video':113 'view':50
24	'abl':38 'access':188 'anticip':87 'approach':69 'area':178 'arizona':14 'behind':68 'big':148 'block':225 'california':11 'came':145 'camp':139 'car':34,240 'caught':128 'close':103,307 'comfort':113 'countri':160 'coupl':17 'cultur':265 'dens':168 'desert':143 'dirt':195 'easi':83,244 'european':4 'even':122 'everi':200 'everywher':197 'exact':156 'expect':154 'fall':21 'far':205 'fear':283 'feel':112 'felt':72 'find':93,190,228 'first':25 'focus':266 'forest':202 'free':138 'general':222 'germani':164 'get':127 'go':198 'heighten':280 'hope':35 'howev':78,183 'huge':192 'impass':217 'intrud':285 'keep':255 'land':302 'last':20 'lawn':258 'leav':66 'liabil':278 'limit':136 'm':2,58,117 'main':98,140,208 'mark':106,214 'massiv':286 'minim':131 'money':56 'much':166,174 'network':193 'nevada':12 'next':47 'night':236 'noth':67 'often':51 'okay':75 'opposit':157 'place':231,298 'possibl':53 'privat':107,180,210,268 'privileg':8 'probabl':130 'problem':287 'prohibit':223 'properti':108,181,211,269 'quiet':61 'rare':213,216 'realli':242,243 'recent':273 'relat':260 'respect':62 'risk':125 'road':99,196,209 'save':55 'secur':230 'sens':281 'settl':169 'sleep':40,114 'small':201 'somewher':115 'space':95 'stay':233 'suppos':119 'surpris':149 'take':203 'tent':46 'thing':259,274 'think':219,248 'though':123 'tradit':254 'travel':10,32,63,238 'unabl':91 'uninhabit':177,301 'us':29,172,263,305 'vandal':289 'vast':163 'virtual':90 'visit':26 'wasn':80,101 'way':186 'week':19 'wrong':297
25	'20':33 '2000':10,45 '30':34 '40':35 'ask':29 'come':24 'fi':4,41 'import':38 'matter':12 'mind':27 'movi':5,42 'one':19 'sci':3,40 'sci-fi':2,39 'seri':7 'think':22 'video':47 'year':36
29	'actual':32 'allow':59 'basi':80 'beaten':43 'boondock':154 'car':10,38 'check':85 'close':179 'contrari':69 'danger':137 'deal':165 'difficult':25 'done':12 'easier':33 'farther':40 'forest':112 'googl':149 'kept':103 'land':113,174 'let':91 'littl':23,132,148 'lot':5,97,162 'make':82 'mark':66 'nation':111 'nervi':134 'okay/lega':116 'overnight':64 'park':93 'peopl':92,126,164 'per':86 'possibl':18 'privat':142 'properti':143 'read':157 'relationship':140 'rest':53 'rvs':94 'seen':29 'set':73 'sleep':35,60 'sort':119,168 'specif':58 'state':77,79,87 'still':108 'stop':54 'stranger':136 'sure':83 'thing':15,50,121,170 'think':125 'topic':152 'track':44 'travel':3,99 'uninhabit':173 'unless':65 'us':8,57,129,177 'use':89 'usual':72,115 'van':100 've':2,28 'vehicl':63 'walmart':88 'way':160 'whether':106 'work':52 'yeah':123
30	'2000':15 'els':6 'fi':11 'import':8 'm':2 'movi':12 'sci':10 'sci-fi':9 'someth':5 'test':4 'video':17
70	'/2011/12/brilliantly-simple-idea-treadmill-desk.html':46 '/2011/12/treadmill-desk-update.html':49 '/2012/01/treadmill-desk-plans.html':52 'bear':54 'blog':14 'build':32 'desk':5,20 'develop':9 'exercis':62 'final':23 'grow':59 'hard':56 'howev':55 'includ':29 'interest':37 'iphon':8 'iphonedevelopment.blogspot.com':45,48,51 'iphonedevelopment.blogspot.com/2011/12/brilliantly-simple-idea-treadmill-desk.html':44 'iphonedevelopment.blogspot.com/2011/12/treadmill-desk-update.html':47 'iphonedevelopment.blogspot.com/2012/01/treadmill-desk-plans.html':50 'jeff':6 'lemarch':7 'look':43 'one':24 'plan':30 'post':15,27 'read':40 'seri':12,38 'treadmil':4,19 'tri':58 'tubbi':60 'use':17 'without':61
76	'convers':35,53 'direct':9 'discours':54 'els':44 'email':22 'follow':34,52 'forth':48 'indent':8 'm':18 'notic':2 'repli':4,14,28,39 'say':24 'someom':37 'someon':23,43 'someth':41 'thing':12 'use':19 'wrote':45
23	'5':30 '788':31 'android':178 'anybodi':262 'app':272,340 'aren':289 'basic':61 'big':236,318 'bit':77 'brows':219 'bruno':28 'ca':29 'case':310 'companion':10 'complet':291 'complic':134 'comput':157,319 'count':224 'creat':330 'd':160 'data':259 'desktop':102,188 'devic':201,307,313,348 'document':75,335 'doesn':222 'done':296 'draft':242 'e':71,216 'e-mail':70,215 'educ':252 'emerg':322 'ever':158 'everyth':66 'experi':82,169 'explanatori':294 'extern':146,306 'faith':9 'favourit':151 'fear':130 'final':246,331 'full':54,97 'full-tim':53 'get':232 'group':266 'hand':111 'hard':88 'hit':38 'home':34,101 'howev':35 'import':334 'io':312,338 'ipad':4,125,143,175 'iphon':176 'keep':316 'keyboard':147 'know':163 'laptop':104 'latest':106 'like':161,282,300 'limit':44 'long':15 'look':281 'love':2 'machin':237 'mail':72,217 'manag':63,230,241,254 'matter':86 'mile':32 'mobil':195,347 'need':68 'never':93,118 'non':210 'non-trivi':209 'note':257 'often':37 'one':261 'os':189,196 'page':123,339 'paper':115 'pc':185 'peopl':326 'photographi':79 'pictur':20 'possibl':45 'print':301 'profession':265 'realli':119,229,325 'replac':98 'research':243 'rid':233 'run':186 'san':27 'secret':270 'seem':92 'self':293 'self-explanatori':292 'setup':280 'shame':138 'similar':342 'slate':184 'someth':208 'somewher':320 'starbuck':25 'store':303 'success':202 'tablet':174,251,299 'tech':356 'tell':353 'term':114 'thing':287 'time':16,55 'tool':57 'travel':59 'tri':47,90,120 'trivial':211 'use':49,122,275,336,345 've':117 'version':332 'wall':40 'way':152 'web':221 'whatev':180 'whether':164 'work':56,140,154,171,200,247,279,352 'write':73 'writer':239
34	'appear':56,178,246 'arrow':354 'autocomplet':212 'automat':57 'back':306 'behavior':392 'believ':388 'bottom':60,96,127,269,351,362 'button':33,93,123,225,244,266,288 'civil':390 'click':185,241,263,285,314,330,345,352 'come':52 'communiti':296,391 'compos':228 'content':46 'convers':137,202 'date':382 'differ':140 'direct':141 'discours':7,402 'discuss':12 'enjoy':260,396 'enter':73 'entir':219 'fellow':295 'field':369 'first':376 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'indic':359 'join':5,200 'keep':26,38,41,143 'know':257,298 'last':367,380 'left':320 'let':255,290 'like':265 'link':145 'list':386 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326,365 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280,368,377,381 'privat':15 'problem':277 'progress':358 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'reach':339,349 'read':39 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':398 'summari':373 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,395 'tip':21 'titl':347 'togeth':146 'toolbar':229 'top':181,341 'topic':63,75,111,119,130,151,344,357,372,385 'tri':6,401 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,399
35	'12345':2017 '123456789':1992,1993,1994,1995,1996,1997,1998,1999,2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016 'ac':61,87,98,130,250,328,359,405,503,514,547,579,645,784,818,852,987,1044,1304,1400,1586,1674,1731,1906,1963,1965 'accumsan':43,381,528,537,658,667,1025,1125,1240,1646,1832,1960 'ad':942 'adipisc':7,163,205,251,269,541,572,594,907,937,1001,1278,1288,1495,1523,1905,1990 'aenean':101,187,855,1508,1562,1589 'aliquam':204,392,488,526,593,679,756,760,771,960,1002,1037,1155,1325,1336,1446,1624,1638,1700,1737,1823,1854 'aliquet':626,706,737,975,1241,1718,1766,1964 'amet':5,121,141,161,268,277,298,350,427,569,709,716,747,828,831,895,992,1041,1229,1237,1319,1340,1503,1506,1530,1720,1764,1772,1865,1988 'ant':45,78,118,471,612,724,1299,1303,1773,1785 'aptent':939 'arcu':242,258,325,432,717,984,993,1338,1491,1507,1528,1538,1744,1909,1971 'auctor':257,422,446,620,1045,1364,1775,1798,1890,1980 'augu':138,283,508,627,673,1357,1368,1459,1532,1622,1778,1937 'bibendum':34,335,363,1179,1270,1742,1759,1774,1793 'blandit':39,172,333,336,361,484,740,838,865,924,929,1160,1416,1612,1862,1886 'class':938 'commodo':689,1092,1183,1192,1313,1478,1673 'condimentum':794,1012,1474,1531,1628 'congu':316,702,873,1249,1344,1501,1693 'consectetur':6,142,162,198,262,621,1121,1682,1989 'consequat':589,1621,1735 'conubia':946 'conval':117,208,464,892,986,1038,1187,1307,1433,1776 'cras':66,183,291,387,489,764,958,1081,1134,1519 'cubilia':55,481 'cum':1193,1650 'cura':56,482 'curabitur':273,691,1205,1263 'cursus':67,229,598,729,841,1053,1213,1664,1748 'dapibus':339,419,900,1082,1162,1463 'diam':11,151,364,602,642,707,741,745,759,870,1068,1265,1680,1856,1982 'dictum':279,810,999,1784,1802 'dictumst':111 'dignissim':40,42,181,578,1010,1059,1099,1337,1455,1603,1948 'dis':1199,1656 'dolor':3,156,159,255,293,305,389,555,567,701,891,1425,1486,1510,1794,1800,1917,1986 'donec':16,240,423,431,441,704,821,966,1005,1148,1221,1253,1315,1347,1546,1596,1605,1611,1690,1847 'dui':290,313,369,545,574,609,654,677,753,918,1112,1143,1349,1476,1591,1910 'egesta':25,228,398,505,854,1022,1588,1869 'eget':83,148,178,338,376,391,395,435,487,531,536,559,678,765,801,805,862,988,1051,1101,1216,1222,1250,1343,1460,1516,1572,1889,1924 'eleifend':144,348,630,769,1085,1139,1346,1494,1606,1637,1741,1903 'elementum':71,357,455,666,743,860,864,884,933,1316,1480,1714,1795,1859 'elit':8,131,164,331,600,1233,1567,1643,1708,1991 'enim':231,619,640,721,798,1054,1356,1431,1564,1565,1722,1762,1955 'erat':63,202,308,525,638,681,803,822,823,914,932,994,1003,1055,1100,1168,1275,1287,1629,1809,1820 'ero':18,20,77,171,216,403,451,575,730,766,936,1119,1173,1479,1633,1863 'est':360,564,605,699,836,971,1383,1841,1861,1885 'et':52,105,129,218,323,416,478,498,500,581,613,623,847,849,983,1062,1197,1256,1332,1350,1385,1392,1427,1500,1540,1553,1581,1583,1654,1679,1707,1824,1834,1872,1934,1940,1950 'etiam':309,317,749,866,970,1097,1371,1662,1686,1779 'eu':201,285,437,507,635,663,685,742,757,825,881,1024,1116,1230,1294,1454,1481,1489,1522,1684,1701,1740,1754,1840 'euismod':390,534,824,1254,1414,1444,1819,1842 'facilisi':192,344,554,557,788,913,1411,1671,1709,1723,1726,1815 'fame':502,851,1585 'faucibus':49,311,404,411,457,475,662,812,1109,1235,1292,1417,1858 'feli':219,346,428,570,734,897,979,1018,1042,1083,1087,1124,1466,1518,1568 'fermentum':292,442,899,1517,1543,1548 'feugiat':271,414,1127,1786,1981 'fringilla':73,261,318,577,967,1008,1132,1289,1369,1472 'fusc':513,655,779,880,990,1283,1354,1482,1640,1893,1967 'gravida':128,324,365,449,571,580,611,723,1098,1117,1610,1944,1979 'habit':494,843,1577 'habitass':109 'hac':108 'hendrerit':353,686,1499,1625 'himenaeo':950 'iaculi':15,544,1388,1594,1962 'id':19,125,145,254,367,374,543,563,647,649,698,815,890,905,919,963,1058,1142,1389,1442,1615,1792,1818,1936,1941 'imperdiet':274,288,633,692,1133,1311,1424,1597 'incepto':949 'integ':397,523,565,583,787,980,1232,1429,1552,1879 'interdum':119,244,326,901,1052,1613,1915,1932 'ipsum':2,46,158,177,211,246,425,472,551,624,773,861,1060,1535,1805,1949,1985 'justo':247,400,415,582,585,687,1050,1159,1163,1178,1291,1295,1408,1602,1743,1849,1882,1884,1902,1928,1942 'lacinia':62,114,152,167,265,790,973,1056,1069,1175,1407,1907 'lacus':13,100,124,252,542,587,782,809,858,969,1271,1422,1770 'laoreet':166,170,314,566,646,1483,1725,1736 'lectus':24,562,682,694,804,1150,1405,1665,1930,1978 'leo':168,517,738,832,920,930,1063,1324,1361,1393,1750 'libero':217,266,329,382,440,461,748,1023,1090,1257,1285,1829,1836,1860,1976 'ligula':295,512,668,800,1171,1267,1706,1850 'litora':943 'loborti':448,727,814,1219,1527,1669,1745 'lorem':1,60,104,157,189,210,249,486,882,927,1033,1208,1255,1345,1419,1452,1526,1537,1846,1984 'luctus':51,402,477,601,1321,1363,1449,1607,1641 'maecena':132,224,263,533,1933 'magna':41,88,236,452,653,797,1335,1608,1817,1923,1935 'magni':1198,1655 'malesuada':10,23,467,501,644,799,850,1102,1167,1418,1488,1584,1601,1878 'massa':190,319,408,462,548,806,816,819,1014,1057,1066,1225,1261,1688,1812 'matti':538,597,604,705,1227,1404,1514,1816,1911 'mauri':136,149,226,275,327,637,674,791,1021,1381,1428,1438,1443,1575,1678,1746,1883,1959 'metus':135,196,203,282,312,469,595,617,632,718,767,911,1144,1211,1252,1461,1533,1727,1831 'mi':85,355,1157,1390,1958 'molesti':232,286,332,401,629,731,834,968,1305,1384,1825,1898 'molli':21,96,906,1107,1843 'mont':1201,1658 'morbi':28,334,356,495,844,1515,1578,1704 'mus':1204,1661 'nam':165,807,876,951,1015,1406 'nascetur':1202,1659 'natoqu':1195,1652 'nec':169,182,259,454,520,725,813,877,896,976,995,1013,1019,1031,1072,1091,1209,1269,1276,1281,1477,1592,1663,1687,1728,1796,1828,1845,1891 'nequ':72,223,358,377,492,515,524,539,592,739,778,955,982,989,1039,1076,1136,1242,1394,1470,1839,1853,1916 'netus':499,848,1582 'nibh':213,260,688,785,793,808,820,909,1046,1061,1128,1138,1277,1309,1372,1382,1453,1614,1732 'nisi':321,904,1103,1122,1327,1328,1401,1420,1561,1593,1632,1873 'nisl':459,726,917,1177,1218,1675,1715 'non':79,342,584,591,652,661,872,916,925,934,1118,1246,1259,1297,1559,1694,1769,1851 'nostra':947 'nulla':180,191,304,337,343,345,372,384,483,606,608,671,675,817,928,1048,1088,1111,1300,1467,1966 'nullam':193,460,506,651,665,1074,1837,1926 'nunc':9,37,97,302,421,573,625,634,643,690,972,1120,1293,1341,1362,1450,1739,1749,1760,1827,1871,1951 'odio':375,388,447,535,558,868,1007,1093,1188,1247,1755,1897 'orci':50,253,347,476,532,546,650,839,1027,1073,1078,1312,1556 'ornar':234,264,443,553,616,869,1095,1226,1286,1445,1475,1921,1954 'parturi':1200,1657 'pellentesqu':64,112,429,493,842,878,887,1169,1399,1458,1469,1576,1644,1780,1787,1808,1887,1946 'penatibus':1196,1653 'per':945,948 'pharetra':17,750,1070,1174,1331 'phasellus':38,174,373,998,1106,1130,1165,1186,1768 'placerat':781,795,1089,1140,1260,1504,1524,1888 'platea':110 'porta':154,341,518,683,957,1153 'porttitor':186,696,1217,1274,1440 'posuer':54,106,153,315,480,530,735,1191,1258,1412,1956 'potenti':27,1551,1712 'praesent':898,1391 'pretium':299,430,710,762,777,871,1080,1248,1360,1493,1513,1557,1569,1598,1616 'primi':47,473 'proin':86,220,450,1110,1395,1413,1457,1473,1724,1943,1947,1957 'pulvinar':245,322,351,438,463,736,935,1272,1447,1539,1639,1821,1952,1983 'purus':126,396,409,711,786,879,889,922,1147,1380,1484,1525,1626,1689,1870,1969 'quam':115,509,561,657,1365,1521,1545,1647,1782 'qui':173,306,362,439,456,466,521,618,700,728,1065,1067,1182,1266,1409,1437,1465,1471,1490,1604,1630,1677,1830,1844,1953,1968 'quisqu':256,1141,1636,1666,1974 'rhoncus':95,703,1104,1264,1558,1710,1914 'ridiculus':1203,1660 'risus':237,522,556,744,874,997,1036,1094,1096,1185,1245,1282,1667,1702,1895 'rutrum':14,127,134,143,212,284,680,796,1047,1333,1434,1855 'sagitti':307,670,910,1016,1398,1876,1931,1945 'sapien':233,278,656,664,1006,1151,1190,1320,1410,1498,1617,1627,1703,1765,1791,1874 'scelerisqu':58,175,903,923,1322,1386,1520,1698,1721 'sed':12,36,57,70,90,123,147,188,227,238,366,370,413,549,607,615,639,722,732,775,776,833,921,931,1035,1084,1123,1166,1224,1280,1334,1451,1492,1511,1620,1696,1753,1788,1797,1804,1814,1913 'sem':69,89,94,137,270,417,433,599,770,857,953,1207,1234,1668,1685,1912 'semper':378,453,614,733,977,1623 'senectus':497,846,1580 'sit':4,120,140,160,267,276,297,349,426,568,708,715,746,827,830,894,991,1040,1228,1236,1318,1339,1502,1505,1529,1719,1763,1771,1864,1987 'socii':1194,1651 'sociosqu':941 'sodal':399,996,1049,1115 'sollicitudin':371,379,485,720,826,1000,1043,1086,1367,1432,1571,1807 'suscipit':184,225,840,1210,1238,1781,1822 'suspendiss':26,380,1273,1439,1550,1566,1711,1900 'taciti':940 'tellus':92,300,758,1154,1231,1554,1599,1635,1642 'tempor':139,301,754,1353,1436,1789,1975 'tempus':103,185,588,780,1302,1342,1378,1631,1877,1938 'tincidunt':102,280,789,835,1017,1108,1129,1135,1352,1396,1468,1695,1973 'torquent':944 'tortor':32,239,340,368,412,774,1030,1373,1415,1426,1430,1456,1692,1699,1892,1925 'tristiqu':80,385,496,576,648,676,802,845,1421,1541,1579,1649,1918,1920 'turpi':206,504,751,853,1034,1317,1351,1512,1587,1717,1734,1922 'ullamcorp':222,436,560,867,893,1131,1329,1549,1595,1645,1697,1866 'ultric':33,53,209,479,829,1279,1308,1487,1573,1767,1799,1927,1939 'ultrici':84,113,420,610,885,1029,1618,1681,1738 'urna':30,146,199,230,491,631,908,915,965,1028,1215,1223,1402,1441,1497,1691,1806,1813,1867,1901,1919 'ut':65,74,93,116,133,150,207,243,281,287,303,354,406,527,713,768,902,962,1145,1161,1176,1355,1379,1496,1542,1574,1648,1676,1761,1838 'varius':68,241,418,511,1079,1152,1214,1268,1758,1852 'vehicula':179,248,296,636,961,1075,1181,1262,1290,1348,1397 'vel':22,194,221,289,330,590,695,752,837,856,888,1011,1314,1330,1359,1377,1485,1670,1716,1929,1977 'velit':81,99,195,444,540,684,863,883,886,1296,1752,1757,1826,1868 'venenati':235,660,761,875,985,1032,1184,1323,1547,1881,1972 'vestibulum':31,44,59,424,470,714,783,1026,1212,1301,1326,1358,1462,1509,1536,1590,1803,1899 'vita':29,35,91,294,320,407,552,811,952,974,1137,1170,1180,1239,1375,1387,1534,1570,1634,1747,1783,1908 'vivamus':82,200,859,1064,1243,1306,1713,1730,1810,1875 'viverra':394,434,550,712,755,1146,1149,1298,1448,1894 'volutpat':386,465,519,792,964,1004,1156,1284,1790,1833 'vulput':176,215,659,693,763,956,959,1020,1113,1164,1370,1374,1376,1729,1848
36	'12345':2017 '123456789':1992,1993,1994,1995,1996,1997,1998,1999,2000,2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013,2014,2015,2016 'ac':61,87,98,130,250,328,359,405,503,514,547,579,645,784,818,852,987,1044,1304,1400,1586,1674,1731,1906,1963,1965 'accumsan':43,381,528,537,658,667,1025,1125,1240,1646,1832,1960 'ad':942 'adipisc':7,163,205,251,269,541,572,594,907,937,1001,1278,1288,1495,1523,1905,1990 'aenean':101,187,855,1508,1562,1589 'aliquam':204,392,488,526,593,679,756,760,771,960,1002,1037,1155,1325,1336,1446,1624,1638,1700,1737,1823,1854 'aliquet':626,706,737,975,1241,1718,1766,1964 'amet':5,121,141,161,268,277,298,350,427,569,709,716,747,828,831,895,992,1041,1229,1237,1319,1340,1503,1506,1530,1720,1764,1772,1865,1988 'ant':45,78,118,471,612,724,1299,1303,1773,1785 'aptent':939 'arcu':242,258,325,432,717,984,993,1338,1491,1507,1528,1538,1744,1909,1971 'auctor':257,422,446,620,1045,1364,1775,1798,1890,1980 'augu':138,283,508,627,673,1357,1368,1459,1532,1622,1778,1937 'bibendum':34,335,363,1179,1270,1742,1759,1774,1793 'blandit':39,172,333,336,361,484,740,838,865,924,929,1160,1416,1612,1862,1886 'class':938 'commodo':689,1092,1183,1192,1313,1478,1673 'condimentum':794,1012,1474,1531,1628 'congu':316,702,873,1249,1344,1501,1693 'consectetur':6,142,162,198,262,621,1121,1682,1989 'consequat':589,1621,1735 'conubia':946 'conval':117,208,464,892,986,1038,1187,1307,1433,1776 'cras':66,183,291,387,489,764,958,1081,1134,1519 'cubilia':55,481 'cum':1193,1650 'cura':56,482 'curabitur':273,691,1205,1263 'cursus':67,229,598,729,841,1053,1213,1664,1748 'dapibus':339,419,900,1082,1162,1463 'diam':11,151,364,602,642,707,741,745,759,870,1068,1265,1680,1856,1982 'dictum':279,810,999,1784,1802 'dictumst':111 'dignissim':40,42,181,578,1010,1059,1099,1337,1455,1603,1948 'dis':1199,1656 'dolor':3,156,159,255,293,305,389,555,567,701,891,1425,1486,1510,1794,1800,1917,1986 'donec':16,240,423,431,441,704,821,966,1005,1148,1221,1253,1315,1347,1546,1596,1605,1611,1690,1847 'dui':290,313,369,545,574,609,654,677,753,918,1112,1143,1349,1476,1591,1910 'egesta':25,228,398,505,854,1022,1588,1869 'eget':83,148,178,338,376,391,395,435,487,531,536,559,678,765,801,805,862,988,1051,1101,1216,1222,1250,1343,1460,1516,1572,1889,1924 'eleifend':144,348,630,769,1085,1139,1346,1494,1606,1637,1741,1903 'elementum':71,357,455,666,743,860,864,884,933,1316,1480,1714,1795,1859 'elit':8,131,164,331,600,1233,1567,1643,1708,1991 'enim':231,619,640,721,798,1054,1356,1431,1564,1565,1722,1762,1955 'erat':63,202,308,525,638,681,803,822,823,914,932,994,1003,1055,1100,1168,1275,1287,1629,1809,1820 'ero':18,20,77,171,216,403,451,575,730,766,936,1119,1173,1479,1633,1863 'est':360,564,605,699,836,971,1383,1841,1861,1885 'et':52,105,129,218,323,416,478,498,500,581,613,623,847,849,983,1062,1197,1256,1332,1350,1385,1392,1427,1500,1540,1553,1581,1583,1654,1679,1707,1824,1834,1872,1934,1940,1950 'etiam':309,317,749,866,970,1097,1371,1662,1686,1779 'eu':201,285,437,507,635,663,685,742,757,825,881,1024,1116,1230,1294,1454,1481,1489,1522,1684,1701,1740,1754,1840 'euismod':390,534,824,1254,1414,1444,1819,1842 'facilisi':192,344,554,557,788,913,1411,1671,1709,1723,1726,1815 'fame':502,851,1585 'faucibus':49,311,404,411,457,475,662,812,1109,1235,1292,1417,1858 'feli':219,346,428,570,734,897,979,1018,1042,1083,1087,1124,1466,1518,1568 'fermentum':292,442,899,1517,1543,1548 'feugiat':271,414,1127,1786,1981 'fringilla':73,261,318,577,967,1008,1132,1289,1369,1472 'fusc':513,655,779,880,990,1283,1354,1482,1640,1893,1967 'gravida':128,324,365,449,571,580,611,723,1098,1117,1610,1944,1979 'habit':494,843,1577 'habitass':109 'hac':108 'hendrerit':353,686,1499,1625 'himenaeo':950 'iaculi':15,544,1388,1594,1962 'id':19,125,145,254,367,374,543,563,647,649,698,815,890,905,919,963,1058,1142,1389,1442,1615,1792,1818,1936,1941 'imperdiet':274,288,633,692,1133,1311,1424,1597 'incepto':949 'integ':397,523,565,583,787,980,1232,1429,1552,1879 'interdum':119,244,326,901,1052,1613,1915,1932 'ipsum':2,46,158,177,211,246,425,472,551,624,773,861,1060,1535,1805,1949,1985 'justo':247,400,415,582,585,687,1050,1159,1163,1178,1291,1295,1408,1602,1743,1849,1882,1884,1902,1928,1942 'lacinia':62,114,152,167,265,790,973,1056,1069,1175,1407,1907 'lacus':13,100,124,252,542,587,782,809,858,969,1271,1422,1770 'laoreet':166,170,314,566,646,1483,1725,1736 'lectus':24,562,682,694,804,1150,1405,1665,1930,1978 'leo':168,517,738,832,920,930,1063,1324,1361,1393,1750 'libero':217,266,329,382,440,461,748,1023,1090,1257,1285,1829,1836,1860,1976 'ligula':295,512,668,800,1171,1267,1706,1850 'litora':943 'loborti':448,727,814,1219,1527,1669,1745 'lorem':1,60,104,157,189,210,249,486,882,927,1033,1208,1255,1345,1419,1452,1526,1537,1846,1984 'luctus':51,402,477,601,1321,1363,1449,1607,1641 'maecena':132,224,263,533,1933 'magna':41,88,236,452,653,797,1335,1608,1817,1923,1935 'magni':1198,1655 'malesuada':10,23,467,501,644,799,850,1102,1167,1418,1488,1584,1601,1878 'massa':190,319,408,462,548,806,816,819,1014,1057,1066,1225,1261,1688,1812 'matti':538,597,604,705,1227,1404,1514,1816,1911 'mauri':136,149,226,275,327,637,674,791,1021,1381,1428,1438,1443,1575,1678,1746,1883,1959 'metus':135,196,203,282,312,469,595,617,632,718,767,911,1144,1211,1252,1461,1533,1727,1831 'mi':85,355,1157,1390,1958 'molesti':232,286,332,401,629,731,834,968,1305,1384,1825,1898 'molli':21,96,906,1107,1843 'mont':1201,1658 'morbi':28,334,356,495,844,1515,1578,1704 'mus':1204,1661 'nam':165,807,876,951,1015,1406 'nascetur':1202,1659 'natoqu':1195,1652 'nec':169,182,259,454,520,725,813,877,896,976,995,1013,1019,1031,1072,1091,1209,1269,1276,1281,1477,1592,1663,1687,1728,1796,1828,1845,1891 'nequ':72,223,358,377,492,515,524,539,592,739,778,955,982,989,1039,1076,1136,1242,1394,1470,1839,1853,1916 'netus':499,848,1582 'nibh':213,260,688,785,793,808,820,909,1046,1061,1128,1138,1277,1309,1372,1382,1453,1614,1732 'nisi':321,904,1103,1122,1327,1328,1401,1420,1561,1593,1632,1873 'nisl':459,726,917,1177,1218,1675,1715 'non':79,342,584,591,652,661,872,916,925,934,1118,1246,1259,1297,1559,1694,1769,1851 'nostra':947 'nulla':180,191,304,337,343,345,372,384,483,606,608,671,675,817,928,1048,1088,1111,1300,1467,1966 'nullam':193,460,506,651,665,1074,1837,1926 'nunc':9,37,97,302,421,573,625,634,643,690,972,1120,1293,1341,1362,1450,1739,1749,1760,1827,1871,1951 'odio':375,388,447,535,558,868,1007,1093,1188,1247,1755,1897 'orci':50,253,347,476,532,546,650,839,1027,1073,1078,1312,1556 'ornar':234,264,443,553,616,869,1095,1226,1286,1445,1475,1921,1954 'parturi':1200,1657 'pellentesqu':64,112,429,493,842,878,887,1169,1399,1458,1469,1576,1644,1780,1787,1808,1887,1946 'penatibus':1196,1653 'per':945,948 'pharetra':17,750,1070,1174,1331 'phasellus':38,174,373,998,1106,1130,1165,1186,1768 'placerat':781,795,1089,1140,1260,1504,1524,1888 'platea':110 'porta':154,341,518,683,957,1153 'porttitor':186,696,1217,1274,1440 'posuer':54,106,153,315,480,530,735,1191,1258,1412,1956 'potenti':27,1551,1712 'praesent':898,1391 'pretium':299,430,710,762,777,871,1080,1248,1360,1493,1513,1557,1569,1598,1616 'primi':47,473 'proin':86,220,450,1110,1395,1413,1457,1473,1724,1943,1947,1957 'pulvinar':245,322,351,438,463,736,935,1272,1447,1539,1639,1821,1952,1983 'purus':126,396,409,711,786,879,889,922,1147,1380,1484,1525,1626,1689,1870,1969 'quam':115,509,561,657,1365,1521,1545,1647,1782 'qui':173,306,362,439,456,466,521,618,700,728,1065,1067,1182,1266,1409,1437,1465,1471,1490,1604,1630,1677,1830,1844,1953,1968 'quisqu':256,1141,1636,1666,1974 'rhoncus':95,703,1104,1264,1558,1710,1914 'ridiculus':1203,1660 'risus':237,522,556,744,874,997,1036,1094,1096,1185,1245,1282,1667,1702,1895 'rutrum':14,127,134,143,212,284,680,796,1047,1333,1434,1855 'sagitti':307,670,910,1016,1398,1876,1931,1945 'sapien':233,278,656,664,1006,1151,1190,1320,1410,1498,1617,1627,1703,1765,1791,1874 'scelerisqu':58,175,903,923,1322,1386,1520,1698,1721 'sed':12,36,57,70,90,123,147,188,227,238,366,370,413,549,607,615,639,722,732,775,776,833,921,931,1035,1084,1123,1166,1224,1280,1334,1451,1492,1511,1620,1696,1753,1788,1797,1804,1814,1913 'sem':69,89,94,137,270,417,433,599,770,857,953,1207,1234,1668,1685,1912 'semper':378,453,614,733,977,1623 'senectus':497,846,1580 'sit':4,120,140,160,267,276,297,349,426,568,708,715,746,827,830,894,991,1040,1228,1236,1318,1339,1502,1505,1529,1719,1763,1771,1864,1987 'socii':1194,1651 'sociosqu':941 'sodal':399,996,1049,1115 'sollicitudin':371,379,485,720,826,1000,1043,1086,1367,1432,1571,1807 'suscipit':184,225,840,1210,1238,1781,1822 'suspendiss':26,380,1273,1439,1550,1566,1711,1900 'taciti':940 'tellus':92,300,758,1154,1231,1554,1599,1635,1642 'tempor':139,301,754,1353,1436,1789,1975 'tempus':103,185,588,780,1302,1342,1378,1631,1877,1938 'tincidunt':102,280,789,835,1017,1108,1129,1135,1352,1396,1468,1695,1973 'torquent':944 'tortor':32,239,340,368,412,774,1030,1373,1415,1426,1430,1456,1692,1699,1892,1925 'tristiqu':80,385,496,576,648,676,802,845,1421,1541,1579,1649,1918,1920 'turpi':206,504,751,853,1034,1317,1351,1512,1587,1717,1734,1922 'ullamcorp':222,436,560,867,893,1131,1329,1549,1595,1645,1697,1866 'ultric':33,53,209,479,829,1279,1308,1487,1573,1767,1799,1927,1939 'ultrici':84,113,420,610,885,1029,1618,1681,1738 'urna':30,146,199,230,491,631,908,915,965,1028,1215,1223,1402,1441,1497,1691,1806,1813,1867,1901,1919 'ut':65,74,93,116,133,150,207,243,281,287,303,354,406,527,713,768,902,962,1145,1161,1176,1355,1379,1496,1542,1574,1648,1676,1761,1838 'varius':68,241,418,511,1079,1152,1214,1268,1758,1852 'vehicula':179,248,296,636,961,1075,1181,1262,1290,1348,1397 'vel':22,194,221,289,330,590,695,752,837,856,888,1011,1314,1330,1359,1377,1485,1670,1716,1929,1977 'velit':81,99,195,444,540,684,863,883,886,1296,1752,1757,1826,1868 'venenati':235,660,761,875,985,1032,1184,1323,1547,1881,1972 'vestibulum':31,44,59,424,470,714,783,1026,1212,1301,1326,1358,1462,1509,1536,1590,1803,1899 'vita':29,35,91,294,320,407,552,811,952,974,1137,1170,1180,1239,1375,1387,1534,1570,1634,1747,1783,1908 'vivamus':82,200,859,1064,1243,1306,1713,1730,1810,1875 'viverra':394,434,550,712,755,1146,1149,1298,1448,1894 'volutpat':386,465,519,792,964,1004,1156,1284,1790,1833 'vulput':176,215,659,693,763,956,959,1020,1113,1164,1370,1374,1376,1729,1848
37	'12345':30 '123456789':5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29 'jackass':4
71	'13':35 '1600s':50 '4':61 'bibl':57 'charli':20,58 'dinner':43 'discov':18 'funni':27 'grow':10 'hear':30 'internet':16 'isn':23 'kid':6,47 'meme':19 'near':25 'old':38 'part':3 'repeat':32 'sentienc':12 'start':13 'thing':54 'think':46 'unicorn':22,60 'use':14 'verbatim':33 'video':62 'week':41 'worst':2 'year':37 'year-old':36
73	'20':43 '3.5':47,110 '50':115 '875':108 'abl':30,69 'ass':75 'base':139 'bear':149 'begin':99 'bonus':125 'catch':129 'check':96 'check-up':95 'combin':2 'consist':71 'coupl':37 'cultur':134,140 'day':50 'desk':8 'doctor':82 'everi':49,112 'exercis':26,101,157 'get':72 'goal':106 'great':19 'grow':154 'happi':66 'hard':151 'hasn':57 'help':59 'hour':53 'howev':150 'huge':87 'ipad':13 'longer':34 'm':64,118,128 'mile':48,109,111 'mileston':135,141 'move':77 'never':144 'past':42 'pretti':119 're':86 'regimen':102 'shape':90 'signific':62 'stream':16 'sure':120 'sustain':32 'take':51 'time':146 'treadmil':5,11 'tri':153 'tubbi':155 'upsid':126 've':28 'video':15,138 'video-bas':137 'walk':46 'week':39,116 'weekday':113 'weight':61 'well':136 'without':156 'year':44,104
38	'appear':56,178,246 'arrow':365 'autocomplet':212 'automat':57 'back':306 'behavior':396 'believ':392 'bottom':60,96,127,269,361,373 'button':33,93,123,225,244,266,288 'civil':394 'click':185,241,263,285,314,330,349,362,378 'come':52 'communiti':296,395 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,406 'discuss':12 'enjoy':260,400 'enter':73 'entir':219 'fellow':295 'field':382 'first':389 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'indic':370 'join':5,200 'keep':26,38,41,143 'know':257,298 'last':380 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'move':344 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326,357,376 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280,381,390 'privat':15 'problem':277 'progress':369 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'reach':359 'read':39,339 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':402 'summari':386 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,399 'tip':21 'titl':351 'togeth':146 'toolbar':229 'top':181,347,354 'topic':63,75,111,119,130,151,341,368,385 'tri':6,405 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,403
39	'4':15 'charli':11,12 'good':8 'laugh':9 'unicorn':14 'video':16 'wife':2
40	'2000':33 'bodi':20 'fi':29 'go':3,7 'imag':24 'imdb':17 'import':26 'link':15 'm':2 'mani':23 'moon':9 'movi':30 'post':13 'sci':28 'sci-fi':27 'video':35
41	'2000':41 'bodi':22 'clay':1 'fi':37 'go':5,9 'imag':26 'imdb':19 'import':34 'link':17 'm':4 'mani':25 'moon':11 'movi':38 'post':15 'said':2 'sci':36 'sci-fi':35 'tri':27 'video':43 'work':31
42	'2000':32 '2009':23 'edit':5 'fi':28 'imag':13 'imdb':15 'imdb.com':21 'import':25 'like':18 'look':17 'low':11 'low-r':10 'moon':22 'movi':29 'res':12 'sci':27 'sci-fi':26 'second':20 'shiver':2 'super':9 'timber':4 'video':34 'well':1
43	'2000':19 'appear':7 'broken':8 'fi':15 'hello':1 'imag':6 'import':12 'movi':16 'sci':14 'sci-fi':13 'video':21 'work':4
44	'access':36,56,70 'allmansretten':11 'allow':114 'appli':72 'area':95 'aren':112 'call':10,51 'categori':75 'certain':37,74,93 'close':130 'common':87 'develop':89 'england':66 'europ':4 'everyman':26 'exclud':98 'exercis':46 'freedom':14,18,22 'garden':91 'general':31 'glee':110 'heath':83 'land':42,79,88,90,125 'main':77 'moor':82 'mountain':81 'much':2 'onto':117 'own':41 'permiss':121 'privat':40,118 'properti':119 'public':32,38,55,69 'recreat':44 'regist':86 'rig':101 'right':28,34,48,53,62,71 'roam':16,20,24,64 'scandinavian':9 'shoot':107 'sometim':50 'specif':80,97 'throughout':1 'trespass':108 'uncultiv':78 'uninhabit':124 'us':105,128 'wale':68 'wander':116 'wikipedia.org':17 'wilder':59 'without':120
45	'ago':8 'bug':2 'come':27 'conclus':30 'confirm':16 'discours':36,38 'erad':5 'launch':24 'localhost:4000':10 'mani':1 'old':35 'present':12 'prior':22 'run':34 'softwar':37 'somebodi':15 'try2':32 'upgrad':21 'week':7 'whether':17
52	'come':19 'conclus':22 'config':15 'discours':28,30 'forum':13 'forum-level':12 'isn':2 'level':14 'old':27 'option':16 'regress':10 'run':26 'see':8 'softwar':29 'though':4 'try2':24
53	'affect':15 'come':34 'conclus':37 'copi':29 'delet':19 'dev':9 'discours':43,45 'doesn':26 'get':28 'll':18 'localhost:4000':31 'old':42 'otherwis':22 'problem':13 'rubi':7 'run':3,41 'softwar':44 'still':12 'thread':21 'tri':1 'try2':16,39
54	'12345':4 'come':7 'conclus':10 'delet':1 'discours':16,18 'old':15 'run':14 'softwar':17 'thread':3 'try2':12
55	'appear':56,178,246 'arrow':365 'autocomplet':212 'automat':57 'back':306 'behavior':396 'believ':392 'bottom':60,96,127,269,361,373 'button':33,93,123,225,244,266,288 'civil':394 'click':185,241,263,285,314,330,349,362,378 'come':52 'communiti':296,395 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,406 'discuss':12 'enjoy':260,400 'enter':73 'entir':219 'fellow':295 'field':382 'first':389 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'indic':370 'join':5,200 'keep':26,38,41,143 'know':257,298 'last':380 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'move':344 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326,357,376 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280,381,390 'privat':15 'problem':277 'progress':369 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'reach':359 'read':39,339 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':402 'summari':386 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,399 'tip':21 'titl':351 'togeth':146 'toolbar':229 'top':181,347,354 'topic':63,75,111,119,130,151,341,368,385 'tri':6,405 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,403
56	'123':4 '2000':13 'broken':3 'fi':9 'import':6 'look':2 'movi':10 'sci':8 'sci-fi':7 'still':1 'video':15
72	'add':15,30 'bunch':5 'discours':35 'imag':16 'pictur':9,31 'post':19,34 'seen':3 'somehow':26 'topic':7 'upload':24 've':2
57	'appear':56,178,246 'arrow':365 'autocomplet':212 'automat':57 'back':306 'behavior':396 'believ':392 'bottom':60,96,127,269,361,373 'button':33,93,123,225,244,266,288 'civil':394 'click':185,241,263,285,314,330,349,362,378 'come':52 'communiti':296,395 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,406 'discuss':12 'enjoy':260,400 'enter':73 'entir':219 'fellow':295 'field':382 'first':389 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'indic':370 'join':5,200 'keep':26,38,41,143 'know':257,298 'last':380 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'move':344 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326,357,376 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280,381,390 'privat':15 'problem':277 'progress':369 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'reach':359 'read':39,339 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':402 'summari':386 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,399 'tip':21 'titl':351 'togeth':146 'toolbar':229 'top':181,347,354 'topic':63,75,111,119,130,151,341,368,385 'tri':6,405 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,403
58	'air':29 'angri':24,28 'appl':14 'bother':39 'comput':16 'crazi':4 'drive':2 'fist':25 'mac':8,15,41,43 'misus':35,46 'nerd':19 'network':18 'peopl':6 'refer':12 'shake':22 'similar':34 'tech':49 'type':7 'vs':42 'word':48 'words/abbreviations':37
59	'appear':56,178,246 'arrow':365 'autocomplet':212 'automat':57 'back':306 'behavior':396 'believ':392 'bottom':60,96,127,269,361,373 'button':33,93,123,225,244,266,288 'civil':394 'click':185,241,263,285,314,330,349,362,378 'come':52 'communiti':296,395 'compos':228 'content':46 'convers':137,202 'differ':140 'direct':141 'discours':7,406 'discuss':12 'enjoy':260,400 'enter':73 'entir':219 'fellow':295 'field':382 'first':389 'flag':287 'forum':13 'get':23,305 'hesit':283 'hi':1 'highlight':238,249 'home':309 'icon':316,333 'import':223 'indic':370 'join':5,200 'keep':26,38,41,143 'know':257,298 'last':380 'left':320 'let':255,290 'like':265 'link':145 'load':48 'look':250 'member':297 'mention':172,204 'messag':16 'moder':292 'move':344 'name':207 'navig':329 'need':65 'new':50,78,150 'next':31 'notif':176,189 'number':36,190 'otherwis':328 'overal':107 'page':32,35,69,184,310,326,357,376 'person':116 'pop':214 'post':79,89,99,157,168,220,237,253,262,272,280,381,390 'privat':15 'problem':277 'progress':369 'quick':20 'quot':169,217,224,231 'rather':112 're':72 're-ent':71 'reach':359 'read':39,339 'refresh':67 'repli':51,83,85,92,104,122,148,165,243 'right':154,337 'scroll':27,42 'search':322 'section':234 'see':77,192,275 'someon':164,205,256 'specif':88,115 'start':25,208 'stay':402 'summari':386 'take':135 'talk':160,195 'tap':187 'thank':3 'theme':108 'time':313,399 'tip':21 'titl':351 'togeth':146 'toolbar':229 'top':181,347,354 'topic':63,75,111,119,130,151,341,368,385 'tri':6,405 'type':209 'upper':319,336 'use':90,120,147,221 'user':325 'usernam':174 'visit':323 'want':102,133 'welcom':9,403
60	'1800':3 'advanc':43 'adventur':239 'allow':154 'also':85 'american':15,205 'anoth':231 'barb':59 'baron':111 'bear':254 'brought':252 'call':82 'cattl':40,45,107,110,195 'cattlemen':87 'claim':127 'cliff':245 'close':295 'come':187 'compel':232 'compet':10 'conflict':48 'continu':281 'control':64 'could':26,223 'countless':236 'countri':46 'cross':180 'cultur':145 'danger':178,237 'day':202 'dead':155 'depend':72 'develop':171 'earli':201 'eat':94 'enforc':214 'enter':271 'etc':246 'even':226 'expans':206 'exploit':131 'farmer':18,53 'fatten':38 'fenc':20,55,122,136,181,285 'forc':156 'frontier':16 'furthermor':150 'general':117 'grass':95 'graze':108 'inevit':50 'ingrain':141 'interest':9,34 'keep':74 'land':12,23,57,103,118,262,273,290 'landown':256 'law':152,213 'lawsuit':249 'lead':17 'liabil':274 'littl':210 'livelihood':71 'lot':6,190 'mainten':282 'make':176,224,260 'mine':243 'much':163 'notic':139,184 'notori':92 'occur':198 'one':216,222 'open':77 'ownership':128 'part':172 'particular':146 'passer':265 'pit':86 'play':276 'post':124,138,183 'practic':134 'preval':165 'prevent':268 'rancher':69,114 'rang':76,83 'reason':233 'role':278 'safe':220,263 'separ':8 'settler':42 'sheep':90 'sheepherd':89 'sign':126 'smaller':113 'so-cal':80 'sought':62 'sourc':66,115 'stubbl':99 'success':248 'thiev':193 'though':228 'today':286 'total':30 'trespass':161 'type':240 'uninhabit':289 'unsuit':105 'us':144,168,293 'use':28,159 'war':84,196 'water':65 'well':244 'west':149 'westward':204 'whose':70 'wire':60 'world':175 'would':129
61	'200':18 'categori':12,37 'charact':19 'definit':38 'descript':8,27 'discuss':36 'establish':32 'first':3 'general':40 'keep':15 'longer':26 'new':11 'paragraph':4 'replac':1 'rule':34 'short':7 'space':22 'tri':13 'use':20 'well':29
62	'200':18 'categori':12,37 'charact':19 'definit':38 'descript':8,27 'discuss':36 'establish':32 'first':3 'game':40 'keep':15 'longer':26 'new':11 'paragraph':4 'replac':1 'rule':34 'short':7 'space':22 'tri':13 'use':20 'well':29
63	'200':18 'categori':12,37 'charact':19 'definit':38 'descript':8,27 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'music':40 'new':11 'paragraph':4 'replac':1 'rule':34 'short':7 'space':22 'tri':13 'use':20 'well':29
64	'200':18 'categori':12,37 'charact':19 'definit':38 'descript':8,27 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'movi':40 'new':11 'paragraph':4 'replac':1 'rule':34 'short':7 'space':22 'tri':13 'use':20 'well':29
65	'200':18 'categori':12,37 'charact':19 'definit':38 'descript':8,27 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'new':11 'paragraph':4 'replac':1 'rule':34 'short':7 'space':22 'sport':40 'tri':13 'use':20 'well':29
66	'200':18 'categori':12,37 'charact':19 'definit':38 'descript':8,27 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'new':11 'paragraph':4 'replac':1 'rule':34 'school':40 'short':7 'space':22 'tri':13 'use':20 'well':29
67	'200':18 'categori':12,37 'charact':19 'definit':38 'descript':8,27 'discuss':36 'establish':32 'first':3 'keep':15 'longer':26 'new':11 'paragraph':4 'pet':40 'replac':1 'rule':34 'short':7 'space':22 'tri':13 'use':20 'well':29
69	'acronym':33 'all-cap':25 'around':12 'came':29 'cap':27 'cultur':10 'dammit':17 'enorm':8 'mac':35,37 'mayb':34 'mean':16 'misus':40 'nerd':9 'perl':1,3,5 'retcon':32 'see':22 'sensit':11 'tech':43 'version':28 'vs':36 'word':14,42
78	'appear':8 'categori':14 'congratul':15 'get':17 'pin':5 'top':11 'topic':2 'vagrant':18
77	'/vagrant':110 'account':25,36 'admin':58 'also':93 'around':28 'base':96 'cd':109 'chang':125 'check':67,75 'command':106 'congratul':145 'creat':42 'data':134 'databas':98 'dataset':80 'db':117,120 'default':17 'develop':113 'discours':15,77,112 'dumps/development-image.sql':143 'dumps/production-image.sql':115 'environ':13 'eviltrout':56 'execut':103,137 'follow':51,105 'get':85,147 'imag':99 'includ':20,94 'info':65 'instal':19,92,101 'instead':144 'jatwood':59 'latest':64 'log':45 'look':33 'migrat':118 'mind':127 'one':43,48 'password':54,55 'pg':114,142 'play':27 'pleas':66 'prepar':122 'product':79,97 'project':72 'psql':111 'rake':116,119 're':32 'readme.md':69 'regular':60 'see':4 'set':9 'ssh':108 'start':86 'success':8 'test':38,89,121,133 'thank':73 'topic':23,90 'use':131,141 'user':61 'vagrant':12,107,148 've':7 'want':83,129 'without':87
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY schema_migrations (version) FROM stdin;
20120311163914
20120311164326
20120311170118
20120311201341
20120311210245
20120416201606
20120420183447
20120423140906
20120423142820
20120423151548
20120425145456
20120427150624
20120427151452
20120427154330
20120427172031
20120502183240
20120502192121
20120503205521
20120507144132
20120507144222
20120514144549
20120514173920
20120514204934
20120517200130
20120518200115
20120519182212
20120523180723
20120523184307
20120523201329
20120525194845
20120529175956
20120529202707
20120530150726
20120530160745
20120530200724
20120530212912
20120614190726
20120614202024
20120615180517
20120618152946
20120618212349
20120618214856
20120619150807
20120619153349
20120619172714
20120621155351
20120621190310
20120622200242
20120625145714
20120625162318
20120625174544
20120625195326
20120629143908
20120629150253
20120629151243
20120629182637
20120702211427
20120703184734
20120703201312
20120703203623
20120703210004
20120704160659
20120704201743
20120705181724
20120708210305
20120712150500
20120712151934
20120713201324
20120716020835
20120716173544
20120718044955
20120719004636
20120720013733
20120720044246
20120720162422
20120723051512
20120724234502
20120724234711
20120725183347
20120726201830
20120726235129
20120727005556
20120727150428
20120727213543
20120802151210
20120806030641
20120806062617
20120803191426
20120807223020
20120809020415
20120809030647
20120809053414
20120809154750
20120809174649
20120809175110
20120809201855
20120810064839
20120813201426
20120812235417
20120813004347
20120813042912
20120815004411
20120815180106
20120815204733
20120816050526
20120816205537
20120816205538
20120820191804
20120821191616
20120823205956
20120824171908
20120828204209
20120828204624
20120830182736
20120910171504
20120918152319
20120918205931
20120919152846
20120921055428
20120921155050
20120921162512
20120921163606
20120924182031
20120924182000
20120925171620
20120925190802
20120928170023
20121009161116
20121011155904
20121017162924
20121018103721
20121018182709
20121018133039
20121106015500
20121108193516
20121109164630
20121113200844
20121113200845
20121115172544
20121116212424
20121119190529
20121119200843
20121122033316
20121121202035
20121121205215
20121123054127
20121123063630
20121129160035
20121129184948
20121130191818
20121130010400
20121202225421
20121203181719
20121204183855
20121204193747
20121205162143
20121207000741
20121211233131
20121216230719
20121218205642
20121224072204
20121224095139
20121224100650
20121228192219
20130107165207
20130108195847
20130115012140
20130115021937
20130115043603
20130116151829
20130120222728
20130121231352
20130122051134
20130122232825
20130123070909
20130125002652
20130125030305
20130125031122
20130127213646
20130128182013
20130129010625
20130129163244
20130129174845
20130130154611
20130131055710
20130201000828
20130201023409
20130203204338
20130204000159
20130205021905
20130207200019
20130208220635
20130213021450
20130213203300
20130221215017
20130226015336
20130306180148
20130311181327
20130313004922
20130314093434
20130315180637
20130319122248
20130320012100
20130320024345
\.


--
-- Data for Name: site_customizations; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY site_customizations (id, name, stylesheet, header, "position", user_id, enabled, key, created_at, updated_at, override_default_style, stylesheet_baked) FROM stdin;
\.


--
-- Name: site_customizations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('site_customizations_id_seq', 1, false);


--
-- Data for Name: site_settings; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY site_settings (id, name, data_type, value, created_at, updated_at) FROM stdin;
1	system_username	1	admin	2013-01-07 21:57:34.992013	2013-01-07 21:57:34.992013
4	enforce_global_nicknames	5	f	2013-01-31 19:21:09.2881	2013-01-31 19:21:09.2881
9	default_trust_level	3	1	2013-02-01 04:59:26.005661	2013-02-01 04:59:26.005661
10	logo_small_url	1	/assets/logo-single.png	2013-02-01 18:35:23.217003	2013-02-01 18:35:23.217003
3	allow_import	5	f	2013-01-08 19:12:11.048611	2013-02-02 19:17:38.825082
11	imgur_api_key	1		2013-02-04 21:29:08.243033	2013-02-04 21:29:08.243033
6	twitter_consumer_key	1		2013-01-31 22:29:09.581927	2013-02-04 21:29:23.984213
5	twitter_consumer_secret	1		2013-01-31 22:29:08.759612	2013-02-04 21:29:24.781212
8	facebook_app_id	1		2013-01-31 22:29:36.358104	2013-02-04 21:29:25.758071
7	facebook_app_secret	1		2013-01-31 22:29:35.633543	2013-02-04 21:29:26.268495
2	title	1	Vagrant Discourse	2013-01-07 21:58:44.645732	2013-02-04 21:29:36.617707
12	port	3	4000	2013-02-04 21:29:38.485156	2013-02-04 21:29:38.485156
\.


--
-- Name: site_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('site_settings_id_seq', 12, true);


--
-- Data for Name: topic_allowed_users; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topic_allowed_users (id, user_id, topic_id, created_at, updated_at) FROM stdin;
2	2	9	2013-01-07 21:56:54.295319	2013-01-07 21:56:54.295319
3	3	16	2013-01-24 09:00:43.214819	2013-01-24 09:00:43.214819
4	2	16	2013-01-24 09:00:43.217325	2013-01-24 09:00:43.217325
5	5	17	2013-01-29 05:15:31.524706	2013-01-29 05:15:31.524706
6	2	17	2013-01-29 05:15:31.528232	2013-01-29 05:15:31.528232
7	6	18	2013-01-29 05:25:59.442145	2013-01-29 05:25:59.442145
8	2	18	2013-01-29 05:25:59.443257	2013-01-29 05:25:59.443257
9	7	19	2013-01-31 19:46:04.646767	2013-01-31 19:46:04.646767
10	2	19	2013-01-31 19:46:04.649102	2013-01-31 19:46:04.649102
11	9	20	2013-01-31 20:15:19.048354	2013-01-31 20:15:19.048354
12	2	20	2013-01-31 20:15:19.053201	2013-01-31 20:15:19.053201
13	11	21	2013-01-31 20:25:33.706081	2013-01-31 20:25:33.706081
14	2	21	2013-01-31 20:25:33.710095	2013-01-31 20:25:33.710095
15	12	22	2013-01-31 20:38:43.558163	2013-01-31 20:38:43.558163
16	2	22	2013-01-31 20:38:43.562023	2013-01-31 20:38:43.562023
17	13	28	2013-01-31 21:51:24.900807	2013-01-31 21:51:24.900807
18	2	28	2013-01-31 21:51:24.903475	2013-01-31 21:51:24.903475
19	14	29	2013-01-31 21:54:37.542693	2013-01-31 21:54:37.542693
20	2	29	2013-01-31 21:54:37.553925	2013-01-31 21:54:37.553925
21	15	30	2013-01-31 22:18:59.281714	2013-01-31 22:18:59.281714
22	2	30	2013-01-31 22:18:59.285701	2013-01-31 22:18:59.285701
23	16	31	2013-01-31 23:45:27.811781	2013-01-31 23:45:27.811781
24	2	31	2013-01-31 23:45:27.813715	2013-01-31 23:45:27.813715
25	19	32	2013-02-01 01:29:40.461904	2013-02-01 01:29:40.461904
26	2	32	2013-02-01 01:29:40.464443	2013-02-01 01:29:40.464443
27	20	35	2013-02-01 04:37:17.972472	2013-02-01 04:37:17.972472
28	2	35	2013-02-01 04:37:17.97501	2013-02-01 04:37:17.97501
29	22	37	2013-02-04 18:20:42.870323	2013-02-04 18:20:42.870323
30	2	37	2013-02-04 18:20:42.875681	2013-02-04 18:20:42.875681
31	21	38	2013-02-04 18:27:43.894674	2013-02-04 18:27:43.894674
32	2	38	2013-02-04 18:27:43.900305	2013-02-04 18:27:43.900305
33	23	40	2013-02-04 18:41:40.362099	2013-02-04 18:41:40.362099
34	2	40	2013-02-04 18:41:40.365529	2013-02-04 18:41:40.365529
\.


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('topic_allowed_users_id_seq', 34, true);


--
-- Data for Name: topic_invites; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topic_invites (id, topic_id, invite_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: topic_invites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('topic_invites_id_seq', 1, false);


--
-- Data for Name: topic_link_clicks; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topic_link_clicks (id, topic_link_id, user_id, ip, created_at, updated_at) FROM stdin;
\.


--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('topic_link_clicks_id_seq', 1, true);


--
-- Data for Name: topic_links; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topic_links (id, topic_id, post_id, user_id, url, domain, internal, link_topic_id, created_at, updated_at, reflection, clicks, link_post_id) FROM stdin;
1	17	17	2	/faq	localhost:4000	t	\N	2013-01-29 05:15:31.878076	2013-01-29 05:15:31.878076	f	0	\N
2	18	18	2	/faq	localhost:4000	t	\N	2013-01-29 05:25:59.514352	2013-01-29 05:25:59.514352	f	1	\N
3	19	19	2	/faq	localhost:4000	t	\N	2013-01-31 19:46:05.070561	2013-01-31 19:46:05.070561	f	0	\N
4	20	20	2	/faq	localhost:4000	t	\N	2013-01-31 20:15:19.352562	2013-01-31 20:15:19.352562	f	0	\N
5	21	21	2	/faq	localhost:4000	t	\N	2013-01-31 20:25:33.946631	2013-01-31 20:25:33.946631	f	0	\N
6	22	22	2	/faq	localhost:4000	t	\N	2013-01-31 20:38:43.822587	2013-01-31 20:38:43.822587	f	0	\N
7	28	26	2	/faq	localhost:4000	t	\N	2013-01-31 21:51:25.181263	2013-01-31 21:51:25.181263	f	0	\N
8	29	27	2	/faq	localhost:4000	t	\N	2013-01-31 21:54:37.989246	2013-01-31 21:54:37.989246	f	0	\N
9	26	24	11	http://windmillnetworking.wpengine.netdna-cdn.com/wp-content/uploads/2009/03/Private-Property-Keep-Out1.jpg	windmillnetworking.wpengine.netdna-cdn.com	f	\N	2013-01-31 22:01:34.511034	2013-01-31 22:01:34.511034	f	0	\N
10	30	32	2	/faq	localhost:4000	t	\N	2013-01-31 22:18:59.53398	2013-01-31 22:18:59.53398	f	0	\N
11	31	33	2	/faq	localhost:4000	t	\N	2013-01-31 23:45:28.03956	2013-01-31 23:45:28.03956	f	0	\N
12	32	34	2	/faq	localhost:4000	t	\N	2013-02-01 01:29:40.759894	2013-02-01 01:29:40.759894	f	0	\N
15	35	38	2	/faq	localhost:4000	t	\N	2013-02-01 04:37:18.308773	2013-02-01 04:37:18.308773	f	0	\N
17	27	42	20	http://www.imdb.com/title/tt1182345/?ref_=sr_3	www.imdb.com	f	\N	2013-02-01 14:13:35.317796	2013-02-01 14:13:35.317796	f	0	\N
18	26	44	20	http://en.wikipedia.org/wiki/Freedom_to_roam	en.wikipedia.org	f	\N	2013-02-01 14:17:38.398835	2013-02-01 14:17:38.398835	f	0	\N
19	37	55	2	/faq	localhost:4000	t	\N	2013-02-04 18:20:43.174758	2013-02-04 18:20:43.174758	f	0	\N
20	38	57	2	/faq	localhost:4000	t	\N	2013-02-04 18:27:44.449087	2013-02-04 18:27:44.449087	f	0	\N
21	40	59	2	/faq	localhost:4000	t	\N	2013-02-04 18:41:41.010499	2013-02-04 18:41:41.010499	f	0	\N
22	26	60	23	http://www.cliffsnotes.com/study_guide/The-Cattle-Kingdom.topicArticleId-25238,articleId-25174.html	www.cliffsnotes.com	f	\N	2013-02-04 18:56:50.131902	2013-02-04 18:56:50.131902	f	0	\N
23	48	70	22	http://iphonedevelopment.blogspot.com/2011/12/brilliantly-simple-idea-treadmill-desk.html	iphonedevelopment.blogspot.com	f	\N	2013-02-04 19:43:40.636807	2013-02-04 19:43:40.636807	f	0	\N
24	48	70	22	http://iphonedevelopment.blogspot.com/2011/12/treadmill-desk-update.html	iphonedevelopment.blogspot.com	f	\N	2013-02-04 19:43:40.642941	2013-02-04 19:43:40.642941	f	0	\N
25	48	70	22	http://iphonedevelopment.blogspot.com/2012/01/treadmill-desk-plans.html	iphonedevelopment.blogspot.com	f	\N	2013-02-04 19:43:40.701098	2013-02-04 19:43:40.701098	f	0	\N
26	53	77	24	https://github.com/discourse/discourse/blob/master/README.md	github.com	f	\N	2013-03-20 22:58:35.35759	2013-03-20 22:58:35.35759	f	0	\N
\.


--
-- Name: topic_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('topic_links_id_seq', 26, true);


--
-- Data for Name: topic_users; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topic_users (user_id, topic_id, starred, posted, last_read_post_number, seen_post_count, starred_at, last_visited_at, first_visited_at, notification_level, notifications_changed_at, notifications_reason_id, total_msecs_viewed, cleared_pinned_at) FROM stdin;
2	9	f	t	1	1	\N	2013-01-07 21:56:54	2013-01-07 21:56:54	3	2013-01-07 21:56:54	1	0	\N
2	10	f	t	1	1	\N	2013-01-07 22:01:32	2013-01-07 22:01:32	3	2013-01-07 22:01:32	1	27077	\N
2	11	f	t	1	1	\N	2013-01-07 22:01:53	2013-01-07 22:01:53	3	2013-01-07 22:01:53	1	0	\N
2	12	f	t	1	1	\N	2013-01-07 22:03:02	2013-01-07 22:03:02	3	2013-01-07 22:03:02	1	0	\N
22	15	f	f	2	2	\N	2013-02-04 19:38:06	2013-02-04 18:35:34	1	\N	\N	14048	\N
2	34	f	f	3	3	\N	2013-02-04 15:06:51	2013-02-01 21:53:20	1	\N	\N	41546	\N
2	16	f	t	1	1	\N	2013-01-24 09:00:43	2013-01-24 09:00:43	3	2013-01-24 09:00:43	1	0	\N
3	14	f	f	1	1	\N	2013-01-24 09:00:54	2013-01-24 09:00:54	1	\N	\N	0	\N
2	19	f	t	1	1	\N	2013-01-31 19:46:04	2013-01-31 19:46:04	3	2013-01-31 19:46:04	1	0	\N
19	26	f	f	2	2	\N	2013-02-01 02:19:52	2013-02-01 02:19:52	1	\N	\N	24030	\N
4	15	f	f	1	1	\N	2013-01-24 23:27:12	2013-01-24 23:27:12	2	\N	\N	180093	\N
5	15	f	f	1	1	\N	2013-01-29 05:19:16	2013-01-29 05:19:16	1	\N	\N	6002	\N
4	14	f	f	1	1	\N	2013-01-24 23:56:21	2013-01-24 23:56:21	1	\N	\N	3002	\N
2	17	f	t	1	1	\N	2013-01-29 05:15:31	2013-01-29 05:15:31	3	2013-01-29 05:15:31	1	0	\N
2	18	f	t	1	1	\N	2013-01-29 05:25:59	2013-01-29 05:25:59	3	2013-01-29 05:25:59	1	0	\N
20	15	f	t	2	2	\N	2013-02-01 13:56:20	2013-02-01 04:37:35	2	2013-02-01 04:37:48	4	52110	\N
5	14	f	f	1	1	\N	2013-01-29 05:19:13	2013-01-29 05:15:35	1	\N	\N	7006	\N
16	31	f	f	1	1	\N	2013-01-31 23:45:44	2013-01-31 23:45:44	1	\N	\N	43136	\N
16	27	f	f	\N	\N	\N	2013-02-01 00:00:08	2013-02-01 00:00:08	1	\N	\N	0	\N
20	26	f	t	3	3	\N	2013-02-01 17:17:40	2013-02-01 14:14:54	2	2013-02-01 14:17:38	4	186221	\N
11	25	f	t	1	1	\N	2013-02-01 01:07:03	2013-01-31 21:04:37	3	2013-01-31 21:04:37	1	433541	\N
2	20	f	t	1	1	\N	2013-01-31 20:15:19	2013-01-31 20:15:19	3	2013-01-31 20:15:19	1	0	\N
9	27	f	t	3	3	\N	2013-02-01 01:05:28	2013-01-31 21:45:18	3	2013-01-31 21:45:18	1	457460	\N
22	27	f	t	8	8	\N	2013-02-04 18:35:22	2013-02-04 18:20:57	2	2013-02-04 18:21:14	4	29139	\N
9	15	f	f	1	1	\N	2013-01-31 20:15:24	2013-01-31 20:15:24	1	\N	\N	8145	\N
9	14	f	f	1	1	\N	2013-01-31 20:17:05	2013-01-31 20:17:05	1	\N	\N	2002	\N
2	21	f	t	1	1	\N	2013-01-31 20:25:33	2013-01-31 20:25:33	3	2013-01-31 20:25:33	1	0	\N
2	22	f	t	1	1	\N	2013-01-31 20:38:43	2013-01-31 20:38:43	3	2013-01-31 20:38:43	1	0	\N
12	15	f	f	0	1	\N	2013-01-31 20:41:36	2013-01-31 20:41:36	1	\N	\N	2017	\N
12	14	f	f	0	1	\N	2013-01-31 20:41:40	2013-01-31 20:41:40	1	\N	\N	1001	\N
9	25	f	f	1	1	\N	2013-02-01 01:05:44	2013-01-31 21:58:51	1	\N	\N	7006	\N
12	22	f	f	1	1	\N	2013-01-31 20:50:35	2013-01-31 20:38:57	1	\N	\N	4020	\N
2	15	f	t	3	3	\N	2013-02-04 19:49:18	2013-01-07 22:06:26	3	2013-01-07 22:06:26	1	40890	\N
6	18	f	f	1	1	\N	2013-01-29 05:27:08	2013-01-29 05:26:41	1	\N	\N	36039	\N
19	27	f	f	8	8	\N	2013-02-04 19:54:03	2013-02-01 02:36:02	2	\N	\N	279418	\N
2	32	f	t	1	1	\N	2013-02-01 01:29:40	2013-02-01 01:29:40	3	2013-02-01 01:29:40	1	0	\N
23	14	f	f	1	1	\N	2013-02-04 19:58:12	2013-02-04 18:58:55	1	\N	\N	0	\N
11	15	f	f	1	1	\N	2013-01-31 21:21:21	2013-01-31 21:21:21	1	\N	\N	28133	\N
14	26	f	t	2	2	\N	2013-01-31 22:07:10	2013-01-31 22:07:10	2	2013-01-31 22:10:16	4	184005	\N
7	36	f	t	2	2	\N	2013-02-01 18:55:59	2013-02-01 18:55:59	2	2013-02-01 18:56:27	4	36024	\N
20	27	f	t	7	7	\N	2013-02-01 14:13:43	2013-02-01 04:37:54	2	2013-02-01 04:38:45	4	173575	\N
19	34	t	t	5	3	2013-02-01 02:19:48	2013-02-01 05:16:03	2013-02-01 01:51:28	3	2013-02-01 01:51:28	1	1067018	\N
2	29	f	t	1	1	\N	2013-01-31 21:54:37	2013-01-31 21:54:37	3	2013-01-31 21:54:37	1	0	\N
2	38	f	t	1	1	\N	2013-02-04 18:27:43	2013-02-04 18:27:43	3	2013-02-04 18:27:43	1	0	\N
12	26	f	f	1	3	\N	2013-02-04 18:45:06	2013-01-31 21:54:46	1	\N	\N	2000	\N
7	19	f	f	1	1	\N	2013-01-31 21:13:07	2013-01-31 19:46:23	2	\N	\N	67074	\N
12	25	f	f	1	1	\N	2013-01-31 21:54:49	2013-01-31 21:54:49	1	\N	\N	2003	\N
2	28	f	t	1	1	\N	2013-01-31 21:51:24	2013-01-31 21:51:24	3	2013-01-31 21:51:24	1	0	\N
11	36	f	f	1	1	\N	2013-02-01 18:54:43	2013-02-01 16:55:59	1	\N	\N	22018	\N
15	27	f	f	4	4	\N	2013-02-01 04:58:30	2013-02-01 04:58:30	1	\N	\N	32103	\N
9	26	f	f	2	2	\N	2013-01-31 22:18:29	2013-01-31 21:45:26	1	\N	\N	52050	\N
2	30	f	t	1	1	\N	2013-01-31 22:18:59	2013-01-31 22:18:59	3	2013-01-31 22:18:59	1	0	\N
15	30	f	f	1	1	\N	2013-01-31 22:19:06	2013-01-31 22:19:06	1	\N	\N	3001	\N
12	27	f	t	3	8	\N	2013-02-04 18:44:58	2013-01-31 21:54:42	2	2013-01-31 22:11:11	4	51078	\N
2	31	f	t	1	1	\N	2013-01-31 23:45:27	2013-01-31 23:45:27	3	2013-01-31 23:45:27	1	0	\N
7	26	f	f	3	3	\N	2013-02-01 18:56:35	2013-02-01 18:56:35	1	\N	\N	10009	\N
19	25	f	f	1	1	\N	2013-02-01 03:48:28	2013-02-01 03:08:57	2	\N	\N	473711	\N
19	14	f	f	1	1	\N	2013-02-01 03:56:47	2013-02-01 03:08:42	1	\N	\N	7009	\N
2	35	f	t	1	1	\N	2013-02-01 04:37:17	2013-02-01 04:37:17	3	2013-02-01 04:37:17	1	0	\N
20	35	f	f	1	1	\N	2013-02-01 04:37:27	2013-02-01 04:37:27	1	\N	\N	4010	\N
11	27	f	t	7	7	\N	2013-02-04 18:17:54	2013-01-31 22:01:48	2	2013-02-01 14:06:39	4	229656	\N
2	36	f	t	4	4	\N	2013-02-04 18:14:41	2013-02-04 15:07:31	2	2013-02-04 15:17:53	4	315213	\N
7	34	f	f	3	3	\N	2013-02-01 18:33:45	2013-02-01 18:33:45	1	\N	\N	51064	\N
15	34	f	f	3	3	\N	2013-02-01 05:00:30	2013-02-01 05:00:30	1	\N	\N	17099	\N
11	34	f	f	5	3	\N	2013-02-01 17:00:32	2013-02-01 16:57:16	2	\N	\N	213228	\N
7	27	f	f	7	7	\N	2013-02-01 18:56:45	2013-02-01 18:56:45	1	\N	\N	20013	\N
2	37	f	t	1	1	\N	2013-02-04 18:20:42	2013-02-04 18:20:42	3	2013-02-04 18:20:42	1	0	\N
20	36	f	t	4	4	\N	2013-02-04 18:00:25	2013-02-01 14:21:26	3	2013-02-01 14:21:26	1	39126	\N
11	26	f	t	3	3	\N	2013-02-02 13:46:24	2013-01-31 21:34:39	3	2013-01-31 21:34:39	1	339561	\N
2	14	f	t	1	1	\N	2013-02-04 15:39:25	2013-01-07 22:04:47	3	2013-01-07 22:04:47	1	169054	\N
22	37	f	f	1	1	\N	2013-02-04 18:20:50	2013-02-04 18:20:50	1	\N	\N	3009	\N
2	27	f	f	8	8	\N	2013-02-04 18:22:35	2013-02-02 21:36:12	1	\N	\N	21411	\N
21	39	f	f	1	1	\N	2013-02-04 18:34:19	2013-02-04 18:34:19	1	\N	\N	24032	\N
21	38	f	f	1	1	\N	2013-02-04 18:33:56	2013-02-04 18:33:56	1	\N	\N	18031	\N
22	39	f	t	2	2	\N	2013-02-04 19:40:31	2013-02-04 18:32:37	3	2013-02-04 18:32:37	1	46092	\N
22	26	f	f	4	4	\N	2013-02-04 19:37:13	2013-02-04 18:38:32	2	\N	\N	118289	\N
22	25	f	f	1	1	\N	2013-02-04 18:38:51	2013-02-04 18:38:51	1	\N	\N	36030	\N
2	40	f	t	1	1	\N	2013-02-04 18:41:40	2013-02-04 18:41:40	3	2013-02-04 18:41:40	1	0	\N
23	40	f	f	0	1	\N	2013-02-04 18:41:46	2013-02-04 18:41:46	1	\N	\N	999	\N
23	15	f	f	2	2	\N	2013-02-04 18:42:28	2013-02-04 18:42:28	1	\N	\N	8999	\N
23	25	f	f	1	1	\N	2013-02-04 18:42:42	2013-02-04 18:42:42	2	\N	\N	93009	\N
23	26	f	t	4	4	\N	2013-02-04 18:44:18	2013-02-04 18:44:18	2	2013-02-04 18:56:49	4	84991	\N
2	13	f	t	1	1	\N	2013-02-04 19:26:32	2013-01-07 22:03:53	3	2013-01-07 22:03:53	1	0	\N
2	39	f	f	1	1	\N	2013-02-04 19:22:25	2013-02-04 19:22:25	1	\N	\N	0	\N
2	41	f	t	1	1	\N	2013-02-04 19:28:30	2013-02-04 19:28:30	3	2013-02-04 19:28:30	1	0	\N
2	42	f	t	1	1	\N	2013-02-04 19:29:11	2013-02-04 19:29:11	3	2013-02-04 19:29:11	1	0	\N
2	43	f	t	1	1	\N	2013-02-04 19:29:52	2013-02-04 19:29:52	3	2013-02-04 19:29:52	1	0	\N
2	44	f	t	1	1	\N	2013-02-04 19:30:35	2013-02-04 19:30:35	3	2013-02-04 19:30:35	1	0	\N
2	45	f	t	1	1	\N	2013-02-04 19:31:27	2013-02-04 19:31:27	3	2013-02-04 19:31:27	1	0	\N
2	46	f	t	1	1	\N	2013-02-04 19:32:14	2013-02-04 19:32:14	3	2013-02-04 19:32:14	1	0	\N
2	47	f	t	1	1	\N	2013-02-04 19:34:04	2013-02-04 19:34:04	3	2013-02-04 19:34:04	1	0	\N
22	14	f	f	1	1	\N	2013-02-04 19:38:26	2013-02-04 19:38:26	1	\N	\N	3001	\N
7	51	f	t	1	1	\N	2013-02-04 20:00:07	2013-02-04 20:00:06	3	2013-02-04 20:00:06	1	2002	\N
7	50	f	t	1	1	\N	2013-02-04 20:01:04	2013-02-04 19:58:33	3	2013-02-04 19:58:33	1	21015	\N
7	52	f	t	1	1	\N	2013-02-04 20:03:22	2013-02-04 20:03:21	3	2013-02-04 20:03:21	1	5000	\N
7	48	f	f	1	1	\N	2013-02-04 19:39:32	2013-02-04 19:39:32	1	\N	\N	19017	\N
19	39	f	t	2	2	\N	2013-02-04 19:39:02	2013-02-04 19:39:02	2	2013-02-04 19:40:13	4	82110	\N
19	15	f	t	3	3	\N	2013-02-04 19:41:13	2013-02-01 02:35:55	2	2013-02-04 19:44:27	4	279347	\N
19	49	f	f	1	1	\N	2013-02-04 19:52:19	2013-02-04 19:52:19	1	\N	\N	7010	\N
19	48	f	t	3	3	\N	2013-02-04 19:52:44	2013-02-04 19:47:18	2	2013-02-04 19:51:59	4	264333	\N
19	32	f	f	0	1	\N	2013-02-04 19:53:15	2013-02-04 19:53:15	1	\N	\N	6016	\N
7	49	f	t	1	1	\N	2013-02-04 19:51:48	2013-02-04 19:51:47	3	2013-02-04 19:51:47	1	21017	\N
2	49	f	f	1	1	\N	2013-02-04 19:56:21	2013-02-04 19:56:21	1	\N	\N	8001	\N
2	48	f	f	3	3	\N	2013-02-04 19:56:30	2013-02-04 19:56:30	1	\N	\N	2006	\N
23	48	f	t	3	3	\N	2013-02-04 19:57:58	2013-02-04 19:38:46	3	2013-02-04 19:38:46	1	0	\N
22	48	f	t	2	2	\N	2013-02-04 19:40:53	2013-02-04 19:40:53	2	2013-02-04 19:43:40	4	127256	\N
23	49	f	f	1	1	\N	2013-02-04 19:58:03	2013-02-04 19:58:03	1	\N	\N	0	\N
5	17	f	f	1	1	\N	2013-02-04 21:34:01	2013-02-04 21:34:01	1	\N	\N	1001	\N
24	13	f	f	1	1	\N	2013-03-20 23:01:39	2013-03-20 23:01:39	1	\N	\N	1001	2013-03-20 23:01:40.836981
24	12	f	f	1	1	\N	2013-03-20 23:01:43	2013-03-20 23:01:43	1	\N	\N	1001	2013-03-20 23:01:44.073379
24	11	f	f	1	1	\N	2013-03-20 23:01:46	2013-03-20 23:01:46	1	\N	\N	1001	2013-03-20 23:01:47.127275
24	10	f	f	1	1	\N	2013-03-20 23:01:49	2013-03-20 23:01:49	1	\N	\N	1000	2013-03-20 23:01:50.272568
24	53	f	t	2	2	\N	2013-03-20 23:02:06	2013-02-04 22:39:42	3	2013-02-04 22:39:42	1	254251	\N
24	47	f	f	1	1	\N	2013-03-20 23:01:18	2013-03-20 22:59:35	1	\N	\N	7006	2013-03-20 23:01:20.285835
24	46	f	f	1	1	\N	2013-03-20 23:01:22	2013-03-20 23:01:22	1	\N	\N	2003	2013-03-20 23:01:23.374008
24	45	f	f	1	1	\N	2013-03-20 23:01:25	2013-03-20 23:01:25	1	\N	\N	1001	2013-03-20 23:01:26.488306
24	44	f	f	1	1	\N	2013-03-20 23:01:28	2013-03-20 23:01:28	1	\N	\N	1002	2013-03-20 23:01:29.517648
24	43	f	f	1	1	\N	2013-03-20 23:01:31	2013-03-20 23:01:31	1	\N	\N	1001	2013-03-20 23:01:32.304494
24	42	f	f	1	1	\N	2013-03-20 23:01:34	2013-03-20 23:01:34	1	\N	\N	1002	2013-03-20 23:01:34.953043
24	41	f	f	1	1	\N	2013-03-20 23:01:36	2013-03-20 23:01:36	1	\N	\N	1001	2013-03-20 23:01:37.706389
\.


--
-- Data for Name: topics; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topics (id, title, last_posted_at, created_at, updated_at, views, posts_count, user_id, last_post_user_id, reply_count, featured_user1_id, featured_user2_id, featured_user3_id, avg_time, deleted_at, highest_post_number, image_url, off_topic_count, like_count, incoming_link_count, bookmark_count, star_count, category_id, visible, moderator_posts_count, closed, archived, bumped_at, has_best_of, meta_data, vote_count, archetype, featured_user4_id, custom_flag_count, spam_count, illegal_count, inappropriate_count, pinned_at) FROM stdin;
37	Welcome to Try Discourse!	2013-02-04 18:20:43.015643	2013-02-04 18:20:42.861615	2013-02-04 18:20:43.317377	1	1	2	2	0	\N	\N	\N	3	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-02-04 18:20:43.015643	f	\N	0	private_message	\N	0	0	0	0	\N
48	A bear, however hard he tries, grows tubby without exercise.	2013-02-04 19:51:59.86907	2013-02-04 19:38:46.480644	2013-02-04 19:52:00.221386	6	3	23	19	1	22	\N	\N	78	\N	3	\N	0	2	0	0	0	\N	t	0	f	f	2013-02-04 19:51:59.86907	f	\N	0	regular	\N	0	0	0	0	\N
49	How do I add pictures to a post?	2013-02-04 19:51:47.945822	2013-02-04 19:51:47.552833	2013-02-04 19:51:48.111142	4	1	7	7	0	\N	\N	\N	7	\N	1	\N	0	0	0	0	0	1	t	0	f	f	2013-02-04 19:51:47.552333	f	\N	0	regular	\N	0	0	0	0	\N
51	How do I reply to folks here?	2013-02-04 20:00:06.872741	2013-02-04 20:00:06.741454	2013-02-04 20:00:06.974377	1	1	7	7	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-02-04 20:00:06.741117	f	\N	0	regular	\N	0	0	0	0	\N
50	A few qestions about remembering what I've read	2013-02-04 19:58:33.287182	2013-02-04 19:58:32.996731	2013-02-04 20:00:23.423696	1	1	7	7	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-02-04 19:58:33.287182	f	\N	0	regular	\N	0	0	0	0	\N
52	How do I follow conversations	2013-02-04 20:03:22.058651	2013-02-04 20:03:21.685801	2013-02-04 20:03:22.206247	1	1	7	7	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	1	t	0	f	f	2013-02-04 20:03:22.058651	f	\N	0	regular	\N	0	0	0	0	\N
21	Welcome to Try Discourse!	2013-01-31 20:25:33.786175	2013-01-31 20:25:33.695696	2013-01-31 20:25:34.128938	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-31 20:25:33.695176	f	\N	0	private_message	\N	0	0	0	0	\N
36	I have come to the conclusion that try2 is running old Discourse software	2013-02-04 18:00:51.857089	2013-02-01 14:21:26.575247	2013-02-04 18:00:52.040983	6	4	20	20	0	2	7	\N	35	2013-02-04 18:14:49.112063	4	\N	0	1	0	0	0	1	t	0	f	f	2013-02-04 18:00:51.857089	f	\N	0	regular	\N	0	0	0	0	\N
38	Welcome to Try Discourse!	2013-02-04 18:27:44.262101	2013-02-04 18:27:43.77708	2013-02-04 18:27:44.603	1	1	2	2	0	\N	\N	\N	15	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-02-04 18:27:44.262101	f	\N	0	private_message	\N	0	0	0	0	\N
15	Charlie The Unicorn 4	2013-02-04 19:44:27.276622	2013-01-07 22:06:26.856165	2013-02-04 19:44:27.548535	21	3	2	19	1	20	\N	\N	28	\N	3	\N	0	0	0	0	0	4	t	0	f	f	2013-02-04 19:44:27.276622	f	\N	0	regular	\N	0	0	0	0	\N
29	Welcome to Try Discourse!	2013-01-31 21:54:37.777704	2013-01-31 21:54:37.322636	2013-01-31 21:54:38.980532	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-31 21:54:37.321987	f	\N	0	private_message	\N	0	0	0	0	\N
28	Welcome to Try Discourse!	2013-01-31 21:51:25.091254	2013-01-31 21:51:24.895874	2013-01-31 21:51:25.439479	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-31 21:51:25.091254	f	\N	0	private_message	\N	0	0	0	0	\N
32	Welcome to Try Discourse!	2013-02-01 01:29:40.614741	2013-02-01 01:29:40.404507	2013-02-01 01:29:41.703771	1	1	2	2	0	\N	\N	\N	6	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-02-01 01:29:40.404203	f	\N	0	private_message	\N	0	0	0	0	\N
31	Welcome to Try Discourse!	2013-01-31 23:45:27.940884	2013-01-31 23:45:27.807282	2013-01-31 23:45:28.262431	1	1	2	2	0	\N	\N	\N	33	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-31 23:45:27.807023	f	\N	0	private_message	\N	0	0	0	0	\N
9	Welcome to Discourse!	2013-01-07 21:56:54.616967	2013-01-07 21:56:54.281529	2013-01-07 21:56:54.81107	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-07 21:56:54.280898	f	\N	0	private_message	\N	0	0	0	0	\N
30	Welcome to Try Discourse!	2013-01-31 22:18:59.442965	2013-01-31 22:18:59.2738	2013-01-31 22:19:00.682961	1	1	2	2	0	\N	\N	\N	3	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-31 22:18:59.273279	f	\N	0	private_message	\N	0	0	0	0	\N
18	Welcome to Try Discourse!	2013-01-29 05:25:59.472797	2013-01-29 05:25:59.43942	2013-01-29 05:25:59.688037	1	1	2	2	0	\N	\N	\N	36	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-29 05:25:59.439192	f	\N	0	private_message	\N	0	0	0	0	\N
20	Welcome to Try Discourse!	2013-01-31 20:15:19.196245	2013-01-31 20:15:19.038385	2013-01-31 20:15:19.785394	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-31 20:15:19.038099	f	\N	0	private_message	\N	0	0	0	0	\N
16	Welcome to Try Discourse!	2013-01-24 09:00:43.26506	2013-01-24 09:00:43.209655	2013-01-24 09:00:43.937383	0	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-24 09:00:43.209359	f	\N	0	private_message	\N	0	0	0	0	\N
40	Welcome to Try Discourse!	2013-02-04 18:41:40.760571	2013-02-04 18:41:40.34959	2013-02-04 18:41:41.355272	1	1	2	2	0	\N	\N	\N	1	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-02-04 18:41:40.349353	f	\N	0	private_message	\N	0	0	0	0	\N
25	Do you use a mobile device for ALL your work? Tell me how!	2013-01-31 21:04:37.636947	2013-01-31 21:04:37.420296	2013-02-01 01:13:15.437473	12	1	11	11	0	\N	\N	\N	32	\N	1	http://localhost:4000/uploads/try2_discourse/7/blob.png	0	0	1	0	0	2	t	0	f	f	2013-02-01 01:13:15.520004	f	\N	0	regular	\N	0	0	0	0	\N
22	Welcome to Try Discourse!	2013-01-31 20:38:43.690107	2013-01-31 20:38:43.547266	2013-01-31 20:38:44.684729	1	1	2	2	0	\N	\N	\N	4	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-31 20:38:43.546987	f	\N	0	private_message	\N	0	0	0	0	\N
39	MAC vs. Mac and the misuse of words	2013-02-04 19:40:13.635558	2013-02-04 18:32:37.483059	2013-02-04 19:40:13.94479	4	2	22	19	1	\N	\N	\N	23	\N	2	\N	0	0	0	0	0	2	t	0	f	f	2013-02-04 19:40:13.635558	f	\N	0	regular	\N	0	0	0	0	\N
27	Most important Sci-Fi movie of the 2000's?	2013-02-04 18:21:14.309176	2013-01-31 21:45:17.931318	2013-02-04 18:21:14.659115	22	8	9	22	3	20	12	11	11	\N	8	\N	0	2	4	0	0	4	t	0	f	f	2013-02-04 18:21:14.309176	f	\N	0	regular	\N	0	0	0	0	\N
14	Try All The Things!	2013-01-07 22:04:47.515687	2013-01-07 22:04:47.403684	2013-01-07 22:04:47.77737	11	1	2	2	0	\N	\N	\N	3	\N	1	\N	0	0	0	0	0	1	t	0	f	f	2013-01-07 22:04:47.403364	f	\N	0	regular	\N	0	0	0	0	\N
26	Why is uninhabited land in the US so closed off?	2013-02-04 18:56:49.789741	2013-01-31 21:34:39.242171	2013-02-04 18:56:50.435905	14	4	11	23	0	14	20	\N	40	\N	4	\N	0	2	1	0	0	\N	t	0	f	f	2013-02-04 18:56:49.789741	f	\N	0	regular	\N	0	0	0	0	\N
34	123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 123456789 12345	2013-02-01 02:08:39.576351	2013-02-01 01:51:28.244731	2013-02-01 02:08:39.744083	9	3	19	19	2	\N	\N	\N	7	2013-02-04 15:07:00.040417	3	\N	0	0	0	1	1	\N	t	0	f	f	2013-02-01 02:16:38.206069	f	\N	0	regular	\N	0	0	0	0	\N
35	Welcome to Try Discourse!	2013-02-01 04:37:18.133193	2013-02-01 04:37:17.89569	2013-02-01 04:37:19.528042	1	1	2	2	0	\N	\N	\N	4	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-02-01 04:37:18.133193	f	\N	0	private_message	\N	0	0	0	0	\N
19	Welcome to Try Discourse!	2013-01-31 19:46:04.965622	2013-01-31 19:46:04.635874	2013-01-31 19:46:05.505907	1	1	2	2	0	\N	\N	\N	67	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-31 19:46:04.585927	f	\N	0	private_message	\N	0	0	0	0	\N
10	Discourse	2013-01-07 22:01:32.173703	2013-01-07 22:01:32.091105	2013-01-07 22:01:32.286535	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	1	t	0	f	f	2013-01-07 22:01:32.09083	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
17	Welcome to Try Discourse!	2013-01-29 05:15:31.723979	2013-01-29 05:15:31.448247	2013-01-29 05:15:32.670938	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-01-29 05:15:31.447955	f	\N	0	private_message	\N	0	0	0	0	\N
53	Congratulations on getting Vagrant up!	2013-02-04 22:39:55.890904	2013-02-04 22:39:42.946129	2013-03-20 22:59:11.587487	7	2	24	24	0	\N	\N	\N	\N	\N	2	\N	0	0	0	0	0	\N	t	1	f	f	2013-02-04 22:39:43.233076	f	\N	0	regular	\N	0	0	0	0	2013-02-04 22:39:42.946129
47	Category definition for Pets	2013-02-04 19:34:05.121327	2013-02-04 19:34:04.747543	2013-02-04 19:34:05.493424	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	11	t	0	f	f	2013-02-04 19:34:05.121327	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
46	Category definition for School	2013-02-04 19:32:14.656467	2013-02-04 19:32:14.574417	2013-02-04 19:32:15.5416	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	10	t	0	f	f	2013-02-04 19:32:14.574203	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
45	Category definition for Sports	2013-02-04 19:31:27.379578	2013-02-04 19:31:27.10224	2013-02-04 19:31:27.500952	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	9	t	0	f	f	2013-02-04 19:31:27.102033	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
44	Category definition for Movies	2013-02-04 19:30:36.2761	2013-02-04 19:30:35.972724	2013-02-04 19:30:36.382499	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	8	t	0	f	f	2013-02-04 19:30:36.2761	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
43	Category definition for Music	2013-02-04 19:29:52.839308	2013-02-04 19:29:52.531052	2013-02-04 19:29:53.281567	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	7	t	0	f	f	2013-02-04 19:29:52.530841	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
42	Category definition for Gaming	2013-02-04 19:29:11.625953	2013-02-04 19:29:11.284011	2013-02-04 19:29:11.758178	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	6	t	0	f	f	2013-02-04 19:29:11.283687	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
41	Category definition for General	2013-02-04 19:28:30.91322	2013-02-04 19:28:30.817381	2013-02-04 19:28:31.071112	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	5	t	0	f	f	2013-02-04 19:28:30.816865	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
13	Videos	2013-01-07 22:03:53.869432	2013-01-07 22:03:53.824692	2013-01-07 22:03:54.107101	2	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	4	t	0	f	f	2013-01-07 22:03:53.824403	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
12	Pics	2013-01-07 22:03:02.816133	2013-01-07 22:03:02.765939	2013-01-07 22:03:03.014387	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	3	t	0	f	f	2013-01-07 22:03:02.765539	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
11	Tech	2013-01-07 22:01:53.720331	2013-01-07 22:01:53.673426	2013-01-07 22:01:53.928507	1	1	2	2	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	2	t	0	f	f	2013-01-07 22:01:53.673177	f	\N	0	regular	\N	0	0	0	0	2013-03-20 19:01:03.740043
\.


--
-- Name: topics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('topics_id_seq', 53, true);


--
-- Data for Name: twitter_user_infos; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY twitter_user_infos (id, user_id, screen_name, twitter_user_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('twitter_user_infos_id_seq', 2, true);


--
-- Data for Name: uploads; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY uploads (id, user_id, topic_id, original_filename, filesize, width, height, url, created_at, updated_at) FROM stdin;
1	11	1234	blob	6045	60	45	/uploads/try2_discourse/1/blob.png	2013-01-31 20:41:52.608949	2013-01-31 20:41:52.618202
2	11	1234	blob	6045	60	45	/uploads/try2_discourse/2/blob.png	2013-01-31 20:42:00.442369	2013-01-31 20:42:00.497318
3	11	1234	blob	6045	60	45	/uploads/try2_discourse/3/blob.png	2013-01-31 20:42:07.011091	2013-01-31 20:42:07.023196
4	11	1234	blob	6045	60	45	/uploads/try2_discourse/4/blob.png	2013-01-31 20:42:23.767832	2013-01-31 20:42:23.775213
5	11	1234	blob	211772	400	300	/uploads/try2_discourse/5/blob.png	2013-01-31 20:50:26.037468	2013-01-31 20:50:26.053711
6	11	1234	blob	211772	400	300	/uploads/try2_discourse/6/blob.png	2013-01-31 20:51:48.60319	2013-01-31 20:51:48.612874
7	11	1234	blob	211038	400	300	/uploads/try2_discourse/7/blob.png	2013-02-01 01:12:10.951907	2013-02-01 01:12:10.964442
8	19	1234	Tom Baseball.jpg	155380	690	994	/uploads/try2_discourse/8/tom_baseball.jpeg	2013-02-01 01:59:58.626497	2013-02-01 01:59:58.637671
9	19	1234	Scratch.txt	208	\N	\N		2013-02-01 02:24:15.192394	2013-02-01 02:24:15.192394
10	20	1234	MV5BMTgzODgyNTQwOV5BMl5BanBnXkFtZTcwNzc0NTc0Mg@@._V1_SY317_CR0,0,214,317_.jpg	16584	214	317	/uploads/try2_discourse/10/mv5bmtgzodgyntqwov5bml5banbnxkftztcwnzc0ntc0mg__v1_sy317_cr00214317_.jpeg	2013-02-01 14:13:32.866955	2013-02-01 14:13:32.8737
11	20	1234	MV5BMTgzODgyNTQwOV5BMl5BanBnXkFtZTcwNzc0NTc0Mg@@._V1_SY317_CR0,0,214,317_.jpg	16584	214	317	/uploads/try2_discourse/11/mv5bmtgzodgyntqwov5bml5banbnxkftztcwnzc0ntc0mg__v1_sy317_cr00214317_.jpeg	2013-02-01 14:13:54.035135	2013-02-01 14:13:54.055294
12	11	1234	6358969_460s_v2.jpg	53630	460	623	/uploads/try2_discourse/12/6358969_460s_v2.jpeg	2013-02-04 18:18:32.869739	2013-02-04 18:18:32.87947
13	11	1234	36526.jpg	235180	600	579	/uploads/try2_discourse/13/36526.jpeg	2013-02-04 18:20:14.316719	2013-02-04 18:20:14.332322
14	21	1234	dnd_dun_SmileyBob-1.gif	851345	690	545	/uploads/try2_discourse/14/dnd_dun_smileybob1.gif	2013-02-04 19:15:10.175522	2013-02-04 19:15:10.19155
\.


--
-- Name: uploads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('uploads_id_seq', 14, true);


--
-- Data for Name: user_actions; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY user_actions (id, action_type, user_id, target_topic_id, target_post_id, target_user_id, acting_user_id, created_at, updated_at) FROM stdin;
23	12	2	9	-1	\N	2	2013-01-07 21:56:54.281529	2013-01-07 21:56:54.436811
24	4	2	10	-1	\N	2	2013-01-07 22:01:32.091105	2013-01-07 22:01:32.114801
27	4	2	11	-1	\N	2	2013-01-07 22:01:53.673426	2013-01-07 22:01:53.696275
30	4	2	12	-1	\N	2	2013-01-07 22:03:02.765939	2013-01-07 22:03:02.790958
33	4	2	13	-1	\N	2	2013-01-07 22:03:53.824692	2013-01-07 22:03:53.848021
36	4	2	14	-1	\N	2	2013-01-07 22:04:47.403684	2013-01-07 22:04:47.464741
39	4	2	15	-1	\N	2	2013-01-07 22:06:26.856165	2013-01-07 22:06:26.902676
40	12	2	16	-1	\N	2	2013-01-24 09:00:43.209655	2013-01-24 09:00:43.250998
41	13	3	16	-1	\N	2	2013-01-24 09:00:43.209655	2013-01-24 09:00:43.253124
110	4	9	27	-1	\N	9	2013-01-31 21:45:17.931318	2013-01-31 21:45:18.007626
364	1	23	48	70	\N	23	2013-02-04 19:49:56.52356	2013-02-04 19:49:56.583421
259	5	20	26	44	\N	20	2013-02-01 14:17:38.286098	2013-02-01 14:17:38.384081
46	12	2	17	-1	\N	2	2013-01-29 05:15:31.448247	2013-01-29 05:15:31.564305
47	13	5	17	-1	\N	2	2013-01-29 05:15:31.448247	2013-01-29 05:15:31.566406
114	12	2	28	-1	\N	2	2013-01-31 21:51:24.895874	2013-01-31 21:51:24.953022
115	13	13	28	-1	\N	2	2013-01-31 21:51:24.895874	2013-01-31 21:51:24.956317
188	5	19	34	37	\N	19	2013-02-01 02:08:39.576351	2013-02-01 02:08:39.703257
262	4	20	36	-1	\N	20	2013-02-01 14:21:26.575247	2013-02-01 14:21:26.605061
52	12	2	18	-1	\N	2	2013-01-29 05:25:59.43942	2013-01-29 05:25:59.451196
53	13	6	18	-1	\N	2	2013-01-29 05:25:59.43942	2013-01-29 05:25:59.452729
365	2	22	48	70	\N	23	2013-02-04 19:49:56.52356	2013-02-04 19:49:56.590923
120	12	2	29	-1	\N	2	2013-01-31 21:54:37.322636	2013-01-31 21:54:37.643689
121	13	14	29	-1	\N	2	2013-01-31 21:54:37.322636	2013-01-31 21:54:37.647119
58	12	2	19	-1	\N	2	2013-01-31 19:46:04.635874	2013-01-31 19:46:04.741925
59	13	7	19	-1	\N	2	2013-01-31 19:46:04.635874	2013-01-31 19:46:04.74429
266	1	11	26	44	\N	11	2013-02-01 16:56:34.134477	2013-02-01 16:56:34.175981
267	2	20	26	44	\N	11	2013-02-01 16:56:34.134477	2013-02-01 16:56:34.18058
377	4	7	50	-1	\N	7	2013-02-04 19:58:32.996731	2013-02-04 19:58:33.059172
64	12	2	20	-1	\N	2	2013-01-31 20:15:19.038385	2013-01-31 20:15:19.153083
65	13	9	20	-1	\N	2	2013-01-31 20:15:19.038385	2013-01-31 20:15:19.155224
127	5	9	27	28	\N	9	2013-01-31 21:56:35.884318	2013-01-31 21:56:36.041604
70	12	2	21	-1	\N	2	2013-01-31 20:25:33.695696	2013-01-31 20:25:33.754306
71	13	11	21	-1	\N	2	2013-01-31 20:25:33.695696	2013-01-31 20:25:33.758117
281	5	2	36	53	\N	2	2013-02-04 15:17:53.58021	2013-02-04 15:17:53.6622
284	1	20	36	53	\N	20	2013-02-04 18:00:35.847315	2013-02-04 18:00:35.931084
285	2	2	36	53	\N	20	2013-02-04 18:00:35.847315	2013-02-04 18:00:35.939547
76	12	2	22	-1	\N	2	2013-01-31 20:38:43.547266	2013-01-31 20:38:43.650809
77	13	12	22	-1	\N	2	2013-01-31 20:38:43.547266	2013-01-31 20:38:43.653853
298	6	20	27	56	\N	22	2013-02-04 18:21:14.442755	2013-02-04 18:21:14.4512
299	5	22	27	56	\N	22	2013-02-04 18:21:14.309176	2013-02-04 18:21:14.53963
140	5	14	26	29	\N	14	2013-01-31 22:10:16.460181	2013-01-31 22:10:16.636047
86	4	11	25	-1	\N	11	2013-01-31 21:04:37.420296	2013-01-31 21:04:37.49966
302	12	2	38	-1	\N	2	2013-02-04 18:27:43.77708	2013-02-04 18:27:43.940614
144	5	12	27	30	\N	12	2013-01-31 22:11:11.074018	2013-01-31 22:11:11.145098
303	13	21	38	-1	\N	2	2013-02-04 18:27:43.77708	2013-02-04 18:27:43.94468
147	1	9	26	29	\N	9	2013-01-31 22:16:50.569085	2013-01-31 22:16:50.650129
148	2	14	26	29	\N	9	2013-01-31 22:16:50.569085	2013-01-31 22:16:50.6544
149	12	2	30	-1	\N	2	2013-01-31 22:18:59.2738	2013-01-31 22:18:59.336246
150	13	15	30	-1	\N	2	2013-01-31 22:18:59.2738	2013-01-31 22:18:59.339422
308	4	22	39	-1	\N	22	2013-02-04 18:32:37.483059	2013-02-04 18:32:37.543648
99	4	11	26	-1	\N	11	2013-01-31 21:34:39.242171	2013-01-31 21:34:39.299586
215	3	19	34	37	\N	19	2013-02-01 02:18:22.472302	2013-02-01 02:18:22.497694
155	12	2	31	-1	\N	2	2013-01-31 23:45:27.807282	2013-01-31 23:45:27.839894
156	13	16	31	-1	\N	2	2013-01-31 23:45:27.807282	2013-01-31 23:45:27.841546
218	12	2	35	-1	\N	2	2013-02-01 04:37:17.89569	2013-02-01 04:37:18.093044
219	13	20	35	-1	\N	2	2013-02-01 04:37:17.89569	2013-02-01 04:37:18.095788
319	5	23	26	60	\N	23	2013-02-04 18:56:49.789741	2013-02-04 18:56:50.074628
165	12	2	32	-1	\N	2	2013-02-01 01:29:40.404507	2013-02-01 01:29:40.567447
166	13	19	32	-1	\N	2	2013-02-01 01:29:40.404507	2013-02-01 01:29:40.571538
225	5	20	15	39	\N	20	2013-02-01 04:37:48.575147	2013-02-01 04:37:48.701876
172	4	19	34	-1	\N	19	2013-02-01 01:51:28.244731	2013-02-01 01:51:28.390865
229	5	20	27	40	\N	20	2013-02-01 04:38:45.330664	2013-02-01 04:38:45.509055
233	6	20	27	41	\N	11	2013-02-01 14:06:39.085218	2013-02-01 14:06:39.093787
178	5	19	34	36	\N	19	2013-02-01 02:03:13.153865	2013-02-01 02:03:13.426764
234	5	11	27	41	\N	11	2013-02-01 14:06:39.027174	2013-02-01 14:06:39.186741
338	4	2	45	-1	\N	2	2013-02-04 19:31:27.10224	2013-02-04 19:31:27.20845
242	6	11	27	42	\N	20	2013-02-01 14:12:42.263558	2013-02-01 14:12:42.270386
243	5	20	27	42	\N	20	2013-02-01 14:12:42.227156	2013-02-01 14:12:42.315519
344	4	2	47	-1	\N	2	2013-02-04 19:34:04.747543	2013-02-04 19:34:04.844774
347	4	23	48	-1	\N	23	2013-02-04 19:38:46.480644	2013-02-04 19:38:46.62717
366	4	7	49	-1	\N	7	2013-02-04 19:51:47.552833	2013-02-04 19:51:47.688937
251	5	20	27	43	\N	20	2013-02-01 14:14:08.52838	2013-02-01 14:14:08.62722
371	6	23	48	73	\N	19	2013-02-04 19:51:59.988748	2013-02-04 19:51:59.995205
372	5	19	48	73	\N	19	2013-02-04 19:51:59.86907	2013-02-04 19:52:00.158993
275	5	7	36	52	\N	7	2013-02-01 18:56:27.376407	2013-02-01 18:56:27.421532
278	1	7	27	28	\N	7	2013-02-01 18:57:00.235727	2013-02-01 18:57:00.257254
279	2	9	27	28	\N	7	2013-02-01 18:57:00.235727	2013-02-01 18:57:00.3055
375	1	23	48	73	\N	23	2013-02-04 19:57:43.066756	2013-02-04 19:57:43.10696
287	5	20	36	54	\N	20	2013-02-04 18:00:51.857089	2013-02-04 18:00:51.990235
289	12	2	37	-1	\N	2	2013-02-04 18:20:42.861615	2013-02-04 18:20:42.99695
290	13	22	37	-1	\N	2	2013-02-04 18:20:42.861615	2013-02-04 18:20:42.999178
376	2	19	48	73	\N	23	2013-02-04 19:57:43.066756	2013-02-04 19:57:43.114578
380	4	7	51	-1	\N	7	2013-02-04 20:00:06.741454	2013-02-04 20:00:06.796256
295	1	22	27	43	\N	22	2013-02-04 18:21:02.611043	2013-02-04 18:21:02.668523
296	2	20	27	43	\N	22	2013-02-04 18:21:02.611043	2013-02-04 18:21:02.673273
385	4	7	52	-1	\N	7	2013-02-04 20:03:21.685801	2013-02-04 20:03:21.781708
312	12	2	40	-1	\N	2	2013-02-04 18:41:40.34959	2013-02-04 18:41:40.567983
313	13	23	40	-1	\N	2	2013-02-04 18:41:40.34959	2013-02-04 18:41:40.572276
326	4	2	41	-1	\N	2	2013-02-04 19:28:30.817381	2013-02-04 19:28:30.872764
329	4	2	42	-1	\N	2	2013-02-04 19:29:11.284011	2013-02-04 19:29:11.370682
332	4	2	43	-1	\N	2	2013-02-04 19:29:52.531052	2013-02-04 19:29:52.597828
335	4	2	44	-1	\N	2	2013-02-04 19:30:35.972724	2013-02-04 19:30:36.030676
341	4	2	46	-1	\N	2	2013-02-04 19:32:14.574417	2013-02-04 19:32:14.595088
351	6	22	39	69	\N	19	2013-02-04 19:40:13.769063	2013-02-04 19:40:13.779449
352	5	19	39	69	\N	19	2013-02-04 19:40:13.635558	2013-02-04 19:40:13.896447
356	5	22	48	70	\N	22	2013-02-04 19:43:40.45135	2013-02-04 19:43:40.608949
360	6	2	15	71	\N	19	2013-02-04 19:44:27.383482	2013-02-04 19:44:27.392723
361	5	19	15	71	\N	19	2013-02-04 19:44:27.276622	2013-02-04 19:44:27.444825
389	4	24	53	-1	\N	24	2013-02-04 22:39:42.946129	2013-02-04 22:39:43.018252
392	5	24	53	78	\N	24	2013-02-04 22:39:55.890904	2013-02-04 22:39:55.908879
\.


--
-- Name: user_actions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('user_actions_id_seq', 397, true);


--
-- Data for Name: user_open_ids; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY user_open_ids (id, user_id, email, url, created_at, updated_at, active) FROM stdin;
\.


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('user_open_ids_id_seq', 2, true);


--
-- Data for Name: user_visits; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY user_visits (id, user_id, visited_at) FROM stdin;
52	24	2013-03-20
\.


--
-- Name: user_visits_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('user_visits_id_seq', 52, true);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY users (id, username, created_at, updated_at, name, bio_raw, seen_notification_id, last_posted_at, email, password_hash, salt, active, username_lower, auth_token, last_seen_at, website, admin, last_emailed_at, email_digests, trust_level, bio_cooked, email_private_messages, email_direct, approved, approved_by_id, approved_at, topics_entered, posts_read_count, digest_after_days, previous_visit_at, banned_at, banned_till, date_of_birth, auto_track_topics_after_msecs, views, flag_level, time_read, days_visited, ip_address, new_topic_duration_minutes, external_links_in_new_tab, enable_quoting, moderator) FROM stdin;
21	OldSchoolDM	2013-02-04 18:10:14.84202	2013-02-04 18:33:20.338235	The Old School DM	I was primarily an AD&D 1st edition DM and campaign designer for over 20 years then "retired" for about 10. I'm now getting back into it because my professional illustrator/daughter and I are building a game-world/campaign and we're building it for 4th edition. I've also developed a bit of a thing for paper terrain for my games	47	\N	oldschooldm@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	oldschooldm		2013-02-04 20:03:24	http://cardboard-warriors.proboards.com/index.cgi?action=userrecentposts&user=oldschooldm	f	2013-02-04 18:10:15.547097	t	1	<p>I was primarily an AD&amp;D 1st edition DM and campaign designer for over 20 years then "retired" for about 10. I'm now getting back into it because my professional illustrator/daughter and I are building a game-world/campaign and we're building it for 4th edition. I've also developed a bit of a thing for paper terrain for my games</p>	t	t	f	\N	\N	2	2	7	\N	\N	\N	\N	60000	0	0	43	1	98.234.248.204	\N	f	t	f
19	gknauss	2013-02-01 01:28:51.197714	2013-02-04 19:47:08.936018	Greg Knauss	HELLO\n=====	47	2013-02-04 19:51:59.86907	gknauss@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	gknauss		2013-02-04 19:54:03	http://---	f	2013-02-04 19:46:59.279009	t	1	<h1>HELLO  </h1>	t	t	f	\N	\N	7	20	7	2013-02-01 05:17:58	\N	\N	\N	60000	0	0	324148	2	67.49.59.30	\N	f	t	f
22	clay_7	2013-02-04 18:20:33.984339	2013-02-04 19:37:00.322684	Clay	\N	47	2013-02-04 19:43:40.45135	clay_7@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	clay_7		2013-02-04 19:43:38	\N	f	2013-02-04 19:36:52.34913	t	1	\N	t	t	f	\N	\N	8	21	7	\N	\N	\N	\N	\N	0	0	4976	1	174.99.106.174	\N	f	t	f
4	marcy	2013-01-24 09:49:19.002165	2013-01-25 00:36:56.361142	Marcy	\N	47	\N	marcy@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	marcy		2013-01-25 00:36:56	\N	f	2013-02-01 06:00:01.288905	t	2	\N	t	t	f	\N	\N	0	2	7	2013-01-24 11:03:41	\N	\N	\N	\N	0	0	40	2	\N	\N	f	t	f
3	NickSahler	2013-01-24 08:55:35.16022	2013-01-25 03:03:02.504085	Nick	\N	47	\N	nicksahler@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	nicksahler		2013-01-25 03:03:02	\N	f	2013-02-01 06:00:01.279965	t	2	\N	t	t	f	\N	\N	1	0	7	2013-01-24 19:35:23	\N	\N	\N	\N	0	0	0	2	\N	\N	f	t	f
12	lowell	2013-01-31 20:38:33.750006	2013-01-31 23:39:41.112804	Lowell	\N	47	2013-01-31 22:11:11.074018	lowell@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	lowell		2013-02-04 18:44:58	\N	f	2013-01-31 20:38:44.603209	t	1	\N	t	t	f	\N	\N	6	11	7	2013-01-31 23:39:41	\N	\N	\N	\N	0	0	338768	2	108.18.225.101	\N	f	t	f
20	Clay	2013-02-01 04:35:15.52826	2013-02-01 18:37:25.374171	Clay	\N	47	2013-02-04 18:00:51.857089	clay@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	clay		2013-02-04 18:00:19	\N	f	2013-02-04 18:26:15.827878	t	1	\N	t	t	f	\N	\N	5	17	7	2013-02-01 18:37:25	\N	\N	\N	\N	0	0	307403	2	174.99.106.174	\N	f	t	f
14	jessamyn	2013-01-31 21:54:31.129088	2013-01-31 22:10:16.172254	JessamynSecond	\N	47	2013-01-31 22:10:16.460181	jessamyn@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	jessamyn		2013-01-31 22:10:16	\N	f	2013-01-31 21:59:40.780718	t	1	\N	t	t	f	\N	\N	1	2	7	\N	\N	\N	\N	\N	0	0	185	1	\N	\N	f	t	f
23	stienman	2013-02-04 18:41:40.094815	2013-02-04 18:41:40.134626	Adam Davis	\N	47	2013-02-04 19:38:46.835615	stienman@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	stienman		2013-02-04 20:03:24	\N	f	\N	t	1	\N	t	t	f	\N	\N	6	10	7	\N	\N	\N	\N	\N	0	0	4585	1	50.77.241.137	\N	f	t	f
7	johnsmith	2013-01-31 19:43:10.344943	2013-02-01 21:06:52.196439	John Smith	\N	47	2013-02-04 20:03:22.058651	johnsmith@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	johnsmith		2013-02-04 20:03:12	\N	f	2013-01-31 19:46:05.421519	t	1	\N	t	t	f	\N	\N	6	17	7	2013-02-01 21:06:52	\N	\N	\N	\N	0	0	346618	3	50.148.146.96	\N	f	t	f
15	sam.saffron	2013-01-31 22:18:59.177595	2013-01-31 22:38:47.947069	Sam Saffron	\N	47	\N	sam.saffron@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	sam.saffron		2013-01-31 22:38:47	\N	t	2013-01-31 22:19:00.662951	t	1	\N	t	t	f	\N	\N	3	8	7	\N	\N	\N	\N	\N	0	0	24100	3	\N	\N	f	t	f
11	pekka.gaiser	2013-01-31 20:25:26.284977	2013-01-31 22:03:43.918788	Pekka	\N	47	2013-02-01 14:06:39.027174	pekka.gaiser@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	pekka.gaiser		2013-02-04 18:20:06	\N	f	2013-02-01 14:13:35.357434	t	1	\N	t	t	f	\N	\N	6	18	7	2013-02-04 10:55:41	\N	\N	\N	\N	0	0	335743	5	141.70.15.48	\N	f	t	f
8	pekka	2013-01-31 20:11:44.021908	2013-01-31 20:11:44.021908	Pekka	\N	47	\N	pekka@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	\N	pekka		\N	\N	f	2013-01-31 20:11:44.752331	t	1	\N	t	t	f	\N	\N	0	0	7	\N	\N	\N	\N	\N	0	0	0	0	\N	\N	f	t	f
10	pekka1980	2013-01-31 20:24:22.27334	2013-01-31 20:24:22.27334	pekka	\N	47	\N	pekka1980@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	\N	pekka1980		\N	\N	f	2013-01-31 20:24:22.414254	t	1	\N	t	t	f	\N	\N	0	0	7	\N	\N	\N	\N	\N	0	0	0	0	\N	\N	f	t	f
13	jessamynyahoo	2013-01-31 21:51:14.543573	2013-01-31 21:51:27.190172	JessamynYahoo	\N	47	\N	jessamynyahoo@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	jessamynyahoo		2013-01-31 21:51:27	\N	f	2013-01-31 21:51:25.424202	t	1	\N	t	t	f	\N	\N	0	0	7	\N	\N	\N	\N	\N	0	0	0	1	\N	\N	f	t	f
5	jatwood	2013-01-29 05:15:31.240082	2013-01-31 19:19:15.999247	Jatwood	\N	47	\N	jatwood@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	jatwood		2013-02-04 22:36:06	\N	f	2013-01-29 05:15:32.64973	t	1	\N	t	t	f	\N	\N	2	2	7	2013-02-04 21:33:50	\N	\N	\N	\N	0	0	40	3	10.0.2.2	\N	f	t	f
9	Gnoggo	2013-01-31 20:15:02.756761	2013-02-01 01:05:21.135975	Gnoggo	\N	47	2013-01-31 21:56:35.884318	gnoggo@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	gnoggo		2013-02-01 01:05:21	\N	f	2013-01-31 20:15:19.686241	t	1	\N	t	t	f	\N	\N	5	8	7	2013-01-31 22:27:32	\N	\N	\N	\N	0	0	17419	2	\N	\N	f	t	f
16	tinkertim	2013-01-31 23:45:17.425938	2013-02-01 00:00:08.746489	Tim Post	\N	47	\N	tinkertim@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	tinkertim		2013-02-01 00:00:08	\N	f	2013-01-31 23:45:28.2474	t	1	\N	t	t	f	\N	\N	2	1	7	\N	\N	\N	\N	\N	0	0	38	2	\N	\N	f	t	f
6	wumpus1	2013-01-29 05:25:59.393086	2013-01-29 05:30:05.365112	Wumpus1	\N	47	\N	wumpus1@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	wumpus1		2013-01-29 05:30:05	\N	f	2013-01-29 05:25:59.675726	t	1	\N	t	t	f	\N	\N	1	1	7	\N	\N	\N	\N	\N	0	0	20	1	\N	\N	f	t	f
2	admin	2013-01-07 21:55:41.905352	2013-02-03 20:37:53.322196	Admin	\N	47	2013-02-04 19:34:05.121327	admin@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	admin		2013-02-04 19:56:03	\N	t	2013-01-07 21:56:05.123178	t	2	\N	t	t	f	\N	\N	7	21	7	2013-02-04 15:42:13	\N	\N	\N	\N	0	0	252250	15	99.255.193.148	\N	f	t	f
24	eviltrout	2013-02-04 21:20:02.922912	2013-02-04 21:24:36.499662	eviltrout	\N	0	2013-02-04 22:39:55.890904	eviltrout@mailinator.com	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	eviltrout		2013-03-20 23:02:11	\N	t	\N	t	1	\N	t	t	f	\N	\N	0	0	7	2013-02-04 22:40:58	\N	\N	\N	\N	0	0	411	1	10.0.2.2	\N	f	t	f
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('users_id_seq', 24, true);


--
-- Data for Name: users_search; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY users_search (id, search_data) FROM stdin;
2	'admin':1,2
3	'nick':2 'nicksahl':1
4	'marci':1,2
5	'jatwood':1,2
6	'wumpus1':1,2
7	'john':2 'johnsmith':1 'smith':3
8	'pekka':1,2
9	'gnoggo':1,2
10	'pekka':2 'pekka1980':1
11	'pekka':2 'pekka.gaiser':1
12	'lowel':1,2
13	'jessamynyahoo':1,2
14	'jessamyn':1 'jessamynsecond':2
15	'saffron':3 'sam':2 'sam.saffron':1
16	'post':3 'tim':2 'tinkertim':1
20	'clay':1,2
21	'dm':5 'old':3 'oldschooldm':1 'school':4
22	'7':2 'clay':1,3
23	'adam':2 'davi':3 'stienman':1
19	'gknauss':1 'greg':2 'knauss':3
24	'eviltourt':1 'eviltrout':2
\.


--
-- Data for Name: versions; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY versions (id, versioned_id, versioned_type, user_id, user_type, user_name, modifications, number, reverted_from, tag, created_at, updated_at) FROM stdin;
3	25	Topic	\N	\N	\N	---\nid:\n- \n- 25\ntitle:\n- \n- Are there people here who use a tablet for ALL their work?\nuser_id:\n- \n- 11\nlast_post_user_id:\n- \n- 11\ncategory_id:\n- \n- 2\nbumped_at:\n- \n- 2013-01-31 21:04:37.419808668 Z\n	2	\N	\N	2013-01-31 21:04:37.487067	2013-01-31 21:04:37.487067
4	25	Topic	\N	\N	\N	---\ntitle:\n- Are there people here who use a tablet for ALL their work?\n- Are there people here who use a mobile device for ALL their work?\n	3	\N	\N	2013-01-31 21:04:51.548955	2013-01-31 21:04:51.548955
5	23	Post	11	User	\N	---\nraw:\n- ! 'I love my iPad, it''s been a faithful companion to me for a long time.\n\n\n  However, its possibilities are limited. I tried to use it as a full-time working\n  tool while traveling and basically, I managed to do everything I needed to - E-Mail,\n  writing some documents, a bit of photography.... but my experience is that no matter\n  how hard I try, it seems never to be a full replacement for my home desktop or laptop,\n  the latest when I have to hand in a term paper. I''ve never really tried to use\n  Pages on iPad for that. Which is a shame, because working on the iPad with an external\n  keyboard is my favourite way of working with a computer **ever!**\n\n\n  I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as **their only working device.** You have to be doing something\n  non-trivial on it: just E-Mailing and browsing the web doesn''t count. Any writers\n  out there who no longer need a "big" machine? Educators who manage all their notes\n  and research on a tablet?'\n- ! 'I love my iPad, it''s been a faithful companion to me for a long time.\n\n\n  However, I often hit a wall because of its limited possibilities. I tried to use\n  it as a full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I''ve never\n  really tried to use Pages on iPad for that because I fear it''s too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my favourite\n  way of working with a computer **ever!**\n\n\n  I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as **their only working device, successfully.** You have\n  to be doing something non-trivial on it: just E-Mailing and browsing the web doesn''t\n  count. Any writers out there who no longer need a "big" machine? Educators who manage\n  all their notes and research on a tablet?'\ncooked:\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, its possibilities are limited. I tried to use it as a full-time working\n  tool while traveling and basically, I managed to do everything I needed to - E-Mail,\n  writing some documents, a bit of photography.... but my experience is that no matter\n  how hard I try, it seems never to be a full replacement for my home desktop or laptop,\n  the latest when I have to hand in a term paper. I''ve never really tried to use\n  Pages on iPad for that. Which is a shame, because working on the iPad with an external\n  keyboard is my favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device.</strong> You have to\n  be doing something non-trivial on it: just E-Mailing and browsing the web doesn''t\n  count. Any writers out there who no longer need a "big" machine? Educators who manage\n  all their notes and research on a tablet?</p>'\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count. Any writers out there who no longer need a "big" machine? Educators\n  who manage all their notes and research on a tablet?</p>'\ncached_version:\n- 1\n- 2\n	2	\N	\N	2013-01-31 21:09:42.103534	2013-01-31 21:09:42.103534
6	23	Post	11	User	\N	---\nraw:\n- ! 'I love my iPad, it''s been a faithful companion to me for a long time.\n\n\n  However, I often hit a wall because of its limited possibilities. I tried to use\n  it as a full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I''ve never\n  really tried to use Pages on iPad for that because I fear it''s too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my favourite\n  way of working with a computer **ever!**\n\n\n  I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as **their only working device, successfully.** You have\n  to be doing something non-trivial on it: just E-Mailing and browsing the web doesn''t\n  count. Any writers out there who no longer need a "big" machine? Educators who manage\n  all their notes and research on a tablet?'\n- ! 'I love my iPad, it''s been a faithful companion to me for a long time.\n\n\n  However, I often hit a wall because of its limited possibilities. I tried to use\n  it as a full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I''ve never\n  really tried to use Pages on iPad for that because I fear it''s too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my favourite\n  way of working with a computer **ever!**\n\n\n  I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as **their only working device, successfully.** You have\n  to be doing something non-trivial on it: just E-Mailing and browsing the web doesn''t\n  count.  Has any of you really managed to get rid of the "big machine"? Any writers\n  who manage drafts, research, and their final work, only on a tablet? Educators who\n  manage all their notes and data on one? Anybody from other professional groups?\n  What apps do you use, what does your working setup look like?'\ncooked:\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count. Any writers out there who no longer need a "big" machine? Educators\n  who manage all their notes and research on a tablet?</p>'\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? What apps do you use, what does your working setup look like?</p>'\ncached_version:\n- 2\n- 3\n	3	\N	\N	2013-01-31 21:11:02.327715	2013-01-31 21:11:02.327715
7	23	Post	11	User	\N	---\nraw:\n- ! 'I love my iPad, it''s been a faithful companion to me for a long time.\n\n\n  However, I often hit a wall because of its limited possibilities. I tried to use\n  it as a full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I''ve never\n  really tried to use Pages on iPad for that because I fear it''s too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my favourite\n  way of working with a computer **ever!**\n\n\n  I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as **their only working device, successfully.** You have\n  to be doing something non-trivial on it: just E-Mailing and browsing the web doesn''t\n  count.  Has any of you really managed to get rid of the "big machine"? Any writers\n  who manage drafts, research, and their final work, only on a tablet? Educators who\n  manage all their notes and data on one? Anybody from other professional groups?\n  What apps do you use, what does your working setup look like?'\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\nHowever,\n  I often hit a wall because of its limited possibilities. I tried to use it as a\n  full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my favourite\n  way of working with a computer **ever!**\\n\\nI'd like to know whether any of you\n  have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely trivial from a tablet, like printing or storing to an external device\n  (in the case of iOS devices)?"\ncooked:\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? What apps do you use, what does your working setup look like?</p>'\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely trivial from a tablet, like printing\n  or storing to an external device (in the case of iOS devices)?</p>'\ncached_version:\n- 3\n- 4\n	4	\N	\N	2013-01-31 21:11:34.418011	2013-01-31 21:11:34.418011
8	23	Post	11	User	\N	---\nraw:\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\nHowever,\n  I often hit a wall because of its limited possibilities. I tried to use it as a\n  full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my favourite\n  way of working with a computer **ever!**\\n\\nI'd like to know whether any of you\n  have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely trivial from a tablet, like printing or storing to an external device\n  (in the case of iOS devices)?"\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\nHowever,\n  I often hit a wall because of its limited possibilities. I tried to use it as a\n  full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely trivial from a tablet, like printing or storing to an external device\n  (in the case of iOS devices)?"\ncooked:\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely trivial from a tablet, like printing\n  or storing to an external device (in the case of iOS devices)?</p>'\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely trivial from a tablet, like printing\n  or storing to an external device (in the case of iOS devices)?</p>'\ncached_version:\n- 4\n- 5\n	5	\N	\N	2013-01-31 21:12:32.925348	2013-01-31 21:12:32.925348
30	49	Topic	\N	\N	\N	---\nid:\n- \n- 49\ntitle:\n- \n- How do I add pictures to a post?\nuser_id:\n- \n- 7\nlast_post_user_id:\n- \n- 7\ncategory_id:\n- \n- 1\nbumped_at:\n- \n- 2013-02-04 19:51:47.552333487 Z\n	2	\N	\N	2013-02-04 19:51:47.619088	2013-02-04 19:51:47.619088
31	50	Topic	\N	\N	\N	---\ntitle:\n- A few qestions about remembering what I've read here\n- A few qestions about remembering what I've read\n	2	\N	\N	2013-02-04 20:00:23.441731	2013-02-04 20:00:23.441731
9	23	Post	11	User	\N	---\nraw:\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\nHowever,\n  I often hit a wall because of its limited possibilities. I tried to use it as a\n  full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely trivial from a tablet, like printing or storing to an external device\n  (in the case of iOS devices)?"\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\nHowever,\n  I often hit a wall because of its limited possibilities. I tried to use it as a\n  full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely self-explanatory when done from a tablet, like printing or storing to\n  an external device (in the case of iOS devices)? Do you keep a big computer somewhere\n  for emergencies? Are there really people out there who create final versions of\n  important documents using the iOS Pages app or similar?"\ncooked:\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely trivial from a tablet, like printing\n  or storing to an external device (in the case of iOS devices)?</p>'\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely self-explanatory when done from\n  a tablet, like printing or storing to an external device (in the case of iOS devices)?\n  Do you keep a big computer somewhere for emergencies? Are there really people out\n  there who create final versions of important documents using the iOS Pages app or\n  similar?</p>'\ncached_version:\n- 5\n- 6\n	6	\N	\N	2013-01-31 21:13:30.417337	2013-01-31 21:13:30.417337
10	25	Topic	\N	\N	\N	---\ntitle:\n- Are there people here who use a mobile device for ALL their work?\n- Do you use a mobile device for ALL your work?\n	4	\N	\N	2013-01-31 21:18:14.07396	2013-01-31 21:18:14.07396
11	25	Topic	\N	\N	\N	---\ntitle:\n- Do you use a mobile device for ALL your work?\n- Do you use a mobile device for ALL your work? Tell me how!\n	5	\N	\N	2013-01-31 21:31:33.066408	2013-01-31 21:31:33.066408
12	24	Post	11	User	\N	---\nraw:\n- ! "I'm a European who had the privilege of travelling California, Nevada, and Arizona\n  for a couple of weeks last fall. It was my first visit to the US. I was travelling\n  by car, hoping to be able to sleep in it (or in a tent next to it) as often as possible\n  to save money. I'm a very quiet, respectful traveler with a \\"leave nothing behind\\"\n  approach so I felt that was okay to do. \\n\\nHowever, that wasn't as easy as I had\n  anticipated. Quite the contrary! I was virtually unable to find any space off the\n  main roads that wasn't closed off, and marked \\"private property.\\" I don't feel\n  comfortable sleeping somewhere I'm not supposed to be (even though the risk of getting\n  caught was probably minimal) so I had to limit my free camping mainly to the desert.\\n\\nThis\n  came as a big surprise to me. Germany is much more densely settled than the US,\n  and much of its uninhabited area is private property, too. However, it's *way* more\n  accessible. You find a huge network of dirt roads everywhere, going through every\n  small forest, taking you far off the main roads. Private property is rarely marked,\n  and rarely impassable (I think it's prohibited to make it so in most cases). Finding\n  a secure place for the night to stay (away from prying eyes, and invisible to the\n  main road) when traveling by car is really, really easy.\\n\\nWhy do you think this\n  is?\\n\\n- Is this a traditional thing, related to the US's cultural appreciation\n  of private property?\\n- Is it a recent thing, to do with liability / a heightened\n  sense of fear from intruders?\\n- Was I just in the wrong places?"\n- ! "I'm a European who had the privilege of travelling California, Nevada, and Arizona\n  for a couple of weeks last fall. It was my first visit to the US. I was travelling\n  by car, hoping to be able to sleep in it (or in a tent next to it) as often as possible\n  to save money. I'm a very quiet, respectful traveler with a \\"leave nothing behind\\"\n  approach so I felt that was okay to do. \\n\\nHowever, that wasn't as easy as I had\n  anticipated! I was virtually unable to find any space off the main roads that wasn't\n  closed off, and marked \\"private property.\\" I don't feel comfortable sleeping somewhere\n  I'm not supposed to be (even though the risk of getting caught was probably minimal)\n  so I had to limit my free camping mainly to the desert.\\n\\nThis came as a big surprise\n  to me. Germany is much more densely settled than the US, and much of its uninhabited\n  area is private property, too. However, it's *way* more accessible. You find a huge\n  network of dirt roads everywhere, going through every small forest, taking you far\n  off the main roads. Private property is rarely marked, and rarely impassable (I\n  think it's generally prohibited to block it off). Finding a secure place to stay\n  for the night while traveling by car is really, really easy.\\n\\nWhy do you think\n  this is?\\n\\n- Is this a traditional, \\"keep off my lawn\\" thing, related to the\n  US's cultural focus on private property?\\n- Is it a recent thing, to do with liability\n  / a heightened sense of fear from intruders / massive problems with vandalism and\n  such?\\n- Was I just in the wrong places?"\ncooked:\n- ! '<p>I''m a European who had the privilege of travelling California, Nevada, and\n  Arizona for a couple of weeks last fall. It was my first visit to the US. I was\n  travelling by car, hoping to be able to sleep in it (or in a tent next to it) as\n  often as possible to save money. I''m a very quiet, respectful traveler with a "leave\n  nothing behind" approach so I felt that was okay to do. </p>\n\n\n  <p>However, that wasn''t as easy as I had anticipated. Quite the contrary! I was\n  virtually unable to find any space off the main roads that wasn''t closed off, and\n  marked "private property." I don''t feel comfortable sleeping somewhere I''m not\n  supposed to be (even though the risk of getting caught was probably minimal) so\n  I had to limit my free camping mainly to the desert.</p>\n\n\n  <p>This came as a big surprise to me. Germany is much more densely settled than\n  the US, and much of its uninhabited area is private property, too. However, it''s\n  <em>way</em> more accessible. You find a huge network of dirt roads everywhere,\n  going through every small forest, taking you far off the main roads. Private property\n  is rarely marked, and rarely impassable (I think it''s prohibited to make it so\n  in most cases). Finding a secure place for the night to stay (away from prying eyes,\n  and invisible to the main road) when traveling by car is really, really easy.</p>\n\n\n  <p>Why do you think this is?</p>\n\n\n  <ul>\n\n  <li>Is this a traditional thing, related to the US''s cultural appreciation of private\n  property?</li>\n\n  <li>Is it a recent thing, to do with liability / a heightened sense of fear from\n  intruders?</li>\n\n  <li>Was I just in the wrong places?</li>\n\n  </ul>'\n- ! '<p>I''m a European who had the privilege of travelling California, Nevada, and\n  Arizona for a couple of weeks last fall. It was my first visit to the US. I was\n  travelling by car, hoping to be able to sleep in it (or in a tent next to it) as\n  often as possible to save money. I''m a very quiet, respectful traveler with a "leave\n  nothing behind" approach so I felt that was okay to do. </p>\n\n\n  <p>However, that wasn''t as easy as I had anticipated! I was virtually unable to\n  find any space off the main roads that wasn''t closed off, and marked "private property."\n  I don''t feel comfortable sleeping somewhere I''m not supposed to be (even though\n  the risk of getting caught was probably minimal) so I had to limit my free camping\n  mainly to the desert.</p>\n\n\n  <p>This came as a big surprise to me. Germany is much more densely settled than\n  the US, and much of its uninhabited area is private property, too. However, it''s\n  <em>way</em> more accessible. You find a huge network of dirt roads everywhere,\n  going through every small forest, taking you far off the main roads. Private property\n  is rarely marked, and rarely impassable (I think it''s generally prohibited to block\n  it off). Finding a secure place to stay for the night while traveling by car is\n  really, really easy.</p>\n\n\n  <p>Why do you think this is?</p>\n\n\n  <ul>\n\n  <li>Is this a traditional, "keep off my lawn" thing, related to the US''s cultural\n  focus on private property?</li>\n\n  <li>Is it a recent thing, to do with liability / a heightened sense of fear from\n  intruders / massive problems with vandalism and such?</li>\n\n  <li>Was I just in the wrong places?</li>\n\n  </ul>'\ncached_version:\n- 1\n- 2\n	2	\N	\N	2013-01-31 21:39:55.766918	2013-01-31 21:39:55.766918
13	24	Post	11	User	\N	---\nraw:\n- ! "I'm a European who had the privilege of travelling California, Nevada, and Arizona\n  for a couple of weeks last fall. It was my first visit to the US. I was travelling\n  by car, hoping to be able to sleep in it (or in a tent next to it) as often as possible\n  to save money. I'm a very quiet, respectful traveler with a \\"leave nothing behind\\"\n  approach so I felt that was okay to do. \\n\\nHowever, that wasn't as easy as I had\n  anticipated! I was virtually unable to find any space off the main roads that wasn't\n  closed off, and marked \\"private property.\\" I don't feel comfortable sleeping somewhere\n  I'm not supposed to be (even though the risk of getting caught was probably minimal)\n  so I had to limit my free camping mainly to the desert.\\n\\nThis came as a big surprise\n  to me. Germany is much more densely settled than the US, and much of its uninhabited\n  area is private property, too. However, it's *way* more accessible. You find a huge\n  network of dirt roads everywhere, going through every small forest, taking you far\n  off the main roads. Private property is rarely marked, and rarely impassable (I\n  think it's generally prohibited to block it off). Finding a secure place to stay\n  for the night while traveling by car is really, really easy.\\n\\nWhy do you think\n  this is?\\n\\n- Is this a traditional, \\"keep off my lawn\\" thing, related to the\n  US's cultural focus on private property?\\n- Is it a recent thing, to do with liability\n  / a heightened sense of fear from intruders / massive problems with vandalism and\n  such?\\n- Was I just in the wrong places?"\n- ! "I'm a European who had the privilege of travelling California, Nevada, and Arizona\n  for a couple of weeks last fall. It was my first visit to the US. I was travelling\n  by car, hoping to be able to sleep in it (or in a tent next to it) as often as possible\n  to save money. I'm a very quiet, respectful traveler with a \\"leave nothing behind\\"\n  approach so I felt that was okay to do. \\n\\nHowever, that wasn't as easy as I had\n  anticipated! I was virtually unable to find any space off the main roads that wasn't\n  closed off, and marked \\"private property.\\" I don't feel comfortable sleeping somewhere\n  I'm not supposed to be (even though the risk of getting caught was probably minimal)\n  so I had to limit my free camping mainly to the desert.\\n\\nThis came as a big surprise\n  to me, I had expected the exact opposite because the country is so vast. Germany\n  is much more densely settled than the US, and much of its uninhabited area is private\n  property, too. However, it's *way* more accessible. You find a huge network of dirt\n  roads everywhere, going through every small forest, taking you far off the main\n  roads. Private property is rarely marked, and rarely impassable (I think it's generally\n  prohibited to block it off). Finding a secure place to stay for the night while\n  traveling by car is really, really easy.\\n\\nWhy do you think this is?\\n\\n- Is this\n  a traditional, \\"keep off my lawn\\" thing, related to the US's cultural focus on\n  private property?\\n- Is it a recent thing, to do with liability / a heightened sense\n  of fear from intruders / massive problems with vandalism and such?\\n- Was I just\n  in the wrong places?"\ncooked:\n- ! '<p>I''m a European who had the privilege of travelling California, Nevada, and\n  Arizona for a couple of weeks last fall. It was my first visit to the US. I was\n  travelling by car, hoping to be able to sleep in it (or in a tent next to it) as\n  often as possible to save money. I''m a very quiet, respectful traveler with a "leave\n  nothing behind" approach so I felt that was okay to do. </p>\n\n\n  <p>However, that wasn''t as easy as I had anticipated! I was virtually unable to\n  find any space off the main roads that wasn''t closed off, and marked "private property."\n  I don''t feel comfortable sleeping somewhere I''m not supposed to be (even though\n  the risk of getting caught was probably minimal) so I had to limit my free camping\n  mainly to the desert.</p>\n\n\n  <p>This came as a big surprise to me. Germany is much more densely settled than\n  the US, and much of its uninhabited area is private property, too. However, it''s\n  <em>way</em> more accessible. You find a huge network of dirt roads everywhere,\n  going through every small forest, taking you far off the main roads. Private property\n  is rarely marked, and rarely impassable (I think it''s generally prohibited to block\n  it off). Finding a secure place to stay for the night while traveling by car is\n  really, really easy.</p>\n\n\n  <p>Why do you think this is?</p>\n\n\n  <ul>\n\n  <li>Is this a traditional, "keep off my lawn" thing, related to the US''s cultural\n  focus on private property?</li>\n\n  <li>Is it a recent thing, to do with liability / a heightened sense of fear from\n  intruders / massive problems with vandalism and such?</li>\n\n  <li>Was I just in the wrong places?</li>\n\n  </ul>'\n- ! '<p>I''m a European who had the privilege of travelling California, Nevada, and\n  Arizona for a couple of weeks last fall. It was my first visit to the US. I was\n  travelling by car, hoping to be able to sleep in it (or in a tent next to it) as\n  often as possible to save money. I''m a very quiet, respectful traveler with a "leave\n  nothing behind" approach so I felt that was okay to do. </p>\n\n\n  <p>However, that wasn''t as easy as I had anticipated! I was virtually unable to\n  find any space off the main roads that wasn''t closed off, and marked "private property."\n  I don''t feel comfortable sleeping somewhere I''m not supposed to be (even though\n  the risk of getting caught was probably minimal) so I had to limit my free camping\n  mainly to the desert.</p>\n\n\n  <p>This came as a big surprise to me, I had expected the exact opposite because\n  the country is so vast. Germany is much more densely settled than the US, and much\n  of its uninhabited area is private property, too. However, it''s <em>way</em> more\n  accessible. You find a huge network of dirt roads everywhere, going through every\n  small forest, taking you far off the main roads. Private property is rarely marked,\n  and rarely impassable (I think it''s generally prohibited to block it off). Finding\n  a secure place to stay for the night while traveling by car is really, really easy.</p>\n\n\n  <p>Why do you think this is?</p>\n\n\n  <ul>\n\n  <li>Is this a traditional, "keep off my lawn" thing, related to the US''s cultural\n  focus on private property?</li>\n\n  <li>Is it a recent thing, to do with liability / a heightened sense of fear from\n  intruders / massive problems with vandalism and such?</li>\n\n  <li>Was I just in the wrong places?</li>\n\n  </ul>'\ncached_version:\n- 2\n- 3\n	3	\N	\N	2013-01-31 21:40:29.300543	2013-01-31 21:40:29.300543
14	27	Topic	\N	\N	\N	---\nid:\n- \n- 27\ntitle:\n- \n- Which Sci-Fi movie is the most important one of the 2000's and why?\nuser_id:\n- \n- 9\nlast_post_user_id:\n- \n- 9\ncategory_id:\n- \n- 4\nbumped_at:\n- \n- 2013-01-31 21:45:17.930836509 Z\n	2	\N	\N	2013-01-31 21:45:17.966544	2013-01-31 21:45:17.966544
15	26	Topic	\N	\N	\N	---\ntitle:\n- Why is uninhabited land in the US (at least in CA) so closed off?\n- Why is uninhabited land in the US so closed off?\n	2	\N	\N	2013-01-31 22:01:10.668955	2013-01-31 22:01:10.668955
16	27	Topic	\N	\N	\N	---\ntitle:\n- Which Sci-Fi movie is the most important one of the 2000's and why?\n- Most important Sci-Fi movie of the 2000's?\n	3	\N	\N	2013-01-31 22:04:33.697882	2013-01-31 22:04:33.697882
17	25	Post	9	User	\N	---\nraw:\n- Which Sci-Fi movie (or series) of the 2000's mattered most to you? Which is the\n  one that you think will come to your mind when asked about it 20, 30, 40 years?\n- Which Sci-Fi movie (or series) of the 2000's mattered most to you? Which is the\n  one that you think will come to your mind when asked about it in 20, 30, 40 years?\ncooked:\n- <p>Which Sci-Fi movie (or series) of the 2000's mattered most to you? Which is the\n  one that you think will come to your mind when asked about it 20, 30, 40 years?</p>\n- <p>Which Sci-Fi movie (or series) of the 2000's mattered most to you? Which is the\n  one that you think will come to your mind when asked about it in 20, 30, 40 years?</p>\ncached_version:\n- 1\n- 2\n	2	\N	\N	2013-01-31 22:04:44.616199	2013-01-31 22:04:44.616199
29	39	Topic	\N	\N	\N	---\nid:\n- \n- 39\ntitle:\n- \n- MAC vs. Mac and the misuse of words\nuser_id:\n- \n- 22\nlast_post_user_id:\n- \n- 22\ncategory_id:\n- \n- 2\nbumped_at:\n- \n- 2013-02-04 18:32:37.482807900 Z\n	2	\N	\N	2013-02-04 18:32:37.530052	2013-02-04 18:32:37.530052
18	23	Post	11	User	\N	---\nraw:\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\nHowever,\n  I often hit a wall because of its limited possibilities. I tried to use it as a\n  full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely self-explanatory when done from a tablet, like printing or storing to\n  an external device (in the case of iOS devices)? Do you keep a big computer somewhere\n  for emergencies? Are there really people out there who create final versions of\n  important documents using the iOS Pages app or similar?"\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\n Here's\n  a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:\\n\\n<img\n  src='/uploads/try2_discourse/6/blob.png' width='400' height='300'>\\n\\nHowever, I\n  often hit a wall because of its limited possibilities. I tried to use it as a full-time\n  working tool while traveling and basically, I managed to do everything I needed\n  to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely self-explanatory when done from a tablet, like printing or storing to\n  an external device (in the case of iOS devices)? Do you keep a big computer somewhere\n  for emergencies? Are there really people out there who create final versions of\n  important documents using the iOS Pages app or similar?"\ncooked:\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely self-explanatory when done from\n  a tablet, like printing or storing to an external device (in the case of iOS devices)?\n  Do you keep a big computer somewhere for emergencies? Are there really people out\n  there who create final versions of important documents using the iOS Pages app or\n  similar?</p>'\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>Here''s a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:</p>\n\n\n  <p><img src="http://cdn2.discourse.org/uploads/try2_discourse/6/blob.png" width="400"\n  height="300"></p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely self-explanatory when done from\n  a tablet, like printing or storing to an external device (in the case of iOS devices)?\n  Do you keep a big computer somewhere for emergencies? Are there really people out\n  there who create final versions of important documents using the iOS Pages app or\n  similar?</p>'\ncached_version:\n- 6\n- 7\n	7	\N	\N	2013-02-01 01:06:36.546961	2013-02-01 01:06:36.546961
19	23	Post	11	User	\N	---\nraw:\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\n Here's\n  a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:\\n\\n<img\n  src='/uploads/try2_discourse/6/blob.png' width='400' height='300'>\\n\\nHowever, I\n  often hit a wall because of its limited possibilities. I tried to use it as a full-time\n  working tool while traveling and basically, I managed to do everything I needed\n  to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely self-explanatory when done from a tablet, like printing or storing to\n  an external device (in the case of iOS devices)? Do you keep a big computer somewhere\n  for emergencies? Are there really people out there who create final versions of\n  important documents using the iOS Pages app or similar?"\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\n Here's\n  a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:\\n\\n<img\n  src='/uploads/try2_discourse/7/blob.png' width='400' height='300'>\\n\\nHowever, I\n  often hit a wall because of its limited possibilities. I tried to use it as a full-time\n  working tool while traveling and basically, I managed to do everything I needed\n  to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely self-explanatory when done from a tablet, like printing or storing to\n  an external device (in the case of iOS devices)? Do you keep a big computer somewhere\n  for emergencies? Are there really people out there who create final versions of\n  important documents using the iOS Pages app or similar?"\ncooked:\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>Here''s a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:</p>\n\n\n  <p><img src="http://cdn2.discourse.org/uploads/try2_discourse/6/blob.png" width="400"\n  height="300"></p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely self-explanatory when done from\n  a tablet, like printing or storing to an external device (in the case of iOS devices)?\n  Do you keep a big computer somewhere for emergencies? Are there really people out\n  there who create final versions of important documents using the iOS Pages app or\n  similar?</p>'\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>Here''s a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:</p>\n\n\n  <p><img src="http://cdn2.discourse.org/uploads/try2_discourse/7/blob.png" width="400"\n  height="300"></p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely self-explanatory when done from\n  a tablet, like printing or storing to an external device (in the case of iOS devices)?\n  Do you keep a big computer somewhere for emergencies? Are there really people out\n  there who create final versions of important documents using the iOS Pages app or\n  similar?</p>'\ncached_version:\n- 7\n- 8\n	8	\N	\N	2013-02-01 01:12:14.399225	2013-02-01 01:12:14.399225
20	23	Post	11	User	\N	---\nraw:\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\n Here's\n  a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:\\n\\n<img\n  src='/uploads/try2_discourse/7/blob.png' width='400' height='300'>\\n\\nHowever, I\n  often hit a wall because of its limited possibilities. I tried to use it as a full-time\n  working tool while traveling and basically, I managed to do everything I needed\n  to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely self-explanatory when done from a tablet, like printing or storing to\n  an external device (in the case of iOS devices)? Do you keep a big computer somewhere\n  for emergencies? Are there really people out there who create final versions of\n  important documents using the iOS Pages app or similar?"\n- ! "I love my iPad, it's been a faithful companion to me for a long time.\\n\\n Here's\n  a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:\\n\\n<img\n  src='http://localhost:4000/uploads/try2_discourse/7/blob.png' width='400' height='300'>\\n\\nHowever,\n  I often hit a wall because of its limited possibilities. I tried to use it as a\n  full-time working tool while traveling and basically, I managed to do everything\n  I needed to - E-Mail, writing some documents, a bit of photography.... but my experience\n  is that no matter how hard I try, it seems never to be a full replacement for my\n  home desktop or laptop, the latest when I have to hand in a term paper. I've never\n  really tried to use Pages on iPad for that because I fear it's too complicated.\n  Which is a shame, because working on the iPad with an external keyboard is my most\n  favourite way of working with a computer **ever!**\\n\\nI'd like to know whether any\n  of you have experience with working with a Tablet (iPad, iPhone or Android or whatever,\n  but not a Slate PC running a desktop OS, it has to be a mobile OS) as **their only\n  working device, successfully.** You have to be doing something non-trivial on it:\n  just E-Mailing and browsing the web doesn't count.  Has any of you really managed\n  to get rid of the \\"big machine\\"? Any writers who manage drafts, research, and\n  their final work, only on a tablet? Educators who manage all their notes and data\n  on one? Anybody from other professional groups? \\n\\nWhat's your secret. What apps\n  do you use, what does your working setup look like? How do you do things that aren't\n  completely self-explanatory when done from a tablet, like printing or storing to\n  an external device (in the case of iOS devices)? Do you keep a big computer somewhere\n  for emergencies? Are there really people out there who create final versions of\n  important documents using the iOS Pages app or similar?"\ncooked:\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>Here''s a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:</p>\n\n\n  <p><img src="http://cdn2.discourse.org/uploads/try2_discourse/7/blob.png" width="400"\n  height="300"></p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely self-explanatory when done from\n  a tablet, like printing or storing to an external device (in the case of iOS devices)?\n  Do you keep a big computer somewhere for emergencies? Are there really people out\n  there who create final versions of important documents using the iOS Pages app or\n  similar?</p>'\n- ! '<p>I love my iPad, it''s been a faithful companion to me for a long time.</p>\n\n\n  <p>Here''s a picture of it at a Starbucks in San Bruno, CA, 5,788 miles from home:</p>\n\n\n  <p><img src="http://localhost:4000/uploads/try2_discourse/7/blob.png" width="400"\n  height="300"></p>\n\n\n  <p>However, I often hit a wall because of its limited possibilities. I tried to\n  use it as a full-time working tool while traveling and basically, I managed to do\n  everything I needed to - E-Mail, writing some documents, a bit of photography....\n  but my experience is that no matter how hard I try, it seems never to be a full\n  replacement for my home desktop or laptop, the latest when I have to hand in a term\n  paper. I''ve never really tried to use Pages on iPad for that because I fear it''s\n  too complicated. Which is a shame, because working on the iPad with an external\n  keyboard is my most favourite way of working with a computer <strong>ever!</strong></p>\n\n\n  <p>I''d like to know whether any of you have experience with working with a Tablet\n  (iPad, iPhone or Android or whatever, but not a Slate PC running a desktop OS, it\n  has to be a mobile OS) as <strong>their only working device, successfully.</strong>\n  You have to be doing something non-trivial on it: just E-Mailing and browsing the\n  web doesn''t count.  Has any of you really managed to get rid of the "big machine"?\n  Any writers who manage drafts, research, and their final work, only on a tablet?\n  Educators who manage all their notes and data on one? Anybody from other professional\n  groups? </p>\n\n\n  <p>What''s your secret. What apps do you use, what does your working setup look\n  like? How do you do things that aren''t completely self-explanatory when done from\n  a tablet, like printing or storing to an external device (in the case of iOS devices)?\n  Do you keep a big computer somewhere for emergencies? Are there really people out\n  there who create final versions of important documents using the iOS Pages app or\n  similar?</p>'\ncached_version:\n- 8\n- 9\n	9	\N	\N	2013-02-01 01:13:15.486068	2013-02-01 01:13:15.486068
21	37	Post	19	User	\N	---\nraw:\n- ! '<style>.test { font-size: 1000px; text-color: red; }</style>\n\n\n  <div class="test">Hello</div>'\n- ! '&lt;style>.test { font-size: 1000px; text-color: red; }</style>\n\n\n  <div class="test">Hello</div>'\ncooked:\n- ! '<p>.test { font-size: 1000px; text-color: red; }</p>\n\n\n  <div class="test">Hello</div>'\n- ! '<p>&lt;style&gt;.test { font-size: 1000px; text-color: red; }</p>\n\n\n  <div class="test">Hello</div>'\ncached_version:\n- 1\n- 2\n	2	\N	\N	2013-02-01 02:14:03.855865	2013-02-01 02:14:03.855865
22	37	Post	19	User	\N	---\nraw:\n- ! '&lt;style>.test { font-size: 1000px; text-color: red; }</style>\n\n\n  <div class="test">Hello</div>'\n- <script>alert(1);</script>\ncooked:\n- ! '<p>&lt;style&gt;.test { font-size: 1000px; text-color: red; }</p>\n\n\n  <div class="test">Hello</div>'\n- alert(1);\ncached_version:\n- 2\n- 3\n	3	\N	\N	2013-02-01 02:14:21.617019	2013-02-01 02:14:21.617019
23	37	Post	19	User	\N	---\nraw:\n- <script>alert(1);</script>\n- <script>document.write("alert(1);");</script>\ncooked:\n- alert(1);\n- document.write("alert(1);");\ncached_version:\n- 3\n- 4\n	4	\N	\N	2013-02-01 02:15:18.729279	2013-02-01 02:15:18.729279
24	37	Post	19	User	\N	---\nraw:\n- <script>document.write("alert(1);");</script>\n- <script>document.write("<script>alert(1);</script>");</script>\ncooked:\n- document.write("alert(1);");\n- document.write("&lt;script&gt;alert(1);");\ncached_version:\n- 4\n- 5\n	5	\N	\N	2013-02-01 02:15:49.807198	2013-02-01 02:15:49.807198
25	37	Post	19	User	\N	---\nraw:\n- <script>document.write("<script>alert(1);</script>");</script>\n- ! '&nbsp;\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  &nbsp;\n\n\n  I am a jackass.'\ncooked:\n- document.write("&lt;script&gt;alert(1);");\n- ! '<p> \n\n   </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p> </p>\n\n\n  <p>I am a jackass.</p>'\ncached_version:\n- 5\n- 6\n	6	\N	\N	2013-02-01 02:16:38.113428	2013-02-01 02:16:38.113428
32	52	Topic	\N	\N	\N	---\nid:\n- \n- 52\ntitle:\n- \n- How do I follow conversations\nuser_id:\n- \n- 7\nlast_post_user_id:\n- \n- 7\ncategory_id:\n- \n- 1\nbumped_at:\n- \n- 2013-02-04 20:03:21.685307786 Z\n	2	\N	\N	2013-02-04 20:03:21.747695	2013-02-04 20:03:21.747695
33	77	Post	24	User	\N	---\nraw:\n- |-\n  If you can see this, you've successfully set up a vagrant environment for discourse.\n\n  If you're looking for an account to test out, you can create one or log in as one of the following with the password: `password`.\n\n  - eviltrout **an admin**\n  - tinkertim **regular user**\n  - jatwood **regular user**\n\n  For the latest info, please check the README.md in the project. Thanks for checking out Discourse!\n- |\n  If you can see this, you've successfully set up a vagrant environment for discourse. By default this install includes a few topics and accounts to play around with.\n\n  If you're looking for an account to test out, you can create one or log in as one of the following with the password: `password`.\n\n  - eviltrout **an admin**\n  - jatwood **regular user**\n\n  For the latest info, please check the [README.md](https://github.com/discourse/discourse/blob/master/README.md) in the project. Thanks for checking out Discourse!\n\n  ---\n\n  ### Production Images\n\n  If you want to get started without the test topics, this install also includes a base production database image. To install it execute the following commands:\n\n  ```bash\n  vagrant ssh\n  cd /vagrant\n  psql discourse_development < pg_dumps/production-image.sql\n  ```\n\n  If you change your mind and want to use the test data again, just execute the above but using `pg_dumps/development-image.sql` instead.\ncooked:\n- |-\n  <p>If you can see this, you've successfully set up a vagrant environment for discourse.</p>\n\n  <p>If you're looking for an account to test out, you can create one or log in as one of the following with the password: <code>password</code>.</p>\n\n  <ul>\n  <li>eviltrout <strong>an admin</strong>\n  </li>\n  <li>tinkertim <strong>regular user</strong>\n  </li>\n  <li>jatwood <strong>regular user</strong>\n  </li>\n  </ul><p>For the latest info, please check the README.md in the project. Thanks for checking out Discourse!</p>\n- "<p>If you can see this, you've successfully set up a vagrant environment for discourse.\n  By default this install includes a few topics and accounts to play around with.</p>\\n\\n<p>If\n  you're looking for an account to test out, you can create one or log in as one of\n  the following with the password: <code>password</code>.</p>\\n\\n<ul>\\n<li>eviltrout\n  <strong>an admin</strong>\\n</li>\\n<li>jatwood <strong>regular user</strong>\\n</li>\\n</ul><p>For\n  the latest info, please check the <a href=\\"https://github.com/discourse/discourse/blob/master/README.md\\"\n  rel=\\"nofollow\\">README.md</a> in the project. Thanks for checking out Discourse!</p>\\n\\n<hr><h3>Production\n  Images</h3>\\n\\n<p>If you want to get started without the test topics, this install\n  also includes a base production database image. To install it execute the following\n  commands:</p>\\n\\n<pre><code class=\\"bash\\">vagrant ssh  \\ncd /vagrant  \\npsql discourse_development\n  &lt; pg_dumps/production-image.sql  \\n</code></pre>\\n\\n<p>If you change your mind\n  and want to use the test data again, just execute the above but using <code>pg_dumps/development-image.sql</code>\n  instead.  </p>"\ncached_version:\n- 1\n- 2\nlast_version_at:\n- 2013-02-04 22:39:43.232568000 Z\n- 2013-03-20 22:58:35.140445191 Z\n	2	\N	\N	2013-03-20 22:58:35.268019	2013-03-20 22:58:35.268019
\.


--
-- Name: versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('versions_id_seq', 33, true);


--
-- Data for Name: views; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY views (parent_id, parent_type, ip, viewed_at, user_id) FROM stdin;
53	Topic	167772674	2013-03-19	\N
53	Topic	167772674	2013-03-20	\N
53	Topic	167772674	2013-03-20	24
53	Topic	167772674	2013-03-20	\N
53	Topic	167772674	2013-03-20	24
53	Topic	167772674	2013-03-20	24
47	Topic	167772674	2013-03-20	24
46	Topic	167772674	2013-03-20	24
45	Topic	167772674	2013-03-20	24
44	Topic	167772674	2013-03-20	24
43	Topic	167772674	2013-03-20	24
42	Topic	167772674	2013-03-20	24
41	Topic	167772674	2013-03-20	24
13	Topic	167772674	2013-03-20	24
12	Topic	167772674	2013-03-20	24
11	Topic	167772674	2013-03-20	24
10	Topic	167772674	2013-03-20	24
\.


SET search_path = backup, pg_catalog;

--
-- Name: actions_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY user_actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);


--
-- Name: categories_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category_featured_users_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY category_featured_users
    ADD CONSTRAINT category_featured_users_pkey PRIMARY KEY (id);


--
-- Name: draft_sequences_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY draft_sequences
    ADD CONSTRAINT draft_sequences_pkey PRIMARY KEY (id);


--
-- Name: drafts_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY drafts
    ADD CONSTRAINT drafts_pkey PRIMARY KEY (id);


--
-- Name: email_logs_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY email_logs
    ADD CONSTRAINT email_logs_pkey PRIMARY KEY (id);


--
-- Name: email_tokens_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY email_tokens
    ADD CONSTRAINT email_tokens_pkey PRIMARY KEY (id);


--
-- Name: facebook_user_infos_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY facebook_user_infos
    ADD CONSTRAINT facebook_user_infos_pkey PRIMARY KEY (id);


--
-- Name: forum_thread_link_clicks_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topic_link_clicks
    ADD CONSTRAINT forum_thread_link_clicks_pkey PRIMARY KEY (id);


--
-- Name: forum_thread_links_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topic_links
    ADD CONSTRAINT forum_thread_links_pkey PRIMARY KEY (id);


--
-- Name: forum_threads_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topics
    ADD CONSTRAINT forum_threads_pkey PRIMARY KEY (id);


--
-- Name: incoming_links_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY incoming_links
    ADD CONSTRAINT incoming_links_pkey PRIMARY KEY (id);


--
-- Name: invites_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


--
-- Name: notifications_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: onebox_renders_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY onebox_renders
    ADD CONSTRAINT onebox_renders_pkey PRIMARY KEY (id);


--
-- Name: post_action_types_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY post_action_types
    ADD CONSTRAINT post_action_types_pkey PRIMARY KEY (id);


--
-- Name: post_actions_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY post_actions
    ADD CONSTRAINT post_actions_pkey PRIMARY KEY (id);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: site_customizations_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY site_customizations
    ADD CONSTRAINT site_customizations_pkey PRIMARY KEY (id);


--
-- Name: site_settings_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (id);


--
-- Name: topic_allowed_users_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topic_allowed_users
    ADD CONSTRAINT topic_allowed_users_pkey PRIMARY KEY (id);


--
-- Name: topic_invites_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topic_invites
    ADD CONSTRAINT topic_invites_pkey PRIMARY KEY (id);


--
-- Name: trust_levels_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY trust_levels
    ADD CONSTRAINT trust_levels_pkey PRIMARY KEY (id);


--
-- Name: twitter_user_infos_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY twitter_user_infos
    ADD CONSTRAINT twitter_user_infos_pkey PRIMARY KEY (id);


--
-- Name: uploads_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY uploads
    ADD CONSTRAINT uploads_pkey PRIMARY KEY (id);


--
-- Name: user_open_ids_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY user_open_ids
    ADD CONSTRAINT user_open_ids_pkey PRIMARY KEY (id);


--
-- Name: user_visits_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY user_visits
    ADD CONSTRAINT user_visits_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: versions_pkey; Type: CONSTRAINT; Schema: backup; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: actions_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY user_actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);


--
-- Name: categories_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories_search_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY categories_search
    ADD CONSTRAINT categories_search_pkey PRIMARY KEY (id);


--
-- Name: category_featured_users_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY category_featured_users
    ADD CONSTRAINT category_featured_users_pkey PRIMARY KEY (id);


--
-- Name: draft_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY draft_sequences
    ADD CONSTRAINT draft_sequences_pkey PRIMARY KEY (id);


--
-- Name: drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY drafts
    ADD CONSTRAINT drafts_pkey PRIMARY KEY (id);


--
-- Name: email_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY email_logs
    ADD CONSTRAINT email_logs_pkey PRIMARY KEY (id);


--
-- Name: email_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY email_tokens
    ADD CONSTRAINT email_tokens_pkey PRIMARY KEY (id);


--
-- Name: facebook_user_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY facebook_user_infos
    ADD CONSTRAINT facebook_user_infos_pkey PRIMARY KEY (id);


--
-- Name: forum_thread_link_clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topic_link_clicks
    ADD CONSTRAINT forum_thread_link_clicks_pkey PRIMARY KEY (id);


--
-- Name: forum_thread_links_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topic_links
    ADD CONSTRAINT forum_thread_links_pkey PRIMARY KEY (id);


--
-- Name: forum_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topics
    ADD CONSTRAINT forum_threads_pkey PRIMARY KEY (id);


--
-- Name: github_user_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY github_user_infos
    ADD CONSTRAINT github_user_infos_pkey PRIMARY KEY (id);


--
-- Name: incoming_links_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY incoming_links
    ADD CONSTRAINT incoming_links_pkey PRIMARY KEY (id);


--
-- Name: invites_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


--
-- Name: message_bus_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY message_bus
    ADD CONSTRAINT message_bus_pkey PRIMARY KEY (id);


--
-- Name: notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: onebox_renders_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY onebox_renders
    ADD CONSTRAINT onebox_renders_pkey PRIMARY KEY (id);


--
-- Name: post_action_types_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY post_action_types
    ADD CONSTRAINT post_action_types_pkey PRIMARY KEY (id);


--
-- Name: post_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY post_actions
    ADD CONSTRAINT post_actions_pkey PRIMARY KEY (id);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: posts_search_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY posts_search
    ADD CONSTRAINT posts_search_pkey PRIMARY KEY (id);


--
-- Name: site_customizations_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY site_customizations
    ADD CONSTRAINT site_customizations_pkey PRIMARY KEY (id);


--
-- Name: site_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (id);


--
-- Name: topic_allowed_users_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topic_allowed_users
    ADD CONSTRAINT topic_allowed_users_pkey PRIMARY KEY (id);


--
-- Name: topic_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY topic_invites
    ADD CONSTRAINT topic_invites_pkey PRIMARY KEY (id);


--
-- Name: twitter_user_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY twitter_user_infos
    ADD CONSTRAINT twitter_user_infos_pkey PRIMARY KEY (id);


--
-- Name: uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY uploads
    ADD CONSTRAINT uploads_pkey PRIMARY KEY (id);


--
-- Name: user_open_ids_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY user_open_ids
    ADD CONSTRAINT user_open_ids_pkey PRIMARY KEY (id);


--
-- Name: user_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY user_visits
    ADD CONSTRAINT user_visits_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_search_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY users_search
    ADD CONSTRAINT users_search_pkey PRIMARY KEY (id);


--
-- Name: versions_pkey; Type: CONSTRAINT; Schema: public; Owner: vagrant; Tablespace: 
--

ALTER TABLE ONLY versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


SET search_path = backup, pg_catalog;

--
-- Name: cat_featured_threads; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX cat_featured_threads ON category_featured_topics USING btree (category_id, topic_id);


--
-- Name: idx_search_thread; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX idx_search_thread ON topics USING gin (to_tsvector('english'::regconfig, (title)::text));


--
-- Name: idx_search_user; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX idx_search_user ON users USING gin (to_tsvector('english'::regconfig, (username)::text));


--
-- Name: idx_unique_actions; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_actions ON post_actions USING btree (user_id, post_action_type_id, post_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_unique_rows; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_rows ON user_actions USING btree (action_type, user_id, target_topic_id, target_post_id, acting_user_id);


--
-- Name: incoming_index; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX incoming_index ON incoming_links USING btree (topic_id, post_number);


--
-- Name: index_actions_on_acting_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_actions_on_acting_user_id ON user_actions USING btree (acting_user_id);


--
-- Name: index_actions_on_user_id_and_action_type; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_actions_on_user_id_and_action_type ON user_actions USING btree (user_id, action_type);


--
-- Name: index_categories_on_forum_thread_count; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_categories_on_forum_thread_count ON categories USING btree (topic_count);


--
-- Name: index_categories_on_name; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_categories_on_name ON categories USING btree (name);


--
-- Name: index_category_featured_users_on_category_id_and_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_category_featured_users_on_category_id_and_user_id ON category_featured_users USING btree (category_id, user_id);


--
-- Name: index_draft_sequences_on_user_id_and_draft_key; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_draft_sequences_on_user_id_and_draft_key ON draft_sequences USING btree (user_id, draft_key);


--
-- Name: index_drafts_on_user_id_and_draft_key; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_drafts_on_user_id_and_draft_key ON drafts USING btree (user_id, draft_key);


--
-- Name: index_email_logs_on_created_at; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_email_logs_on_created_at ON email_logs USING btree (created_at DESC);


--
-- Name: index_email_logs_on_user_id_and_created_at; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_email_logs_on_user_id_and_created_at ON email_logs USING btree (user_id, created_at DESC);


--
-- Name: index_email_tokens_on_token; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_email_tokens_on_token ON email_tokens USING btree (token);


--
-- Name: index_facebook_user_infos_on_facebook_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_user_infos_on_facebook_user_id ON facebook_user_infos USING btree (facebook_user_id);


--
-- Name: index_facebook_user_infos_on_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_user_infos_on_user_id ON facebook_user_infos USING btree (user_id);


--
-- Name: index_forum_thread_link_clicks_on_forum_thread_link_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_forum_thread_link_clicks_on_forum_thread_link_id ON topic_link_clicks USING btree (topic_link_id);


--
-- Name: index_forum_thread_links_on_forum_thread_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_forum_thread_links_on_forum_thread_id ON topic_links USING btree (topic_id);


--
-- Name: index_forum_thread_links_on_forum_thread_id_and_post_id_and_url; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_forum_thread_links_on_forum_thread_id_and_post_id_and_url ON topic_links USING btree (topic_id, post_id, url);


--
-- Name: index_forum_thread_users_on_forum_thread_id_and_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_forum_thread_users_on_forum_thread_id_and_user_id ON topic_users USING btree (topic_id, user_id);


--
-- Name: index_forum_threads_on_bumped_at; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_forum_threads_on_bumped_at ON topics USING btree (bumped_at DESC);


--
-- Name: index_forum_threads_on_category_id_and_sub_tag_and_bumped_at; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_forum_threads_on_category_id_and_sub_tag_and_bumped_at ON topics USING btree (category_id, sub_tag, bumped_at);


--
-- Name: index_invites_on_email_and_invited_by_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_invites_on_email_and_invited_by_id ON invites USING btree (email, invited_by_id);


--
-- Name: index_invites_on_invite_key; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_invites_on_invite_key ON invites USING btree (invite_key);


--
-- Name: index_notifications_on_post_action_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_notifications_on_post_action_id ON notifications USING btree (post_action_id);


--
-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_notifications_on_user_id_and_created_at ON notifications USING btree (user_id, created_at);


--
-- Name: index_onebox_renders_on_url; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_onebox_renders_on_url ON onebox_renders USING btree (url);


--
-- Name: index_post_actions_on_post_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_post_actions_on_post_id ON post_actions USING btree (post_id);


--
-- Name: index_post_onebox_renders_on_post_id_and_onebox_render_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_post_onebox_renders_on_post_id_and_onebox_render_id ON post_onebox_renders USING btree (post_id, onebox_render_id);


--
-- Name: index_post_replies_on_post_id_and_reply_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_post_replies_on_post_id_and_reply_id ON post_replies USING btree (post_id, reply_id);


--
-- Name: index_posts_on_reply_to_post_number; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_posts_on_reply_to_post_number ON posts USING btree (reply_to_post_number);


--
-- Name: index_posts_on_topic_id_and_post_number; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_posts_on_topic_id_and_post_number ON posts USING btree (topic_id, post_number);


--
-- Name: index_site_customizations_on_key; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_site_customizations_on_key ON site_customizations USING btree (key);


--
-- Name: index_topic_allowed_users_on_topic_id_and_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_topic_id_and_user_id ON topic_allowed_users USING btree (topic_id, user_id);


--
-- Name: index_topic_allowed_users_on_user_id_and_topic_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_user_id_and_topic_id ON topic_allowed_users USING btree (user_id, topic_id);


--
-- Name: index_topic_invites_on_invite_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_topic_invites_on_invite_id ON topic_invites USING btree (invite_id);


--
-- Name: index_topic_invites_on_topic_id_and_invite_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_invites_on_topic_id_and_invite_id ON topic_invites USING btree (topic_id, invite_id);


--
-- Name: index_twitter_user_infos_on_twitter_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_twitter_user_infos_on_twitter_user_id ON twitter_user_infos USING btree (twitter_user_id);


--
-- Name: index_twitter_user_infos_on_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_twitter_user_infos_on_user_id ON twitter_user_infos USING btree (user_id);


--
-- Name: index_uploads_on_forum_thread_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_uploads_on_forum_thread_id ON uploads USING btree (topic_id);


--
-- Name: index_uploads_on_user_id; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_uploads_on_user_id ON uploads USING btree (user_id);


--
-- Name: index_user_open_ids_on_url; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_user_open_ids_on_url ON user_open_ids USING btree (url);


--
-- Name: index_user_visits_on_user_id_and_visited_at; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_user_visits_on_user_id_and_visited_at ON user_visits USING btree (user_id, visited_at);


--
-- Name: index_users_on_auth_token; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_users_on_auth_token ON users USING btree (auth_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_last_posted_at; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_users_on_last_posted_at ON users USING btree (last_posted_at);


--
-- Name: index_users_on_username; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username ON users USING btree (username);


--
-- Name: index_users_on_username_lower; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username_lower ON users USING btree (username_lower);


--
-- Name: index_versions_on_created_at; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_created_at ON versions USING btree (created_at);


--
-- Name: index_versions_on_number; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_number ON versions USING btree (number);


--
-- Name: index_versions_on_tag; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_tag ON versions USING btree (tag);


--
-- Name: index_versions_on_user_id_and_user_type; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_user_id_and_user_type ON versions USING btree (user_id, user_type);


--
-- Name: index_versions_on_user_name; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_user_name ON versions USING btree (user_name);


--
-- Name: index_versions_on_versioned_id_and_versioned_type; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_versioned_id_and_versioned_type ON versions USING btree (versioned_id, versioned_type);


--
-- Name: index_views_on_parent_id_and_parent_type; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_views_on_parent_id_and_parent_type ON views USING btree (parent_id, parent_type);


--
-- Name: post_timings_summary; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE INDEX post_timings_summary ON post_timings USING btree (topic_id, post_number);


--
-- Name: post_timings_unique; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX post_timings_unique ON post_timings USING btree (topic_id, post_number, user_id);


--
-- Name: unique_views; Type: INDEX; Schema: backup; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX unique_views ON views USING btree (parent_id, parent_type, ip, viewed_at);


SET search_path = public, pg_catalog;

--
-- Name: cat_featured_threads; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX cat_featured_threads ON category_featured_topics USING btree (category_id, topic_id);


--
-- Name: idx_posts_user_id_deleted_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX idx_posts_user_id_deleted_at ON posts USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_search_category; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX idx_search_category ON categories_search USING gin (search_data);


--
-- Name: idx_search_post; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX idx_search_post ON posts_search USING gin (search_data);


--
-- Name: idx_search_user; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX idx_search_user ON users_search USING gin (search_data);


--
-- Name: idx_topics_user_id_deleted_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX idx_topics_user_id_deleted_at ON topics USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_unique_actions; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_actions ON post_actions USING btree (user_id, post_action_type_id, post_id, deleted_at);


--
-- Name: idx_unique_rows; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_rows ON user_actions USING btree (action_type, user_id, target_topic_id, target_post_id, acting_user_id);


--
-- Name: incoming_index; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX incoming_index ON incoming_links USING btree (topic_id, post_number);


--
-- Name: index_actions_on_acting_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_actions_on_acting_user_id ON user_actions USING btree (acting_user_id);


--
-- Name: index_actions_on_user_id_and_action_type; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_actions_on_user_id_and_action_type ON user_actions USING btree (user_id, action_type);


--
-- Name: index_categories_on_forum_thread_count; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_categories_on_forum_thread_count ON categories USING btree (topic_count);


--
-- Name: index_categories_on_name; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_categories_on_name ON categories USING btree (name);


--
-- Name: index_category_featured_users_on_category_id_and_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_category_featured_users_on_category_id_and_user_id ON category_featured_users USING btree (category_id, user_id);


--
-- Name: index_draft_sequences_on_user_id_and_draft_key; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_draft_sequences_on_user_id_and_draft_key ON draft_sequences USING btree (user_id, draft_key);


--
-- Name: index_drafts_on_user_id_and_draft_key; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_drafts_on_user_id_and_draft_key ON drafts USING btree (user_id, draft_key);


--
-- Name: index_email_logs_on_created_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_email_logs_on_created_at ON email_logs USING btree (created_at DESC);


--
-- Name: index_email_logs_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_email_logs_on_user_id_and_created_at ON email_logs USING btree (user_id, created_at DESC);


--
-- Name: index_email_tokens_on_token; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_email_tokens_on_token ON email_tokens USING btree (token);


--
-- Name: index_facebook_user_infos_on_facebook_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_user_infos_on_facebook_user_id ON facebook_user_infos USING btree (facebook_user_id);


--
-- Name: index_facebook_user_infos_on_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_user_infos_on_user_id ON facebook_user_infos USING btree (user_id);


--
-- Name: index_forum_thread_link_clicks_on_forum_thread_link_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_forum_thread_link_clicks_on_forum_thread_link_id ON topic_link_clicks USING btree (topic_link_id);


--
-- Name: index_forum_thread_links_on_forum_thread_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_forum_thread_links_on_forum_thread_id ON topic_links USING btree (topic_id);


--
-- Name: index_forum_thread_links_on_forum_thread_id_and_post_id_and_url; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_forum_thread_links_on_forum_thread_id_and_post_id_and_url ON topic_links USING btree (topic_id, post_id, url);


--
-- Name: index_forum_thread_users_on_forum_thread_id_and_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_forum_thread_users_on_forum_thread_id_and_user_id ON topic_users USING btree (topic_id, user_id);


--
-- Name: index_forum_threads_on_bumped_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_forum_threads_on_bumped_at ON topics USING btree (bumped_at DESC);


--
-- Name: index_github_user_infos_on_github_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_github_user_infos_on_github_user_id ON github_user_infos USING btree (github_user_id);


--
-- Name: index_github_user_infos_on_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_github_user_infos_on_user_id ON github_user_infos USING btree (user_id);


--
-- Name: index_invites_on_email_and_invited_by_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_invites_on_email_and_invited_by_id ON invites USING btree (email, invited_by_id);


--
-- Name: index_invites_on_invite_key; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_invites_on_invite_key ON invites USING btree (invite_key);


--
-- Name: index_message_bus_on_created_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_message_bus_on_created_at ON message_bus USING btree (created_at);


--
-- Name: index_notifications_on_post_action_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_notifications_on_post_action_id ON notifications USING btree (post_action_id);


--
-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_notifications_on_user_id_and_created_at ON notifications USING btree (user_id, created_at);


--
-- Name: index_onebox_renders_on_url; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_onebox_renders_on_url ON onebox_renders USING btree (url);


--
-- Name: index_post_actions_on_post_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_post_actions_on_post_id ON post_actions USING btree (post_id);


--
-- Name: index_post_onebox_renders_on_post_id_and_onebox_render_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_post_onebox_renders_on_post_id_and_onebox_render_id ON post_onebox_renders USING btree (post_id, onebox_render_id);


--
-- Name: index_post_replies_on_post_id_and_reply_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_post_replies_on_post_id_and_reply_id ON post_replies USING btree (post_id, reply_id);


--
-- Name: index_posts_on_reply_to_post_number; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_posts_on_reply_to_post_number ON posts USING btree (reply_to_post_number);


--
-- Name: index_posts_on_topic_id_and_post_number; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_posts_on_topic_id_and_post_number ON posts USING btree (topic_id, post_number);


--
-- Name: index_site_customizations_on_key; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_site_customizations_on_key ON site_customizations USING btree (key);


--
-- Name: index_topic_allowed_users_on_topic_id_and_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_topic_id_and_user_id ON topic_allowed_users USING btree (topic_id, user_id);


--
-- Name: index_topic_allowed_users_on_user_id_and_topic_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_user_id_and_topic_id ON topic_allowed_users USING btree (user_id, topic_id);


--
-- Name: index_topic_invites_on_invite_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_topic_invites_on_invite_id ON topic_invites USING btree (invite_id);


--
-- Name: index_topic_invites_on_topic_id_and_invite_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_invites_on_topic_id_and_invite_id ON topic_invites USING btree (topic_id, invite_id);


--
-- Name: index_twitter_user_infos_on_twitter_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_twitter_user_infos_on_twitter_user_id ON twitter_user_infos USING btree (twitter_user_id);


--
-- Name: index_twitter_user_infos_on_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_twitter_user_infos_on_user_id ON twitter_user_infos USING btree (user_id);


--
-- Name: index_uploads_on_forum_thread_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_uploads_on_forum_thread_id ON uploads USING btree (topic_id);


--
-- Name: index_uploads_on_user_id; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_uploads_on_user_id ON uploads USING btree (user_id);


--
-- Name: index_user_open_ids_on_url; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_user_open_ids_on_url ON user_open_ids USING btree (url);


--
-- Name: index_user_visits_on_user_id_and_visited_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_user_visits_on_user_id_and_visited_at ON user_visits USING btree (user_id, visited_at);


--
-- Name: index_users_on_auth_token; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_users_on_auth_token ON users USING btree (auth_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_last_posted_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_users_on_last_posted_at ON users USING btree (last_posted_at);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username ON users USING btree (username);


--
-- Name: index_users_on_username_lower; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username_lower ON users USING btree (username_lower);


--
-- Name: index_versions_on_created_at; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_created_at ON versions USING btree (created_at);


--
-- Name: index_versions_on_number; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_number ON versions USING btree (number);


--
-- Name: index_versions_on_tag; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_tag ON versions USING btree (tag);


--
-- Name: index_versions_on_user_id_and_user_type; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_user_id_and_user_type ON versions USING btree (user_id, user_type);


--
-- Name: index_versions_on_user_name; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_user_name ON versions USING btree (user_name);


--
-- Name: index_versions_on_versioned_id_and_versioned_type; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_versions_on_versioned_id_and_versioned_type ON versions USING btree (versioned_id, versioned_type);


--
-- Name: index_views_on_parent_id_and_parent_type; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX index_views_on_parent_id_and_parent_type ON views USING btree (parent_id, parent_type);


--
-- Name: post_timings_summary; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE INDEX post_timings_summary ON post_timings USING btree (topic_id, post_number);


--
-- Name: post_timings_unique; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX post_timings_unique ON post_timings USING btree (topic_id, post_number, user_id);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: vagrant; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- PostgreSQL database dump complete
--

