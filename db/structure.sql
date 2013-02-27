--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: backup; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA backup;


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


SET search_path = backup, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: categories; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE categories_id_seq
    START WITH 5
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE categories_id_seq OWNED BY categories.id;


--
-- Name: category_featured_topics; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE category_featured_topics (
    category_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: category_featured_users; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE category_featured_users (
    id integer NOT NULL,
    category_id integer,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: category_featured_users_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE category_featured_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_featured_users_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE category_featured_users_id_seq OWNED BY category_featured_users.id;


--
-- Name: draft_sequences; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE draft_sequences (
    id integer NOT NULL,
    user_id integer NOT NULL,
    draft_key character varying(255) NOT NULL,
    sequence integer NOT NULL
);


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE draft_sequences_id_seq
    START WITH 20
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE draft_sequences_id_seq OWNED BY draft_sequences.id;


--
-- Name: drafts; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: drafts_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE drafts_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE drafts_id_seq OWNED BY drafts.id;


--
-- Name: email_logs; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE email_logs (
    id integer NOT NULL,
    to_address character varying(255) NOT NULL,
    email_type character varying(255) NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: email_logs_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE email_logs_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE email_logs_id_seq OWNED BY email_logs.id;


--
-- Name: email_tokens; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: email_tokens_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE email_tokens_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE email_tokens_id_seq OWNED BY email_tokens.id;


--
-- Name: facebook_user_infos; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE facebook_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE facebook_user_infos_id_seq OWNED BY facebook_user_infos.id;


--
-- Name: incoming_links; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: incoming_links_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE incoming_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incoming_links_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE incoming_links_id_seq OWNED BY incoming_links.id;


--
-- Name: invites; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invites_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE invites_id_seq OWNED BY invites.id;


--
-- Name: notifications; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id;


--
-- Name: onebox_renders; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: onebox_renders_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE onebox_renders_id_seq
    START WITH 2
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: onebox_renders_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE onebox_renders_id_seq OWNED BY onebox_renders.id;


--
-- Name: post_action_types; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE post_action_types (
    name_key character varying(50) NOT NULL,
    is_flag boolean DEFAULT false NOT NULL,
    icon character varying(20),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id integer NOT NULL
);


--
-- Name: post_action_types_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE post_action_types_id_seq
    START WITH 6
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_action_types_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE post_action_types_id_seq OWNED BY post_action_types.id;


--
-- Name: post_actions; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: post_actions_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE post_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE post_actions_id_seq OWNED BY post_actions.id;


--
-- Name: post_onebox_renders; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE post_onebox_renders (
    post_id integer NOT NULL,
    onebox_render_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_replies; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE post_replies (
    post_id integer,
    reply_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_timings; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE post_timings (
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    user_id integer NOT NULL,
    msecs integer NOT NULL
);


--
-- Name: posts; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE posts_id_seq
    START WITH 16
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE posts_id_seq OWNED BY posts.id;


--
-- Name: site_customizations; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: site_customizations_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE site_customizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_customizations_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE site_customizations_id_seq OWNED BY site_customizations.id;


--
-- Name: site_settings; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE site_settings (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    data_type integer NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: site_settings_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE site_settings_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE site_settings_id_seq OWNED BY site_settings.id;


--
-- Name: topic_allowed_users; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE topic_allowed_users (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE topic_allowed_users_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE topic_allowed_users_id_seq OWNED BY topic_allowed_users.id;


--
-- Name: topic_invites; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE topic_invites (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    invite_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_invites_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE topic_invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_invites_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE topic_invites_id_seq OWNED BY topic_invites.id;


--
-- Name: topic_link_clicks; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE topic_link_clicks (
    id integer NOT NULL,
    topic_link_id integer NOT NULL,
    user_id integer,
    ip bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE topic_link_clicks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE topic_link_clicks_id_seq OWNED BY topic_link_clicks.id;


--
-- Name: topic_links; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: topic_links_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE topic_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_links_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE topic_links_id_seq OWNED BY topic_links.id;


--
-- Name: topic_users; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: topics; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE topics_id_seq
    START WITH 16
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE topics_id_seq OWNED BY topics.id;


--
-- Name: trust_levels; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE trust_levels (
    id integer NOT NULL,
    name_key character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: trust_levels_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE trust_levels_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trust_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE trust_levels_id_seq OWNED BY trust_levels.id;


--
-- Name: twitter_user_infos; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE twitter_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    screen_name character varying(255) NOT NULL,
    twitter_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE twitter_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE twitter_user_infos_id_seq OWNED BY twitter_user_infos.id;


--
-- Name: uploads; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: uploads_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE uploads_id_seq OWNED BY uploads.id;


--
-- Name: user_actions; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: user_actions_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE user_actions_id_seq
    START WITH 40
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE user_actions_id_seq OWNED BY user_actions.id;


--
-- Name: user_open_ids; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE user_open_ids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE user_open_ids_id_seq OWNED BY user_open_ids.id;


--
-- Name: user_visits; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE user_visits (
    id integer NOT NULL,
    user_id integer NOT NULL,
    visited_at date NOT NULL
);


--
-- Name: user_visits_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE user_visits_id_seq
    START WITH 4
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE user_visits_id_seq OWNED BY user_visits.id;


--
-- Name: users; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 3
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: versions; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
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


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: backup; Owner: -
--

CREATE SEQUENCE versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: backup; Owner: -
--

ALTER SEQUENCE versions_id_seq OWNED BY versions.id;


--
-- Name: views; Type: TABLE; Schema: backup; Owner: -; Tablespace: 
--

CREATE TABLE views (
    parent_id integer NOT NULL,
    parent_type character varying(50) NOT NULL,
    ip bigint NOT NULL,
    viewed_at timestamp without time zone NOT NULL,
    user_id integer
);


SET search_path = public, pg_catalog;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
    description text
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE categories_id_seq OWNED BY categories.id;


--
-- Name: categories_search; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE categories_search (
    id integer NOT NULL,
    search_data tsvector
);


--
-- Name: category_featured_topics; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE category_featured_topics (
    category_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: category_featured_users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE category_featured_users (
    id integer NOT NULL,
    category_id integer,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: category_featured_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE category_featured_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_featured_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE category_featured_users_id_seq OWNED BY category_featured_users.id;


--
-- Name: draft_sequences; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE draft_sequences (
    id integer NOT NULL,
    user_id integer NOT NULL,
    draft_key character varying(255) NOT NULL,
    sequence integer NOT NULL
);


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE draft_sequences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE draft_sequences_id_seq OWNED BY draft_sequences.id;


--
-- Name: drafts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: drafts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE drafts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE drafts_id_seq OWNED BY drafts.id;


--
-- Name: email_logs; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE email_logs (
    id integer NOT NULL,
    to_address character varying(255) NOT NULL,
    email_type character varying(255) NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: email_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE email_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE email_logs_id_seq OWNED BY email_logs.id;


--
-- Name: email_tokens; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: email_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE email_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE email_tokens_id_seq OWNED BY email_tokens.id;


--
-- Name: facebook_user_infos; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE facebook_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facebook_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE facebook_user_infos_id_seq OWNED BY facebook_user_infos.id;


--
-- Name: github_user_infos; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE github_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    screen_name character varying(255) NOT NULL,
    github_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: github_user_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE github_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: github_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE github_user_infos_id_seq OWNED BY github_user_infos.id;


--
-- Name: incoming_links; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: incoming_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE incoming_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incoming_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE incoming_links_id_seq OWNED BY incoming_links.id;


--
-- Name: invites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE invites_id_seq OWNED BY invites.id;


--
-- Name: message_bus; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE message_bus (
    id integer NOT NULL,
    name character varying(255),
    context character varying(255),
    data text,
    created_at timestamp without time zone
);


--
-- Name: message_bus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE message_bus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: message_bus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE message_bus_id_seq OWNED BY message_bus.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE notifications_id_seq OWNED BY notifications.id;


--
-- Name: onebox_renders; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: onebox_renders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE onebox_renders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: onebox_renders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE onebox_renders_id_seq OWNED BY onebox_renders.id;


--
-- Name: post_action_types; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: post_action_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_action_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_action_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_action_types_id_seq OWNED BY post_action_types.id;


--
-- Name: post_actions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: post_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE post_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE post_actions_id_seq OWNED BY post_actions.id;


--
-- Name: post_onebox_renders; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_onebox_renders (
    post_id integer NOT NULL,
    onebox_render_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_replies; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_replies (
    post_id integer,
    reply_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_timings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE post_timings (
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    user_id integer NOT NULL,
    msecs integer NOT NULL
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
    user_deleted boolean DEFAULT false NOT NULL
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE posts_id_seq OWNED BY posts.id;


--
-- Name: posts_search; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE posts_search (
    id integer NOT NULL,
    search_data tsvector
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: site_customizations; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: site_customizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE site_customizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_customizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE site_customizations_id_seq OWNED BY site_customizations.id;


--
-- Name: site_settings; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE site_settings (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    data_type integer NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: site_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE site_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE site_settings_id_seq OWNED BY site_settings.id;


--
-- Name: topic_allowed_users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE topic_allowed_users (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE topic_allowed_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE topic_allowed_users_id_seq OWNED BY topic_allowed_users.id;


--
-- Name: topic_invites; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE topic_invites (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    invite_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE topic_invites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE topic_invites_id_seq OWNED BY topic_invites.id;


--
-- Name: topic_link_clicks; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE topic_link_clicks (
    id integer NOT NULL,
    topic_link_id integer NOT NULL,
    user_id integer,
    ip bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE topic_link_clicks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE topic_link_clicks_id_seq OWNED BY topic_link_clicks.id;


--
-- Name: topic_links; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: topic_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE topic_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE topic_links_id_seq OWNED BY topic_links.id;


--
-- Name: topic_users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
    CONSTRAINT test_starred_at CHECK (((starred = false) OR (starred_at IS NOT NULL)))
);


--
-- Name: topics; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
    pinned boolean DEFAULT false NOT NULL,
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
    inappropriate_count integer DEFAULT 0 NOT NULL
);


--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE topics_id_seq OWNED BY topics.id;


--
-- Name: twitter_user_infos; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE twitter_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    screen_name character varying(255) NOT NULL,
    twitter_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE twitter_user_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: twitter_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE twitter_user_infos_id_seq OWNED BY twitter_user_infos.id;


--
-- Name: uploads; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE uploads_id_seq OWNED BY uploads.id;


--
-- Name: user_actions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: user_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_actions_id_seq OWNED BY user_actions.id;


--
-- Name: user_open_ids; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_open_ids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_open_ids_id_seq OWNED BY user_open_ids.id;


--
-- Name: user_visits; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE user_visits (
    id integer NOT NULL,
    user_id integer NOT NULL,
    visited_at date NOT NULL
);


--
-- Name: user_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE user_visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE user_visits_id_seq OWNED BY user_visits.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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
    new_topic_duration_minutes integer
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: users_search; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE users_search (
    id integer NOT NULL,
    search_data tsvector
);


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -; Tablespace: 
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


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE versions_id_seq OWNED BY versions.id;


--
-- Name: views; Type: TABLE; Schema: public; Owner: -; Tablespace: 
--

CREATE TABLE views (
    parent_id integer NOT NULL,
    parent_type character varying(50) NOT NULL,
    ip bigint NOT NULL,
    viewed_at date NOT NULL,
    user_id integer
);


SET search_path = backup, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY categories ALTER COLUMN id SET DEFAULT nextval('categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY category_featured_users ALTER COLUMN id SET DEFAULT nextval('category_featured_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY draft_sequences ALTER COLUMN id SET DEFAULT nextval('draft_sequences_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY drafts ALTER COLUMN id SET DEFAULT nextval('drafts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY email_logs ALTER COLUMN id SET DEFAULT nextval('email_logs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY email_tokens ALTER COLUMN id SET DEFAULT nextval('email_tokens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY facebook_user_infos ALTER COLUMN id SET DEFAULT nextval('facebook_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY incoming_links ALTER COLUMN id SET DEFAULT nextval('incoming_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY invites ALTER COLUMN id SET DEFAULT nextval('invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY onebox_renders ALTER COLUMN id SET DEFAULT nextval('onebox_renders_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY post_action_types ALTER COLUMN id SET DEFAULT nextval('post_action_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY post_actions ALTER COLUMN id SET DEFAULT nextval('post_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY posts ALTER COLUMN id SET DEFAULT nextval('posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY site_customizations ALTER COLUMN id SET DEFAULT nextval('site_customizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY site_settings ALTER COLUMN id SET DEFAULT nextval('site_settings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY topic_allowed_users ALTER COLUMN id SET DEFAULT nextval('topic_allowed_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY topic_invites ALTER COLUMN id SET DEFAULT nextval('topic_invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY topic_link_clicks ALTER COLUMN id SET DEFAULT nextval('topic_link_clicks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY topic_links ALTER COLUMN id SET DEFAULT nextval('topic_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY topics ALTER COLUMN id SET DEFAULT nextval('topics_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY trust_levels ALTER COLUMN id SET DEFAULT nextval('trust_levels_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY twitter_user_infos ALTER COLUMN id SET DEFAULT nextval('twitter_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY uploads ALTER COLUMN id SET DEFAULT nextval('uploads_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY user_actions ALTER COLUMN id SET DEFAULT nextval('user_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY user_open_ids ALTER COLUMN id SET DEFAULT nextval('user_open_ids_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY user_visits ALTER COLUMN id SET DEFAULT nextval('user_visits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: backup; Owner: -
--

ALTER TABLE ONLY versions ALTER COLUMN id SET DEFAULT nextval('versions_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY categories ALTER COLUMN id SET DEFAULT nextval('categories_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY category_featured_users ALTER COLUMN id SET DEFAULT nextval('category_featured_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY draft_sequences ALTER COLUMN id SET DEFAULT nextval('draft_sequences_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY drafts ALTER COLUMN id SET DEFAULT nextval('drafts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY email_logs ALTER COLUMN id SET DEFAULT nextval('email_logs_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY email_tokens ALTER COLUMN id SET DEFAULT nextval('email_tokens_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY facebook_user_infos ALTER COLUMN id SET DEFAULT nextval('facebook_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY github_user_infos ALTER COLUMN id SET DEFAULT nextval('github_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY incoming_links ALTER COLUMN id SET DEFAULT nextval('incoming_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY invites ALTER COLUMN id SET DEFAULT nextval('invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY message_bus ALTER COLUMN id SET DEFAULT nextval('message_bus_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY notifications ALTER COLUMN id SET DEFAULT nextval('notifications_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY onebox_renders ALTER COLUMN id SET DEFAULT nextval('onebox_renders_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_action_types ALTER COLUMN id SET DEFAULT nextval('post_action_types_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY post_actions ALTER COLUMN id SET DEFAULT nextval('post_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY posts ALTER COLUMN id SET DEFAULT nextval('posts_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY site_customizations ALTER COLUMN id SET DEFAULT nextval('site_customizations_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY site_settings ALTER COLUMN id SET DEFAULT nextval('site_settings_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY topic_allowed_users ALTER COLUMN id SET DEFAULT nextval('topic_allowed_users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY topic_invites ALTER COLUMN id SET DEFAULT nextval('topic_invites_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY topic_link_clicks ALTER COLUMN id SET DEFAULT nextval('topic_link_clicks_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY topic_links ALTER COLUMN id SET DEFAULT nextval('topic_links_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY topics ALTER COLUMN id SET DEFAULT nextval('topics_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY twitter_user_infos ALTER COLUMN id SET DEFAULT nextval('twitter_user_infos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY uploads ALTER COLUMN id SET DEFAULT nextval('uploads_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_actions ALTER COLUMN id SET DEFAULT nextval('user_actions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_open_ids ALTER COLUMN id SET DEFAULT nextval('user_open_ids_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY user_visits ALTER COLUMN id SET DEFAULT nextval('user_visits_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY versions ALTER COLUMN id SET DEFAULT nextval('versions_id_seq'::regclass);


SET search_path = backup, pg_catalog;

--
-- Name: actions_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);


--
-- Name: categories_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category_featured_users_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY category_featured_users
    ADD CONSTRAINT category_featured_users_pkey PRIMARY KEY (id);


--
-- Name: draft_sequences_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY draft_sequences
    ADD CONSTRAINT draft_sequences_pkey PRIMARY KEY (id);


--
-- Name: drafts_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY drafts
    ADD CONSTRAINT drafts_pkey PRIMARY KEY (id);


--
-- Name: email_logs_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY email_logs
    ADD CONSTRAINT email_logs_pkey PRIMARY KEY (id);


--
-- Name: email_tokens_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY email_tokens
    ADD CONSTRAINT email_tokens_pkey PRIMARY KEY (id);


--
-- Name: facebook_user_infos_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY facebook_user_infos
    ADD CONSTRAINT facebook_user_infos_pkey PRIMARY KEY (id);


--
-- Name: forum_thread_link_clicks_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topic_link_clicks
    ADD CONSTRAINT forum_thread_link_clicks_pkey PRIMARY KEY (id);


--
-- Name: forum_thread_links_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topic_links
    ADD CONSTRAINT forum_thread_links_pkey PRIMARY KEY (id);


--
-- Name: forum_threads_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topics
    ADD CONSTRAINT forum_threads_pkey PRIMARY KEY (id);


--
-- Name: incoming_links_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY incoming_links
    ADD CONSTRAINT incoming_links_pkey PRIMARY KEY (id);


--
-- Name: invites_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


--
-- Name: notifications_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: onebox_renders_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY onebox_renders
    ADD CONSTRAINT onebox_renders_pkey PRIMARY KEY (id);


--
-- Name: post_action_types_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_action_types
    ADD CONSTRAINT post_action_types_pkey PRIMARY KEY (id);


--
-- Name: post_actions_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_actions
    ADD CONSTRAINT post_actions_pkey PRIMARY KEY (id);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: site_customizations_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY site_customizations
    ADD CONSTRAINT site_customizations_pkey PRIMARY KEY (id);


--
-- Name: site_settings_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (id);


--
-- Name: topic_allowed_users_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topic_allowed_users
    ADD CONSTRAINT topic_allowed_users_pkey PRIMARY KEY (id);


--
-- Name: topic_invites_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topic_invites
    ADD CONSTRAINT topic_invites_pkey PRIMARY KEY (id);


--
-- Name: trust_levels_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY trust_levels
    ADD CONSTRAINT trust_levels_pkey PRIMARY KEY (id);


--
-- Name: twitter_user_infos_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY twitter_user_infos
    ADD CONSTRAINT twitter_user_infos_pkey PRIMARY KEY (id);


--
-- Name: uploads_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY uploads
    ADD CONSTRAINT uploads_pkey PRIMARY KEY (id);


--
-- Name: user_open_ids_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_open_ids
    ADD CONSTRAINT user_open_ids_pkey PRIMARY KEY (id);


--
-- Name: user_visits_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_visits
    ADD CONSTRAINT user_visits_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: versions_pkey; Type: CONSTRAINT; Schema: backup; Owner: -; Tablespace: 
--

ALTER TABLE ONLY versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_actions
    ADD CONSTRAINT actions_pkey PRIMARY KEY (id);


--
-- Name: categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories_search_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY categories_search
    ADD CONSTRAINT categories_search_pkey PRIMARY KEY (id);


--
-- Name: category_featured_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY category_featured_users
    ADD CONSTRAINT category_featured_users_pkey PRIMARY KEY (id);


--
-- Name: draft_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY draft_sequences
    ADD CONSTRAINT draft_sequences_pkey PRIMARY KEY (id);


--
-- Name: drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY drafts
    ADD CONSTRAINT drafts_pkey PRIMARY KEY (id);


--
-- Name: email_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY email_logs
    ADD CONSTRAINT email_logs_pkey PRIMARY KEY (id);


--
-- Name: email_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY email_tokens
    ADD CONSTRAINT email_tokens_pkey PRIMARY KEY (id);


--
-- Name: facebook_user_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY facebook_user_infos
    ADD CONSTRAINT facebook_user_infos_pkey PRIMARY KEY (id);


--
-- Name: forum_thread_link_clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topic_link_clicks
    ADD CONSTRAINT forum_thread_link_clicks_pkey PRIMARY KEY (id);


--
-- Name: forum_thread_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topic_links
    ADD CONSTRAINT forum_thread_links_pkey PRIMARY KEY (id);


--
-- Name: forum_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topics
    ADD CONSTRAINT forum_threads_pkey PRIMARY KEY (id);


--
-- Name: github_user_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY github_user_infos
    ADD CONSTRAINT github_user_infos_pkey PRIMARY KEY (id);


--
-- Name: incoming_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY incoming_links
    ADD CONSTRAINT incoming_links_pkey PRIMARY KEY (id);


--
-- Name: invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


--
-- Name: message_bus_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY message_bus
    ADD CONSTRAINT message_bus_pkey PRIMARY KEY (id);


--
-- Name: notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: onebox_renders_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY onebox_renders
    ADD CONSTRAINT onebox_renders_pkey PRIMARY KEY (id);


--
-- Name: post_action_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_action_types
    ADD CONSTRAINT post_action_types_pkey PRIMARY KEY (id);


--
-- Name: post_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY post_actions
    ADD CONSTRAINT post_actions_pkey PRIMARY KEY (id);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: posts_search_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY posts_search
    ADD CONSTRAINT posts_search_pkey PRIMARY KEY (id);


--
-- Name: site_customizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY site_customizations
    ADD CONSTRAINT site_customizations_pkey PRIMARY KEY (id);


--
-- Name: site_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (id);


--
-- Name: topic_allowed_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topic_allowed_users
    ADD CONSTRAINT topic_allowed_users_pkey PRIMARY KEY (id);


--
-- Name: topic_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY topic_invites
    ADD CONSTRAINT topic_invites_pkey PRIMARY KEY (id);


--
-- Name: twitter_user_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY twitter_user_infos
    ADD CONSTRAINT twitter_user_infos_pkey PRIMARY KEY (id);


--
-- Name: uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY uploads
    ADD CONSTRAINT uploads_pkey PRIMARY KEY (id);


--
-- Name: user_open_ids_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_open_ids
    ADD CONSTRAINT user_open_ids_pkey PRIMARY KEY (id);


--
-- Name: user_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY user_visits
    ADD CONSTRAINT user_visits_pkey PRIMARY KEY (id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_search_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY users_search
    ADD CONSTRAINT users_search_pkey PRIMARY KEY (id);


--
-- Name: versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -; Tablespace: 
--

ALTER TABLE ONLY versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


SET search_path = backup, pg_catalog;

--
-- Name: cat_featured_threads; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX cat_featured_threads ON category_featured_topics USING btree (category_id, topic_id);


--
-- Name: idx_search_thread; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX idx_search_thread ON topics USING gin (to_tsvector('english'::regconfig, (title)::text));


--
-- Name: idx_search_user; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX idx_search_user ON users USING gin (to_tsvector('english'::regconfig, (username)::text));


--
-- Name: idx_unique_actions; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_actions ON post_actions USING btree (user_id, post_action_type_id, post_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_unique_rows; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_rows ON user_actions USING btree (action_type, user_id, target_topic_id, target_post_id, acting_user_id);


--
-- Name: incoming_index; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX incoming_index ON incoming_links USING btree (topic_id, post_number);


--
-- Name: index_actions_on_acting_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_actions_on_acting_user_id ON user_actions USING btree (acting_user_id);


--
-- Name: index_actions_on_user_id_and_action_type; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_actions_on_user_id_and_action_type ON user_actions USING btree (user_id, action_type);


--
-- Name: index_categories_on_forum_thread_count; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_categories_on_forum_thread_count ON categories USING btree (topic_count);


--
-- Name: index_categories_on_name; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_categories_on_name ON categories USING btree (name);


--
-- Name: index_category_featured_users_on_category_id_and_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_category_featured_users_on_category_id_and_user_id ON category_featured_users USING btree (category_id, user_id);


--
-- Name: index_draft_sequences_on_user_id_and_draft_key; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_draft_sequences_on_user_id_and_draft_key ON draft_sequences USING btree (user_id, draft_key);


--
-- Name: index_drafts_on_user_id_and_draft_key; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_drafts_on_user_id_and_draft_key ON drafts USING btree (user_id, draft_key);


--
-- Name: index_email_logs_on_created_at; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_email_logs_on_created_at ON email_logs USING btree (created_at DESC);


--
-- Name: index_email_logs_on_user_id_and_created_at; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_email_logs_on_user_id_and_created_at ON email_logs USING btree (user_id, created_at DESC);


--
-- Name: index_email_tokens_on_token; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_email_tokens_on_token ON email_tokens USING btree (token);


--
-- Name: index_facebook_user_infos_on_facebook_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_user_infos_on_facebook_user_id ON facebook_user_infos USING btree (facebook_user_id);


--
-- Name: index_facebook_user_infos_on_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_user_infos_on_user_id ON facebook_user_infos USING btree (user_id);


--
-- Name: index_forum_thread_link_clicks_on_forum_thread_link_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_thread_link_clicks_on_forum_thread_link_id ON topic_link_clicks USING btree (topic_link_id);


--
-- Name: index_forum_thread_links_on_forum_thread_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_thread_links_on_forum_thread_id ON topic_links USING btree (topic_id);


--
-- Name: index_forum_thread_links_on_forum_thread_id_and_post_id_and_url; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_forum_thread_links_on_forum_thread_id_and_post_id_and_url ON topic_links USING btree (topic_id, post_id, url);


--
-- Name: index_forum_thread_users_on_forum_thread_id_and_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_forum_thread_users_on_forum_thread_id_and_user_id ON topic_users USING btree (topic_id, user_id);


--
-- Name: index_forum_threads_on_bumped_at; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_threads_on_bumped_at ON topics USING btree (bumped_at DESC);


--
-- Name: index_forum_threads_on_category_id_and_sub_tag_and_bumped_at; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_threads_on_category_id_and_sub_tag_and_bumped_at ON topics USING btree (category_id, sub_tag, bumped_at);


--
-- Name: index_invites_on_email_and_invited_by_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_invites_on_email_and_invited_by_id ON invites USING btree (email, invited_by_id);


--
-- Name: index_invites_on_invite_key; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_invites_on_invite_key ON invites USING btree (invite_key);


--
-- Name: index_notifications_on_post_action_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_notifications_on_post_action_id ON notifications USING btree (post_action_id);


--
-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_notifications_on_user_id_and_created_at ON notifications USING btree (user_id, created_at);


--
-- Name: index_onebox_renders_on_url; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_onebox_renders_on_url ON onebox_renders USING btree (url);


--
-- Name: index_post_actions_on_post_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_post_actions_on_post_id ON post_actions USING btree (post_id);


--
-- Name: index_post_onebox_renders_on_post_id_and_onebox_render_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_post_onebox_renders_on_post_id_and_onebox_render_id ON post_onebox_renders USING btree (post_id, onebox_render_id);


--
-- Name: index_post_replies_on_post_id_and_reply_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_post_replies_on_post_id_and_reply_id ON post_replies USING btree (post_id, reply_id);


--
-- Name: index_posts_on_reply_to_post_number; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_reply_to_post_number ON posts USING btree (reply_to_post_number);


--
-- Name: index_posts_on_topic_id_and_post_number; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_posts_on_topic_id_and_post_number ON posts USING btree (topic_id, post_number);


--
-- Name: index_site_customizations_on_key; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_site_customizations_on_key ON site_customizations USING btree (key);


--
-- Name: index_topic_allowed_users_on_topic_id_and_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_topic_id_and_user_id ON topic_allowed_users USING btree (topic_id, user_id);


--
-- Name: index_topic_allowed_users_on_user_id_and_topic_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_user_id_and_topic_id ON topic_allowed_users USING btree (user_id, topic_id);


--
-- Name: index_topic_invites_on_invite_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_topic_invites_on_invite_id ON topic_invites USING btree (invite_id);


--
-- Name: index_topic_invites_on_topic_id_and_invite_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_invites_on_topic_id_and_invite_id ON topic_invites USING btree (topic_id, invite_id);


--
-- Name: index_twitter_user_infos_on_twitter_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_twitter_user_infos_on_twitter_user_id ON twitter_user_infos USING btree (twitter_user_id);


--
-- Name: index_twitter_user_infos_on_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_twitter_user_infos_on_user_id ON twitter_user_infos USING btree (user_id);


--
-- Name: index_uploads_on_forum_thread_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_uploads_on_forum_thread_id ON uploads USING btree (topic_id);


--
-- Name: index_uploads_on_user_id; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_uploads_on_user_id ON uploads USING btree (user_id);


--
-- Name: index_user_open_ids_on_url; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_user_open_ids_on_url ON user_open_ids USING btree (url);


--
-- Name: index_user_visits_on_user_id_and_visited_at; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_user_visits_on_user_id_and_visited_at ON user_visits USING btree (user_id, visited_at);


--
-- Name: index_users_on_auth_token; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_auth_token ON users USING btree (auth_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_last_posted_at; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_last_posted_at ON users USING btree (last_posted_at);


--
-- Name: index_users_on_username; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username ON users USING btree (username);


--
-- Name: index_users_on_username_lower; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username_lower ON users USING btree (username_lower);


--
-- Name: index_versions_on_created_at; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_created_at ON versions USING btree (created_at);


--
-- Name: index_versions_on_number; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_number ON versions USING btree (number);


--
-- Name: index_versions_on_tag; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_tag ON versions USING btree (tag);


--
-- Name: index_versions_on_user_id_and_user_type; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_user_id_and_user_type ON versions USING btree (user_id, user_type);


--
-- Name: index_versions_on_user_name; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_user_name ON versions USING btree (user_name);


--
-- Name: index_versions_on_versioned_id_and_versioned_type; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_versioned_id_and_versioned_type ON versions USING btree (versioned_id, versioned_type);


--
-- Name: index_views_on_parent_id_and_parent_type; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX index_views_on_parent_id_and_parent_type ON views USING btree (parent_id, parent_type);


--
-- Name: post_timings_summary; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE INDEX post_timings_summary ON post_timings USING btree (topic_id, post_number);


--
-- Name: post_timings_unique; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX post_timings_unique ON post_timings USING btree (topic_id, post_number, user_id);


--
-- Name: unique_views; Type: INDEX; Schema: backup; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_views ON views USING btree (parent_id, parent_type, ip, viewed_at);


SET search_path = public, pg_catalog;

--
-- Name: cat_featured_threads; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX cat_featured_threads ON category_featured_topics USING btree (category_id, topic_id);


--
-- Name: idx_search_category; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_search_category ON categories_search USING gin (search_data);


--
-- Name: idx_search_post; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_search_post ON posts_search USING gin (search_data);


--
-- Name: idx_search_user; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX idx_search_user ON users_search USING gin (search_data);


--
-- Name: idx_unique_actions; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_actions ON post_actions USING btree (user_id, post_action_type_id, post_id, deleted_at);


--
-- Name: idx_unique_rows; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_unique_rows ON user_actions USING btree (action_type, user_id, target_topic_id, target_post_id, acting_user_id);


--
-- Name: incoming_index; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX incoming_index ON incoming_links USING btree (topic_id, post_number);


--
-- Name: index_actions_on_acting_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_actions_on_acting_user_id ON user_actions USING btree (acting_user_id);


--
-- Name: index_actions_on_user_id_and_action_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_actions_on_user_id_and_action_type ON user_actions USING btree (user_id, action_type);


--
-- Name: index_categories_on_forum_thread_count; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_categories_on_forum_thread_count ON categories USING btree (topic_count);


--
-- Name: index_categories_on_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_categories_on_name ON categories USING btree (name);


--
-- Name: index_category_featured_users_on_category_id_and_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_category_featured_users_on_category_id_and_user_id ON category_featured_users USING btree (category_id, user_id);


--
-- Name: index_draft_sequences_on_user_id_and_draft_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_draft_sequences_on_user_id_and_draft_key ON draft_sequences USING btree (user_id, draft_key);


--
-- Name: index_drafts_on_user_id_and_draft_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_drafts_on_user_id_and_draft_key ON drafts USING btree (user_id, draft_key);


--
-- Name: index_email_logs_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_email_logs_on_created_at ON email_logs USING btree (created_at DESC);


--
-- Name: index_email_logs_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_email_logs_on_user_id_and_created_at ON email_logs USING btree (user_id, created_at DESC);


--
-- Name: index_email_tokens_on_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_email_tokens_on_token ON email_tokens USING btree (token);


--
-- Name: index_facebook_user_infos_on_facebook_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_user_infos_on_facebook_user_id ON facebook_user_infos USING btree (facebook_user_id);


--
-- Name: index_facebook_user_infos_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_facebook_user_infos_on_user_id ON facebook_user_infos USING btree (user_id);


--
-- Name: index_forum_thread_link_clicks_on_forum_thread_link_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_thread_link_clicks_on_forum_thread_link_id ON topic_link_clicks USING btree (topic_link_id);


--
-- Name: index_forum_thread_links_on_forum_thread_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_thread_links_on_forum_thread_id ON topic_links USING btree (topic_id);


--
-- Name: index_forum_thread_links_on_forum_thread_id_and_post_id_and_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_forum_thread_links_on_forum_thread_id_and_post_id_and_url ON topic_links USING btree (topic_id, post_id, url);


--
-- Name: index_forum_thread_users_on_forum_thread_id_and_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_forum_thread_users_on_forum_thread_id_and_user_id ON topic_users USING btree (topic_id, user_id);


--
-- Name: index_forum_threads_on_bumped_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_forum_threads_on_bumped_at ON topics USING btree (bumped_at DESC);


--
-- Name: index_github_user_infos_on_github_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_github_user_infos_on_github_user_id ON github_user_infos USING btree (github_user_id);


--
-- Name: index_github_user_infos_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_github_user_infos_on_user_id ON github_user_infos USING btree (user_id);


--
-- Name: index_invites_on_email_and_invited_by_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_invites_on_email_and_invited_by_id ON invites USING btree (email, invited_by_id);


--
-- Name: index_invites_on_invite_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_invites_on_invite_key ON invites USING btree (invite_key);


--
-- Name: index_message_bus_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_message_bus_on_created_at ON message_bus USING btree (created_at);


--
-- Name: index_notifications_on_post_action_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notifications_on_post_action_id ON notifications USING btree (post_action_id);


--
-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_notifications_on_user_id_and_created_at ON notifications USING btree (user_id, created_at);


--
-- Name: index_onebox_renders_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_onebox_renders_on_url ON onebox_renders USING btree (url);


--
-- Name: index_post_actions_on_post_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_post_actions_on_post_id ON post_actions USING btree (post_id);


--
-- Name: index_post_onebox_renders_on_post_id_and_onebox_render_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_post_onebox_renders_on_post_id_and_onebox_render_id ON post_onebox_renders USING btree (post_id, onebox_render_id);


--
-- Name: index_post_replies_on_post_id_and_reply_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_post_replies_on_post_id_and_reply_id ON post_replies USING btree (post_id, reply_id);


--
-- Name: index_posts_on_reply_to_post_number; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_posts_on_reply_to_post_number ON posts USING btree (reply_to_post_number);


--
-- Name: index_posts_on_topic_id_and_post_number; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_posts_on_topic_id_and_post_number ON posts USING btree (topic_id, post_number);


--
-- Name: index_site_customizations_on_key; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_site_customizations_on_key ON site_customizations USING btree (key);


--
-- Name: index_topic_allowed_users_on_topic_id_and_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_topic_id_and_user_id ON topic_allowed_users USING btree (topic_id, user_id);


--
-- Name: index_topic_allowed_users_on_user_id_and_topic_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_user_id_and_topic_id ON topic_allowed_users USING btree (user_id, topic_id);


--
-- Name: index_topic_invites_on_invite_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_topic_invites_on_invite_id ON topic_invites USING btree (invite_id);


--
-- Name: index_topic_invites_on_topic_id_and_invite_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_topic_invites_on_topic_id_and_invite_id ON topic_invites USING btree (topic_id, invite_id);


--
-- Name: index_twitter_user_infos_on_twitter_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_twitter_user_infos_on_twitter_user_id ON twitter_user_infos USING btree (twitter_user_id);


--
-- Name: index_twitter_user_infos_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_twitter_user_infos_on_user_id ON twitter_user_infos USING btree (user_id);


--
-- Name: index_uploads_on_forum_thread_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_uploads_on_forum_thread_id ON uploads USING btree (topic_id);


--
-- Name: index_uploads_on_user_id; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_uploads_on_user_id ON uploads USING btree (user_id);


--
-- Name: index_user_open_ids_on_url; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_user_open_ids_on_url ON user_open_ids USING btree (url);


--
-- Name: index_user_visits_on_user_id_and_visited_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_user_visits_on_user_id_and_visited_at ON user_visits USING btree (user_id, visited_at);


--
-- Name: index_users_on_auth_token; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_auth_token ON users USING btree (auth_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_email ON users USING btree (email);


--
-- Name: index_users_on_last_posted_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_users_on_last_posted_at ON users USING btree (last_posted_at);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username ON users USING btree (username);


--
-- Name: index_users_on_username_lower; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX index_users_on_username_lower ON users USING btree (username_lower);


--
-- Name: index_versions_on_created_at; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_created_at ON versions USING btree (created_at);


--
-- Name: index_versions_on_number; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_number ON versions USING btree (number);


--
-- Name: index_versions_on_tag; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_tag ON versions USING btree (tag);


--
-- Name: index_versions_on_user_id_and_user_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_user_id_and_user_type ON versions USING btree (user_id, user_type);


--
-- Name: index_versions_on_user_name; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_user_name ON versions USING btree (user_name);


--
-- Name: index_versions_on_versioned_id_and_versioned_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_versions_on_versioned_id_and_versioned_type ON versions USING btree (versioned_id, versioned_type);


--
-- Name: index_views_on_parent_id_and_parent_type; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX index_views_on_parent_id_and_parent_type ON views USING btree (parent_id, parent_type);


--
-- Name: post_timings_summary; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE INDEX post_timings_summary ON post_timings USING btree (topic_id, post_number);


--
-- Name: post_timings_unique; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX post_timings_unique ON post_timings USING btree (topic_id, post_number, user_id);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX unique_schema_migrations ON schema_migrations USING btree (version);


--
-- PostgreSQL database dump complete
--

INSERT INTO schema_migrations (version) VALUES ('20120311163914');

INSERT INTO schema_migrations (version) VALUES ('20120311164326');

INSERT INTO schema_migrations (version) VALUES ('20120311170118');

INSERT INTO schema_migrations (version) VALUES ('20120311201341');

INSERT INTO schema_migrations (version) VALUES ('20120311210245');

INSERT INTO schema_migrations (version) VALUES ('20120416201606');

INSERT INTO schema_migrations (version) VALUES ('20120420183447');

INSERT INTO schema_migrations (version) VALUES ('20120423140906');

INSERT INTO schema_migrations (version) VALUES ('20120423142820');

INSERT INTO schema_migrations (version) VALUES ('20120423151548');

INSERT INTO schema_migrations (version) VALUES ('20120425145456');

INSERT INTO schema_migrations (version) VALUES ('20120427150624');

INSERT INTO schema_migrations (version) VALUES ('20120427151452');

INSERT INTO schema_migrations (version) VALUES ('20120427154330');

INSERT INTO schema_migrations (version) VALUES ('20120427172031');

INSERT INTO schema_migrations (version) VALUES ('20120502183240');

INSERT INTO schema_migrations (version) VALUES ('20120502192121');

INSERT INTO schema_migrations (version) VALUES ('20120503205521');

INSERT INTO schema_migrations (version) VALUES ('20120507144132');

INSERT INTO schema_migrations (version) VALUES ('20120507144222');

INSERT INTO schema_migrations (version) VALUES ('20120514144549');

INSERT INTO schema_migrations (version) VALUES ('20120514173920');

INSERT INTO schema_migrations (version) VALUES ('20120514204934');

INSERT INTO schema_migrations (version) VALUES ('20120517200130');

INSERT INTO schema_migrations (version) VALUES ('20120518200115');

INSERT INTO schema_migrations (version) VALUES ('20120519182212');

INSERT INTO schema_migrations (version) VALUES ('20120523180723');

INSERT INTO schema_migrations (version) VALUES ('20120523184307');

INSERT INTO schema_migrations (version) VALUES ('20120523201329');

INSERT INTO schema_migrations (version) VALUES ('20120525194845');

INSERT INTO schema_migrations (version) VALUES ('20120529175956');

INSERT INTO schema_migrations (version) VALUES ('20120529202707');

INSERT INTO schema_migrations (version) VALUES ('20120530150726');

INSERT INTO schema_migrations (version) VALUES ('20120530160745');

INSERT INTO schema_migrations (version) VALUES ('20120530200724');

INSERT INTO schema_migrations (version) VALUES ('20120530212912');

INSERT INTO schema_migrations (version) VALUES ('20120614190726');

INSERT INTO schema_migrations (version) VALUES ('20120614202024');

INSERT INTO schema_migrations (version) VALUES ('20120615180517');

INSERT INTO schema_migrations (version) VALUES ('20120618152946');

INSERT INTO schema_migrations (version) VALUES ('20120618212349');

INSERT INTO schema_migrations (version) VALUES ('20120618214856');

INSERT INTO schema_migrations (version) VALUES ('20120619150807');

INSERT INTO schema_migrations (version) VALUES ('20120619153349');

INSERT INTO schema_migrations (version) VALUES ('20120619172714');

INSERT INTO schema_migrations (version) VALUES ('20120621155351');

INSERT INTO schema_migrations (version) VALUES ('20120621190310');

INSERT INTO schema_migrations (version) VALUES ('20120622200242');

INSERT INTO schema_migrations (version) VALUES ('20120625145714');

INSERT INTO schema_migrations (version) VALUES ('20120625162318');

INSERT INTO schema_migrations (version) VALUES ('20120625174544');

INSERT INTO schema_migrations (version) VALUES ('20120625195326');

INSERT INTO schema_migrations (version) VALUES ('20120629143908');

INSERT INTO schema_migrations (version) VALUES ('20120629150253');

INSERT INTO schema_migrations (version) VALUES ('20120629151243');

INSERT INTO schema_migrations (version) VALUES ('20120629182637');

INSERT INTO schema_migrations (version) VALUES ('20120702211427');

INSERT INTO schema_migrations (version) VALUES ('20120703184734');

INSERT INTO schema_migrations (version) VALUES ('20120703201312');

INSERT INTO schema_migrations (version) VALUES ('20120703203623');

INSERT INTO schema_migrations (version) VALUES ('20120703210004');

INSERT INTO schema_migrations (version) VALUES ('20120704160659');

INSERT INTO schema_migrations (version) VALUES ('20120704201743');

INSERT INTO schema_migrations (version) VALUES ('20120705181724');

INSERT INTO schema_migrations (version) VALUES ('20120708210305');

INSERT INTO schema_migrations (version) VALUES ('20120712150500');

INSERT INTO schema_migrations (version) VALUES ('20120712151934');

INSERT INTO schema_migrations (version) VALUES ('20120713201324');

INSERT INTO schema_migrations (version) VALUES ('20120716020835');

INSERT INTO schema_migrations (version) VALUES ('20120716173544');

INSERT INTO schema_migrations (version) VALUES ('20120718044955');

INSERT INTO schema_migrations (version) VALUES ('20120719004636');

INSERT INTO schema_migrations (version) VALUES ('20120720013733');

INSERT INTO schema_migrations (version) VALUES ('20120720044246');

INSERT INTO schema_migrations (version) VALUES ('20120720162422');

INSERT INTO schema_migrations (version) VALUES ('20120723051512');

INSERT INTO schema_migrations (version) VALUES ('20120724234502');

INSERT INTO schema_migrations (version) VALUES ('20120724234711');

INSERT INTO schema_migrations (version) VALUES ('20120725183347');

INSERT INTO schema_migrations (version) VALUES ('20120726201830');

INSERT INTO schema_migrations (version) VALUES ('20120726235129');

INSERT INTO schema_migrations (version) VALUES ('20120727005556');

INSERT INTO schema_migrations (version) VALUES ('20120727150428');

INSERT INTO schema_migrations (version) VALUES ('20120727213543');

INSERT INTO schema_migrations (version) VALUES ('20120802151210');

INSERT INTO schema_migrations (version) VALUES ('20120803191426');

INSERT INTO schema_migrations (version) VALUES ('20120806030641');

INSERT INTO schema_migrations (version) VALUES ('20120806062617');

INSERT INTO schema_migrations (version) VALUES ('20120807223020');

INSERT INTO schema_migrations (version) VALUES ('20120809020415');

INSERT INTO schema_migrations (version) VALUES ('20120809030647');

INSERT INTO schema_migrations (version) VALUES ('20120809053414');

INSERT INTO schema_migrations (version) VALUES ('20120809154750');

INSERT INTO schema_migrations (version) VALUES ('20120809174649');

INSERT INTO schema_migrations (version) VALUES ('20120809175110');

INSERT INTO schema_migrations (version) VALUES ('20120809201855');

INSERT INTO schema_migrations (version) VALUES ('20120810064839');

INSERT INTO schema_migrations (version) VALUES ('20120812235417');

INSERT INTO schema_migrations (version) VALUES ('20120813004347');

INSERT INTO schema_migrations (version) VALUES ('20120813042912');

INSERT INTO schema_migrations (version) VALUES ('20120813201426');

INSERT INTO schema_migrations (version) VALUES ('20120815004411');

INSERT INTO schema_migrations (version) VALUES ('20120815180106');

INSERT INTO schema_migrations (version) VALUES ('20120815204733');

INSERT INTO schema_migrations (version) VALUES ('20120816050526');

INSERT INTO schema_migrations (version) VALUES ('20120816205537');

INSERT INTO schema_migrations (version) VALUES ('20120816205538');

INSERT INTO schema_migrations (version) VALUES ('20120820191804');

INSERT INTO schema_migrations (version) VALUES ('20120821191616');

INSERT INTO schema_migrations (version) VALUES ('20120823205956');

INSERT INTO schema_migrations (version) VALUES ('20120824171908');

INSERT INTO schema_migrations (version) VALUES ('20120828204209');

INSERT INTO schema_migrations (version) VALUES ('20120828204624');

INSERT INTO schema_migrations (version) VALUES ('20120830182736');

INSERT INTO schema_migrations (version) VALUES ('20120910171504');

INSERT INTO schema_migrations (version) VALUES ('20120918152319');

INSERT INTO schema_migrations (version) VALUES ('20120918205931');

INSERT INTO schema_migrations (version) VALUES ('20120919152846');

INSERT INTO schema_migrations (version) VALUES ('20120921055428');

INSERT INTO schema_migrations (version) VALUES ('20120921155050');

INSERT INTO schema_migrations (version) VALUES ('20120921162512');

INSERT INTO schema_migrations (version) VALUES ('20120921163606');

INSERT INTO schema_migrations (version) VALUES ('20120924182000');

INSERT INTO schema_migrations (version) VALUES ('20120924182031');

INSERT INTO schema_migrations (version) VALUES ('20120925171620');

INSERT INTO schema_migrations (version) VALUES ('20120925190802');

INSERT INTO schema_migrations (version) VALUES ('20120928170023');

INSERT INTO schema_migrations (version) VALUES ('20121009161116');

INSERT INTO schema_migrations (version) VALUES ('20121011155904');

INSERT INTO schema_migrations (version) VALUES ('20121017162924');

INSERT INTO schema_migrations (version) VALUES ('20121018103721');

INSERT INTO schema_migrations (version) VALUES ('20121018133039');

INSERT INTO schema_migrations (version) VALUES ('20121018182709');

INSERT INTO schema_migrations (version) VALUES ('20121106015500');

INSERT INTO schema_migrations (version) VALUES ('20121108193516');

INSERT INTO schema_migrations (version) VALUES ('20121109164630');

INSERT INTO schema_migrations (version) VALUES ('20121113200844');

INSERT INTO schema_migrations (version) VALUES ('20121113200845');

INSERT INTO schema_migrations (version) VALUES ('20121115172544');

INSERT INTO schema_migrations (version) VALUES ('20121116212424');

INSERT INTO schema_migrations (version) VALUES ('20121119190529');

INSERT INTO schema_migrations (version) VALUES ('20121119200843');

INSERT INTO schema_migrations (version) VALUES ('20121121202035');

INSERT INTO schema_migrations (version) VALUES ('20121121205215');

INSERT INTO schema_migrations (version) VALUES ('20121122033316');

INSERT INTO schema_migrations (version) VALUES ('20121123054127');

INSERT INTO schema_migrations (version) VALUES ('20121123063630');

INSERT INTO schema_migrations (version) VALUES ('20121129160035');

INSERT INTO schema_migrations (version) VALUES ('20121129184948');

INSERT INTO schema_migrations (version) VALUES ('20121130010400');

INSERT INTO schema_migrations (version) VALUES ('20121130191818');

INSERT INTO schema_migrations (version) VALUES ('20121202225421');

INSERT INTO schema_migrations (version) VALUES ('20121203181719');

INSERT INTO schema_migrations (version) VALUES ('20121204183855');

INSERT INTO schema_migrations (version) VALUES ('20121204193747');

INSERT INTO schema_migrations (version) VALUES ('20121205162143');

INSERT INTO schema_migrations (version) VALUES ('20121207000741');

INSERT INTO schema_migrations (version) VALUES ('20121211233131');

INSERT INTO schema_migrations (version) VALUES ('20121216230719');

INSERT INTO schema_migrations (version) VALUES ('20121218205642');

INSERT INTO schema_migrations (version) VALUES ('20121224072204');

INSERT INTO schema_migrations (version) VALUES ('20121224095139');

INSERT INTO schema_migrations (version) VALUES ('20121224100650');

INSERT INTO schema_migrations (version) VALUES ('20121228192219');

INSERT INTO schema_migrations (version) VALUES ('20130107165207');

INSERT INTO schema_migrations (version) VALUES ('20130108195847');

INSERT INTO schema_migrations (version) VALUES ('20130115012140');

INSERT INTO schema_migrations (version) VALUES ('20130115021937');

INSERT INTO schema_migrations (version) VALUES ('20130115043603');

INSERT INTO schema_migrations (version) VALUES ('20130116151829');

INSERT INTO schema_migrations (version) VALUES ('20130120222728');

INSERT INTO schema_migrations (version) VALUES ('20130121231352');

INSERT INTO schema_migrations (version) VALUES ('20130122051134');

INSERT INTO schema_migrations (version) VALUES ('20130122232825');

INSERT INTO schema_migrations (version) VALUES ('20130123070909');

INSERT INTO schema_migrations (version) VALUES ('20130125002652');

INSERT INTO schema_migrations (version) VALUES ('20130125030305');

INSERT INTO schema_migrations (version) VALUES ('20130125031122');

INSERT INTO schema_migrations (version) VALUES ('20130127213646');

INSERT INTO schema_migrations (version) VALUES ('20130128182013');

INSERT INTO schema_migrations (version) VALUES ('20130129010625');

INSERT INTO schema_migrations (version) VALUES ('20130129163244');

INSERT INTO schema_migrations (version) VALUES ('20130129174845');

INSERT INTO schema_migrations (version) VALUES ('20130130154611');

INSERT INTO schema_migrations (version) VALUES ('20130131055710');

INSERT INTO schema_migrations (version) VALUES ('20130201000828');

INSERT INTO schema_migrations (version) VALUES ('20130201023409');

INSERT INTO schema_migrations (version) VALUES ('20130203204338');

INSERT INTO schema_migrations (version) VALUES ('20130204000159');

INSERT INTO schema_migrations (version) VALUES ('20130205021905');

INSERT INTO schema_migrations (version) VALUES ('20130207200019');

INSERT INTO schema_migrations (version) VALUES ('20130208220635');

INSERT INTO schema_migrations (version) VALUES ('20130213021450');

INSERT INTO schema_migrations (version) VALUES ('20130213203300');

INSERT INTO schema_migrations (version) VALUES ('20130221215017');

INSERT INTO schema_migrations (version) VALUES ('20130226015336');