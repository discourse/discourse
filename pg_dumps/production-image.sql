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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
    START WITH 1
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
1	meta	B3B5B4	2	1	2013-03-20 22:45:57.07128	2013-03-21 02:18:59.22942	1	\N	\N	\N	meta	Use the 'meta' category to discuss this forum -- things like deciding what sort of topics and replies are appropriate here, what the standards for posts and behavior are, and how we should moderate our community.	FFFFFF
\.


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('categories_id_seq', 1, true);


--
-- Data for Name: categories_search; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY categories_search (id, search_data) FROM stdin;
1	'meta':1
\.


--
-- Data for Name: category_featured_topics; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY category_featured_topics (category_id, topic_id, created_at, updated_at) FROM stdin;
1	3	2013-03-20 22:48:20.791651	2013-03-20 22:48:20.791651
1	2	2013-03-20 22:48:20.791651	2013-03-20 22:48:20.791651
\.


--
-- Data for Name: category_featured_users; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY category_featured_users (id, category_id, user_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: category_featured_users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('category_featured_users_id_seq', 1, false);


--
-- Data for Name: draft_sequences; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY draft_sequences (id, user_id, draft_key, sequence) FROM stdin;
2	1	topic_1	1
3	1	topic_2	1
1	1	new_topic	3
4	1	topic_3	1
\.


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('draft_sequences_id_seq', 4, true);


--
-- Data for Name: drafts; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY drafts (id, user_id, draft_key, data, created_at, updated_at, sequence) FROM stdin;
1	1	new_topic	{"reply":"### What is \\"Meta\\"?\\n\\nMeta means discussion *of the discussion itself* instead of the actual topic of the discussion. For example, discussions about...\\n\\n- The style of discussion.\\n- The participants in the discussion.\\n- The setting in which the discussion occurs.\\n- The relationship of the discussion to other discussions.\\n\\nThe etymology for the “meta-” prefix dates back to [Aristotle’s Metaphysics][1], which came after his works on physics. Meta means “after” in Greek. \\n\\n### Why do we need a meta category?\\n\\nMeta is incredibly important. It is where communities come together to decide who they are and what they are *about*. It is where communities form their core identity and mission statement.\\n\\nMeta is for the folks who enjoy the forum so much that they want to go beyond merely reading and posting -- they want to work together to improve their community in various ways. Meta is the place where all leadership and governance forms within a community, a way to debate and decide direction for the whole community.\\n\\nMeta serves as *community memory*, documenting the history of the community and its culture. There's a story behind every evolution in rules or tone; these shared stories are what bind communities together. Meta also provides a home for all the tiny unique things that make your community what it is: its terminology, its acronyms, its slang.\\n\\n### What kinds of meta topics can I post?\\n\\nSome examples of meta topics:\\n\\n- What sort of topics should we allow and encourage? Which kinds should we explicitly discourage?\\n\\n- What kinds of replies are we looking for? What makes a good reply, and what makes a reply out of bounds or off-topic?\\n\\n- What are our standards for community behavior, beyond what is [defined in the FAQ][2]?\\n\\n- How can we encourage new members of our community and welcome them?\\n\\n- Are we setting a good example for the kinds of discussions we want in our community?\\n\\n- What problems and challenges does our community face, and how can they be resolved?\\n\\n- How should we moderate our community, and who should the moderators be? What should our flag reasons be?\\n\\n- How do we publicize and grow our community?\\n\\n- What does does TLA mean? Who was Kilroy and why does everyone drop his name when they make a typo?\\n\\n- How should (or why did) the rules change?\\n\\nBut really, anything is fair game in the meta category, provided it's a discussion about the community or the forum in some way.\\n\\n[1]: http://en.wikipedia.org/wiki/Metaphysics_(Aristotle)\\n[2]: /faq","action":"createTopic","title":"What is \\"Meta\\"?","categoryName":"meta","archetypeId":"regular","metaData":null}	2013-03-20 22:45:32.790045	2013-03-20 22:48:15.673152	2
\.


--
-- Name: drafts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('drafts_id_seq', 1, true);


--
-- Data for Name: email_logs; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY email_logs (id, to_address, email_type, user_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: email_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('email_logs_id_seq', 1, false);


--
-- Data for Name: email_tokens; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY email_tokens (id, user_id, email, token, confirmed, expired, created_at, updated_at) FROM stdin;
1	1	team@discourse.org	8cbf517b7c21c1b587a3778f0feae5ae	t	f	2013-03-20 22:43:10.977382	2013-03-20 22:43:10.977382
\.


--
-- Name: email_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('email_tokens_id_seq', 1, true);


--
-- Data for Name: facebook_user_infos; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY facebook_user_infos (id, user_id, facebook_user_id, username, first_name, last_name, email, gender, name, link, created_at, updated_at) FROM stdin;
\.


--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('facebook_user_infos_id_seq', 1, false);


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
\.


--
-- Name: incoming_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('incoming_links_id_seq', 1, false);


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

SELECT pg_catalog.setval('message_bus_id_seq', 1, false);


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY notifications (id, notification_type, user_id, data, read, created_at, updated_at, topic_id, post_number, post_action_id) FROM stdin;
\.


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('notifications_id_seq', 1, false);


--
-- Data for Name: onebox_renders; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY onebox_renders (id, url, cooked, expires_at, created_at, updated_at, preview) FROM stdin;
\.


--
-- Name: onebox_renders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('onebox_renders_id_seq', 1, false);


--
-- Data for Name: post_action_types; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_action_types (name_key, is_flag, icon, created_at, updated_at, id, "position") FROM stdin;
bookmark	f	\N	2013-03-20 22:41:50.344171	2013-03-20 22:41:50.344171	1	1
like	f	heart	2013-03-20 22:41:50.350586	2013-03-20 22:41:50.350586	2	2
off_topic	t	\N	2013-03-20 22:41:50.352393	2013-03-20 22:41:50.352393	3	3
inappropriate	t	\N	2013-03-20 22:41:50.354101	2013-03-20 22:41:50.354101	4	4
vote	f	\N	2013-03-20 22:41:50.356248	2013-03-20 22:41:50.356248	5	5
spam	t	\N	2013-03-20 22:41:50.358182	2013-03-20 22:41:50.358182	7	6
custom_flag	t	\N	2013-03-20 22:41:50.360561	2013-03-20 22:41:50.360561	6	7
\.


--
-- Name: post_action_types_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('post_action_types_id_seq', 8, true);


--
-- Data for Name: post_actions; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_actions (id, post_id, user_id, post_action_type_id, deleted_at, created_at, updated_at, deleted_by, message) FROM stdin;
\.


--
-- Name: post_actions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('post_actions_id_seq', 1, false);


--
-- Data for Name: post_onebox_renders; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_onebox_renders (post_id, onebox_render_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: post_replies; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_replies (post_id, reply_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: post_timings; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY post_timings (topic_id, post_number, user_id, msecs) FROM stdin;
1	1	1	8007
2	1	1	27026
3	1	1	6016
\.


--
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY posts (id, user_id, topic_id, post_number, raw, cooked, created_at, updated_at, reply_to_post_number, cached_version, reply_count, quote_count, deleted_at, off_topic_count, like_count, incoming_link_count, bookmark_count, avg_time, score, reads, post_type, vote_count, sort_order, last_editor_id, hidden, hidden_reason_id, custom_flag_count, spam_count, illegal_count, inappropriate_count, last_version_at, user_deleted, reply_to_user_id) FROM stdin;
1	1	1	1	You are now the proud owner of your very own Civilized Discourse Construction Kit. Congratulations! As a new forum admin admin, here's a quick start guide to get you going:\n\n### Login as an Admin<p>\n\nThe production seed data for Discourse forums comes with this topic (obviously!) and a pre-built admin account:\n\n> username: `forumadmin`  \n> password: `password`\n\nYou can login via the blue "Log in" button in the upper-right hand corner of Discourse.\n\nNeedless to say, do NOT forget to change the password on that account.\n\n### Access the Admin Console<p>\n\nTo access the Discourse admin console, add `/admin` to the base URL, like so:\n\n### [/admin](/admin)<p></p>\n\nFrom here, you'll be able to access the Admin functions, all of which are very important, so do check them out: site settings, users, email, flags, and customize.\n\n### Enable Twitter Logins<p>\n\n1. From the Administrative console above, enter **Site Settings**.\n2. Scroll down to the two text fields named:\n\n  `twitter_consumer_key`  \n  `twitter_consumer_secret`  \n\n3. Enter in your respective **key** and **secret** that is issued to you via dev.twitter.com. If you are unsure of what your key/secret is, or you have yet to obtain one, visit the Twitter Dev API FAQ on [how to obtain these keys](https://dev.twitter.com/docs/faq#7447).\n\n### Enable Facebook Logins<p>\n\n1. From the Administrative console above, enter **Site Settings**.\n2. Scroll down to the two text fields named:\n\n  `facebook_app_id`  \n  `facebook_app_secret`  \n\n3. Enter in your respective **id** and **secret** that is issued to you via developers.facebook.com. If you are unsure of what your id/secret is, or you have yet to obtain one, visit the [Facebook Developers :: Access Tokens and Types](https://developers.facebook.com/docs/concepts/login/access-tokens-and-types/) page for more information.\n\n### Creating New Categories<p>\n\nYou will get one new category by default, meta. [Check it out! It's important](/category/meta). But you may want more.\n\nCategories are the **colored labels** used to organize groups of topics in Discourse, and they are completely customizable:\n\n1. Log in to Discourse via an account that has Administrative access.\n2. Click the "Categories" button in the navigation along the top of the site.\n3. You should now see a "Create Category" button.\n4. Select a name and set of colors for the category for it in the dialog that pops up.\n5. Write a paragraph describing what the category is about in the first post of the Category Definition Topic associated with that category. It'll be pinned to the top of the category, and used in a bunch of places.\n\n### File and Image Uploads<p>\n\nImage uploads should work fine out of the box, stored locally, though you can configure it so that images users upload go to Amazon S3.\n\nDiscourse currently does not support arbitrary file uploads, but this functionality is being built as we speak and should be available soon. We'll update this guide when it is ([Reference](http://meta.discourse.org/t/file-upload-support/2879/7)).\n\n### Test Email Sending<p>\n\nDiscourse relies heavily on emails to notify folks about conversations happening on the forum. Visit [the admin email logs](/admin/email_logs), then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>. Did it work? Great! If not, your users may not be getting any email notifications.\n\n### Set your Terms of Service and User Content Licensing<p>\n\nMake sure you set your company name and domain variables for the [Terms of Service](/tos), which is a creative commons document.\n\nYou'll also need to make an important legal decision about the content users post on your forum:\n\n> Your users will always retain copyright on their posts, and will always grant the forum owner enough rights to include their content on the forum.\n> \n> Who is allowed to republish the content posted on this forum?\n> \n> - Only the author\n> - Author and the owner of this forum\n> - Anybody\n\nPlease see our [admin User Content Licensing](/admin/user-content-licensing) page for a brief form that will let you cut and paste your decision into section #3 of the [Terms of Service](/tos).\n\n### Customize CSS / Header Logos<p>\n\n1. Access the Administrative console, and select "Customize".\n\n2. You'll see a list of styles down the left-hand column, and two subcategories: "Stylesheet" and "Header".\n\n  - Insert your custom CSS styles into the "Stylesheet" section.\n\n  - Insert your custom HTML header into the "Header" section.\n\n3. **Enable:** If you wish to have your styles and header take effect on the site, check the "Enable" checkbox, then click "Save". This is also known as "live reloading", which will cause your changes to take effect immediately.\n\n4. **Preview:** If you wish to preview your changes before saving them, click the "preview" link at the bottom of the screen. Your changes will be applied to the site as they are currently saved in the "Customize" panel. If you aren't happy with your changes and wish to revert, simply click the "Undo Preview" link.\n\n5. **Override:** If you wish to have your styles override the default styles on the site, check the "Do not include standard style sheet" checkbox.\n\nHere is some example HTML that would go into the "Header" section within "Customize":\n\n```\n<div class='myheader' style='text-align:center;background-color:#CDCDCD'>\n<a href="/"><img src="http://dummyimage.com/1111x90/CDCDCD/000000.jpg&text=Placeholder+Custom+Header" width="1111px" height="90px" border="0" /></a>    \n</div>\n```\n\n### Ruby and Rails Performance Tweaks<p>\n\n- Be sure you have at least 1 GB of memory for your Discourse server. You might be able to squeak by with less, but we don't recommend it, unless you are an expert.\n\n- We strongly advise setting `RUBY_GC_MALLOC_LIMIT` to something much higher than the default for optimal performance. See [this meta.discourse topic for more details][1]. \n\n### Need more Help?<p>\n\nThis guide is a work in progress and we will be continually improving it with your feedback.\n\nFor more assistance on configuring and running your Discourse forum, see [the support category on meta.discourse.org]().\n\n[1]: http://meta.discourse.org/t/tuning-ruby-and-rails-for-discourse/4126\n[2]: http://meta.discourse.org/category/support	<p>You are now the proud owner of your very own Civilized Discourse Construction Kit. Congratulations! As a new forum admin admin, here's a quick start guide to get you going:</p>\n\n<h3>Login as an Admin</h3><p>\n\n</p><p>The production seed data for Discourse forums comes with this topic (obviously!) and a pre-built admin account:</p>\n\n<blockquote>\n  <p>username: <code>forumadmin</code> <br>\n  password: <code>password</code></p>\n</blockquote>\n\n<p>You can login via the blue "Log in" button in the upper-right hand corner of Discourse.</p>\n\n<p>Needless to say, do NOT forget to change the password on that account.</p>\n\n<h3>Access the Admin Console</h3><p>\n\n</p><p>To access the Discourse admin console, add <code>/admin</code> to the base URL, like so:</p>\n\n<h3><a href="/admin">/admin</a></h3><p></p>\n\n<p>From here, you'll be able to access the Admin functions, all of which are very important, so do check them out: site settings, users, email, flags, and customize.</p>\n\n<h3>Enable Twitter Logins</h3><p>\n\n</p><ol>\n<li>From the Administrative console above, enter <strong>Site Settings</strong>.  </li>\n<li>\n<p>Scroll down to the two text fields named:</p>\n\n<p><code>twitter_consumer_key</code> <br><code>twitter_consumer_secret</code>  </p>\n</li>\n<li><p>Enter in your respective <strong>key</strong> and <strong>secret</strong> that is issued to you via dev.twitter.com. If you are unsure of what your key/secret is, or you have yet to obtain one, visit the Twitter Dev API FAQ on <a href="https://dev.twitter.com/docs/faq#7447" rel="nofollow">how to obtain these keys</a>.</p></li>\n</ol><h3>Enable Facebook Logins</h3><p>\n\n</p><ol>\n<li>From the Administrative console above, enter <strong>Site Settings</strong>.  </li>\n<li>\n<p>Scroll down to the two text fields named:</p>\n\n<p><code>facebook_app_id</code> <br><code>facebook_app_secret</code>  </p>\n</li>\n<li><p>Enter in your respective <strong>id</strong> and <strong>secret</strong> that is issued to you via developers.facebook.com. If you are unsure of what your id/secret is, or you have yet to obtain one, visit the <a href="https://developers.facebook.com/docs/concepts/login/access-tokens-and-types/" rel="nofollow">Facebook Developers :: Access Tokens and Types</a> page for more information.</p></li>\n</ol><h3>Creating New Categories</h3><p>\n\n</p><p>You will get one new category by default, meta. <a href="/category/meta">Check it out! It's important</a>. But you may want more.</p>\n\n<p>Categories are the <strong>colored labels</strong> used to organize groups of topics in Discourse, and they are completely customizable:</p>\n\n<ol>\n<li>Log in to Discourse via an account that has Administrative access.  </li>\n<li>Click the "Categories" button in the navigation along the top of the site.  </li>\n<li>You should now see a "Create Category" button.  </li>\n<li>Select a name and set of colors for the category for it in the dialog that pops up.  </li>\n<li>Write a paragraph describing what the category is about in the first post of the Category Definition Topic associated with that category. It'll be pinned to the top of the category, and used in a bunch of places.</li>\n</ol><h3>File and Image Uploads</h3><p>\n\n</p><p>Image uploads should work fine out of the box, stored locally, though you can configure it so that images users upload go to Amazon S3.</p>\n\n<p>Discourse currently does not support arbitrary file uploads, but this functionality is being built as we speak and should be available soon. We'll update this guide when it is (<a href="http://meta.discourse.org/t/file-upload-support/2879/7" rel="nofollow">Reference</a>).</p>\n\n<h3>Test Email Sending</h3><p>\n\n</p><p>Discourse relies heavily on emails to notify folks about conversations happening on the forum. Visit <a href="/admin/email_logs">the admin email logs</a>, then enter an email address in the "email address to test" field and click <kbd>send test email</kbd>. Did it work? Great! If not, your users may not be getting any email notifications.</p>\n\n<h3>Set your Terms of Service and User Content Licensing</h3><p>\n\n</p><p>Make sure you set your company name and domain variables for the <a href="/tos">Terms of Service</a>, which is a creative commons document.</p>\n\n<p>You'll also need to make an important legal decision about the content users post on your forum:</p>\n\n<blockquote>\n  <p>Your users will always retain copyright on their posts, and will always grant the forum owner enough rights to include their content on the forum.</p>\n  \n  <p>Who is allowed to republish the content posted on this forum?</p>\n  \n  <ul>\n<li>Only the author</li>\n  <li>Author and the owner of this forum</li>\n  <li>Anybody</li>\n  </ul>\n</blockquote>\n\n<p>Please see our <a href="/admin/user-content-licensing">admin User Content Licensing</a> page for a brief form that will let you cut and paste your decision into section #3 of the <a href="/tos">Terms of Service</a>.</p>\n\n<h3>Customize CSS / Header Logos</h3><p>\n\n</p><ol>\n<li><p>Access the Administrative console, and select "Customize".</p></li>\n<li>\n<p>You'll see a list of styles down the left-hand column, and two subcategories: "Stylesheet" and "Header".</p>\n\n<ul>\n<li><p>Insert your custom CSS styles into the "Stylesheet" section.</p></li>\n<li><p>Insert your custom HTML header into the "Header" section.</p></li>\n</ul>\n</li>\n<li><p><strong>Enable:</strong> If you wish to have your styles and header take effect on the site, check the "Enable" checkbox, then click "Save". This is also known as "live reloading", which will cause your changes to take effect immediately.</p></li>\n<li><p><strong>Preview:</strong> If you wish to preview your changes before saving them, click the "preview" link at the bottom of the screen. Your changes will be applied to the site as they are currently saved in the "Customize" panel. If you aren't happy with your changes and wish to revert, simply click the "Undo Preview" link.</p></li>\n<li><p><strong>Override:</strong> If you wish to have your styles override the default styles on the site, check the "Do not include standard style sheet" checkbox.</p></li>\n</ol><p>Here is some example HTML that would go into the "Header" section within "Customize":</p>\n\n<pre><code class="lang-auto">&lt;div class='myheader' style='text-align:center;background-color:#CDCDCD'&gt;  \n&lt;a href="/"&gt;&lt;img src="http://dummyimage.com/1111x90/CDCDCD/000000.jpg&amp;text=Placeholder+Custom+Header" width="1111px" height="90px" border="0" /&gt;&lt;/a&gt;      \n&lt;/div&gt;  \n</code></pre>\n\n<h3>Ruby and Rails Performance Tweaks</h3><p>\n\n</p><ul>\n<li><p>Be sure you have at least 1 GB of memory for your Discourse server. You might be able to squeak by with less, but we don't recommend it, unless you are an expert.</p></li>\n<li><p>We strongly advise setting <code>RUBY_GC_MALLOC_LIMIT</code> to something much higher than the default for optimal performance. See <a href="http://meta.discourse.org/t/tuning-ruby-and-rails-for-discourse/4126" rel="nofollow">this meta.discourse topic for more details</a>. </p></li>\n</ul><h3>Need more Help?</h3><p>\n\n</p><p>This guide is a work in progress and we will be continually improving it with your feedback.</p>\n\n<p>For more assistance on configuring and running your Discourse forum, see <a href="">the support category on meta.discourse.org</a>.</p>	2013-03-20 22:45:32.95978	2013-03-20 22:45:32.95978	\N	1	0	0	\N	0	0	0	0	\N	\N	1	1	0	1	1	f	\N	0	0	0	0	2013-03-20 22:45:32.959665	f	\N
2	1	2	1	Use the 'meta' category to discuss this forum -- things like deciding what sort of topics and replies are appropriate here, what the standards for posts and behavior are, and how we should moderate our community.	<p>Use the 'meta' category to discuss this forum -- things like deciding what sort of topics and replies are appropriate here, what the standards for posts and behavior are, and how we should moderate our community.</p>	2013-03-20 22:45:57.094331	2013-03-20 22:47:01.709115	\N	1	0	0	\N	0	0	0	0	\N	\N	1	1	0	1	1	f	\N	0	0	0	0	2013-03-20 22:45:57.093723	f	\N
3	1	3	1	Meta means discussion *of the discussion itself* instead of the actual topic of the discussion. For example, discussions about...\n\n- The style of discussion.\n- The participants in the discussion.\n- The setting in which the discussion occurs.\n- The relationship of the discussion to other discussions.\n\nThe etymology for the “meta-” prefix dates back to [Aristotle’s Metaphysics][1], which came after his works on physics. Meta means “after” in Greek. \n\n### Why do we need a meta category?\n\nMeta is incredibly important. It is where communities come together to decide who they are and what they are *about*. It is where communities form their core identity and mission statement.\n\nMeta is for the folks who enjoy the forum so much that they want to go beyond merely reading and posting -- they want to work together to improve their community in various ways. Meta is the place where all leadership and governance forms within a community, a way to debate and decide direction for the whole community.\n\nMeta serves as *community memory*, documenting the history of the community and its culture. There's a story behind every evolution in rules or tone; these shared stories are what bind communities together. Meta also provides a home for all the tiny unique things that make your community what it is: its terminology, its acronyms, its slang.\n\n### What kinds of meta topics can I post?\n\nSome examples of meta topics:\n\n- What sort of topics should we allow and encourage? Which kinds should we explicitly discourage?\n\n- What kinds of replies are we looking for? What makes a good reply, and what makes a reply out of bounds or off-topic?\n\n- What are our standards for community behavior, beyond what is [defined in the FAQ][2]?\n\n- How can we encourage new members of our community and welcome them?\n\n- Are we setting a good example for the kinds of discussions we want in our community?\n\n- What problems and challenges does our community face, and how can they be resolved?\n\n- How should we moderate our community, and who should the moderators be? What should our flag reasons be?\n\n- How do we publicize and grow our community?\n\n- What does does TLA mean? Who was Kilroy and why does everyone drop his name when they make a typo?\n\n- How should (or why did) the rules change?\n\nBut really, anything is fair game in the meta category, provided it's a discussion about the community or the forum in some way.\n\n[1]: http://en.wikipedia.org/wiki/Metaphysics_(Aristotle)\n[2]: /faq	<p>Meta means discussion <em>of the discussion itself</em> instead of the actual topic of the discussion. For example, discussions about...</p>\n\n<ul>\n<li>The style of discussion.</li>\n<li>The participants in the discussion.</li>\n<li>The setting in which the discussion occurs.</li>\n<li>The relationship of the discussion to other discussions.</li>\n</ul><p>The etymology for the “meta-” prefix dates back to <a href="http://en.wikipedia.org/wiki/Metaphysics_%28Aristotle%29" rel="nofollow">Aristotle’s Metaphysics</a>, which came after his works on physics. Meta means “after” in Greek. </p>\n\n<h3>Why do we need a meta category?</h3>\n\n<p>Meta is incredibly important. It is where communities come together to decide who they are and what they are <em>about</em>. It is where communities form their core identity and mission statement.</p>\n\n<p>Meta is for the folks who enjoy the forum so much that they want to go beyond merely reading and posting -- they want to work together to improve their community in various ways. Meta is the place where all leadership and governance forms within a community, a way to debate and decide direction for the whole community.</p>\n\n<p>Meta serves as <em>community memory</em>, documenting the history of the community and its culture. There's a story behind every evolution in rules or tone; these shared stories are what bind communities together. Meta also provides a home for all the tiny unique things that make your community what it is: its terminology, its acronyms, its slang.</p>\n\n<h3>What kinds of meta topics can I post?</h3>\n\n<p>Some examples of meta topics:</p>\n\n<ul>\n<li><p>What sort of topics should we allow and encourage? Which kinds should we explicitly discourage?</p></li>\n<li><p>What kinds of replies are we looking for? What makes a good reply, and what makes a reply out of bounds or off-topic?</p></li>\n<li><p>What are our standards for community behavior, beyond what is <a href="/faq">defined in the FAQ</a>?</p></li>\n<li><p>How can we encourage new members of our community and welcome them?</p></li>\n<li><p>Are we setting a good example for the kinds of discussions we want in our community?</p></li>\n<li><p>What problems and challenges does our community face, and how can they be resolved?</p></li>\n<li><p>How should we moderate our community, and who should the moderators be? What should our flag reasons be?</p></li>\n<li><p>How do we publicize and grow our community?</p></li>\n<li><p>What does does TLA mean? Who was Kilroy and why does everyone drop his name when they make a typo?</p></li>\n<li><p>How should (or why did) the rules change?</p></li>\n</ul><p>But really, anything is fair game in the meta category, provided it's a discussion about the community or the forum in some way.</p>	2013-03-20 22:48:20.832956	2013-03-20 22:48:20.832956	\N	1	0	0	\N	0	0	0	0	\N	\N	1	1	0	1	1	f	\N	0	0	0	0	2013-03-20 22:48:20.832447	f	\N
4	1	3	2	This topic is now pinned. It will appear at the top of its category until it is either unpinned by a moderator, or cleared by each user using the Clear Pin button.	<p>This topic is now pinned. It will appear at the top of its category until it is either unpinned by a moderator, or cleared by each user using the Clear Pin button.</p>	2013-03-21 02:20:25.085777	2013-03-21 02:20:25.085777	\N	1	0	0	\N	0	0	0	0	\N	\N	0	2	0	2	1	f	\N	0	0	0	0	2013-03-21 02:20:25.085172	f	\N
\.


--
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('posts_id_seq', 4, true);


--
-- Data for Name: posts_search; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY posts_search (id, search_data) FROM stdin;
1	'/1111x90/cdcdcd/000000.jpg':834 '/a':845 '/admin':101,108 '/div':846 '0':844 '1':858 '1111px':840 '3':634 '90px':842 'abl':114,869 'access':90,95,116,264,323,644 'account':54,89,319 'add':100 'address':488,492 'admin':20,21,35,53,92,98,118,481,614,949 'administr':143,210,322,646 'advis':888 'align':822 'allow':591 'along':331 'also':548,712 'alway':567,575 'amazon':429 'anybodi':610 'api':197 'app':225,228 'appli':751 'arbitrari':436 'aren':766 'assist':933 'associ':381 'author':602,603 'avail':451 'background':825 'background-color':824 'base':104 'blue':64 'border':843 'bottom':743 'box':414 'brief':621 'built':52,444 'bunch':399 'button':67,327,344 'categori':274,280,295,326,343,354,369,378,384,394,944 'caus':719 'cdcdcd':827 'center':823 'chang':84,721,733,748,771 'check':128,284,703,797 'checkbox':706,801 'civil':11 'class':817 'click':324,497,708,737,777 'color':298,351,826 'column':663 'come':43 'common':544 'compani':530 'complet':311 'configur':420,935 'congratul':15 'consol':93,99,144,211,647 'construct':13 'consum':158,161 'content':523,558,585,595,616 'continu':925 'convers':474 'copyright':569 'corner':74 'creat':272,342 'creativ':543 'css':641,673 'current':432,758 'custom':137,640,650,672,681,762,815,837 'customiz':312 'cut':627 'data':39 'decis':555,631 'default':282,792,800,900 'definit':379 'describ':366 'detail':910 'dev':196 'dev.twitter.com':176 'develop':263 'developers.facebook.com':243 'dialog':359 'discours':12,41,76,97,307,316,431,465,864,939,948 'div':816 'document':545 'domain':533 'dummyimage.com':833 'dummyimage.com/1111x90/cdcdcd/000000.jpg':832 'effect':699,724 'email':134,463,469,482,487,491,500,514 'enabl':138,205,688,705 'enough':580 'enter':146,163,213,230,485 'exampl':805 'expert':885 'facebook':206,224,227,262 'faq':198 'feedback':930 'field':155,222,495 'file':402,437 'fine':410 'first':374 'flag':135 'folk':472 'forget':82 'form':622 'forum':19,42,478,563,578,588,599,609,940 'forumadmin':56 'function':119,441 'gb':859 'gc':891 'get':29,277,512 'go':31,427,809 'grant':576 'great':504 'group':303 'guid':27,457,915,952 'hand':73,662 'happen':475 'happi':768 'header':642,669,683,686,697,812,838 'heavili':467 'height':841 'help':913 'higher':897 'href':829 'html':682,806 'id':226,234 'id/secret':251 'imag':404,406,424 'img':830 'immedi':725 'import':125,289,553 'improv':926 'includ':583 'inform':271 'insert':670,679 'issu':172,239 'key':159,167,204 'key/secret':184 'kit':14 'known':713 'label':299 'least':857 'left':661 'left-hand':660 'legal':554 'less':874 'let':625 'licens':524,617 'like':106 'limit':893 'link':740,781 'list':655 'live':715 'll':112,386,454,547,652 'local':416 'log':65,313,483 'login':32,61,140,207 'logo':643 'make':525,551 'malloc':892 'may':292,509 'memori':861 'meta':283 'meta.discourse':906 'meta.discourse.org':946 'might':867 'much':896 'myhead':818 'name':156,223,347,531 'navig':330 'need':549,911 'needless':77 'new':18,273,279 'notif':515 'notifi':471 'obtain':191,202,258 'obvious':47 'one':192,259,278 'optim':902 'organ':302 'overrid':782,790,799 'owner':6,579,606 'page':268,618 'panel':763 'paragraph':365 'password':57,58,86 'past':629 'perform':850,903 'pin':388 'place':401 'placehold':836 'pleas':611 'pop':361 'post':375,560,572,596 'pre':51 'pre-built':50 'preview':726,731,739,780 'product':37 'progress':920 'proud':5 'quick':25,950 'rail':849 'recommend':879 'refer':461 'reli':466 'reload':716 'republish':593 'respect':166,233 'retain':568 'revert':775 'right':72,581 'rubi':847,890 'run':937 's3':430 'save':709,735,759 'say':79 'screen':746 'scroll':149,216 'secret':162,169,229,236 'section':633,678,687,813 'see':340,612,653,904,941 'seed':38 'select':345,649 'send':464,498 'server':865 'servic':520,539,639 'set':132,148,215,349,516,528,889 'simpli':776 'site':131,147,214,336,702,754,796 'someth':895 'soon':452 'speak':447 'squeak':871 'src':831 'start':26,951 'store':415 'strong':887 'style':657,674,695,789,793,819 'stylesheet':667,677 'subcategori':666 'support':435,943 'sure':526,853 'take':698,723 'term':518,537,637 'test':462,494,499 'text':154,221,821,835 'text-align':820 'though':417 'token':265 'top':333,391 'topic':46,305,380,907 'tweak':851 'twitter':139,157,160,195 'two':153,220,665 'type':267 'undo':779 'unless':881 'unsur':180,247 'updat':455 'upload':405,407,426,438 'upper':71 'upper-right':70 'url':105 'use':300,396 'user':133,425,508,522,559,565,615 'usernam':55 'variabl':534 'via':62,175,242,317 'visit':193,260,479 'want':293 'width':839 'wish':691,729,773,785 'within':814 'work':409,503,918 'would':808 'write':363 'yet':189,256
2	'appropri':19 'behavior':27 'categori':4,37 'communiti':35 'decid':11 'definit':38 'discuss':6 'forum':8 'like':10 'meta':3,36,39 'moder':33 'post':25 'repli':17 'sort':13 'standard':23 'thing':9 'topic':15 'use':1
3	'acronym':217 'actual':11 'allow':239 'also':197 'anyth':385 'aristotl':53 'back':51 'behavior':279 'behind':181 'beyond':122,280 'bind':193 'bound':268 'came':57 'categori':74,392 'challeng':318 'chang':382 'come':83 'communiti':82,98,135,151,162,166,173,194,210,278,295,314,321,334,354,400 'core':101 'cultur':176 'date':50 'debat':155 'decid':86,157 'defin':283 'direct':158 'discourag':247 'discuss':3,6,15,18,23,28,34,40,43,309,397 'document':168 'drop':367 'encourag':241,290 'enjoy':112 'etymolog':45 'everi':182 'everyon':366 'evolut':183 'exampl':17,229,304 'explicit':246 'face':322 'fair':387 'faq':286 'flag':344 'folk':110 'form':99,148 'forum':114,403 'game':388 'go':121 'good':259,303 'govern':147 'greek':67 'grow':352 'histori':170 'home':200 'ident':102 'import':78 'improv':133 'incred':77 'instead':8 'kilroy':362 'kind':221,243,249,307 'leadership':145 'look':254 'make':208,257,263,372 'mean':2,64,359 'member':292 'memori':167 'mere':123 'meta':1,48,63,73,75,106,139,163,196,223,231,391,409,410 'metaphys':55 'mission':104 'moder':332,339 'much':116 'name':369 'need':71 'new':291 'occur':35 'off-top':270 'particip':25 'physic':62 'place':142 'post':126,227 'prefix':49 'problem':316 'provid':198,393 'public':350 'read':124 'realli':384 'reason':345 'relationship':37 'repli':251,260,265 'resolv':328 'rule':185,381 'serv':164 'set':30,301 'share':189 'slang':219 'sort':234 'standard':276 'statement':105 'stori':180,190 'style':21 'terminolog':215 'thing':206 'tini':204 'tla':358 'togeth':84,131,195 'tone':187 'topic':12,224,232,236,272 'typo':374 'uniqu':205 'various':137 'want':119,128,311 'way':138,153,406 'welcom':297 'whole':161 'within':149 'work':60,130
4	'appear':8 'button':32 'categori':14 'clear':24,30 'either':18 'meta':35,36 'moder':22 'pin':5,31 'top':11 'topic':2 'unpin':19 'use':28 'user':27
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
20120803191426
20120806030641
20120806062617
20120807223020
20120809020415
20120809030647
20120809053414
20120809154750
20120809174649
20120809175110
20120809201855
20120810064839
20120812235417
20120813004347
20120813042912
20120813201426
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
20120924182000
20120924182031
20120925171620
20120925190802
20120928170023
20121009161116
20121011155904
20121017162924
20121018103721
20121018133039
20121018182709
20121106015500
20121108193516
20121109164630
20121113200844
20121113200845
20121115172544
20121116212424
20121119190529
20121119200843
20121121202035
20121121205215
20121122033316
20121123054127
20121123063630
20121129160035
20121129184948
20121130010400
20121130191818
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
1	system_username	1	forumadmin	2013-03-20 22:43:38.015116	2013-03-20 22:43:38.015116
\.


--
-- Name: site_settings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('site_settings_id_seq', 1, true);


--
-- Data for Name: topic_allowed_users; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topic_allowed_users (id, user_id, topic_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('topic_allowed_users_id_seq', 1, false);


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

SELECT pg_catalog.setval('topic_link_clicks_id_seq', 1, false);


--
-- Data for Name: topic_links; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topic_links (id, topic_id, post_id, user_id, url, domain, internal, link_topic_id, created_at, updated_at, reflection, clicks, link_post_id) FROM stdin;
1	1	1	1	https://dev.twitter.com/docs/faq#7447	dev.twitter.com	f	\N	2013-03-20 22:45:33.007986	2013-03-20 22:45:33.007986	f	0	\N
2	1	1	1	https://developers.facebook.com/docs/concepts/login/access-tokens-and-types/	developers.facebook.com	f	\N	2013-03-20 22:45:33.010892	2013-03-20 22:45:33.010892	f	0	\N
3	1	1	1	/category/meta	localhost	t	\N	2013-03-20 22:45:33.013933	2013-03-20 22:45:33.013933	f	0	\N
4	1	1	1	http://meta.discourse.org/t/file-upload-support/2879/7	meta.discourse.org	f	\N	2013-03-20 22:45:33.015779	2013-03-20 22:45:33.015779	f	0	\N
5	1	1	1	/tos	localhost	t	\N	2013-03-20 22:45:33.019033	2013-03-20 22:45:33.019033	f	0	\N
6	1	1	1	http://meta.discourse.org/t/tuning-ruby-and-rails-for-discourse/4126	meta.discourse.org	f	\N	2013-03-20 22:45:33.021702	2013-03-20 22:45:33.021702	f	0	\N
7	3	3	1	http://en.wikipedia.org/wiki/Metaphysics_%28Aristotle%29	en.wikipedia.org	f	\N	2013-03-20 22:48:20.85045	2013-03-20 22:48:20.85045	f	0	\N
8	3	3	1	/faq	localhost	t	\N	2013-03-20 22:48:20.853988	2013-03-20 22:48:20.853988	f	0	\N
\.


--
-- Name: topic_links_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('topic_links_id_seq', 8, true);


--
-- Data for Name: topic_users; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topic_users (user_id, topic_id, starred, posted, last_read_post_number, seen_post_count, starred_at, last_visited_at, first_visited_at, notification_level, notifications_changed_at, notifications_reason_id, total_msecs_viewed, cleared_pinned_at) FROM stdin;
1	1	f	t	1	1	\N	2013-03-20 22:48:39	2013-03-20 22:45:32	3	2013-03-20 22:45:32	1	24022	\N
1	2	f	t	1	1	\N	2013-03-21 02:19:15	2013-03-20 22:45:57	3	2013-03-20 22:45:57	1	27026	\N
1	3	f	t	2	2	\N	2013-03-21 02:20:21	2013-03-20 22:48:20	3	2013-03-20 22:48:20	1	6016	\N
\.


--
-- Data for Name: topics; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY topics (id, title, last_posted_at, created_at, updated_at, views, posts_count, user_id, last_post_user_id, reply_count, featured_user1_id, featured_user2_id, featured_user3_id, avg_time, deleted_at, highest_post_number, image_url, off_topic_count, like_count, incoming_link_count, bookmark_count, star_count, category_id, visible, moderator_posts_count, closed, archived, bumped_at, has_best_of, meta_data, vote_count, archetype, featured_user4_id, custom_flag_count, spam_count, illegal_count, inappropriate_count, pinned_at) FROM stdin;
1	The Discourse Admin Quick Start Guide	2013-03-20 22:45:32.95978	2013-03-20 22:45:32.863334	2013-03-20 22:45:32.969335	1	1	1	1	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	\N	t	0	f	f	2013-03-20 22:45:32.862922	f	\N	0	regular	\N	0	0	0	0	\N
2	Meta Category Definition	2013-03-20 22:45:57.094331	2013-03-20 22:45:57.076947	2013-03-20 22:47:01.670405	2	1	1	1	0	\N	\N	\N	\N	\N	1	\N	0	0	0	0	0	1	t	0	f	f	2013-03-20 22:45:57.076698	f	\N	0	regular	\N	0	0	0	0	2013-03-20 22:45:57.073216
3	What is "Meta"?	2013-03-21 02:20:25.085777	2013-03-20 22:48:20.794965	2013-03-21 02:20:25.111601	4	2	1	1	0	\N	\N	\N	\N	\N	2	\N	0	0	0	0	0	1	t	1	f	f	2013-03-20 22:48:20.794729	f	\N	0	regular	\N	0	0	0	0	2013-03-21 02:20:24.990989
\.


--
-- Name: topics_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('topics_id_seq', 3, true);


--
-- Data for Name: twitter_user_infos; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY twitter_user_infos (id, user_id, screen_name, twitter_user_id, created_at, updated_at) FROM stdin;
\.


--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('twitter_user_infos_id_seq', 1, false);


--
-- Data for Name: uploads; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY uploads (id, user_id, topic_id, original_filename, filesize, width, height, url, created_at, updated_at) FROM stdin;
\.


--
-- Name: uploads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('uploads_id_seq', 1, false);


--
-- Data for Name: user_actions; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY user_actions (id, action_type, user_id, target_topic_id, target_post_id, target_user_id, acting_user_id, created_at, updated_at) FROM stdin;
1	4	1	1	-1	\N	1	2013-03-20 22:45:32.863334	2013-03-20 22:45:32.905823
3	4	1	2	-1	\N	1	2013-03-20 22:45:57.076947	2013-03-20 22:45:57.084898
7	4	1	3	-1	\N	1	2013-03-20 22:48:20.794965	2013-03-20 22:48:20.807845
11	5	1	3	4	\N	1	2013-03-21 02:20:25.085777	2013-03-21 02:20:25.107204
\.


--
-- Name: user_actions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('user_actions_id_seq', 12, true);


--
-- Data for Name: user_open_ids; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY user_open_ids (id, user_id, email, url, created_at, updated_at, active) FROM stdin;
\.


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('user_open_ids_id_seq', 1, false);


--
-- Data for Name: user_visits; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY user_visits (id, user_id, visited_at) FROM stdin;
1	1	2013-03-20
\.


--
-- Name: user_visits_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('user_visits_id_seq', 1, true);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY users (id, username, created_at, updated_at, name, bio_raw, seen_notification_id, last_posted_at, email, password_hash, salt, active, username_lower, auth_token, last_seen_at, website, admin, last_emailed_at, email_digests, trust_level, bio_cooked, email_private_messages, email_direct, approved, approved_by_id, approved_at, topics_entered, posts_read_count, digest_after_days, previous_visit_at, banned_at, banned_till, date_of_birth, auto_track_topics_after_msecs, views, flag_level, time_read, days_visited, ip_address, new_topic_duration_minutes, external_links_in_new_tab, enable_quoting, moderator) FROM stdin;
1	forumadmin	2013-03-20 22:43:10.955943	2013-03-20 22:44:38.888896	Forum Admin	\N	0	2013-03-20 22:48:20.832956	team@discourse.org	c510193134d9347b917fde91ecfa63fd8580262ebbe757b911bfd0e3469daf3b	8c53b9af0df959d538fcb99ec20a9679	t	forumadmin	8102fd64abe0a669dc300e5141b0ce55	2013-03-21 02:20:11	\N	t	\N	t	0	\N	t	t	f	\N	\N	0	0	7	2013-03-20 22:49:23	\N	\N	\N	\N	0	0	252	1	10.0.2.2	\N	f	t	f
\.


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('users_id_seq', 1, true);


--
-- Data for Name: users_search; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY users_search (id, search_data) FROM stdin;
1	'admin':3 'forum':2 'forumadmin':1
\.


--
-- Data for Name: versions; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY versions (id, versioned_id, versioned_type, user_id, user_type, user_name, modifications, number, reverted_from, tag, created_at, updated_at) FROM stdin;
1	2	Topic	\N	\N	\N	---\ntitle:\n- Category definition for meta\n- Meta Category Definition\n	2	\N	\N	2013-03-20 22:46:46.55544	2013-03-20 22:46:46.55544
2	3	Topic	\N	\N	\N	---\nid:\n- \n- 3\ntitle:\n- \n- What is "Meta"?\nuser_id:\n- \n- 1\nlast_post_user_id:\n- \n- 1\ncategory_id:\n- \n- 1\nbumped_at:\n- \n- 2013-03-20 22:48:20.794729547 Z\n	2	\N	\N	2013-03-20 22:48:20.80273	2013-03-20 22:48:20.80273
\.


--
-- Name: versions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: vagrant
--

SELECT pg_catalog.setval('versions_id_seq', 2, true);


--
-- Data for Name: views; Type: TABLE DATA; Schema: public; Owner: vagrant
--

COPY views (parent_id, parent_type, ip, viewed_at, user_id) FROM stdin;
1	Topic	167772674	2013-03-20	1
2	Topic	167772674	2013-03-20	1
3	Topic	167772674	2013-03-20	1
3	Topic	167772674	2013-03-20	\N
3	Topic	167772674	2013-03-20	1
2	Topic	167772674	2013-03-20	1
3	Topic	167772674	2013-03-20	1
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

