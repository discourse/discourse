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
-- Name: discourse_functions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA discourse_functions;


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: ai_moderation_setting_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ai_moderation_setting_type AS ENUM (
    'spam',
    'nsfw',
    'custom'
);


--
-- Name: hotlinked_media_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.hotlinked_media_status AS ENUM (
    'downloaded',
    'too_large',
    'download_failed',
    'upload_create_failed'
);


--
-- Name: raise_category_settings_require_reply_approval_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -
--

CREATE FUNCTION discourse_functions.raise_category_settings_require_reply_approval_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: require_reply_approval in category_settings is readonly';
  END
$$;


--
-- Name: raise_category_settings_require_topic_approval_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -
--

CREATE FUNCTION discourse_functions.raise_category_settings_require_topic_approval_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: require_topic_approval in category_settings is readonly';
  END
$$;


--
-- Name: raise_discourse_rss_polling_rss_feeds_author_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -
--

CREATE FUNCTION discourse_functions.raise_discourse_rss_polling_rss_feeds_author_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: author in discourse_rss_polling_rss_feeds is readonly';
  END
$$;


--
-- Name: raise_discourse_voting_category_settings_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -
--

CREATE FUNCTION discourse_functions.raise_discourse_voting_category_settings_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: discourse_voting_category_settings is read only';
  END
$$;


--
-- Name: raise_discourse_voting_topic_vote_count_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -
--

CREATE FUNCTION discourse_functions.raise_discourse_voting_topic_vote_count_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: discourse_voting_topic_vote_count is read only';
  END
$$;


--
-- Name: raise_discourse_voting_votes_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -
--

CREATE FUNCTION discourse_functions.raise_discourse_voting_votes_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: discourse_voting_votes is read only';
  END
$$;


--
-- Name: raise_topic_timers_topic_id_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -
--

CREATE FUNCTION discourse_functions.raise_topic_timers_topic_id_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: topic_id in topic_timers is readonly';
  END
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: access_control_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.access_control_lists (
    id bigint NOT NULL,
    target_type character varying(255) NOT NULL,
    target_id bigint NOT NULL,
    owner character varying(100) NOT NULL,
    permission character varying(100) NOT NULL,
    allowed_user_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    allowed_group_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: access_control_lists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.access_control_lists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: access_control_lists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.access_control_lists_id_seq OWNED BY public.access_control_lists.id;


--
-- Name: ad_plugin_house_ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_plugin_house_ads (
    id bigint NOT NULL,
    name character varying NOT NULL,
    html text NOT NULL,
    visible_to_logged_in_users boolean DEFAULT true NOT NULL,
    visible_to_anons boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ad_plugin_house_ads_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_plugin_house_ads_categories (
    ad_plugin_house_ad_id bigint NOT NULL,
    category_id bigint NOT NULL
);


--
-- Name: ad_plugin_house_ads_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_plugin_house_ads_groups (
    ad_plugin_house_ad_id bigint NOT NULL,
    group_id bigint NOT NULL
);


--
-- Name: ad_plugin_house_ads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ad_plugin_house_ads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ad_plugin_house_ads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ad_plugin_house_ads_id_seq OWNED BY public.ad_plugin_house_ads.id;


--
-- Name: ad_plugin_house_ads_routes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_plugin_house_ads_routes (
    ad_plugin_house_ad_id bigint NOT NULL,
    route_name character varying NOT NULL
);


--
-- Name: ad_plugin_impressions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_plugin_impressions (
    id bigint NOT NULL,
    ad_type integer NOT NULL,
    ad_plugin_house_ad_id bigint,
    placement character varying NOT NULL,
    user_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    clicked_at timestamp(6) without time zone
);


--
-- Name: ad_plugin_impressions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ad_plugin_impressions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ad_plugin_impressions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ad_plugin_impressions_id_seq OWNED BY public.ad_plugin_impressions.id;


--
-- Name: admin_dashboard_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_dashboard_reports (
    id bigint NOT NULL,
    "position" integer NOT NULL,
    source character varying NOT NULL,
    identifier character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: admin_dashboard_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_dashboard_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_dashboard_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_dashboard_reports_id_seq OWNED BY public.admin_dashboard_reports.id;


--
-- Name: admin_dashboard_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_dashboard_sections (
    id bigint NOT NULL,
    section_id character varying NOT NULL,
    "position" integer NOT NULL,
    visible boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: admin_dashboard_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_dashboard_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_dashboard_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_dashboard_sections_id_seq OWNED BY public.admin_dashboard_sections.id;


--
-- Name: admin_notices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_notices (
    id bigint NOT NULL,
    subject integer NOT NULL,
    priority integer NOT NULL,
    identifier character varying NOT NULL,
    details json DEFAULT '{}'::json NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: admin_notices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_notices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_notices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_notices_id_seq OWNED BY public.admin_notices.id;


--
-- Name: ai_agent_mcp_servers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_agent_mcp_servers (
    id bigint NOT NULL,
    ai_agent_id bigint NOT NULL,
    ai_mcp_server_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    selected_tool_names jsonb
);


--
-- Name: ai_agent_mcp_servers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_agent_mcp_servers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_agent_mcp_servers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_agent_mcp_servers_id_seq OWNED BY public.ai_agent_mcp_servers.id;


--
-- Name: ai_agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_agents (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(2000) NOT NULL,
    system_prompt character varying(10000000) NOT NULL,
    allowed_group_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    created_by_id integer,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    system boolean DEFAULT false NOT NULL,
    priority boolean DEFAULT false NOT NULL,
    temperature double precision,
    top_p double precision,
    user_id integer,
    max_context_posts integer,
    vision_enabled boolean DEFAULT false NOT NULL,
    vision_max_pixels integer DEFAULT 1048576 NOT NULL,
    rag_chunk_tokens integer DEFAULT 374 NOT NULL,
    rag_chunk_overlap_tokens integer DEFAULT 10 NOT NULL,
    rag_conversation_chunks integer DEFAULT 10 NOT NULL,
    tools json DEFAULT '[]'::json NOT NULL,
    forced_tool_count integer DEFAULT '-1'::integer NOT NULL,
    allow_chat_channel_mentions boolean DEFAULT false NOT NULL,
    allow_chat_direct_messages boolean DEFAULT false NOT NULL,
    allow_topic_mentions boolean DEFAULT false NOT NULL,
    allow_personal_messages boolean DEFAULT true NOT NULL,
    force_default_llm boolean DEFAULT false NOT NULL,
    rag_llm_model_id bigint,
    default_llm_id bigint,
    question_consolidator_llm_id bigint,
    response_format jsonb,
    examples jsonb,
    show_thinking boolean DEFAULT true NOT NULL,
    max_turn_tokens integer,
    compression_threshold integer,
    execution_mode character varying DEFAULT 'default'::character varying NOT NULL,
    require_approval boolean DEFAULT false NOT NULL,
    thinking_effort character varying
);


--
-- Name: ai_agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_agents_id_seq OWNED BY public.ai_agents.id;


--
-- Name: ai_api_audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_api_audit_logs (
    id bigint NOT NULL,
    provider_id integer NOT NULL,
    user_id integer,
    request_tokens integer,
    response_tokens integer,
    raw_request_payload character varying,
    raw_response_payload character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    topic_id integer,
    post_id integer,
    feature_name character varying(255),
    language_model character varying(255),
    feature_context jsonb,
    duration_msecs integer,
    cache_write_tokens integer,
    cache_read_tokens integer,
    llm_id bigint,
    response_status integer,
    request_attempts jsonb,
    estimated_cost numeric(20,10)
);


--
-- Name: ai_api_audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_api_audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_api_audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_api_audit_logs_id_seq OWNED BY public.ai_api_audit_logs.id;


--
-- Name: ai_api_request_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_api_request_stats (
    id bigint NOT NULL,
    bucket_date timestamp(6) without time zone NOT NULL,
    user_id bigint,
    provider_id integer NOT NULL,
    llm_id bigint,
    language_model character varying(255),
    feature_name character varying(255),
    request_tokens integer DEFAULT 0 NOT NULL,
    response_tokens integer DEFAULT 0 NOT NULL,
    cache_read_tokens integer DEFAULT 0 NOT NULL,
    cache_write_tokens integer DEFAULT 0 NOT NULL,
    usage_count integer DEFAULT 1 NOT NULL,
    rolled_up boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    estimated_cost numeric(20,10)
);


--
-- Name: ai_api_request_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_api_request_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_api_request_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_api_request_stats_id_seq OWNED BY public.ai_api_request_stats.id;


--
-- Name: ai_artifact_key_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_artifact_key_values (
    id bigint NOT NULL,
    ai_artifact_id bigint NOT NULL,
    user_id integer NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(20000) NOT NULL,
    public boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_artifact_key_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_artifact_key_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_artifact_key_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_artifact_key_values_id_seq OWNED BY public.ai_artifact_key_values.id;


--
-- Name: ai_artifact_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_artifact_versions (
    id bigint NOT NULL,
    ai_artifact_id bigint NOT NULL,
    version_number integer NOT NULL,
    html character varying(65535),
    css character varying(65535),
    js character varying(65535),
    metadata jsonb,
    change_description character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_artifact_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_artifact_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_artifact_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_artifact_versions_id_seq OWNED BY public.ai_artifact_versions.id;


--
-- Name: ai_artifacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_artifacts (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    name character varying(255) NOT NULL,
    html character varying(65535),
    css character varying(65535),
    js character varying(65535),
    metadata jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_artifacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_artifacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_artifacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_artifacts_id_seq OWNED BY public.ai_artifacts.id;


--
-- Name: ai_document_fragments_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_document_fragments_embeddings (
    rag_document_fragment_id bigint NOT NULL,
    model_id bigint NOT NULL,
    model_version integer NOT NULL,
    strategy_id integer NOT NULL,
    strategy_version integer NOT NULL,
    digest text NOT NULL,
    embeddings public.halfvec NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_mcp_oauth_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_mcp_oauth_tokens (
    id bigint NOT NULL,
    ai_mcp_server_id bigint NOT NULL,
    access_token text,
    refresh_token text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_mcp_oauth_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_mcp_oauth_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_mcp_oauth_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_mcp_oauth_tokens_id_seq OWNED BY public.ai_mcp_oauth_tokens.id;


--
-- Name: ai_mcp_servers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_mcp_servers (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(1000) NOT NULL,
    url character varying(1000) NOT NULL,
    ai_secret_id bigint,
    auth_header character varying(100) DEFAULT 'Authorization'::character varying NOT NULL,
    auth_scheme character varying(100) DEFAULT 'Bearer'::character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    timeout_seconds integer DEFAULT 30 NOT NULL,
    last_health_status character varying(50),
    last_health_error character varying(1000),
    last_checked_at timestamp(6) without time zone,
    last_tools_synced_at timestamp(6) without time zone,
    server_capabilities jsonb DEFAULT '{}'::jsonb NOT NULL,
    protocol_version character varying(100),
    created_by_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    auth_type character varying(50) DEFAULT 'header_secret'::character varying NOT NULL,
    oauth_client_registration character varying(50) DEFAULT 'client_metadata_document'::character varying,
    oauth_client_id character varying(1000),
    oauth_client_secret_ai_secret_id bigint,
    oauth_scopes character varying(2000),
    oauth_granted_scopes character varying(2000),
    oauth_token_type character varying(100),
    oauth_access_token_expires_at timestamp(6) without time zone,
    oauth_authorization_endpoint character varying(1000),
    oauth_token_endpoint character varying(1000),
    oauth_revocation_endpoint character varying(1000),
    oauth_issuer character varying(1000),
    oauth_resource_metadata_url character varying(1000),
    oauth_status character varying(50) DEFAULT 'disconnected'::character varying NOT NULL,
    oauth_last_error character varying(1000),
    oauth_last_authorized_at timestamp(6) without time zone,
    oauth_last_refreshed_at timestamp(6) without time zone,
    oauth_registration_endpoint character varying(1000),
    oauth_authorization_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    oauth_token_params jsonb DEFAULT '{}'::jsonb NOT NULL,
    oauth_require_refresh_token boolean DEFAULT false NOT NULL,
    oauth_token_endpoint_auth_methods_supported jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: ai_mcp_servers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_mcp_servers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_mcp_servers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_mcp_servers_id_seq OWNED BY public.ai_mcp_servers.id;


--
-- Name: ai_moderation_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_moderation_settings (
    id bigint NOT NULL,
    setting_type public.ai_moderation_setting_type NOT NULL,
    data jsonb DEFAULT '{}'::jsonb,
    llm_model_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    ai_agent_id bigint DEFAULT '-31'::integer NOT NULL
);


--
-- Name: ai_moderation_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_moderation_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_moderation_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_moderation_settings_id_seq OWNED BY public.ai_moderation_settings.id;


--
-- Name: ai_posts_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_posts_embeddings (
    post_id bigint NOT NULL,
    model_id bigint NOT NULL,
    model_version integer NOT NULL,
    strategy_id integer NOT NULL,
    strategy_version integer NOT NULL,
    digest text NOT NULL,
    embeddings public.halfvec NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_secrets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_secrets (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    secret character varying(10000) NOT NULL,
    created_by_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_secrets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_secrets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_secrets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_secrets_id_seq OWNED BY public.ai_secrets.id;


--
-- Name: ai_spam_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_spam_logs (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    llm_model_id bigint NOT NULL,
    ai_api_audit_log_id bigint,
    reviewable_id bigint,
    is_spam boolean NOT NULL,
    payload character varying(20000) DEFAULT ''::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    error character varying(3000),
    reason text
);


--
-- Name: ai_spam_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_spam_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_spam_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_spam_logs_id_seq OWNED BY public.ai_spam_logs.id;


--
-- Name: ai_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_summaries (
    id bigint NOT NULL,
    target_id integer NOT NULL,
    target_type character varying NOT NULL,
    summarized_text character varying NOT NULL,
    original_content_sha character varying NOT NULL,
    algorithm character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    summary_type integer DEFAULT 0 NOT NULL,
    origin integer,
    highest_target_number integer DEFAULT 1 NOT NULL
);


--
-- Name: ai_summaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_summaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_summaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_summaries_id_seq OWNED BY public.ai_summaries.id;


--
-- Name: ai_tool_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_tool_actions (
    id bigint NOT NULL,
    tool_name character varying NOT NULL,
    tool_parameters jsonb DEFAULT '{}'::jsonb NOT NULL,
    ai_agent_id bigint NOT NULL,
    bot_user_id integer NOT NULL,
    post_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_tool_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_tool_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_tool_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_tool_actions_id_seq OWNED BY public.ai_tool_actions.id;


--
-- Name: ai_tool_secret_bindings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_tool_secret_bindings (
    id bigint NOT NULL,
    ai_tool_id bigint NOT NULL,
    alias character varying(100) NOT NULL,
    ai_secret_id bigint NOT NULL,
    created_by_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ai_tool_secret_bindings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_tool_secret_bindings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_tool_secret_bindings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_tool_secret_bindings_id_seq OWNED BY public.ai_tool_secret_bindings.id;


--
-- Name: ai_tools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_tools (
    id bigint NOT NULL,
    name character varying NOT NULL,
    description character varying NOT NULL,
    summary character varying NOT NULL,
    parameters jsonb DEFAULT '{}'::jsonb NOT NULL,
    script text NOT NULL,
    created_by_id integer NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    rag_chunk_tokens integer DEFAULT 374 NOT NULL,
    rag_chunk_overlap_tokens integer DEFAULT 10 NOT NULL,
    tool_name character varying(100) DEFAULT ''::character varying NOT NULL,
    rag_llm_model_id bigint,
    is_image_generation_tool boolean DEFAULT false NOT NULL,
    secret_contracts jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: ai_tools_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_tools_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_tools_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_tools_id_seq OWNED BY public.ai_tools.id;


--
-- Name: ai_topics_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_topics_embeddings (
    topic_id bigint NOT NULL,
    model_id bigint NOT NULL,
    model_version integer NOT NULL,
    strategy_id integer NOT NULL,
    strategy_version integer NOT NULL,
    digest text NOT NULL,
    embeddings public.halfvec NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: allowed_pm_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.allowed_pm_users (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    allowed_pm_user_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: allowed_pm_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.allowed_pm_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: allowed_pm_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.allowed_pm_users_id_seq OWNED BY public.allowed_pm_users.id;


--
-- Name: anonymous_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.anonymous_users (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    master_user_id integer NOT NULL,
    active boolean NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: anonymous_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.anonymous_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: anonymous_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.anonymous_users_id_seq OWNED BY public.anonymous_users.id;


--
-- Name: api_key_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_key_scopes (
    id bigint NOT NULL,
    api_key_id integer NOT NULL,
    resource character varying NOT NULL,
    action character varying NOT NULL,
    allowed_parameters json,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: api_key_scopes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_key_scopes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_key_scopes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_key_scopes_id_seq OWNED BY public.api_key_scopes.id;


--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_keys (
    id integer NOT NULL,
    user_id integer,
    created_by_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    allowed_ips inet[],
    hidden boolean DEFAULT false NOT NULL,
    last_used_at timestamp without time zone,
    revoked_at timestamp without time zone,
    description text,
    key_hash character varying NOT NULL,
    truncated_key character varying NOT NULL,
    scope_mode integer
);


--
-- Name: api_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_keys_id_seq OWNED BY public.api_keys.id;


--
-- Name: application_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.application_requests (
    id integer NOT NULL,
    date date NOT NULL,
    req_type integer NOT NULL,
    count integer DEFAULT 0 NOT NULL
);


--
-- Name: application_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.application_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: application_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.application_requests_id_seq OWNED BY public.application_requests.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assignments (
    id bigint NOT NULL,
    topic_id integer NOT NULL,
    assigned_to_id integer NOT NULL,
    assigned_by_user_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    assigned_to_type character varying NOT NULL,
    target_id integer NOT NULL,
    target_type character varying NOT NULL,
    active boolean DEFAULT true,
    note character varying,
    status text
);


--
-- Name: assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.assignments_id_seq OWNED BY public.assignments.id;


--
-- Name: associated_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.associated_groups (
    id bigint NOT NULL,
    name character varying NOT NULL,
    provider_name character varying NOT NULL,
    provider_id character varying NOT NULL,
    last_used timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: associated_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.associated_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: associated_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.associated_groups_id_seq OWNED BY public.associated_groups.id;


--
-- Name: backup_draft_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.backup_draft_posts (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    key character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: backup_draft_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.backup_draft_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: backup_draft_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.backup_draft_posts_id_seq OWNED BY public.backup_draft_posts.id;


--
-- Name: backup_draft_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.backup_draft_topics (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: backup_draft_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.backup_draft_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: backup_draft_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.backup_draft_topics_id_seq OWNED BY public.backup_draft_topics.id;


--
-- Name: backup_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.backup_metadata (
    id bigint NOT NULL,
    name character varying NOT NULL,
    value character varying
);


--
-- Name: backup_metadata_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.backup_metadata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: backup_metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.backup_metadata_id_seq OWNED BY public.backup_metadata.id;


--
-- Name: badge_groupings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badge_groupings (
    id integer NOT NULL,
    name character varying NOT NULL,
    description text,
    "position" integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: badge_groupings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.badge_groupings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: badge_groupings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.badge_groupings_id_seq OWNED BY public.badge_groupings.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    color character varying(6) DEFAULT '0088CC'::character varying NOT NULL,
    topic_id integer,
    topic_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    topics_year integer DEFAULT 0,
    topics_month integer DEFAULT 0,
    topics_week integer DEFAULT 0,
    slug character varying NOT NULL,
    description text,
    text_color character varying(6) DEFAULT 'FFFFFF'::character varying NOT NULL,
    read_restricted boolean DEFAULT false NOT NULL,
    auto_close_hours double precision,
    post_count integer DEFAULT 0 NOT NULL,
    latest_post_id integer,
    latest_topic_id integer,
    "position" integer,
    parent_category_id integer,
    posts_year integer DEFAULT 0,
    posts_month integer DEFAULT 0,
    posts_week integer DEFAULT 0,
    email_in character varying,
    email_in_allow_strangers boolean DEFAULT false,
    topics_day integer DEFAULT 0,
    posts_day integer DEFAULT 0,
    allow_badges boolean DEFAULT true NOT NULL,
    name_lower character varying(50) NOT NULL,
    auto_close_based_on_last_post boolean DEFAULT false,
    topic_template text,
    contains_messages boolean,
    sort_order character varying,
    sort_ascending boolean,
    uploaded_logo_id integer,
    uploaded_background_id integer,
    topic_featured_link_allowed boolean DEFAULT true,
    all_topics_wiki boolean DEFAULT false NOT NULL,
    show_subcategory_list boolean DEFAULT false,
    num_featured_topics integer DEFAULT 3,
    default_view character varying(50),
    subcategory_list_style character varying(50) DEFAULT 'rows_with_featured_topics'::character varying,
    default_top_period character varying(20) DEFAULT 'all'::character varying,
    mailinglist_mirror boolean DEFAULT false NOT NULL,
    minimum_required_tags integer DEFAULT 0 NOT NULL,
    navigate_to_first_post_after_read boolean DEFAULT false NOT NULL,
    search_priority integer DEFAULT 0,
    allow_global_tags boolean DEFAULT false NOT NULL,
    reviewable_by_group_id integer,
    read_only_banner character varying,
    default_list_filter character varying(20) DEFAULT 'all'::character varying,
    allow_unlimited_owner_edits_on_first_post boolean DEFAULT false NOT NULL,
    default_slow_mode_seconds integer,
    uploaded_logo_dark_id integer,
    uploaded_background_dark_id integer,
    style_type integer DEFAULT 0 NOT NULL,
    emoji character varying,
    icon character varying,
    locale character varying(20),
    topic_title_placeholder character varying
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    user_id integer,
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    raw text NOT NULL,
    cooked text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reply_to_post_number integer,
    reply_count integer DEFAULT 0 NOT NULL,
    quote_count integer DEFAULT 0 NOT NULL,
    deleted_at timestamp without time zone,
    off_topic_count integer DEFAULT 0 NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    bookmark_count integer DEFAULT 0 NOT NULL,
    score double precision,
    reads integer DEFAULT 0 NOT NULL,
    post_type integer DEFAULT 1 NOT NULL,
    sort_order integer,
    last_editor_id integer,
    hidden boolean DEFAULT false NOT NULL,
    hidden_reason_id integer,
    notify_moderators_count integer DEFAULT 0 NOT NULL,
    spam_count integer DEFAULT 0 NOT NULL,
    illegal_count integer DEFAULT 0 NOT NULL,
    inappropriate_count integer DEFAULT 0 NOT NULL,
    last_version_at timestamp without time zone NOT NULL,
    user_deleted boolean DEFAULT false NOT NULL,
    reply_to_user_id integer,
    percent_rank double precision DEFAULT 1.0,
    notify_user_count integer DEFAULT 0 NOT NULL,
    like_score integer DEFAULT 0 NOT NULL,
    deleted_by_id integer,
    edit_reason character varying,
    word_count integer,
    version integer DEFAULT 1 NOT NULL,
    cook_method integer DEFAULT 1 NOT NULL,
    wiki boolean DEFAULT false NOT NULL,
    baked_at timestamp without time zone,
    baked_version integer,
    hidden_at timestamp without time zone,
    self_edits integer DEFAULT 0 NOT NULL,
    reply_quoted boolean DEFAULT false NOT NULL,
    via_email boolean DEFAULT false NOT NULL,
    raw_email text,
    public_version integer DEFAULT 1 NOT NULL,
    action_code character varying,
    locked_by_id integer,
    image_upload_id bigint,
    qa_vote_count integer DEFAULT 0,
    outbound_message_id character varying,
    locale character varying(20)
);


--
-- Name: TABLE posts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.posts IS 'If you want to query public posts only, use the badge_posts view.';


--
-- Name: COLUMN posts.post_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.posts.post_number IS 'The position of this post in the topic. The pair (topic_id, post_number) forms a natural key on the posts table.';


--
-- Name: COLUMN posts.raw; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.posts.raw IS 'The raw Markdown that the user entered into the composer.';


--
-- Name: COLUMN posts.cooked; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.posts.cooked IS 'The processed HTML that is presented in a topic.';


--
-- Name: COLUMN posts.reply_to_post_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.posts.reply_to_post_number IS 'If this post is a reply to another, this column is the post_number of the post it''s replying to. [FKEY posts.topic_id, posts.post_number]';


--
-- Name: COLUMN posts.reply_quoted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.posts.reply_quoted IS 'This column is true if the post contains a quote-reply, which causes the in-reply-to indicator to be absent.';


--
-- Name: topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topics (
    id integer NOT NULL,
    title character varying NOT NULL,
    last_posted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    views integer DEFAULT 0 NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    user_id integer,
    last_post_user_id integer NOT NULL,
    reply_count integer DEFAULT 0 NOT NULL,
    featured_user1_id integer,
    featured_user2_id integer,
    featured_user3_id integer,
    deleted_at timestamp without time zone,
    highest_post_number integer DEFAULT 0 NOT NULL,
    like_count integer DEFAULT 0 NOT NULL,
    incoming_link_count integer DEFAULT 0 NOT NULL,
    category_id integer,
    visible boolean DEFAULT true NOT NULL,
    moderator_posts_count integer DEFAULT 0 NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    bumped_at timestamp without time zone NOT NULL,
    has_summary boolean DEFAULT false NOT NULL,
    archetype character varying DEFAULT 'regular'::character varying NOT NULL,
    featured_user4_id integer,
    notify_moderators_count integer DEFAULT 0 NOT NULL,
    spam_count integer DEFAULT 0 NOT NULL,
    pinned_at timestamp without time zone,
    score double precision,
    percent_rank double precision DEFAULT 1.0 NOT NULL,
    subtype character varying,
    slug character varying,
    deleted_by_id integer,
    participant_count integer DEFAULT 1,
    word_count integer,
    excerpt character varying,
    pinned_globally boolean DEFAULT false NOT NULL,
    pinned_until timestamp without time zone,
    fancy_title character varying,
    highest_staff_post_number integer DEFAULT 0 NOT NULL,
    featured_link character varying,
    reviewable_score double precision DEFAULT 0.0 NOT NULL,
    image_upload_id bigint,
    slow_mode_seconds integer DEFAULT 0 NOT NULL,
    bannered_until timestamp without time zone,
    external_id character varying,
    visibility_reason_id integer,
    locale character varying(20),
    og_image_upload_id bigint,
    CONSTRAINT has_category_id CHECK (((category_id IS NOT NULL) OR ((archetype)::text <> 'regular'::text))),
    CONSTRAINT pm_has_no_category CHECK (((category_id IS NULL) OR ((archetype)::text <> 'private_message'::text)))
);


--
-- Name: TABLE topics; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.topics IS 'To query public topics only: SELECT ... FROM topics t LEFT INNER JOIN categories c ON (t.category_id = c.id AND c.read_restricted = false)';


--
-- Name: badge_posts; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.badge_posts AS
 SELECT p.id,
    p.user_id,
    p.topic_id,
    p.post_number,
    p.raw,
    p.cooked,
    p.created_at,
    p.updated_at,
    p.reply_to_post_number,
    p.reply_count,
    p.quote_count,
    p.deleted_at,
    p.off_topic_count,
    p.like_count,
    p.incoming_link_count,
    p.bookmark_count,
    p.score,
    p.reads,
    p.post_type,
    p.sort_order,
    p.last_editor_id,
    p.hidden,
    p.hidden_reason_id,
    p.notify_moderators_count,
    p.spam_count,
    p.illegal_count,
    p.inappropriate_count,
    p.last_version_at,
    p.user_deleted,
    p.reply_to_user_id,
    p.percent_rank,
    p.notify_user_count,
    p.like_score,
    p.deleted_by_id,
    p.edit_reason,
    p.word_count,
    p.version,
    p.cook_method,
    p.wiki,
    p.baked_at,
    p.baked_version,
    p.hidden_at,
    p.self_edits,
    p.reply_quoted,
    p.via_email,
    p.raw_email,
    p.public_version,
    p.action_code,
    p.locked_by_id,
    p.image_upload_id
   FROM ((public.posts p
     JOIN public.topics t ON ((t.id = p.topic_id)))
     JOIN public.categories c ON ((c.id = t.category_id)))
  WHERE (c.allow_badges AND (p.deleted_at IS NULL) AND (t.deleted_at IS NULL) AND (NOT c.read_restricted) AND t.visible AND (p.post_type = ANY (ARRAY[1, 2, 3])));


--
-- Name: badge_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badge_types (
    id integer NOT NULL,
    name character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: badge_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.badge_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: badge_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.badge_types_id_seq OWNED BY public.badge_types.id;


--
-- Name: badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badges (
    id integer NOT NULL,
    name character varying NOT NULL,
    description text,
    badge_type_id integer NOT NULL,
    grant_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    allow_title boolean DEFAULT false NOT NULL,
    multiple_grant boolean DEFAULT false NOT NULL,
    icon character varying DEFAULT 'certificate'::character varying,
    listable boolean DEFAULT true,
    target_posts boolean DEFAULT false,
    query text,
    enabled boolean DEFAULT true NOT NULL,
    auto_revoke boolean DEFAULT true NOT NULL,
    badge_grouping_id integer DEFAULT 5 NOT NULL,
    trigger integer,
    show_posts boolean DEFAULT false NOT NULL,
    system boolean DEFAULT false NOT NULL,
    long_description text,
    image_upload_id integer,
    show_in_post_header boolean DEFAULT false NOT NULL
);


--
-- Name: badges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.badges_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: badges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.badges_id_seq OWNED BY public.badges.id;


--
-- Name: bookmarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookmarks (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying(100),
    reminder_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    reminder_last_sent_at timestamp without time zone,
    reminder_set_at timestamp without time zone,
    auto_delete_preference integer DEFAULT 0 NOT NULL,
    pinned boolean DEFAULT false,
    bookmarkable_id bigint,
    bookmarkable_type character varying
);


--
-- Name: bookmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bookmarks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bookmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bookmarks_id_seq OWNED BY public.bookmarks.id;


--
-- Name: browser_pageview_country_daily_rollups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.browser_pageview_country_daily_rollups (
    id bigint NOT NULL,
    date date NOT NULL,
    country_code character varying(2),
    count bigint NOT NULL,
    logged_in_count bigint NOT NULL
);


--
-- Name: browser_pageview_country_daily_rollups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.browser_pageview_country_daily_rollups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: browser_pageview_country_daily_rollups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.browser_pageview_country_daily_rollups_id_seq OWNED BY public.browser_pageview_country_daily_rollups.id;


--
-- Name: browser_pageview_event_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.browser_pageview_event_scores (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    automation_ua_score smallint DEFAULT 0 NOT NULL,
    known_asn_score smallint DEFAULT 0 NOT NULL,
    velocity_score smallint DEFAULT 0 NOT NULL,
    churn_score smallint DEFAULT 0 NOT NULL,
    rapid_nav_score smallint DEFAULT 0 NOT NULL,
    referrer_score smallint DEFAULT 0 NOT NULL
);


--
-- Name: browser_pageview_event_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.browser_pageview_event_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: browser_pageview_event_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.browser_pageview_event_scores_id_seq OWNED BY public.browser_pageview_event_scores.id;


--
-- Name: browser_pageview_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.browser_pageview_events (
    id bigint NOT NULL,
    url character varying(2000) NOT NULL,
    ip_address inet NOT NULL,
    referrer character varying(2000),
    user_agent character varying(1000) NOT NULL,
    session_id character varying(32) NOT NULL,
    topic_id integer,
    user_id integer,
    country_code character varying(2),
    created_at timestamp without time zone NOT NULL,
    asn integer,
    score integer,
    normalized_referrer character varying(2000),
    normalized_referrer_version smallint,
    source smallint DEFAULT 1 NOT NULL
);


--
-- Name: browser_pageview_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.browser_pageview_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: browser_pageview_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.browser_pageview_events_id_seq OWNED BY public.browser_pageview_events.id;


--
-- Name: browser_pageview_referrer_daily_rollups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.browser_pageview_referrer_daily_rollups (
    id bigint NOT NULL,
    date date NOT NULL,
    normalized_referrer character varying(2000),
    count bigint NOT NULL,
    logged_in_count bigint NOT NULL
);


--
-- Name: browser_pageview_referrer_daily_rollups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.browser_pageview_referrer_daily_rollups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: browser_pageview_referrer_daily_rollups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.browser_pageview_referrer_daily_rollups_id_seq OWNED BY public.browser_pageview_referrer_daily_rollups.id;


--
-- Name: browser_pageview_session_engagements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.browser_pageview_session_engagements (
    id bigint NOT NULL,
    session_id character varying(32) NOT NULL,
    mouse_move_events integer DEFAULT 0 NOT NULL,
    click_events integer DEFAULT 0 NOT NULL,
    key_events integer DEFAULT 0 NOT NULL,
    scroll_events integer DEFAULT 0 NOT NULL,
    touch_events integer DEFAULT 0 NOT NULL,
    back_forward_events integer DEFAULT 0 NOT NULL,
    engaged_seconds integer DEFAULT 0 NOT NULL,
    time_to_first_interaction_ms integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: browser_pageview_session_engagements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.browser_pageview_session_engagements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: browser_pageview_session_engagements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.browser_pageview_session_engagements_id_seq OWNED BY public.browser_pageview_session_engagements.id;


--
-- Name: calendar_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calendar_events (
    id bigint NOT NULL,
    topic_id integer NOT NULL,
    post_id integer,
    post_number integer,
    user_id integer,
    username character varying,
    description character varying,
    start_date timestamp without time zone NOT NULL,
    end_date timestamp without time zone,
    recurrence character varying,
    region character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    timezone character varying
);


--
-- Name: calendar_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.calendar_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: calendar_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.calendar_events_id_seq OWNED BY public.calendar_events.id;


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: categories_web_hooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories_web_hooks (
    web_hook_id integer NOT NULL,
    category_id integer NOT NULL
);


--
-- Name: category_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_custom_fields (
    id integer NOT NULL,
    category_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: category_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_custom_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_custom_fields_id_seq OWNED BY public.category_custom_fields.id;


--
-- Name: category_featured_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_featured_topics (
    category_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    rank integer DEFAULT 0 NOT NULL,
    id integer NOT NULL
);


--
-- Name: category_featured_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_featured_topics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_featured_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_featured_topics_id_seq OWNED BY public.category_featured_topics.id;


--
-- Name: category_form_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_form_templates (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    form_template_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_form_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_form_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_form_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_form_templates_id_seq OWNED BY public.category_form_templates.id;


--
-- Name: category_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_groups (
    id integer NOT NULL,
    category_id integer NOT NULL,
    group_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    permission_type integer DEFAULT 1
);


--
-- Name: category_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_groups_id_seq OWNED BY public.category_groups.id;


--
-- Name: category_localizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_localizations (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    locale character varying(20) NOT NULL,
    name character varying(50) NOT NULL,
    description character varying(1000),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_localizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_localizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_localizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_localizations_id_seq OWNED BY public.category_localizations.id;


--
-- Name: category_moderation_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_moderation_groups (
    id bigint NOT NULL,
    category_id integer,
    group_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_moderation_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_moderation_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_moderation_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_moderation_groups_id_seq OWNED BY public.category_moderation_groups.id;


--
-- Name: category_posting_review_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_posting_review_groups (
    id bigint NOT NULL,
    post_type integer NOT NULL,
    category_id integer NOT NULL,
    group_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_posting_review_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_posting_review_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_posting_review_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_posting_review_groups_id_seq OWNED BY public.category_posting_review_groups.id;


--
-- Name: category_required_tag_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_required_tag_groups (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    tag_group_id bigint NOT NULL,
    min_count integer DEFAULT 1 NOT NULL,
    "order" integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: category_required_tag_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_required_tag_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_required_tag_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_required_tag_groups_id_seq OWNED BY public.category_required_tag_groups.id;


--
-- Name: category_search_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_search_data (
    category_id integer NOT NULL,
    search_data tsvector,
    raw_data text,
    locale text,
    version integer DEFAULT 0
);


--
-- Name: category_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_settings (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    require_topic_approval boolean,
    require_reply_approval boolean,
    num_auto_bump_daily integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    auto_bump_cooldown_days integer DEFAULT 1,
    topic_posting_review_mode integer DEFAULT 0 NOT NULL,
    reply_posting_review_mode integer DEFAULT 0 NOT NULL,
    nested_replies_default boolean DEFAULT false NOT NULL
);


--
-- Name: category_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_settings_id_seq OWNED BY public.category_settings.id;


--
-- Name: category_tag_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_tag_groups (
    id integer NOT NULL,
    category_id integer NOT NULL,
    tag_group_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: category_tag_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_tag_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_tag_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_tag_groups_id_seq OWNED BY public.category_tag_groups.id;


--
-- Name: category_tag_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_tag_stats (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    tag_id bigint NOT NULL,
    topic_count integer DEFAULT 0 NOT NULL
);


--
-- Name: category_tag_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_tag_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_tag_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_tag_stats_id_seq OWNED BY public.category_tag_stats.id;


--
-- Name: category_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_tags (
    id integer NOT NULL,
    category_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: category_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_tags_id_seq OWNED BY public.category_tags.id;


--
-- Name: category_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_users (
    id integer NOT NULL,
    category_id integer NOT NULL,
    user_id integer NOT NULL,
    notification_level integer NOT NULL,
    last_seen_at timestamp without time zone
);


--
-- Name: category_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.category_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.category_users_id_seq OWNED BY public.category_users.id;


--
-- Name: chat_channel_archives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_channel_archives (
    id bigint NOT NULL,
    chat_channel_id bigint NOT NULL,
    archived_by_id integer NOT NULL,
    destination_topic_id integer,
    destination_topic_title character varying,
    destination_category_id integer,
    destination_tags character varying[],
    total_messages integer NOT NULL,
    archived_messages integer DEFAULT 0 NOT NULL,
    archive_error character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_channel_archives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_channel_archives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_channel_archives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_channel_archives_id_seq OWNED BY public.chat_channel_archives.id;


--
-- Name: chat_channel_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_channel_custom_fields (
    id bigint NOT NULL,
    channel_id bigint NOT NULL,
    name character varying(256) NOT NULL,
    value character varying(1000000),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_channel_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_channel_custom_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_channel_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_channel_custom_fields_id_seq OWNED BY public.chat_channel_custom_fields.id;


--
-- Name: chat_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_channels (
    id bigint NOT NULL,
    chatable_id bigint NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by_id integer,
    featured_in_category_id integer,
    delete_after_seconds integer,
    chatable_type character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying,
    description text,
    status integer DEFAULT 0 NOT NULL,
    user_count integer DEFAULT 0 NOT NULL,
    auto_join_users boolean DEFAULT false NOT NULL,
    user_count_stale boolean DEFAULT false NOT NULL,
    type character varying,
    slug character varying,
    allow_channel_wide_mentions boolean DEFAULT true NOT NULL,
    messages_count integer DEFAULT 0 NOT NULL,
    threading_enabled boolean DEFAULT false NOT NULL,
    last_message_id bigint,
    emoji character varying
);


--
-- Name: chat_channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_channels_id_seq OWNED BY public.chat_channels.id;


--
-- Name: chat_drafts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_drafts (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    chat_channel_id bigint NOT NULL,
    data text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    thread_id bigint
);


--
-- Name: chat_drafts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_drafts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_drafts_id_seq OWNED BY public.chat_drafts.id;


--
-- Name: chat_mention_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_mention_notifications (
    chat_mention_id bigint NOT NULL,
    notification_id bigint NOT NULL
);


--
-- Name: chat_mentions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_mentions (
    id bigint NOT NULL,
    chat_message_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    type character varying NOT NULL,
    target_id integer
);


--
-- Name: chat_mentions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_mentions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_mentions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_mentions_id_seq OWNED BY public.chat_mentions.id;


--
-- Name: chat_message_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_custom_fields (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    name character varying(256) NOT NULL,
    value character varying(1000000),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_message_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_message_custom_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_message_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_message_custom_fields_id_seq OWNED BY public.chat_message_custom_fields.id;


--
-- Name: chat_message_custom_prompts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_custom_prompts (
    id bigint NOT NULL,
    message_id bigint NOT NULL,
    custom_prompt json NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_message_custom_prompts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_message_custom_prompts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_message_custom_prompts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_message_custom_prompts_id_seq OWNED BY public.chat_message_custom_prompts.id;


--
-- Name: chat_message_interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_interactions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    chat_message_id bigint NOT NULL,
    action jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_message_interactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_message_interactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_message_interactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_message_interactions_id_seq OWNED BY public.chat_message_interactions.id;


--
-- Name: chat_message_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_links (
    id bigint NOT NULL,
    chat_message_id bigint NOT NULL,
    url character varying(500) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_message_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_message_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_message_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_message_links_id_seq OWNED BY public.chat_message_links.id;


--
-- Name: chat_message_reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_reactions (
    id bigint NOT NULL,
    chat_message_id bigint,
    user_id integer,
    emoji character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_message_reactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_message_reactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_message_reactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_message_reactions_id_seq OWNED BY public.chat_message_reactions.id;


--
-- Name: chat_message_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_revisions (
    id bigint NOT NULL,
    chat_message_id bigint,
    old_message text NOT NULL,
    new_message text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: chat_message_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_message_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_message_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_message_revisions_id_seq OWNED BY public.chat_message_revisions.id;


--
-- Name: chat_message_search_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_search_data (
    chat_message_id bigint NOT NULL,
    search_data tsvector,
    raw_data text,
    locale text,
    version integer DEFAULT 0
);


--
-- Name: chat_message_search_data_chat_message_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_message_search_data_chat_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_message_search_data_chat_message_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_message_search_data_chat_message_id_seq OWNED BY public.chat_message_search_data.chat_message_id;


--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_messages (
    id bigint NOT NULL,
    chat_channel_id bigint NOT NULL,
    user_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by_id integer,
    in_reply_to_id bigint,
    message text,
    cooked text,
    cooked_version integer,
    last_editor_id integer NOT NULL,
    thread_id bigint,
    streaming boolean DEFAULT false NOT NULL,
    excerpt character varying(1000),
    created_by_sdk boolean DEFAULT false NOT NULL,
    blocks jsonb
);


--
-- Name: chat_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_messages_id_seq OWNED BY public.chat_messages.id;


--
-- Name: chat_pinned_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_pinned_messages (
    id bigint NOT NULL,
    chat_message_id bigint NOT NULL,
    chat_channel_id bigint NOT NULL,
    pinned_by_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_pinned_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_pinned_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_pinned_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_pinned_messages_id_seq OWNED BY public.chat_pinned_messages.id;


--
-- Name: chat_thread_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_thread_custom_fields (
    id bigint NOT NULL,
    thread_id bigint NOT NULL,
    name character varying(256) NOT NULL,
    value character varying(1000000),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_thread_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_thread_custom_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_thread_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_thread_custom_fields_id_seq OWNED BY public.chat_thread_custom_fields.id;


--
-- Name: chat_threads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_threads (
    id bigint NOT NULL,
    channel_id bigint NOT NULL,
    original_message_id bigint NOT NULL,
    original_message_user_id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    title character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    replies_count integer DEFAULT 0 NOT NULL,
    last_message_id bigint,
    force boolean DEFAULT false NOT NULL
);


--
-- Name: chat_threads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_threads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_threads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_threads_id_seq OWNED BY public.chat_threads.id;


--
-- Name: chat_webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_webhook_events (
    id bigint NOT NULL,
    chat_message_id bigint NOT NULL,
    incoming_chat_webhook_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: chat_webhook_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_webhook_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_webhook_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_webhook_events_id_seq OWNED BY public.chat_webhook_events.id;


--
-- Name: child_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.child_themes (
    id integer NOT NULL,
    parent_theme_id integer,
    child_theme_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: child_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.child_themes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: child_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.child_themes_id_seq OWNED BY public.child_themes.id;


--
-- Name: classification_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_results (
    id bigint NOT NULL,
    model_used character varying,
    classification_type character varying,
    target_id bigint,
    target_type character varying,
    classification jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: classification_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.classification_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: classification_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.classification_results_id_seq OWNED BY public.classification_results.id;


--
-- Name: color_scheme_colors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.color_scheme_colors (
    id integer NOT NULL,
    name character varying NOT NULL,
    hex character varying NOT NULL,
    color_scheme_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: color_scheme_colors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.color_scheme_colors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: color_scheme_colors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.color_scheme_colors_id_seq OWNED BY public.color_scheme_colors.id;


--
-- Name: color_schemes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.color_schemes (
    id integer NOT NULL,
    name character varying NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    via_wizard boolean DEFAULT false NOT NULL,
    base_scheme_id integer,
    theme_id integer,
    user_selectable boolean DEFAULT false NOT NULL,
    remote_copy boolean DEFAULT false NOT NULL
);


--
-- Name: color_schemes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.color_schemes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: color_schemes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.color_schemes_id_seq OWNED BY public.color_schemes.id;


--
-- Name: completion_prompts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.completion_prompts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    translated_name character varying,
    prompt_type integer DEFAULT 0 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    messages jsonb,
    temperature integer,
    stop_sequences character varying[]
);


--
-- Name: completion_prompts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.completion_prompts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: completion_prompts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.completion_prompts_id_seq OWNED BY public.completion_prompts.id;


--
-- Name: custom_emojis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_emojis (
    id integer NOT NULL,
    name character varying NOT NULL,
    upload_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    "group" character varying(20),
    user_id integer DEFAULT '-1'::integer NOT NULL
);


--
-- Name: custom_emojis_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.custom_emojis_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: custom_emojis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.custom_emojis_id_seq OWNED BY public.custom_emojis.id;


--
-- Name: data_explorer_queries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_explorer_queries (
    id bigint NOT NULL,
    name character varying,
    description text,
    sql text DEFAULT 'SELECT 1'::text NOT NULL,
    user_id integer,
    last_run_at timestamp without time zone,
    hidden boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: data_explorer_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.data_explorer_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: data_explorer_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.data_explorer_queries_id_seq OWNED BY public.data_explorer_queries.id;


--
-- Name: data_explorer_query_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_explorer_query_groups (
    id bigint NOT NULL,
    query_id bigint,
    group_id integer
);


--
-- Name: data_explorer_query_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.data_explorer_query_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: data_explorer_query_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.data_explorer_query_groups_id_seq OWNED BY public.data_explorer_query_groups.id;


--
-- Name: developers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.developers (
    id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: developers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.developers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: developers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.developers_id_seq OWNED BY public.developers.id;


--
-- Name: direct_message_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.direct_message_channels (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    "group" boolean DEFAULT false NOT NULL
);


--
-- Name: direct_message_channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.direct_message_channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: direct_message_channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.direct_message_channels_id_seq OWNED BY public.direct_message_channels.id;


--
-- Name: direct_message_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.direct_message_users (
    id bigint NOT NULL,
    direct_message_channel_id bigint NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: direct_message_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.direct_message_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: direct_message_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.direct_message_users_id_seq OWNED BY public.direct_message_users.id;


--
-- Name: directory_columns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.directory_columns (
    id bigint NOT NULL,
    name character varying,
    automatic_position integer,
    icon character varying,
    user_field_id integer,
    enabled boolean NOT NULL,
    "position" integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    type integer DEFAULT 0 NOT NULL
);


--
-- Name: directory_columns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.directory_columns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_columns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.directory_columns_id_seq OWNED BY public.directory_columns.id;


--
-- Name: directory_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.directory_items (
    id integer NOT NULL,
    period_type integer NOT NULL,
    user_id integer NOT NULL,
    likes_received integer NOT NULL,
    likes_given integer NOT NULL,
    topics_entered integer NOT NULL,
    topic_count integer NOT NULL,
    post_count integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    days_visited integer DEFAULT 0 NOT NULL,
    posts_read integer DEFAULT 0 NOT NULL,
    solutions integer DEFAULT 0,
    gamification_score integer DEFAULT 0
);


--
-- Name: directory_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.directory_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: directory_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.directory_items_id_seq OWNED BY public.directory_items.id;


--
-- Name: discourse_ai_ai_bot_conversation_stars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_ai_ai_bot_conversation_stars (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_ai_ai_bot_conversation_stars_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_ai_ai_bot_conversation_stars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_ai_ai_bot_conversation_stars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_ai_ai_bot_conversation_stars_id_seq OWNED BY public.discourse_ai_ai_bot_conversation_stars.id;


--
-- Name: discourse_automation_automations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_automation_automations (
    id bigint NOT NULL,
    name character varying,
    script character varying NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    last_updated_by_id integer NOT NULL,
    trigger character varying
);


--
-- Name: discourse_automation_automations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_automation_automations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_automation_automations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_automation_automations_id_seq OWNED BY public.discourse_automation_automations.id;


--
-- Name: discourse_automation_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_automation_fields (
    id bigint NOT NULL,
    automation_id bigint NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    component character varying NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    target character varying
);


--
-- Name: discourse_automation_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_automation_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_automation_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_automation_fields_id_seq OWNED BY public.discourse_automation_fields.id;


--
-- Name: discourse_automation_pending_automations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_automation_pending_automations (
    id bigint NOT NULL,
    automation_id bigint NOT NULL,
    execute_at timestamp without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_automation_pending_automations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_automation_pending_automations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_automation_pending_automations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_automation_pending_automations_id_seq OWNED BY public.discourse_automation_pending_automations.id;


--
-- Name: discourse_automation_pending_pms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_automation_pending_pms (
    id bigint NOT NULL,
    target_usernames character varying[],
    sender character varying,
    title character varying,
    raw character varying,
    automation_id bigint NOT NULL,
    execute_at timestamp without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    sender_id bigint,
    target_user_ids bigint[]
);


--
-- Name: discourse_automation_pending_pms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_automation_pending_pms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_automation_pending_pms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_automation_pending_pms_id_seq OWNED BY public.discourse_automation_pending_pms.id;


--
-- Name: discourse_automation_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_automation_stats (
    id bigint NOT NULL,
    automation_id bigint NOT NULL,
    date date NOT NULL,
    last_run_at timestamp(6) without time zone NOT NULL,
    total_time double precision NOT NULL,
    average_run_time double precision NOT NULL,
    min_run_time double precision NOT NULL,
    max_run_time double precision NOT NULL,
    total_runs integer NOT NULL,
    total_errors integer DEFAULT 0 NOT NULL
);


--
-- Name: discourse_automation_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_automation_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_automation_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_automation_stats_id_seq OWNED BY public.discourse_automation_stats.id;


--
-- Name: discourse_automation_user_global_notices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_automation_user_global_notices (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    notice text NOT NULL,
    identifier character varying NOT NULL,
    level character varying DEFAULT 'info'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_automation_user_global_notices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_automation_user_global_notices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_automation_user_global_notices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_automation_user_global_notices_id_seq OWNED BY public.discourse_automation_user_global_notices.id;


--
-- Name: discourse_calendar_disabled_holidays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_calendar_disabled_holidays (
    id bigint NOT NULL,
    holiday_name character varying NOT NULL,
    region_code character varying NOT NULL,
    disabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_calendar_disabled_holidays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_calendar_disabled_holidays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_calendar_disabled_holidays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_calendar_disabled_holidays_id_seq OWNED BY public.discourse_calendar_disabled_holidays.id;


--
-- Name: discourse_calendar_post_event_dates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_calendar_post_event_dates (
    id bigint NOT NULL,
    event_id integer,
    starts_at timestamp without time zone,
    ends_at timestamp without time zone,
    reminder_counter integer DEFAULT 0,
    event_will_start_sent_at timestamp without time zone,
    event_started_sent_at timestamp without time zone,
    finished_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_calendar_post_event_dates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_calendar_post_event_dates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_calendar_post_event_dates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_calendar_post_event_dates_id_seq OWNED BY public.discourse_calendar_post_event_dates.id;


--
-- Name: discourse_post_event_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_post_event_events (
    id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    original_starts_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    original_ends_at timestamp without time zone,
    deleted_at timestamp without time zone,
    raw_invitees character varying[],
    name character varying,
    url character varying(1000),
    custom_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    reminders character varying,
    recurrence character varying,
    timezone character varying,
    minimal boolean,
    closed boolean DEFAULT false NOT NULL,
    chat_enabled boolean DEFAULT false NOT NULL,
    chat_channel_id bigint,
    recurrence_until timestamp(6) without time zone,
    show_local_time boolean DEFAULT false NOT NULL,
    location character varying(1000),
    description character varying(1000),
    max_attendees integer,
    all_day boolean DEFAULT false NOT NULL,
    image_upload_id bigint,
    livestream boolean DEFAULT false NOT NULL
);


--
-- Name: discourse_post_event_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_post_event_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_post_event_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_post_event_events_id_seq OWNED BY public.discourse_post_event_events.id;


--
-- Name: discourse_post_event_invitees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_post_event_invitees (
    id bigint NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    status integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    notified boolean DEFAULT false NOT NULL,
    recurring boolean DEFAULT false NOT NULL
);


--
-- Name: discourse_post_event_invitees_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_post_event_invitees_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_post_event_invitees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_post_event_invitees_id_seq OWNED BY public.discourse_post_event_invitees.id;


--
-- Name: discourse_reactions_reaction_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_reactions_reaction_users (
    id bigint NOT NULL,
    reaction_id bigint,
    user_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    post_id integer
);


--
-- Name: discourse_reactions_reaction_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_reactions_reaction_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_reactions_reaction_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_reactions_reaction_users_id_seq OWNED BY public.discourse_reactions_reaction_users.id;


--
-- Name: discourse_reactions_reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_reactions_reactions (
    id bigint NOT NULL,
    post_id integer,
    reaction_type integer,
    reaction_value character varying,
    reaction_users_count integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_reactions_reactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_reactions_reactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_reactions_reactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_reactions_reactions_id_seq OWNED BY public.discourse_reactions_reactions.id;


--
-- Name: discourse_rss_polling_rss_feeds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_rss_polling_rss_feeds (
    id bigint NOT NULL,
    url character varying NOT NULL,
    category_filter character varying,
    author character varying,
    category_id integer,
    tags character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id bigint
);


--
-- Name: discourse_rss_polling_rss_feeds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_rss_polling_rss_feeds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_rss_polling_rss_feeds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_rss_polling_rss_feeds_id_seq OWNED BY public.discourse_rss_polling_rss_feeds.id;


--
-- Name: discourse_solved_shared_issues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_solved_shared_issues (
    id bigint NOT NULL,
    topic_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_solved_shared_issues_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_solved_shared_issues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_solved_shared_issues_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_solved_shared_issues_id_seq OWNED BY public.discourse_solved_shared_issues.id;


--
-- Name: discourse_solved_solved_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_solved_solved_topics (
    id bigint NOT NULL,
    topic_id bigint NOT NULL,
    answer_post_id integer,
    accepter_user_id integer,
    topic_timer_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_solved_solved_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_solved_solved_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_solved_solved_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_solved_solved_topics_id_seq OWNED BY public.discourse_solved_solved_topics.id;


--
-- Name: discourse_solved_topic_answers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_solved_topic_answers (
    id bigint NOT NULL,
    solved_topic_id bigint NOT NULL,
    answer_post_id bigint NOT NULL,
    accepter_user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_solved_topic_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_solved_topic_answers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_solved_topic_answers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_solved_topic_answers_id_seq OWNED BY public.discourse_solved_topic_answers.id;


--
-- Name: discourse_subscriptions_customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_subscriptions_customers (
    id bigint NOT NULL,
    customer_id character varying NOT NULL,
    product_id character varying,
    user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_subscriptions_customers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_subscriptions_customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_subscriptions_customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_subscriptions_customers_id_seq OWNED BY public.discourse_subscriptions_customers.id;


--
-- Name: discourse_subscriptions_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_subscriptions_products (
    id bigint NOT NULL,
    external_id character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_subscriptions_products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_subscriptions_products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_subscriptions_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_subscriptions_products_id_seq OWNED BY public.discourse_subscriptions_products.id;


--
-- Name: discourse_subscriptions_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_subscriptions_subscriptions (
    id bigint NOT NULL,
    customer_id bigint NOT NULL,
    external_id character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    status character varying
);


--
-- Name: discourse_subscriptions_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_subscriptions_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_subscriptions_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_subscriptions_subscriptions_id_seq OWNED BY public.discourse_subscriptions_subscriptions.id;


--
-- Name: discourse_templates_usage_count; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_templates_usage_count (
    id bigint NOT NULL,
    topic_id integer NOT NULL,
    usage_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_templates_usage_count_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_templates_usage_count_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_templates_usage_count_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_templates_usage_count_id_seq OWNED BY public.discourse_templates_usage_count.id;


--
-- Name: discourse_workflows_ai_authoring_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_ai_authoring_sessions (
    id bigint NOT NULL,
    workflow_id bigint,
    user_id integer NOT NULL,
    status character varying(40) DEFAULT 'drafting'::character varying NOT NULL,
    messages jsonb DEFAULT '[]'::jsonb NOT NULL,
    latest_request text,
    latest_response jsonb DEFAULT '{}'::jsonb NOT NULL,
    proposed_patch jsonb DEFAULT '{}'::jsonb NOT NULL,
    base_workflow_version_id character varying(36),
    base_graph_digest character varying(64),
    risk_level character varying(20),
    applied_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_workflows_ai_authoring_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_ai_authoring_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_ai_authoring_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_ai_authoring_sessions_id_seq OWNED BY public.discourse_workflows_ai_authoring_sessions.id;


--
-- Name: discourse_workflows_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_credentials (
    id bigint NOT NULL,
    name character varying(128) NOT NULL,
    credential_type character varying(64) NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_workflows_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_credentials_id_seq OWNED BY public.discourse_workflows_credentials.id;


--
-- Name: discourse_workflows_data_tables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_data_tables (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    created_by_id integer,
    updated_by_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_workflows_data_tables_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_data_tables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_data_tables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_data_tables_id_seq OWNED BY public.discourse_workflows_data_tables.id;


--
-- Name: discourse_workflows_execution_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_execution_data (
    execution_id bigint NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    workflow_data jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: discourse_workflows_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_executions (
    id bigint NOT NULL,
    workflow_id bigint NOT NULL,
    workflow_version_id character varying(36) NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    execution_mode integer DEFAULT 0 NOT NULL,
    trigger_data jsonb DEFAULT '{}'::jsonb,
    error text,
    waiting_node_id character varying(100),
    waiting_until timestamp(6) without time zone,
    resume_token character varying(64),
    timeout_action character varying(32),
    trigger_node_id character varying(100),
    run_time_ms integer,
    started_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_workflows_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_executions_id_seq OWNED BY public.discourse_workflows_executions.id;


--
-- Name: discourse_workflows_variables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_variables (
    id bigint NOT NULL,
    key character varying(100) NOT NULL,
    value character varying(1000) DEFAULT ''::character varying NOT NULL,
    description text,
    created_by_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_workflows_variables_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_variables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_variables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_variables_id_seq OWNED BY public.discourse_workflows_variables.id;


--
-- Name: discourse_workflows_webhooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_webhooks (
    id bigint NOT NULL,
    workflow_id bigint NOT NULL,
    workflow_version_id character varying(36),
    node_name character varying(100) NOT NULL,
    webhook_path character varying(500) NOT NULL,
    http_method character varying(10) NOT NULL,
    webhook_id character varying(36),
    path_length integer,
    test_webhook boolean DEFAULT false NOT NULL,
    user_id integer,
    workflow_snapshot jsonb,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: discourse_workflows_webhooks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_webhooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_webhooks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_webhooks_id_seq OWNED BY public.discourse_workflows_webhooks.id;


--
-- Name: discourse_workflows_workflow_call_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_workflow_call_runs (
    id bigint NOT NULL,
    parent_execution_id bigint NOT NULL,
    parent_node_id character varying(100) NOT NULL,
    parent_resume_token character varying(64) NOT NULL,
    child_execution_id bigint,
    target_workflow_id bigint NOT NULL,
    target_workflow_version_id character varying(36) NOT NULL,
    user_id bigint,
    trigger_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    error text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_workflows_workflow_call_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_workflow_call_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_workflow_call_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_workflow_call_runs_id_seq OWNED BY public.discourse_workflows_workflow_call_runs.id;


--
-- Name: discourse_workflows_workflow_dependencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_workflow_dependencies (
    id bigint NOT NULL,
    workflow_id bigint NOT NULL,
    dependency_type character varying(50) NOT NULL,
    dependency_key character varying(500) NOT NULL,
    node_id character varying(100),
    workflow_version_id character varying(36),
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: discourse_workflows_workflow_dependencies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_workflow_dependencies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_workflow_dependencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_workflow_dependencies_id_seq OWNED BY public.discourse_workflows_workflow_dependencies.id;


--
-- Name: discourse_workflows_workflow_publish_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_workflow_publish_history (
    id bigint NOT NULL,
    workflow_id bigint NOT NULL,
    version_id character varying(36),
    event character varying(32) NOT NULL,
    user_id integer,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: discourse_workflows_workflow_publish_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_workflow_publish_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_workflow_publish_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_workflow_publish_history_id_seq OWNED BY public.discourse_workflows_workflow_publish_history.id;


--
-- Name: discourse_workflows_workflow_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_workflow_versions (
    version_id character varying(36) NOT NULL,
    workflow_id bigint NOT NULL,
    version_number integer NOT NULL,
    name character varying(100) NOT NULL,
    nodes jsonb DEFAULT '[]'::jsonb NOT NULL,
    connections jsonb DEFAULT '{}'::jsonb NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    autosaved boolean DEFAULT false NOT NULL,
    authors text,
    created_by_id integer NOT NULL,
    updated_by_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_workflows_workflows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discourse_workflows_workflows (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    nodes jsonb DEFAULT '[]'::jsonb NOT NULL,
    connections jsonb DEFAULT '{}'::jsonb NOT NULL,
    static_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    pin_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    trigger_state jsonb DEFAULT '{}'::jsonb NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    version_id character varying(36) NOT NULL,
    active_version_id character varying(36),
    version_counter integer DEFAULT 1 NOT NULL,
    error_workflow_id bigint,
    created_by_id integer NOT NULL,
    updated_by_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discourse_workflows_workflows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discourse_workflows_workflows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discourse_workflows_workflows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discourse_workflows_workflows_id_seq OWNED BY public.discourse_workflows_workflows.id;


--
-- Name: dismissed_topic_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dismissed_topic_users (
    id bigint NOT NULL,
    user_id integer,
    topic_id integer,
    created_at timestamp without time zone
);


--
-- Name: dismissed_topic_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dismissed_topic_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dismissed_topic_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dismissed_topic_users_id_seq OWNED BY public.dismissed_topic_users.id;


--
-- Name: do_not_disturb_timings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.do_not_disturb_timings (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    starts_at timestamp without time zone NOT NULL,
    ends_at timestamp without time zone NOT NULL,
    scheduled boolean DEFAULT false
);


--
-- Name: do_not_disturb_timings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.do_not_disturb_timings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: do_not_disturb_timings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.do_not_disturb_timings_id_seq OWNED BY public.do_not_disturb_timings.id;


--
-- Name: draft_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.draft_sequences (
    id integer NOT NULL,
    user_id integer NOT NULL,
    draft_key character varying NOT NULL,
    sequence bigint NOT NULL
);


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.draft_sequences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: draft_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.draft_sequences_id_seq OWNED BY public.draft_sequences.id;


--
-- Name: drafts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.drafts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    draft_key character varying NOT NULL,
    data text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    sequence bigint DEFAULT 0 NOT NULL,
    revisions integer DEFAULT 1 NOT NULL,
    owner character varying
);


--
-- Name: drafts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.drafts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.drafts_id_seq OWNED BY public.drafts.id;


--
-- Name: email_change_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_change_requests (
    id integer NOT NULL,
    user_id integer NOT NULL,
    old_email character varying,
    new_email character varying NOT NULL,
    old_email_token_id integer,
    new_email_token_id integer,
    change_state integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    requested_by_user_id integer
);


--
-- Name: email_change_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_change_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_change_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_change_requests_id_seq OWNED BY public.email_change_requests.id;


--
-- Name: email_login_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_login_codes (
    id bigint NOT NULL,
    email character varying NOT NULL,
    code_hash character varying NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    consumed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: email_login_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_login_codes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_login_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_login_codes_id_seq OWNED BY public.email_login_codes.id;


--
-- Name: email_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_logs (
    id integer NOT NULL,
    to_address character varying NOT NULL,
    email_type character varying NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    post_id integer,
    bounce_key uuid,
    bounced boolean DEFAULT false NOT NULL,
    message_id character varying,
    smtp_group_id integer,
    cc_addresses text,
    cc_user_ids integer[],
    raw text,
    topic_id integer,
    bounce_error_code character varying,
    smtp_transaction_response character varying(500),
    bcc_addresses text
);


--
-- Name: email_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_logs_id_seq OWNED BY public.email_logs.id;


--
-- Name: email_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    email character varying NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    expired boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    token_hash character varying NOT NULL,
    scope integer
);


--
-- Name: email_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_tokens_id_seq OWNED BY public.email_tokens.id;


--
-- Name: embeddable_host_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.embeddable_host_tags (
    id bigint NOT NULL,
    embeddable_host_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: embeddable_host_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.embeddable_host_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: embeddable_host_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.embeddable_host_tags_id_seq OWNED BY public.embeddable_host_tags.id;


--
-- Name: embeddable_hosts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.embeddable_hosts (
    id integer NOT NULL,
    host character varying NOT NULL,
    category_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    class_name character varying,
    allowed_paths character varying,
    user_id integer
);


--
-- Name: embeddable_hosts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.embeddable_hosts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: embeddable_hosts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.embeddable_hosts_id_seq OWNED BY public.embeddable_hosts.id;


--
-- Name: embedding_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.embedding_definitions (
    id bigint NOT NULL,
    display_name character varying NOT NULL,
    dimensions integer NOT NULL,
    max_sequence_length integer NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    pg_function character varying NOT NULL,
    provider character varying NOT NULL,
    tokenizer_class character varying NOT NULL,
    url character varying NOT NULL,
    api_key character varying,
    seeded boolean DEFAULT false NOT NULL,
    provider_params jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    embed_prompt character varying DEFAULT ''::character varying NOT NULL,
    search_prompt character varying DEFAULT ''::character varying NOT NULL,
    matryoshka_dimensions boolean DEFAULT false NOT NULL,
    ai_secret_id bigint
);


--
-- Name: embedding_definitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.embedding_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: embedding_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.embedding_definitions_id_seq OWNED BY public.embedding_definitions.id;


--
-- Name: external_upload_stubs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_upload_stubs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    original_filename character varying NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    unique_identifier uuid NOT NULL,
    created_by_id integer NOT NULL,
    upload_type character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    multipart boolean DEFAULT false NOT NULL,
    external_upload_identifier character varying,
    filesize bigint NOT NULL
);


--
-- Name: external_upload_stubs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.external_upload_stubs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: external_upload_stubs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.external_upload_stubs_id_seq OWNED BY public.external_upload_stubs.id;


--
-- Name: flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flags (
    id bigint NOT NULL,
    name character varying,
    name_key character varying,
    description text,
    notify_type boolean DEFAULT false NOT NULL,
    auto_action_type boolean DEFAULT false NOT NULL,
    applies_to character varying[] NOT NULL,
    "position" integer NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    score_type boolean DEFAULT false NOT NULL,
    require_message boolean DEFAULT false NOT NULL
);


--
-- Name: flags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flags_id_seq
    START WITH 1001
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flags_id_seq OWNED BY public.flags.id;


--
-- Name: form_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.form_templates (
    id bigint NOT NULL,
    name character varying NOT NULL,
    template text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: form_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.form_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: form_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.form_templates_id_seq OWNED BY public.form_templates.id;


--
-- Name: gamification_leaderboard_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gamification_leaderboard_scores (
    id bigint NOT NULL,
    leaderboard_id bigint NOT NULL,
    user_id bigint NOT NULL,
    date date NOT NULL,
    score integer DEFAULT 0 NOT NULL
);


--
-- Name: gamification_leaderboard_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gamification_leaderboard_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gamification_leaderboard_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gamification_leaderboard_scores_id_seq OWNED BY public.gamification_leaderboard_scores.id;


--
-- Name: gamification_leaderboards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gamification_leaderboards (
    id bigint NOT NULL,
    name character varying NOT NULL,
    from_date date,
    to_date date,
    for_category_id integer,
    created_by_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    visible_to_groups_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    included_groups_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    excluded_groups_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    default_period integer DEFAULT 0,
    period_filter_disabled boolean DEFAULT false NOT NULL,
    score_overrides jsonb,
    scorable_category_ids integer[]
);


--
-- Name: gamification_leaderboards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gamification_leaderboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gamification_leaderboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gamification_leaderboards_id_seq OWNED BY public.gamification_leaderboards.id;


--
-- Name: gamification_score_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gamification_score_events (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    date date NOT NULL,
    points integer NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: gamification_score_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gamification_score_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gamification_score_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gamification_score_events_id_seq OWNED BY public.gamification_score_events.id;


--
-- Name: gamification_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gamification_scores (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    date date NOT NULL,
    score integer NOT NULL
);


--
-- Name: gamification_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gamification_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gamification_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gamification_scores_id_seq OWNED BY public.gamification_scores.id;


--
-- Name: github_commits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.github_commits (
    id bigint NOT NULL,
    repo_id bigint NOT NULL,
    sha character varying(40) NOT NULL,
    email character varying(513) NOT NULL,
    committed_at timestamp without time zone NOT NULL,
    role_id integer NOT NULL,
    merge_commit boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: github_commits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.github_commits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: github_commits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.github_commits_id_seq OWNED BY public.github_commits.id;


--
-- Name: github_repos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.github_repos (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: github_repos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.github_repos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: github_repos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.github_repos_id_seq OWNED BY public.github_repos.id;


--
-- Name: given_daily_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.given_daily_likes (
    user_id integer NOT NULL,
    likes_given integer NOT NULL,
    given_date date NOT NULL,
    limit_reached boolean DEFAULT false NOT NULL
);


--
-- Name: group_archived_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_archived_messages (
    id integer NOT NULL,
    group_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: group_archived_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_archived_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_archived_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_archived_messages_id_seq OWNED BY public.group_archived_messages.id;


--
-- Name: group_associated_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_associated_groups (
    id bigint NOT NULL,
    group_id bigint NOT NULL,
    associated_group_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: group_associated_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_associated_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_associated_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_associated_groups_id_seq OWNED BY public.group_associated_groups.id;


--
-- Name: group_category_notification_defaults; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_category_notification_defaults (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    category_id integer NOT NULL,
    notification_level integer NOT NULL
);


--
-- Name: group_category_notification_defaults_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_category_notification_defaults_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_category_notification_defaults_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_category_notification_defaults_id_seq OWNED BY public.group_category_notification_defaults.id;


--
-- Name: group_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_custom_fields (
    id integer NOT NULL,
    group_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: group_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_custom_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_custom_fields_id_seq OWNED BY public.group_custom_fields.id;


--
-- Name: group_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_histories (
    id integer NOT NULL,
    group_id integer NOT NULL,
    acting_user_id integer NOT NULL,
    target_user_id integer,
    action integer NOT NULL,
    subject character varying,
    prev_value text,
    new_value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: group_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_histories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_histories_id_seq OWNED BY public.group_histories.id;


--
-- Name: group_mentions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_mentions (
    id integer NOT NULL,
    post_id integer,
    group_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: group_mentions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_mentions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_mentions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_mentions_id_seq OWNED BY public.group_mentions.id;


--
-- Name: group_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_requests (
    id bigint NOT NULL,
    group_id integer,
    user_id integer,
    reason text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: group_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_requests_id_seq OWNED BY public.group_requests.id;


--
-- Name: group_tag_notification_defaults; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_tag_notification_defaults (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    tag_id integer NOT NULL,
    notification_level integer NOT NULL
);


--
-- Name: group_tag_notification_defaults_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_tag_notification_defaults_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_tag_notification_defaults_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_tag_notification_defaults_id_seq OWNED BY public.group_tag_notification_defaults.id;


--
-- Name: group_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_users (
    id integer NOT NULL,
    group_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    owner boolean DEFAULT false NOT NULL,
    notification_level integer DEFAULT 2 NOT NULL,
    first_unread_pm_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: group_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.group_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: group_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.group_users_id_seq OWNED BY public.group_users.id;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id integer NOT NULL,
    name character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    automatic boolean DEFAULT false NOT NULL,
    user_count integer DEFAULT 0 NOT NULL,
    automatic_membership_email_domains text,
    primary_group boolean DEFAULT false NOT NULL,
    title character varying,
    grant_trust_level integer,
    incoming_email character varying,
    has_messages boolean DEFAULT false NOT NULL,
    flair_bg_color character varying,
    flair_color character varying,
    bio_raw text,
    bio_cooked text,
    allow_membership_requests boolean DEFAULT false NOT NULL,
    full_name character varying,
    default_notification_level integer DEFAULT 3 NOT NULL,
    visibility_level integer DEFAULT 0 NOT NULL,
    public_exit boolean DEFAULT false NOT NULL,
    public_admission boolean DEFAULT false NOT NULL,
    membership_request_template text,
    messageable_level integer DEFAULT 0,
    mentionable_level integer DEFAULT 0,
    smtp_server character varying,
    smtp_port integer,
    imap_server character varying,
    imap_port integer,
    imap_ssl boolean,
    imap_mailbox_name character varying DEFAULT ''::character varying NOT NULL,
    imap_uid_validity integer DEFAULT 0 NOT NULL,
    imap_last_uid integer DEFAULT 0 NOT NULL,
    email_username character varying,
    email_password character varying,
    publish_read_state boolean DEFAULT false NOT NULL,
    members_visibility_level integer DEFAULT 0 NOT NULL,
    imap_last_error text,
    imap_old_emails integer,
    imap_new_emails integer,
    flair_icon character varying,
    flair_upload_id integer,
    allow_unknown_sender_topic_replies boolean DEFAULT false NOT NULL,
    smtp_enabled boolean DEFAULT false,
    smtp_updated_at timestamp without time zone,
    smtp_updated_by_id integer,
    imap_enabled boolean DEFAULT false,
    imap_updated_at timestamp without time zone,
    imap_updated_by_id integer,
    assignable_level integer DEFAULT 0 NOT NULL,
    email_from_alias character varying,
    smtp_ssl_mode integer DEFAULT 0 NOT NULL
);


--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.groups_id_seq
    AS integer
    START WITH 40
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.groups_id_seq OWNED BY public.groups.id;


--
-- Name: groups_web_hooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups_web_hooks (
    web_hook_id integer NOT NULL,
    group_id integer NOT NULL
);


--
-- Name: ignored_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ignored_users (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    ignored_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    summarized_at timestamp without time zone,
    expiring_at timestamp without time zone NOT NULL
);


--
-- Name: ignored_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ignored_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ignored_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ignored_users_id_seq OWNED BY public.ignored_users.id;


--
-- Name: incoming_chat_webhooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incoming_chat_webhooks (
    id bigint NOT NULL,
    name character varying NOT NULL,
    key character varying NOT NULL,
    chat_channel_id bigint NOT NULL,
    username character varying,
    description character varying,
    emoji character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: incoming_chat_webhooks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.incoming_chat_webhooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incoming_chat_webhooks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.incoming_chat_webhooks_id_seq OWNED BY public.incoming_chat_webhooks.id;


--
-- Name: incoming_domains; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incoming_domains (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    https boolean DEFAULT false NOT NULL,
    port integer NOT NULL
);


--
-- Name: incoming_domains_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.incoming_domains_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incoming_domains_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.incoming_domains_id_seq OWNED BY public.incoming_domains.id;


--
-- Name: incoming_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incoming_emails (
    id integer NOT NULL,
    user_id integer,
    topic_id integer,
    post_id integer,
    raw text,
    error text,
    message_id text,
    from_address text,
    to_addresses text,
    cc_addresses text,
    subject text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    rejection_message text,
    is_auto_generated boolean DEFAULT false,
    is_bounce boolean DEFAULT false NOT NULL,
    imap_uid_validity integer,
    imap_uid integer,
    imap_sync boolean,
    imap_group_id bigint,
    imap_missing boolean DEFAULT false NOT NULL,
    created_via integer DEFAULT 0 NOT NULL
);


--
-- Name: incoming_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.incoming_emails_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incoming_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.incoming_emails_id_seq OWNED BY public.incoming_emails.id;


--
-- Name: incoming_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incoming_links (
    id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    user_id integer,
    ip_address inet,
    current_user_id integer,
    post_id integer NOT NULL,
    incoming_referer_id integer
);


--
-- Name: incoming_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.incoming_links_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incoming_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.incoming_links_id_seq OWNED BY public.incoming_links.id;


--
-- Name: incoming_referers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incoming_referers (
    id integer NOT NULL,
    path character varying(1000) NOT NULL,
    incoming_domain_id integer NOT NULL
);


--
-- Name: incoming_referers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.incoming_referers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: incoming_referers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.incoming_referers_id_seq OWNED BY public.incoming_referers.id;


--
-- Name: inferred_concept_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inferred_concept_posts (
    inferred_concept_id bigint,
    post_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inferred_concept_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inferred_concept_topics (
    inferred_concept_id bigint,
    topic_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inferred_concepts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inferred_concepts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: inferred_concepts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.inferred_concepts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: inferred_concepts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.inferred_concepts_id_seq OWNED BY public.inferred_concepts.id;


--
-- Name: invited_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invited_groups (
    id integer NOT NULL,
    group_id integer,
    invite_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: invited_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invited_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invited_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invited_groups_id_seq OWNED BY public.invited_groups.id;


--
-- Name: invited_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invited_users (
    id bigint NOT NULL,
    user_id integer,
    invite_id integer NOT NULL,
    redeemed_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: invited_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invited_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invited_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invited_users_id_seq OWNED BY public.invited_users.id;


--
-- Name: invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invites (
    id integer NOT NULL,
    invite_key character varying(32) NOT NULL,
    email character varying,
    invited_by_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by_id integer,
    invalidated_at timestamp without time zone,
    moderator boolean DEFAULT false NOT NULL,
    custom_message text,
    emailed_status integer,
    max_redemptions_allowed integer DEFAULT 1 NOT NULL,
    redemption_count integer DEFAULT 0 NOT NULL,
    expires_at timestamp without time zone NOT NULL,
    email_token character varying,
    domain character varying,
    description character varying(100)
);


--
-- Name: invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invites_id_seq OWNED BY public.invites.id;


--
-- Name: javascript_caches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.javascript_caches (
    id bigint NOT NULL,
    theme_field_id bigint,
    digest character varying,
    content text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    theme_id bigint,
    source_map text,
    name character varying,
    external_plugin_imports character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    CONSTRAINT enforce_theme_or_theme_field CHECK ((((theme_id IS NOT NULL) AND (theme_field_id IS NULL)) OR ((theme_id IS NULL) AND (theme_field_id IS NOT NULL))))
);


--
-- Name: javascript_caches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.javascript_caches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: javascript_caches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.javascript_caches_id_seq OWNED BY public.javascript_caches.id;


--
-- Name: linked_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.linked_topics (
    id bigint NOT NULL,
    topic_id bigint NOT NULL,
    original_topic_id bigint NOT NULL,
    sequence integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: linked_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.linked_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: linked_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.linked_topics_id_seq OWNED BY public.linked_topics.id;


--
-- Name: livestream_topic_chat_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.livestream_topic_chat_channels (
    id bigint NOT NULL,
    topic_id bigint NOT NULL,
    chat_channel_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: livestream_topic_chat_channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.livestream_topic_chat_channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: livestream_topic_chat_channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.livestream_topic_chat_channels_id_seq OWNED BY public.livestream_topic_chat_channels.id;


--
-- Name: llm_credit_allocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_credit_allocations (
    id bigint NOT NULL,
    llm_model_id bigint NOT NULL,
    soft_limit_percentage integer DEFAULT 80 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    daily_credits bigint DEFAULT 0 NOT NULL
);


--
-- Name: llm_credit_allocations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_credit_allocations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_credit_allocations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_credit_allocations_id_seq OWNED BY public.llm_credit_allocations.id;


--
-- Name: llm_credit_daily_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_credit_daily_usages (
    id bigint NOT NULL,
    llm_model_id bigint NOT NULL,
    usage_date date NOT NULL,
    credits_used bigint DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: llm_credit_daily_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_credit_daily_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_credit_daily_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_credit_daily_usages_id_seq OWNED BY public.llm_credit_daily_usages.id;


--
-- Name: llm_feature_credit_costs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_feature_credit_costs (
    id bigint NOT NULL,
    llm_model_id bigint NOT NULL,
    feature_name character varying NOT NULL,
    credits_per_token numeric(10,4) DEFAULT 1.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: llm_feature_credit_costs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_feature_credit_costs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_feature_credit_costs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_feature_credit_costs_id_seq OWNED BY public.llm_feature_credit_costs.id;


--
-- Name: llm_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_models (
    id bigint NOT NULL,
    display_name character varying,
    name character varying NOT NULL,
    provider character varying NOT NULL,
    tokenizer character varying NOT NULL,
    max_prompt_tokens integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    url character varying,
    api_key character varying,
    user_id integer,
    enabled_chat_bot boolean DEFAULT false NOT NULL,
    provider_params jsonb DEFAULT '{}'::jsonb,
    vision_enabled boolean DEFAULT false NOT NULL,
    input_cost double precision,
    cached_input_cost double precision,
    output_cost double precision,
    max_output_tokens integer,
    cache_write_cost double precision DEFAULT 0.0,
    allowed_attachment_types text[] DEFAULT '{}'::text[] NOT NULL,
    ai_secret_id bigint
);


--
-- Name: llm_models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_models_id_seq OWNED BY public.llm_models.id;


--
-- Name: llm_quota_usages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_quota_usages (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    llm_quota_id bigint NOT NULL,
    input_tokens_used integer NOT NULL,
    output_tokens_used integer NOT NULL,
    usages integer NOT NULL,
    started_at timestamp(6) without time zone NOT NULL,
    reset_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    cost_used numeric(20,10) DEFAULT 0.0 NOT NULL,
    cache_read_tokens_used integer DEFAULT 0 NOT NULL,
    cache_write_tokens_used integer DEFAULT 0 NOT NULL
);


--
-- Name: llm_quota_usages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_quota_usages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_quota_usages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_quota_usages_id_seq OWNED BY public.llm_quota_usages.id;


--
-- Name: llm_quotas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_quotas (
    id bigint NOT NULL,
    group_id bigint NOT NULL,
    llm_model_id bigint NOT NULL,
    max_tokens integer,
    max_usages integer,
    duration_seconds integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    max_cost numeric(20,10)
);


--
-- Name: llm_quotas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_quotas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_quotas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_quotas_id_seq OWNED BY public.llm_quotas.id;


--
-- Name: message_bus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_bus (
    id integer NOT NULL,
    name character varying,
    context character varying,
    data text,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: message_bus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.message_bus_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: message_bus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.message_bus_id_seq OWNED BY public.message_bus.id;


--
-- Name: model_accuracies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.model_accuracies (
    id bigint NOT NULL,
    model character varying NOT NULL,
    classification_type character varying NOT NULL,
    flags_agreed integer DEFAULT 0 NOT NULL,
    flags_disagreed integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: model_accuracies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.model_accuracies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: model_accuracies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.model_accuracies_id_seq OWNED BY public.model_accuracies.id;


--
-- Name: moved_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.moved_posts (
    id bigint NOT NULL,
    old_topic_id bigint NOT NULL,
    old_post_id bigint NOT NULL,
    old_post_number bigint NOT NULL,
    new_topic_id bigint NOT NULL,
    new_topic_title character varying NOT NULL,
    new_post_id bigint NOT NULL,
    new_post_number bigint NOT NULL,
    created_new_topic boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    old_topic_title character varying,
    post_user_id integer,
    user_id integer,
    full_move boolean
);


--
-- Name: moved_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.moved_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: moved_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.moved_posts_id_seq OWNED BY public.moved_posts.id;


--
-- Name: muted_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.muted_users (
    id integer NOT NULL,
    user_id integer NOT NULL,
    muted_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: muted_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.muted_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: muted_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.muted_users_id_seq OWNED BY public.muted_users.id;


--
-- Name: nested_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nested_topics (
    id bigint NOT NULL,
    topic_id bigint NOT NULL,
    pinned_post_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: nested_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nested_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nested_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nested_topics_id_seq OWNED BY public.nested_topics.id;


--
-- Name: nested_view_post_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nested_view_post_stats (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    direct_reply_count integer DEFAULT 0 NOT NULL,
    total_descendant_count integer DEFAULT 0 NOT NULL,
    whisper_direct_reply_count integer DEFAULT 0 NOT NULL,
    whisper_total_descendant_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: nested_view_post_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.nested_view_post_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: nested_view_post_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.nested_view_post_stats_id_seq OWNED BY public.nested_view_post_stats.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    notification_type integer NOT NULL,
    user_id integer NOT NULL,
    data character varying(1000) NOT NULL,
    read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    topic_id integer,
    post_number integer,
    post_action_id integer,
    high_priority boolean DEFAULT false NOT NULL,
    id bigint NOT NULL
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: oauth2_user_infos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth2_user_infos (
    id integer NOT NULL,
    user_id integer NOT NULL,
    uid character varying NOT NULL,
    provider character varying NOT NULL,
    email character varying,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: oauth2_user_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth2_user_infos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth2_user_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth2_user_infos_id_seq OWNED BY public.oauth2_user_infos.id;


--
-- Name: onceoff_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.onceoff_logs (
    id integer NOT NULL,
    job_name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: onceoff_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.onceoff_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: onceoff_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.onceoff_logs_id_seq OWNED BY public.onceoff_logs.id;


--
-- Name: optimized_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.optimized_images (
    id integer NOT NULL,
    sha1 character varying(40) NOT NULL,
    extension character varying(10) NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    upload_id integer NOT NULL,
    url character varying NOT NULL,
    filesize integer,
    etag character varying,
    version integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: optimized_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.optimized_images_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: optimized_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.optimized_images_id_seq OWNED BY public.optimized_images.id;


--
-- Name: optimized_videos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.optimized_videos (
    id bigint NOT NULL,
    upload_id integer NOT NULL,
    optimized_upload_id integer NOT NULL,
    adapter character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: optimized_videos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.optimized_videos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: optimized_videos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.optimized_videos_id_seq OWNED BY public.optimized_videos.id;


--
-- Name: permalinks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permalinks (
    id integer NOT NULL,
    url character varying(1000) NOT NULL,
    topic_id integer,
    post_id integer,
    category_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_url character varying(1000),
    tag_id integer,
    user_id integer
);


--
-- Name: permalinks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permalinks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permalinks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permalinks_id_seq OWNED BY public.permalinks.id;


--
-- Name: plugin_store_rows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.plugin_store_rows (
    id integer NOT NULL,
    plugin_name character varying NOT NULL,
    key character varying NOT NULL,
    type_name character varying NOT NULL,
    value text
);


--
-- Name: plugin_store_rows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.plugin_store_rows_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: plugin_store_rows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.plugin_store_rows_id_seq OWNED BY public.plugin_store_rows.id;


--
-- Name: policy_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.policy_users (
    id bigint NOT NULL,
    post_policy_id bigint NOT NULL,
    user_id integer NOT NULL,
    accepted_at timestamp without time zone,
    revoked_at timestamp without time zone,
    expired_at timestamp without time zone,
    version character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: policy_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.policy_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: policy_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.policy_users_id_seq OWNED BY public.policy_users.id;


--
-- Name: poll_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.poll_options (
    id bigint NOT NULL,
    poll_id bigint,
    digest character varying NOT NULL,
    html text NOT NULL,
    anonymous_votes integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: poll_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.poll_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: poll_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.poll_options_id_seq OWNED BY public.poll_options.id;


--
-- Name: poll_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.poll_votes (
    poll_id bigint,
    poll_option_id bigint,
    user_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    rank integer DEFAULT 0 NOT NULL
);


--
-- Name: polls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.polls (
    id bigint NOT NULL,
    post_id bigint,
    name character varying DEFAULT 'poll'::character varying NOT NULL,
    close_at timestamp without time zone,
    type integer DEFAULT 0 NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    results integer DEFAULT 0 NOT NULL,
    visibility integer DEFAULT 0 NOT NULL,
    min integer,
    max integer,
    step integer,
    anonymous_voters integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    chart_type integer DEFAULT 0 NOT NULL,
    groups character varying,
    title character varying,
    dynamic boolean DEFAULT false NOT NULL,
    closed_by_id integer,
    closed_at timestamp(6) without time zone
);


--
-- Name: polls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.polls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: polls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.polls_id_seq OWNED BY public.polls.id;


--
-- Name: post_action_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_action_types (
    name_key character varying(50) NOT NULL,
    is_flag boolean DEFAULT false NOT NULL,
    icon character varying(20),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id integer NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    score_bonus double precision DEFAULT 0.0 NOT NULL,
    reviewable_priority integer DEFAULT 0 NOT NULL
);


--
-- Name: post_action_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_action_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_action_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_action_types_id_seq OWNED BY public.post_action_types.id;


--
-- Name: post_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_actions (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    post_action_type_id integer NOT NULL,
    deleted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_by_id integer,
    related_post_id integer,
    staff_took_action boolean DEFAULT false NOT NULL,
    deferred_by_id integer,
    targets_topic boolean DEFAULT false NOT NULL,
    agreed_at timestamp without time zone,
    agreed_by_id integer,
    deferred_at timestamp without time zone,
    disagreed_at timestamp without time zone,
    disagreed_by_id integer
);


--
-- Name: post_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_actions_id_seq OWNED BY public.post_actions.id;


--
-- Name: post_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_custom_fields (
    id integer NOT NULL,
    post_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_custom_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_custom_fields_id_seq OWNED BY public.post_custom_fields.id;


--
-- Name: post_custom_prompts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_custom_prompts (
    id bigint NOT NULL,
    post_id integer NOT NULL,
    custom_prompt json NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: post_custom_prompts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_custom_prompts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_custom_prompts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_custom_prompts_id_seq OWNED BY public.post_custom_prompts.id;


--
-- Name: post_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_details (
    id integer NOT NULL,
    post_id integer,
    key character varying,
    value character varying,
    extra text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_details_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_details_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_details_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_details_id_seq OWNED BY public.post_details.id;


--
-- Name: post_hotlinked_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_hotlinked_media (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    url character varying NOT NULL,
    status public.hotlinked_media_status NOT NULL,
    upload_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: post_hotlinked_media_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_hotlinked_media_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_hotlinked_media_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_hotlinked_media_id_seq OWNED BY public.post_hotlinked_media.id;


--
-- Name: post_localizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_localizations (
    id bigint NOT NULL,
    post_id integer NOT NULL,
    post_version integer NOT NULL,
    locale character varying(20) NOT NULL,
    raw text NOT NULL,
    cooked text NOT NULL,
    localizer_user_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: post_localizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_localizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_localizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_localizations_id_seq OWNED BY public.post_localizations.id;


--
-- Name: post_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_policies (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    renew_start timestamp without time zone,
    renew_days integer,
    next_renew_at timestamp without time zone,
    reminder character varying,
    last_reminded_at timestamp without time zone,
    version character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    renew_interval integer,
    private boolean DEFAULT false NOT NULL,
    last_bumped_at timestamp(6) without time zone,
    add_users_to_group integer
);


--
-- Name: post_policies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_policies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_policies_id_seq OWNED BY public.post_policies.id;


--
-- Name: post_policy_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_policy_groups (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    post_policy_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: post_policy_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_policy_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_policy_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_policy_groups_id_seq OWNED BY public.post_policy_groups.id;


--
-- Name: post_replies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_replies (
    post_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reply_post_id integer
);


--
-- Name: post_reply_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_reply_keys (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    reply_key uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: post_reply_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_reply_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_reply_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_reply_keys_id_seq OWNED BY public.post_reply_keys.id;


--
-- Name: post_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_revisions (
    id integer NOT NULL,
    user_id integer,
    post_id integer,
    modifications text,
    number integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    hidden boolean DEFAULT false NOT NULL
);


--
-- Name: post_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_revisions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_revisions_id_seq OWNED BY public.post_revisions.id;


--
-- Name: post_search_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_search_data (
    post_id integer NOT NULL,
    search_data tsvector,
    raw_data text,
    locale character varying,
    version integer DEFAULT 0,
    private_message boolean NOT NULL
);


--
-- Name: post_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_stats (
    id integer NOT NULL,
    post_id integer,
    drafts_saved integer,
    typing_duration_msecs integer,
    composer_open_duration_msecs integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    composer_version integer,
    writing_device character varying,
    writing_device_user_agent character varying
);


--
-- Name: post_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_stats_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_stats_id_seq OWNED BY public.post_stats.id;


--
-- Name: post_timings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_timings (
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    user_id integer NOT NULL,
    msecs integer NOT NULL
);


--
-- Name: post_voting_comment_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_voting_comment_custom_fields (
    id bigint NOT NULL,
    post_voting_comment_id bigint NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: post_voting_comment_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_voting_comment_custom_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_voting_comment_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_voting_comment_custom_fields_id_seq OWNED BY public.post_voting_comment_custom_fields.id;


--
-- Name: post_voting_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_voting_comments (
    id bigint NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    raw text NOT NULL,
    cooked text NOT NULL,
    cooked_version integer,
    deleted_at timestamp without time zone,
    deleted_by_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    qa_vote_count integer DEFAULT 0,
    last_editor_id integer NOT NULL,
    CONSTRAINT qa_vote_count_positive CHECK ((qa_vote_count >= 0))
);


--
-- Name: post_voting_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_voting_comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_voting_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_voting_comments_id_seq OWNED BY public.post_voting_comments.id;


--
-- Name: post_voting_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_voting_votes (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    direction character varying NOT NULL,
    votable_type character varying NOT NULL,
    votable_id bigint NOT NULL
);


--
-- Name: post_voting_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_voting_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_voting_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_voting_votes_id_seq OWNED BY public.post_voting_votes.id;


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: problem_check_trackers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.problem_check_trackers (
    id bigint NOT NULL,
    identifier character varying NOT NULL,
    blips integer DEFAULT 0 NOT NULL,
    last_run_at timestamp(6) without time zone,
    next_run_at timestamp(6) without time zone,
    last_success_at timestamp(6) without time zone,
    last_problem_at timestamp(6) without time zone,
    details json DEFAULT '{}'::json,
    target character varying DEFAULT '__NULL__'::character varying NOT NULL,
    ignored_at timestamp(6) without time zone
);


--
-- Name: problem_check_trackers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.problem_check_trackers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: problem_check_trackers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.problem_check_trackers_id_seq OWNED BY public.problem_check_trackers.id;


--
-- Name: published_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.published_pages (
    id bigint NOT NULL,
    topic_id bigint NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    public boolean DEFAULT false NOT NULL
);


--
-- Name: published_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.published_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: published_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.published_pages_id_seq OWNED BY public.published_pages.id;


--
-- Name: push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_subscriptions (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    data character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    error_count integer DEFAULT 0 NOT NULL,
    first_error_at timestamp without time zone
);


--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.push_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.push_subscriptions_id_seq OWNED BY public.push_subscriptions.id;


--
-- Name: quoted_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quoted_posts (
    id integer NOT NULL,
    post_id integer NOT NULL,
    quoted_post_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: quoted_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quoted_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quoted_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quoted_posts_id_seq OWNED BY public.quoted_posts.id;


--
-- Name: rag_document_fragments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rag_document_fragments (
    id bigint NOT NULL,
    fragment text NOT NULL,
    upload_id integer NOT NULL,
    fragment_number integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    metadata text,
    target_id bigint NOT NULL,
    target_type character varying(800) NOT NULL
);


--
-- Name: rag_document_fragments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rag_document_fragments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rag_document_fragments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rag_document_fragments_id_seq OWNED BY public.rag_document_fragments.id;


--
-- Name: redelivering_webhook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.redelivering_webhook_events (
    id bigint NOT NULL,
    web_hook_event_id bigint NOT NULL,
    processing boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: redelivering_webhook_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.redelivering_webhook_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: redelivering_webhook_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.redelivering_webhook_events_id_seq OWNED BY public.redelivering_webhook_events.id;


--
-- Name: remote_themes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.remote_themes (
    id integer NOT NULL,
    remote_url character varying NOT NULL,
    remote_version character varying,
    local_version character varying,
    about_url character varying,
    license_url character varying,
    commits_behind integer,
    remote_updated_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    private_key text,
    branch character varying,
    last_error_text text,
    authors character varying,
    theme_version character varying,
    minimum_discourse_version character varying,
    maximum_discourse_version character varying,
    local_compat_ref character varying,
    remote_compat_ref character varying
);


--
-- Name: remote_themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.remote_themes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: remote_themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.remote_themes_id_seq OWNED BY public.remote_themes.id;


--
-- Name: reviewable_claimed_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviewable_claimed_topics (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    automatic boolean DEFAULT false NOT NULL
);


--
-- Name: reviewable_claimed_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviewable_claimed_topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviewable_claimed_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviewable_claimed_topics_id_seq OWNED BY public.reviewable_claimed_topics.id;


--
-- Name: reviewable_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviewable_histories (
    id bigint NOT NULL,
    reviewable_id integer NOT NULL,
    reviewable_history_type integer NOT NULL,
    status integer NOT NULL,
    created_by_id integer NOT NULL,
    edited json,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: reviewable_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviewable_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviewable_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviewable_histories_id_seq OWNED BY public.reviewable_histories.id;


--
-- Name: reviewable_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviewable_notes (
    id bigint NOT NULL,
    reviewable_id bigint NOT NULL,
    user_id bigint NOT NULL,
    content text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: reviewable_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviewable_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviewable_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviewable_notes_id_seq OWNED BY public.reviewable_notes.id;


--
-- Name: reviewable_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviewable_scores (
    id bigint NOT NULL,
    reviewable_id integer NOT NULL,
    user_id integer NOT NULL,
    reviewable_score_type integer NOT NULL,
    status integer NOT NULL,
    score double precision DEFAULT 0.0 NOT NULL,
    take_action_bonus double precision DEFAULT 0.0 NOT NULL,
    reviewed_by_id integer,
    reviewed_at timestamp without time zone,
    meta_topic_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reason character varying,
    user_accuracy_bonus double precision DEFAULT 0.0 NOT NULL,
    context character varying
);


--
-- Name: reviewable_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviewable_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviewable_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviewable_scores_id_seq OWNED BY public.reviewable_scores.id;


--
-- Name: reviewables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviewables (
    id bigint NOT NULL,
    type character varying NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    created_by_id integer NOT NULL,
    reviewable_by_moderator boolean DEFAULT false NOT NULL,
    reviewable_by_group_id integer,
    category_id integer,
    topic_id integer,
    score double precision DEFAULT 0.0 NOT NULL,
    potential_spam boolean DEFAULT false NOT NULL,
    target_id integer,
    target_type character varying,
    target_created_by_id integer,
    payload json,
    version integer DEFAULT 0 NOT NULL,
    latest_score timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    force_review boolean DEFAULT false NOT NULL,
    reject_reason text,
    potentially_illegal boolean DEFAULT false,
    type_source character varying DEFAULT 'unknown'::character varying NOT NULL
);


--
-- Name: reviewables_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviewables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviewables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviewables_id_seq OWNED BY public.reviewables.id;


--
-- Name: scheduler_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scheduler_stats (
    id integer NOT NULL,
    name character varying NOT NULL,
    hostname character varying NOT NULL,
    pid integer NOT NULL,
    duration_ms integer,
    live_slots_start integer,
    live_slots_finish integer,
    started_at timestamp without time zone NOT NULL,
    success boolean,
    error text
);


--
-- Name: scheduler_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.scheduler_stats_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: scheduler_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.scheduler_stats_id_seq OWNED BY public.scheduler_stats.id;


--
-- Name: schema_migration_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migration_details (
    id integer NOT NULL,
    version character varying NOT NULL,
    name character varying,
    hostname character varying,
    git_version character varying,
    rails_version character varying,
    duration integer,
    direction character varying,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: schema_migration_details_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.schema_migration_details_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schema_migration_details_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.schema_migration_details_id_seq OWNED BY public.schema_migration_details.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: screened_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.screened_emails (
    id integer NOT NULL,
    email character varying NOT NULL,
    action_type integer NOT NULL,
    match_count integer DEFAULT 0 NOT NULL,
    last_match_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    ip_address inet
);


--
-- Name: screened_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.screened_emails_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screened_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.screened_emails_id_seq OWNED BY public.screened_emails.id;


--
-- Name: screened_ip_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.screened_ip_addresses (
    id integer NOT NULL,
    ip_address inet NOT NULL,
    action_type integer NOT NULL,
    match_count integer DEFAULT 0 NOT NULL,
    last_match_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: screened_ip_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.screened_ip_addresses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screened_ip_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.screened_ip_addresses_id_seq OWNED BY public.screened_ip_addresses.id;


--
-- Name: screened_urls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.screened_urls (
    id integer NOT NULL,
    url character varying NOT NULL,
    domain character varying NOT NULL,
    action_type integer NOT NULL,
    match_count integer DEFAULT 0 NOT NULL,
    last_match_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    ip_address inet
);


--
-- Name: screened_urls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.screened_urls_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screened_urls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.screened_urls_id_seq OWNED BY public.screened_urls.id;


--
-- Name: search_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_logs (
    id integer NOT NULL,
    term character varying NOT NULL,
    user_id integer,
    ip_address inet,
    search_result_id integer,
    search_type integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    search_result_type integer,
    user_agent character varying(2000)
);


--
-- Name: search_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.search_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: search_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.search_logs_id_seq OWNED BY public.search_logs.id;


--
-- Name: shared_ai_conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shared_ai_conversations (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    target_id integer NOT NULL,
    target_type character varying NOT NULL,
    title character varying NOT NULL,
    llm_name character varying NOT NULL,
    context jsonb NOT NULL,
    share_key character varying NOT NULL,
    excerpt character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: shared_ai_conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shared_ai_conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shared_ai_conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shared_ai_conversations_id_seq OWNED BY public.shared_ai_conversations.id;


--
-- Name: shared_drafts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shared_drafts (
    topic_id integer NOT NULL,
    category_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id bigint NOT NULL
);


--
-- Name: shared_drafts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shared_drafts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shared_drafts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shared_drafts_id_seq OWNED BY public.shared_drafts.id;


--
-- Name: shelved_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shelved_notifications (
    id bigint NOT NULL,
    notification_id bigint NOT NULL
);


--
-- Name: shelved_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shelved_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shelved_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shelved_notifications_id_seq OWNED BY public.shelved_notifications.id;


--
-- Name: sidebar_section_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sidebar_section_links (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    linkable_id integer NOT NULL,
    linkable_type character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    sidebar_section_id integer,
    "position" integer DEFAULT 0 NOT NULL
);


--
-- Name: sidebar_section_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sidebar_section_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sidebar_section_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sidebar_section_links_id_seq OWNED BY public.sidebar_section_links.id;


--
-- Name: sidebar_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sidebar_sections (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    title character varying(30) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    public boolean DEFAULT false NOT NULL,
    section_type integer
);


--
-- Name: sidebar_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sidebar_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sidebar_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sidebar_sections_id_seq OWNED BY public.sidebar_sections.id;


--
-- Name: sidebar_urls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sidebar_urls (
    id bigint NOT NULL,
    name character varying(80) NOT NULL,
    value character varying(1000) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    icon character varying(40) NOT NULL,
    external boolean DEFAULT false NOT NULL,
    segment integer DEFAULT 0 NOT NULL
);


--
-- Name: sidebar_urls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sidebar_urls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sidebar_urls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sidebar_urls_id_seq OWNED BY public.sidebar_urls.id;


--
-- Name: silenced_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.silenced_assignments (
    id bigint NOT NULL,
    assignment_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: silenced_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.silenced_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: silenced_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.silenced_assignments_id_seq OWNED BY public.silenced_assignments.id;


--
-- Name: single_sign_on_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.single_sign_on_records (
    id integer NOT NULL,
    user_id integer NOT NULL,
    external_id character varying NOT NULL,
    last_payload text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_username character varying,
    external_email character varying,
    external_name character varying,
    external_avatar_url character varying(2000),
    external_profile_background_url character varying,
    external_card_background_url character varying
);


--
-- Name: single_sign_on_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.single_sign_on_records_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: single_sign_on_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.single_sign_on_records_id_seq OWNED BY public.single_sign_on_records.id;


--
-- Name: site_setting_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_setting_groups (
    id bigint NOT NULL,
    name character varying NOT NULL,
    group_ids character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: site_setting_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.site_setting_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_setting_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.site_setting_groups_id_seq OWNED BY public.site_setting_groups.id;


--
-- Name: site_setting_localizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_setting_localizations (
    id bigint NOT NULL,
    setting_name character varying NOT NULL,
    locale character varying(20) NOT NULL,
    value text NOT NULL,
    cooked text,
    localizer_user_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: site_setting_localizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.site_setting_localizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_setting_localizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.site_setting_localizations_id_seq OWNED BY public.site_setting_localizations.id;


--
-- Name: site_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_settings (
    id integer NOT NULL,
    name character varying NOT NULL,
    data_type integer NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: site_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.site_settings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.site_settings_id_seq OWNED BY public.site_settings.id;


--
-- Name: sitemaps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sitemaps (
    id bigint NOT NULL,
    name character varying NOT NULL,
    last_posted_at timestamp without time zone NOT NULL,
    enabled boolean DEFAULT true NOT NULL
);


--
-- Name: sitemaps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sitemaps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sitemaps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sitemaps_id_seq OWNED BY public.sitemaps.id;


--
-- Name: skipped_email_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.skipped_email_logs (
    id bigint NOT NULL,
    email_type character varying NOT NULL,
    to_address character varying NOT NULL,
    user_id integer,
    post_id integer,
    reason_type integer NOT NULL,
    custom_reason text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: skipped_email_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.skipped_email_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: skipped_email_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.skipped_email_logs_id_seq OWNED BY public.skipped_email_logs.id;


--
-- Name: stylesheet_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stylesheet_cache (
    id integer NOT NULL,
    target character varying NOT NULL,
    digest character varying NOT NULL,
    content text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    theme_id integer DEFAULT '-1'::integer NOT NULL,
    source_map text
);


--
-- Name: stylesheet_cache_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stylesheet_cache_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stylesheet_cache_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stylesheet_cache_id_seq OWNED BY public.stylesheet_cache.id;


--
-- Name: summary_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.summary_sections (
    id bigint NOT NULL,
    target_id integer NOT NULL,
    target_type character varying NOT NULL,
    content_range int4range,
    summarized_text character varying NOT NULL,
    meta_section_id integer,
    original_content_sha character varying NOT NULL,
    algorithm character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: summary_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.summary_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: summary_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.summary_sections_id_seq OWNED BY public.summary_sections.id;


--
-- Name: tag_group_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_group_memberships (
    id integer NOT NULL,
    tag_id integer NOT NULL,
    tag_group_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: tag_group_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_group_memberships_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_group_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_group_memberships_id_seq OWNED BY public.tag_group_memberships.id;


--
-- Name: tag_group_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_group_permissions (
    id bigint NOT NULL,
    tag_group_id bigint NOT NULL,
    group_id bigint NOT NULL,
    permission_type integer DEFAULT 1 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: tag_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_group_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_group_permissions_id_seq OWNED BY public.tag_group_permissions.id;


--
-- Name: tag_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_groups (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    parent_tag_id integer,
    one_per_topic boolean DEFAULT false
);


--
-- Name: tag_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_groups_id_seq OWNED BY public.tag_groups.id;


--
-- Name: tag_localizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_localizations (
    id bigint NOT NULL,
    tag_id bigint NOT NULL,
    locale character varying(20) NOT NULL,
    name character varying NOT NULL,
    description character varying(1000),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tag_localizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_localizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_localizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_localizations_id_seq OWNED BY public.tag_localizations.id;


--
-- Name: tag_search_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_search_data (
    tag_id integer NOT NULL,
    search_data tsvector,
    raw_data text,
    locale text,
    version integer DEFAULT 0
);


--
-- Name: tag_search_data_tag_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_search_data_tag_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_search_data_tag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_search_data_tag_id_seq OWNED BY public.tag_search_data.tag_id;


--
-- Name: tag_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_users (
    id integer NOT NULL,
    tag_id integer NOT NULL,
    user_id integer NOT NULL,
    notification_level integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: tag_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_users_id_seq OWNED BY public.tag_users.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    pm_topic_count integer DEFAULT 0 NOT NULL,
    target_tag_id integer,
    description character varying(1000),
    public_topic_count integer DEFAULT 0 NOT NULL,
    staff_topic_count integer DEFAULT 0 NOT NULL,
    locale character varying(20),
    slug character varying DEFAULT ''::character varying NOT NULL
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: tags_web_hooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags_web_hooks (
    web_hook_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: theme_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.theme_fields (
    id integer NOT NULL,
    theme_id integer NOT NULL,
    target_id integer NOT NULL,
    name character varying(255) NOT NULL,
    value text NOT NULL,
    value_baked text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    compiler_version character varying(50) DEFAULT 0 NOT NULL,
    error character varying,
    upload_id integer,
    type_id integer DEFAULT 0 NOT NULL
);


--
-- Name: theme_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.theme_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: theme_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.theme_fields_id_seq OWNED BY public.theme_fields.id;


--
-- Name: theme_modifier_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.theme_modifier_sets (
    id bigint NOT NULL,
    theme_id bigint NOT NULL,
    serialize_topic_excerpts boolean,
    csp_extensions character varying[],
    svg_icons character varying[],
    topic_thumbnail_sizes character varying[],
    custom_homepage boolean,
    serialize_post_user_badges character varying[],
    theme_setting_modifiers jsonb,
    serialize_topic_op_likes_data boolean,
    serialize_topic_is_hot boolean,
    only_theme_color_schemes boolean
);


--
-- Name: theme_modifier_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.theme_modifier_sets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: theme_modifier_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.theme_modifier_sets_id_seq OWNED BY public.theme_modifier_sets.id;


--
-- Name: theme_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.theme_settings (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    data_type integer NOT NULL,
    value text,
    theme_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    json_value jsonb
);


--
-- Name: theme_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.theme_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: theme_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.theme_settings_id_seq OWNED BY public.theme_settings.id;


--
-- Name: theme_settings_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.theme_settings_migrations (
    id bigint NOT NULL,
    theme_id integer NOT NULL,
    theme_field_id integer NOT NULL,
    version integer NOT NULL,
    name character varying(150) NOT NULL,
    diff json NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: theme_settings_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.theme_settings_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: theme_settings_migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.theme_settings_migrations_id_seq OWNED BY public.theme_settings_migrations.id;


--
-- Name: theme_site_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.theme_site_settings (
    id bigint NOT NULL,
    theme_id integer NOT NULL,
    name character varying NOT NULL,
    data_type integer NOT NULL,
    value text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: theme_site_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.theme_site_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: theme_site_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.theme_site_settings_id_seq OWNED BY public.theme_site_settings.id;


--
-- Name: theme_svg_sprites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.theme_svg_sprites (
    id bigint NOT NULL,
    theme_id integer NOT NULL,
    upload_id integer NOT NULL,
    sprite bytea NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: theme_svg_sprites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.theme_svg_sprites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: theme_svg_sprites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.theme_svg_sprites_id_seq OWNED BY public.theme_svg_sprites.id;


--
-- Name: theme_translation_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.theme_translation_overrides (
    id bigint NOT NULL,
    theme_id integer NOT NULL,
    locale character varying NOT NULL,
    translation_key character varying NOT NULL,
    value character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: theme_translation_overrides_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.theme_translation_overrides_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: theme_translation_overrides_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.theme_translation_overrides_id_seq OWNED BY public.theme_translation_overrides.id;


--
-- Name: themes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.themes (
    id integer NOT NULL,
    name character varying NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    compiler_version integer DEFAULT 0 NOT NULL,
    user_selectable boolean DEFAULT false NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    color_scheme_id integer,
    remote_theme_id integer,
    component boolean DEFAULT false NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    auto_update boolean DEFAULT true NOT NULL,
    dark_color_scheme_id integer
);


--
-- Name: themes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.themes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: themes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.themes_id_seq OWNED BY public.themes.id;


--
-- Name: top_topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.top_topics (
    id integer NOT NULL,
    topic_id integer,
    yearly_posts_count integer DEFAULT 0 NOT NULL,
    yearly_views_count integer DEFAULT 0 NOT NULL,
    yearly_likes_count integer DEFAULT 0 NOT NULL,
    monthly_posts_count integer DEFAULT 0 NOT NULL,
    monthly_views_count integer DEFAULT 0 NOT NULL,
    monthly_likes_count integer DEFAULT 0 NOT NULL,
    weekly_posts_count integer DEFAULT 0 NOT NULL,
    weekly_views_count integer DEFAULT 0 NOT NULL,
    weekly_likes_count integer DEFAULT 0 NOT NULL,
    daily_posts_count integer DEFAULT 0 NOT NULL,
    daily_views_count integer DEFAULT 0 NOT NULL,
    daily_likes_count integer DEFAULT 0 NOT NULL,
    daily_score double precision DEFAULT 0.0,
    weekly_score double precision DEFAULT 0.0,
    monthly_score double precision DEFAULT 0.0,
    yearly_score double precision DEFAULT 0.0,
    all_score double precision DEFAULT 0.0,
    daily_op_likes_count integer DEFAULT 0 NOT NULL,
    weekly_op_likes_count integer DEFAULT 0 NOT NULL,
    monthly_op_likes_count integer DEFAULT 0 NOT NULL,
    yearly_op_likes_count integer DEFAULT 0 NOT NULL,
    quarterly_posts_count integer DEFAULT 0 NOT NULL,
    quarterly_views_count integer DEFAULT 0 NOT NULL,
    quarterly_likes_count integer DEFAULT 0 NOT NULL,
    quarterly_score double precision DEFAULT 0.0,
    quarterly_op_likes_count integer DEFAULT 0 NOT NULL
);


--
-- Name: top_topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.top_topics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: top_topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.top_topics_id_seq OWNED BY public.top_topics.id;


--
-- Name: topic_allowed_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_allowed_groups (
    id integer NOT NULL,
    group_id integer NOT NULL,
    topic_id integer NOT NULL
);


--
-- Name: topic_allowed_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_allowed_groups_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_allowed_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_allowed_groups_id_seq OWNED BY public.topic_allowed_groups.id;


--
-- Name: topic_allowed_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_allowed_users (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_allowed_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_allowed_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_allowed_users_id_seq OWNED BY public.topic_allowed_users.id;


--
-- Name: topic_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_custom_fields (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_custom_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_custom_fields_id_seq OWNED BY public.topic_custom_fields.id;


--
-- Name: topic_embeds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_embeds (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    post_id integer NOT NULL,
    embed_url character varying(1000) NOT NULL,
    content_sha1 character varying(40),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by_id integer,
    embed_content_cache text
);


--
-- Name: topic_embeds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_embeds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_embeds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_embeds_id_seq OWNED BY public.topic_embeds.id;


--
-- Name: topic_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_groups (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    topic_id integer NOT NULL,
    last_read_post_number integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_groups_id_seq OWNED BY public.topic_groups.id;


--
-- Name: topic_hot_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_hot_scores (
    id bigint NOT NULL,
    topic_id integer NOT NULL,
    score double precision DEFAULT 0.0 NOT NULL,
    recent_likes integer DEFAULT 0 NOT NULL,
    recent_posters integer DEFAULT 0 NOT NULL,
    recent_first_bumped_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: topic_hot_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_hot_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_hot_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_hot_scores_id_seq OWNED BY public.topic_hot_scores.id;


--
-- Name: topic_invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_invites (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    invite_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_invites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_invites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_invites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_invites_id_seq OWNED BY public.topic_invites.id;


--
-- Name: topic_link_clicks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_link_clicks (
    id integer NOT NULL,
    topic_link_id integer NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    ip_address inet
);


--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_link_clicks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_link_clicks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_link_clicks_id_seq OWNED BY public.topic_link_clicks.id;


--
-- Name: topic_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_links (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    post_id integer,
    user_id integer NOT NULL,
    url character varying NOT NULL,
    domain character varying(100) NOT NULL,
    internal boolean DEFAULT false NOT NULL,
    link_topic_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    reflection boolean DEFAULT false,
    clicks integer DEFAULT 0 NOT NULL,
    link_post_id integer,
    title character varying,
    crawled_at timestamp without time zone,
    quote boolean DEFAULT false NOT NULL,
    extension character varying(10)
);


--
-- Name: topic_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_links_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_links_id_seq OWNED BY public.topic_links.id;


--
-- Name: topic_localizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_localizations (
    id bigint NOT NULL,
    topic_id integer NOT NULL,
    locale character varying(20) NOT NULL,
    title character varying NOT NULL,
    fancy_title character varying NOT NULL,
    localizer_user_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    excerpt character varying
);


--
-- Name: topic_localizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_localizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_localizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_localizations_id_seq OWNED BY public.topic_localizations.id;


--
-- Name: topic_search_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_search_data (
    topic_id integer NOT NULL,
    raw_data text,
    locale character varying NOT NULL,
    search_data tsvector,
    version integer DEFAULT 0
);


--
-- Name: topic_search_data_topic_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_search_data_topic_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_search_data_topic_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_search_data_topic_id_seq OWNED BY public.topic_search_data.topic_id;


--
-- Name: topic_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_tags (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: topic_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_tags_id_seq OWNED BY public.topic_tags.id;


--
-- Name: topic_thumbnails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_thumbnails (
    id bigint NOT NULL,
    upload_id bigint NOT NULL,
    optimized_image_id bigint,
    max_width integer NOT NULL,
    max_height integer NOT NULL
);


--
-- Name: topic_thumbnails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_thumbnails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_thumbnails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_thumbnails_id_seq OWNED BY public.topic_thumbnails.id;


--
-- Name: topic_timers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_timers (
    id integer NOT NULL,
    execute_at timestamp without time zone NOT NULL,
    status_type integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer,
    based_on_last_post boolean DEFAULT false NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    category_id integer,
    public_type boolean DEFAULT true,
    duration_minutes integer,
    type character varying DEFAULT 'TopicTimer'::character varying NOT NULL,
    timerable_id integer NOT NULL
);


--
-- Name: topic_timers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_timers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_timers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_timers_id_seq OWNED BY public.topic_timers.id;


--
-- Name: topic_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_users (
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    posted boolean DEFAULT false NOT NULL,
    last_read_post_number integer,
    last_visited_at timestamp without time zone,
    first_visited_at timestamp without time zone,
    notification_level integer DEFAULT 1 NOT NULL,
    notifications_changed_at timestamp without time zone,
    notifications_reason_id integer,
    total_msecs_viewed integer DEFAULT 0 NOT NULL,
    cleared_pinned_at timestamp without time zone,
    id integer NOT NULL,
    last_emailed_post_number integer,
    liked boolean DEFAULT false,
    bookmarked boolean DEFAULT false,
    last_posted_at timestamp without time zone
);


--
-- Name: topic_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_users_id_seq OWNED BY public.topic_users.id;


--
-- Name: topic_view_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_view_stats (
    id bigint NOT NULL,
    topic_id integer NOT NULL,
    viewed_at date NOT NULL,
    anonymous_views integer DEFAULT 0 NOT NULL,
    logged_in_views integer DEFAULT 0 NOT NULL
);


--
-- Name: topic_view_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_view_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_view_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_view_stats_id_seq OWNED BY public.topic_view_stats.id;


--
-- Name: topic_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_views (
    topic_id integer NOT NULL,
    viewed_at date NOT NULL,
    user_id integer,
    ip_address inet
);


--
-- Name: topic_voting_category_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_voting_category_settings (
    id bigint NOT NULL,
    category_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: topic_voting_category_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_voting_category_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_voting_category_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_voting_category_settings_id_seq OWNED BY public.topic_voting_category_settings.id;


--
-- Name: topic_voting_topic_vote_count; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_voting_topic_vote_count (
    id bigint NOT NULL,
    topic_id integer,
    votes_count integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: topic_voting_topic_vote_count_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_voting_topic_vote_count_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_voting_topic_vote_count_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_voting_topic_vote_count_id_seq OWNED BY public.topic_voting_topic_vote_count.id;


--
-- Name: topic_voting_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_voting_votes (
    id bigint NOT NULL,
    topic_id integer,
    user_id integer,
    archive boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: topic_voting_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topic_voting_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topic_voting_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topic_voting_votes_id_seq OWNED BY public.topic_voting_votes.id;


--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topics_id_seq OWNED BY public.topics.id;


--
-- Name: translation_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.translation_overrides (
    id integer NOT NULL,
    locale character varying NOT NULL,
    translation_key character varying NOT NULL,
    value character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    original_translation text,
    status integer DEFAULT 0 NOT NULL
);


--
-- Name: translation_overrides_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.translation_overrides_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: translation_overrides_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.translation_overrides_id_seq OWNED BY public.translation_overrides.id;


--
-- Name: unsubscribe_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unsubscribe_keys (
    key character varying(64) NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    unsubscribe_key_type character varying,
    topic_id integer,
    post_id integer
);


--
-- Name: upcoming_change_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.upcoming_change_events (
    id bigint NOT NULL,
    event_type integer NOT NULL,
    upcoming_change_name character varying NOT NULL,
    event_data json,
    acting_user_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: upcoming_change_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.upcoming_change_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: upcoming_change_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.upcoming_change_events_id_seq OWNED BY public.upcoming_change_events.id;


--
-- Name: upload_references; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.upload_references (
    id bigint NOT NULL,
    upload_id bigint NOT NULL,
    target_type character varying NOT NULL,
    target_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: upload_references_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.upload_references_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: upload_references_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.upload_references_id_seq OWNED BY public.upload_references.id;


--
-- Name: uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.uploads (
    id integer NOT NULL,
    user_id integer NOT NULL,
    original_filename character varying NOT NULL,
    filesize bigint NOT NULL,
    width integer,
    height integer,
    url character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    sha1 character varying(40),
    origin character varying(2000),
    retain_hours integer,
    extension character varying(10),
    thumbnail_width integer,
    thumbnail_height integer,
    etag character varying,
    secure boolean DEFAULT false NOT NULL,
    access_control_post_id bigint,
    original_sha1 character varying,
    animated boolean,
    verification_status integer DEFAULT 1 NOT NULL,
    security_last_changed_at timestamp without time zone,
    security_last_changed_reason character varying,
    dominant_color text
);


--
-- Name: uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.uploads_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.uploads_id_seq OWNED BY public.uploads.id;


--
-- Name: user_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_actions (
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

CREATE SEQUENCE public.user_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_actions_id_seq OWNED BY public.user_actions.id;


--
-- Name: user_api_key_client_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_api_key_client_scopes (
    id bigint NOT NULL,
    user_api_key_client_id bigint NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_api_key_client_scopes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_api_key_client_scopes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_api_key_client_scopes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_api_key_client_scopes_id_seq OWNED BY public.user_api_key_client_scopes.id;


--
-- Name: user_api_key_clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_api_key_clients (
    id bigint NOT NULL,
    client_id character varying NOT NULL,
    application_name character varying NOT NULL,
    public_key character varying,
    auth_redirect character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_api_key_clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_api_key_clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_api_key_clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_api_key_clients_id_seq OWNED BY public.user_api_key_clients.id;


--
-- Name: user_api_key_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_api_key_scopes (
    id bigint NOT NULL,
    user_api_key_id integer NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    allowed_parameters jsonb
);


--
-- Name: user_api_key_scopes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_api_key_scopes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_api_key_scopes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_api_key_scopes_id_seq OWNED BY public.user_api_key_scopes.id;


--
-- Name: user_api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_api_keys (
    id integer NOT NULL,
    user_id integer NOT NULL,
    client_id character varying,
    application_name character varying,
    push_url character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    revoked_at timestamp without time zone,
    last_used_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    key_hash character varying NOT NULL,
    user_api_key_client_id bigint,
    expires_at timestamp(6) without time zone
);


--
-- Name: user_api_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_api_keys_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_api_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_api_keys_id_seq OWNED BY public.user_api_keys.id;


--
-- Name: user_archived_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_archived_messages (
    id integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_archived_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_archived_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_archived_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_archived_messages_id_seq OWNED BY public.user_archived_messages.id;


--
-- Name: user_associated_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_associated_accounts (
    id bigint NOT NULL,
    provider_name character varying NOT NULL,
    provider_uid character varying NOT NULL,
    user_id integer,
    last_used timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    info jsonb DEFAULT '{}'::jsonb NOT NULL,
    credentials jsonb DEFAULT '{}'::jsonb NOT NULL,
    extra jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_associated_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_associated_accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_associated_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_associated_accounts_id_seq OWNED BY public.user_associated_accounts.id;


--
-- Name: user_associated_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_associated_groups (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    associated_group_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_associated_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_associated_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_associated_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_associated_groups_id_seq OWNED BY public.user_associated_groups.id;


--
-- Name: user_auth_token_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_auth_token_logs (
    id integer NOT NULL,
    action character varying NOT NULL,
    user_auth_token_id integer,
    user_id integer,
    client_ip inet,
    user_agent character varying,
    auth_token character varying,
    created_at timestamp without time zone,
    path character varying
);


--
-- Name: user_auth_token_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_auth_token_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_auth_token_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_auth_token_logs_id_seq OWNED BY public.user_auth_token_logs.id;


--
-- Name: user_auth_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_auth_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    auth_token character varying NOT NULL,
    prev_auth_token character varying NOT NULL,
    user_agent character varying,
    auth_token_seen boolean DEFAULT false NOT NULL,
    client_ip inet,
    rotated_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    seen_at timestamp without time zone,
    authenticated_with_oauth boolean DEFAULT false,
    impersonated_user_id integer,
    impersonation_expires_at timestamp(6) without time zone
);


--
-- Name: user_auth_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_auth_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_auth_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_auth_tokens_id_seq OWNED BY public.user_auth_tokens.id;


--
-- Name: user_avatars; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_avatars (
    id integer NOT NULL,
    user_id integer NOT NULL,
    custom_upload_id integer,
    gravatar_upload_id integer,
    last_gravatar_download_attempt timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_avatars_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_avatars_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_avatars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_avatars_id_seq OWNED BY public.user_avatars.id;


--
-- Name: user_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_badges (
    id integer NOT NULL,
    badge_id integer NOT NULL,
    user_id integer NOT NULL,
    granted_at timestamp without time zone NOT NULL,
    granted_by_id integer NOT NULL,
    post_id integer,
    seq integer DEFAULT 0 NOT NULL,
    featured_rank integer,
    created_at timestamp without time zone NOT NULL,
    is_favorite boolean,
    notification_id bigint
);


--
-- Name: user_badges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_badges_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_badges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_badges_id_seq OWNED BY public.user_badges.id;


--
-- Name: user_chat_channel_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_chat_channel_memberships (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    chat_channel_id bigint NOT NULL,
    last_read_message_id bigint,
    following boolean DEFAULT false NOT NULL,
    muted boolean DEFAULT false NOT NULL,
    desktop_notification_level integer DEFAULT 1 NOT NULL,
    mobile_notification_level integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    last_unread_mention_when_emailed_id bigint,
    join_mode integer DEFAULT 0 NOT NULL,
    last_viewed_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    notification_level integer DEFAULT 1 NOT NULL,
    starred boolean DEFAULT false NOT NULL,
    last_viewed_pins_at timestamp(6) without time zone
);


--
-- Name: user_chat_channel_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_chat_channel_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_chat_channel_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_chat_channel_memberships_id_seq OWNED BY public.user_chat_channel_memberships.id;


--
-- Name: user_chat_thread_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_chat_thread_memberships (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    thread_id bigint NOT NULL,
    last_read_message_id bigint,
    notification_level integer DEFAULT 2 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    thread_title_prompt_seen boolean DEFAULT false NOT NULL,
    last_unread_message_when_emailed_id bigint
);


--
-- Name: user_chat_thread_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_chat_thread_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_chat_thread_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_chat_thread_memberships_id_seq OWNED BY public.user_chat_thread_memberships.id;


--
-- Name: user_custom_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_custom_fields (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_custom_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_custom_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_custom_fields_id_seq OWNED BY public.user_custom_fields.id;


--
-- Name: user_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_emails (
    id integer NOT NULL,
    user_id integer NOT NULL,
    email character varying(513) NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    normalized_email character varying
);


--
-- Name: user_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_emails_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_emails_id_seq OWNED BY public.user_emails.id;


--
-- Name: user_exports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_exports (
    id integer NOT NULL,
    file_name character varying NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    upload_id integer,
    topic_id integer
);


--
-- Name: user_exports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_exports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_exports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_exports_id_seq OWNED BY public.user_exports.id;


--
-- Name: user_field_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_field_options (
    id integer NOT NULL,
    user_field_id integer NOT NULL,
    value character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_field_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_field_options_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_field_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_field_options_id_seq OWNED BY public.user_field_options.id;


--
-- Name: user_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_fields (
    id integer NOT NULL,
    name character varying NOT NULL,
    field_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    editable boolean DEFAULT false NOT NULL,
    description character varying NOT NULL,
    required boolean DEFAULT true NOT NULL,
    show_on_profile boolean DEFAULT false NOT NULL,
    "position" integer DEFAULT 0,
    show_on_user_card boolean DEFAULT false NOT NULL,
    external_name character varying,
    external_type character varying,
    searchable boolean DEFAULT false NOT NULL,
    requirement integer DEFAULT 0 NOT NULL,
    field_type_enum integer NOT NULL,
    show_on_signup boolean DEFAULT true NOT NULL
);


--
-- Name: user_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_fields_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_fields_id_seq OWNED BY public.user_fields.id;


--
-- Name: user_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_histories (
    id integer NOT NULL,
    action integer NOT NULL,
    acting_user_id integer,
    target_user_id integer,
    details text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    context character varying,
    ip_address character varying,
    email character varying,
    subject text,
    previous_value text,
    new_value text,
    topic_id integer,
    admin_only boolean DEFAULT false,
    post_id integer,
    custom_type character varying,
    category_id integer,
    reviewable_id bigint
);


--
-- Name: user_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_histories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_histories_id_seq OWNED BY public.user_histories.id;


--
-- Name: user_ip_address_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_ip_address_histories (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    ip_address inet NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_ip_address_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_ip_address_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_ip_address_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_ip_address_histories_id_seq OWNED BY public.user_ip_address_histories.id;


--
-- Name: user_notification_schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_notification_schedules (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    day_0_start_time integer NOT NULL,
    day_0_end_time integer NOT NULL,
    day_1_start_time integer NOT NULL,
    day_1_end_time integer NOT NULL,
    day_2_start_time integer NOT NULL,
    day_2_end_time integer NOT NULL,
    day_3_start_time integer NOT NULL,
    day_3_end_time integer NOT NULL,
    day_4_start_time integer NOT NULL,
    day_4_end_time integer NOT NULL,
    day_5_start_time integer NOT NULL,
    day_5_end_time integer NOT NULL,
    day_6_start_time integer NOT NULL,
    day_6_end_time integer NOT NULL
);


--
-- Name: user_notification_schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_notification_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_notification_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_notification_schedules_id_seq OWNED BY public.user_notification_schedules.id;


--
-- Name: user_open_ids; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_open_ids (
    id integer NOT NULL,
    user_id integer NOT NULL,
    email character varying NOT NULL,
    url character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    active boolean NOT NULL
);


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_open_ids_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_open_ids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_open_ids_id_seq OWNED BY public.user_open_ids.id;


--
-- Name: user_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_options (
    user_id integer NOT NULL,
    mailing_list_mode boolean DEFAULT false NOT NULL,
    email_digests boolean,
    external_links_in_new_tab boolean DEFAULT false NOT NULL,
    enable_quoting boolean DEFAULT true NOT NULL,
    dynamic_favicon boolean DEFAULT false NOT NULL,
    automatically_unpin_topics boolean DEFAULT true NOT NULL,
    digest_after_minutes integer,
    auto_track_topics_after_msecs integer,
    new_topic_duration_minutes integer,
    last_redirected_to_top_at timestamp without time zone,
    email_previous_replies integer DEFAULT 2 NOT NULL,
    email_in_reply_to boolean DEFAULT true NOT NULL,
    like_notification_frequency integer DEFAULT 1 NOT NULL,
    mailing_list_mode_frequency integer DEFAULT 1 NOT NULL,
    include_tl0_in_digests boolean DEFAULT false,
    notification_level_when_replying integer,
    theme_key_seq integer DEFAULT 0 NOT NULL,
    allow_private_messages boolean DEFAULT true NOT NULL,
    homepage_id integer,
    theme_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    hide_profile_and_presence boolean DEFAULT false NOT NULL,
    text_size_key integer DEFAULT 0 NOT NULL,
    text_size_seq integer DEFAULT 0 NOT NULL,
    email_level integer DEFAULT 1 NOT NULL,
    email_messages_level integer DEFAULT 0 NOT NULL,
    title_count_mode_key integer DEFAULT 0 NOT NULL,
    enable_defer boolean DEFAULT false NOT NULL,
    timezone character varying,
    enable_allowed_pm_users boolean DEFAULT false NOT NULL,
    dark_scheme_id integer,
    skip_new_user_tips boolean DEFAULT false NOT NULL,
    color_scheme_id integer,
    default_calendar integer DEFAULT 0 NOT NULL,
    chat_enabled boolean DEFAULT true NOT NULL,
    only_chat_push_notifications boolean,
    oldest_search_log_date timestamp without time zone,
    chat_sound character varying,
    dismissed_channel_retention_reminder boolean,
    dismissed_dm_retention_reminder boolean,
    bookmark_auto_delete_preference integer DEFAULT 3 NOT NULL,
    ignore_channel_wide_mention boolean,
    chat_email_frequency integer DEFAULT 1 NOT NULL,
    seen_popups integer[],
    policy_email_frequency integer DEFAULT 0 NOT NULL,
    chat_header_indicator_preference integer DEFAULT 0 NOT NULL,
    sidebar_link_to_filtered_list boolean DEFAULT false NOT NULL,
    sidebar_show_count_of_new_items boolean DEFAULT false NOT NULL,
    watched_precedence_over_muted boolean DEFAULT false NOT NULL,
    chat_separate_sidebar_mode integer DEFAULT 0 NOT NULL,
    topics_unread_when_closed boolean DEFAULT true NOT NULL,
    show_thread_title_prompts boolean DEFAULT true NOT NULL,
    auto_image_caption boolean DEFAULT false NOT NULL,
    enable_smart_lists boolean DEFAULT true NOT NULL,
    hide_profile boolean DEFAULT false NOT NULL,
    hide_presence boolean DEFAULT false NOT NULL,
    chat_send_shortcut integer DEFAULT 0 NOT NULL,
    notification_level_when_assigned integer DEFAULT 3 NOT NULL,
    chat_quick_reaction_type integer DEFAULT 0 NOT NULL,
    chat_quick_reactions_custom character varying,
    ai_search_discoveries boolean DEFAULT true NOT NULL,
    composition_mode integer DEFAULT 1 NOT NULL,
    interface_color_mode integer DEFAULT 1 NOT NULL,
    enable_markdown_monospace_font boolean DEFAULT true NOT NULL,
    notify_on_linked_posts boolean DEFAULT true NOT NULL,
    discourse_rewind_share_publicly boolean DEFAULT false NOT NULL,
    discourse_rewind_dismissed_at timestamp(6) without time zone,
    discourse_rewind_enabled boolean DEFAULT true NOT NULL,
    notify_on_solved boolean DEFAULT true NOT NULL,
    show_original_content boolean DEFAULT false NOT NULL,
    enable_upcoming_change_available_notifications boolean DEFAULT true NOT NULL
);


--
-- Name: user_passwords; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_passwords (
    id integer NOT NULL,
    user_id integer NOT NULL,
    password_hash character varying(64) NOT NULL,
    password_salt character varying(32) NOT NULL,
    password_algorithm character varying(64) NOT NULL,
    password_expired_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_passwords_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_passwords_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_passwords_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_passwords_id_seq OWNED BY public.user_passwords.id;


--
-- Name: user_profile_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profile_views (
    id integer NOT NULL,
    user_profile_id integer NOT NULL,
    viewed_at timestamp without time zone NOT NULL,
    ip_address inet,
    user_id integer
);


--
-- Name: user_profile_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_profile_views_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_profile_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_profile_views_id_seq OWNED BY public.user_profile_views.id;


--
-- Name: user_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profiles (
    user_id integer NOT NULL,
    location character varying(3000),
    website character varying(3000),
    bio_raw text,
    bio_cooked text,
    dismissed_banner_key integer,
    bio_cooked_version integer,
    views integer DEFAULT 0 NOT NULL,
    profile_background_upload_id integer,
    card_background_upload_id integer,
    granted_title_badge_id bigint,
    featured_topic_id integer
);


--
-- Name: user_required_fields_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_required_fields_versions (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_required_fields_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_required_fields_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_required_fields_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_required_fields_versions_id_seq OWNED BY public.user_required_fields_versions.id;


--
-- Name: user_search_data; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_search_data (
    user_id integer NOT NULL,
    search_data tsvector,
    raw_data text,
    locale text,
    version integer DEFAULT 0
);


--
-- Name: user_second_factors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_second_factors (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    method integer NOT NULL,
    data character varying NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    last_used timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying(300)
);


--
-- Name: user_second_factors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_second_factors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_second_factors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_second_factors_id_seq OWNED BY public.user_second_factors.id;


--
-- Name: user_security_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_security_keys (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    credential_id character varying NOT NULL,
    public_key character varying NOT NULL,
    factor_type integer DEFAULT 0 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    name character varying(300) NOT NULL,
    last_used timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_security_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_security_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_security_keys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_security_keys_id_seq OWNED BY public.user_security_keys.id;


--
-- Name: user_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_stats (
    user_id integer NOT NULL,
    topics_entered integer DEFAULT 0 NOT NULL,
    time_read integer DEFAULT 0 NOT NULL,
    days_visited integer DEFAULT 0 NOT NULL,
    posts_read_count integer DEFAULT 0 NOT NULL,
    likes_given integer DEFAULT 0 NOT NULL,
    likes_received integer DEFAULT 0 NOT NULL,
    new_since timestamp without time zone NOT NULL,
    read_faq timestamp without time zone,
    first_post_created_at timestamp without time zone,
    post_count integer DEFAULT 0 NOT NULL,
    topic_count integer DEFAULT 0 NOT NULL,
    bounce_score double precision DEFAULT 0 NOT NULL,
    reset_bounce_score_after timestamp without time zone,
    flags_agreed integer DEFAULT 0 NOT NULL,
    flags_disagreed integer DEFAULT 0 NOT NULL,
    flags_ignored integer DEFAULT 0 NOT NULL,
    first_unread_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    distinct_badge_count integer DEFAULT 0 NOT NULL,
    first_unread_pm_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    digest_attempted_at timestamp without time zone,
    post_edits_count integer,
    draft_count integer DEFAULT 0 NOT NULL,
    pending_posts_count integer DEFAULT 0 NOT NULL
);


--
-- Name: user_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_statuses (
    user_id integer NOT NULL,
    emoji character varying NOT NULL,
    description character varying NOT NULL,
    set_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone
);


--
-- Name: user_statuses_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_statuses_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_statuses_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_statuses_user_id_seq OWNED BY public.user_statuses.user_id;


--
-- Name: user_uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_uploads (
    id bigint NOT NULL,
    upload_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: user_uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_uploads_id_seq OWNED BY public.user_uploads.id;


--
-- Name: user_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_visits (
    id integer NOT NULL,
    user_id integer NOT NULL,
    visited_at date NOT NULL,
    posts_read integer DEFAULT 0,
    mobile boolean DEFAULT false,
    time_read integer DEFAULT 0 NOT NULL
);


--
-- Name: user_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_visits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_visits_id_seq OWNED BY public.user_visits.id;


--
-- Name: user_warnings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_warnings (
    id integer NOT NULL,
    topic_id integer NOT NULL,
    user_id integer NOT NULL,
    created_by_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_warnings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_warnings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_warnings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_warnings_id_seq OWNED BY public.user_warnings.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(60) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying,
    last_posted_at timestamp without time zone,
    active boolean DEFAULT false NOT NULL,
    username_lower character varying(60) NOT NULL,
    last_seen_at timestamp without time zone,
    admin boolean DEFAULT false NOT NULL,
    last_emailed_at timestamp without time zone,
    trust_level integer NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    approved_by_id integer,
    approved_at timestamp without time zone,
    previous_visit_at timestamp without time zone,
    suspended_at timestamp without time zone,
    suspended_till timestamp without time zone,
    date_of_birth date,
    views integer DEFAULT 0 NOT NULL,
    flag_level integer DEFAULT 0 NOT NULL,
    ip_address inet,
    moderator boolean DEFAULT false,
    title character varying,
    uploaded_avatar_id integer,
    locale character varying(10),
    primary_group_id integer,
    registration_ip_address inet,
    staged boolean DEFAULT false NOT NULL,
    first_seen_at timestamp without time zone,
    silenced_till timestamp without time zone,
    group_locked_trust_level integer,
    manual_locked_trust_level integer,
    secure_identifier character varying,
    flair_group_id integer,
    last_seen_reviewable_id integer,
    required_fields_version integer,
    seen_notification_id bigint DEFAULT 0 NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: watched_word_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watched_word_groups (
    id bigint NOT NULL,
    action integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: watched_word_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.watched_word_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: watched_word_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.watched_word_groups_id_seq OWNED BY public.watched_word_groups.id;


--
-- Name: watched_words; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.watched_words (
    id integer NOT NULL,
    word character varying NOT NULL,
    action integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    replacement character varying,
    case_sensitive boolean DEFAULT false NOT NULL,
    watched_word_group_id bigint,
    html boolean DEFAULT false NOT NULL
);


--
-- Name: watched_words_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.watched_words_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: watched_words_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.watched_words_id_seq OWNED BY public.watched_words.id;


--
-- Name: web_crawler_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_crawler_requests (
    id bigint NOT NULL,
    date date NOT NULL,
    user_agent character varying NOT NULL,
    count integer DEFAULT 0 NOT NULL
);


--
-- Name: web_crawler_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.web_crawler_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: web_crawler_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.web_crawler_requests_id_seq OWNED BY public.web_crawler_requests.id;


--
-- Name: web_hook_event_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_hook_event_types (
    id integer NOT NULL,
    name character varying NOT NULL,
    "group" integer
);


--
-- Name: web_hook_event_types_hooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_hook_event_types_hooks (
    web_hook_id integer NOT NULL,
    web_hook_event_type_id integer NOT NULL
);


--
-- Name: web_hook_event_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.web_hook_event_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: web_hook_event_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.web_hook_event_types_id_seq OWNED BY public.web_hook_event_types.id;


--
-- Name: web_hook_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_hook_events (
    id bigint NOT NULL,
    web_hook_id integer NOT NULL,
    headers character varying,
    payload text,
    status integer DEFAULT 0,
    response_headers character varying,
    response_body text,
    duration integer DEFAULT 0,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: web_hook_events_daily_aggregates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_hook_events_daily_aggregates (
    id bigint NOT NULL,
    web_hook_id bigint NOT NULL,
    date date,
    successful_event_count integer,
    failed_event_count integer,
    mean_duration integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: web_hook_events_daily_aggregates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.web_hook_events_daily_aggregates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: web_hook_events_daily_aggregates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.web_hook_events_daily_aggregates_id_seq OWNED BY public.web_hook_events_daily_aggregates.id;


--
-- Name: web_hook_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.web_hook_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: web_hook_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.web_hook_events_id_seq OWNED BY public.web_hook_events.id;


--
-- Name: web_hooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_hooks (
    id integer NOT NULL,
    payload_url character varying NOT NULL,
    content_type integer DEFAULT 1 NOT NULL,
    last_delivery_status integer DEFAULT 1 NOT NULL,
    status integer DEFAULT 1 NOT NULL,
    secret character varying DEFAULT ''::character varying,
    wildcard_web_hook boolean DEFAULT false NOT NULL,
    verify_certificate boolean DEFAULT true NOT NULL,
    active boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: web_hooks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.web_hooks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: web_hooks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.web_hooks_id_seq OWNED BY public.web_hooks.id;


--
-- Name: access_control_lists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_control_lists ALTER COLUMN id SET DEFAULT nextval('public.access_control_lists_id_seq'::regclass);


--
-- Name: ad_plugin_house_ads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_house_ads ALTER COLUMN id SET DEFAULT nextval('public.ad_plugin_house_ads_id_seq'::regclass);


--
-- Name: ad_plugin_impressions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_impressions ALTER COLUMN id SET DEFAULT nextval('public.ad_plugin_impressions_id_seq'::regclass);


--
-- Name: admin_dashboard_reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_dashboard_reports ALTER COLUMN id SET DEFAULT nextval('public.admin_dashboard_reports_id_seq'::regclass);


--
-- Name: admin_dashboard_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_dashboard_sections ALTER COLUMN id SET DEFAULT nextval('public.admin_dashboard_sections_id_seq'::regclass);


--
-- Name: admin_notices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_notices ALTER COLUMN id SET DEFAULT nextval('public.admin_notices_id_seq'::regclass);


--
-- Name: ai_agent_mcp_servers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_agent_mcp_servers ALTER COLUMN id SET DEFAULT nextval('public.ai_agent_mcp_servers_id_seq'::regclass);


--
-- Name: ai_agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_agents ALTER COLUMN id SET DEFAULT nextval('public.ai_agents_id_seq'::regclass);


--
-- Name: ai_api_audit_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_api_audit_logs ALTER COLUMN id SET DEFAULT nextval('public.ai_api_audit_logs_id_seq'::regclass);


--
-- Name: ai_api_request_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_api_request_stats ALTER COLUMN id SET DEFAULT nextval('public.ai_api_request_stats_id_seq'::regclass);


--
-- Name: ai_artifact_key_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_artifact_key_values ALTER COLUMN id SET DEFAULT nextval('public.ai_artifact_key_values_id_seq'::regclass);


--
-- Name: ai_artifact_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_artifact_versions ALTER COLUMN id SET DEFAULT nextval('public.ai_artifact_versions_id_seq'::regclass);


--
-- Name: ai_artifacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_artifacts ALTER COLUMN id SET DEFAULT nextval('public.ai_artifacts_id_seq'::regclass);


--
-- Name: ai_mcp_oauth_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_mcp_oauth_tokens ALTER COLUMN id SET DEFAULT nextval('public.ai_mcp_oauth_tokens_id_seq'::regclass);


--
-- Name: ai_mcp_servers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_mcp_servers ALTER COLUMN id SET DEFAULT nextval('public.ai_mcp_servers_id_seq'::regclass);


--
-- Name: ai_moderation_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_moderation_settings ALTER COLUMN id SET DEFAULT nextval('public.ai_moderation_settings_id_seq'::regclass);


--
-- Name: ai_secrets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_secrets ALTER COLUMN id SET DEFAULT nextval('public.ai_secrets_id_seq'::regclass);


--
-- Name: ai_spam_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_spam_logs ALTER COLUMN id SET DEFAULT nextval('public.ai_spam_logs_id_seq'::regclass);


--
-- Name: ai_summaries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_summaries ALTER COLUMN id SET DEFAULT nextval('public.ai_summaries_id_seq'::regclass);


--
-- Name: ai_tool_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tool_actions ALTER COLUMN id SET DEFAULT nextval('public.ai_tool_actions_id_seq'::regclass);


--
-- Name: ai_tool_secret_bindings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tool_secret_bindings ALTER COLUMN id SET DEFAULT nextval('public.ai_tool_secret_bindings_id_seq'::regclass);


--
-- Name: ai_tools id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tools ALTER COLUMN id SET DEFAULT nextval('public.ai_tools_id_seq'::regclass);


--
-- Name: allowed_pm_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allowed_pm_users ALTER COLUMN id SET DEFAULT nextval('public.allowed_pm_users_id_seq'::regclass);


--
-- Name: anonymous_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anonymous_users ALTER COLUMN id SET DEFAULT nextval('public.anonymous_users_id_seq'::regclass);


--
-- Name: api_key_scopes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_key_scopes ALTER COLUMN id SET DEFAULT nextval('public.api_key_scopes_id_seq'::regclass);


--
-- Name: api_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys ALTER COLUMN id SET DEFAULT nextval('public.api_keys_id_seq'::regclass);


--
-- Name: application_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_requests ALTER COLUMN id SET DEFAULT nextval('public.application_requests_id_seq'::regclass);


--
-- Name: assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments ALTER COLUMN id SET DEFAULT nextval('public.assignments_id_seq'::regclass);


--
-- Name: associated_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associated_groups ALTER COLUMN id SET DEFAULT nextval('public.associated_groups_id_seq'::regclass);


--
-- Name: backup_draft_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backup_draft_posts ALTER COLUMN id SET DEFAULT nextval('public.backup_draft_posts_id_seq'::regclass);


--
-- Name: backup_draft_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backup_draft_topics ALTER COLUMN id SET DEFAULT nextval('public.backup_draft_topics_id_seq'::regclass);


--
-- Name: backup_metadata id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backup_metadata ALTER COLUMN id SET DEFAULT nextval('public.backup_metadata_id_seq'::regclass);


--
-- Name: badge_groupings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_groupings ALTER COLUMN id SET DEFAULT nextval('public.badge_groupings_id_seq'::regclass);


--
-- Name: badge_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_types ALTER COLUMN id SET DEFAULT nextval('public.badge_types_id_seq'::regclass);


--
-- Name: badges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges ALTER COLUMN id SET DEFAULT nextval('public.badges_id_seq'::regclass);


--
-- Name: bookmarks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks ALTER COLUMN id SET DEFAULT nextval('public.bookmarks_id_seq'::regclass);


--
-- Name: browser_pageview_country_daily_rollups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_country_daily_rollups ALTER COLUMN id SET DEFAULT nextval('public.browser_pageview_country_daily_rollups_id_seq'::regclass);


--
-- Name: browser_pageview_event_scores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_event_scores ALTER COLUMN id SET DEFAULT nextval('public.browser_pageview_event_scores_id_seq'::regclass);


--
-- Name: browser_pageview_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_events ALTER COLUMN id SET DEFAULT nextval('public.browser_pageview_events_id_seq'::regclass);


--
-- Name: browser_pageview_referrer_daily_rollups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_referrer_daily_rollups ALTER COLUMN id SET DEFAULT nextval('public.browser_pageview_referrer_daily_rollups_id_seq'::regclass);


--
-- Name: browser_pageview_session_engagements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_session_engagements ALTER COLUMN id SET DEFAULT nextval('public.browser_pageview_session_engagements_id_seq'::regclass);


--
-- Name: calendar_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events ALTER COLUMN id SET DEFAULT nextval('public.calendar_events_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: category_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.category_custom_fields_id_seq'::regclass);


--
-- Name: category_featured_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_featured_topics ALTER COLUMN id SET DEFAULT nextval('public.category_featured_topics_id_seq'::regclass);


--
-- Name: category_form_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_form_templates ALTER COLUMN id SET DEFAULT nextval('public.category_form_templates_id_seq'::regclass);


--
-- Name: category_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_groups ALTER COLUMN id SET DEFAULT nextval('public.category_groups_id_seq'::regclass);


--
-- Name: category_localizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_localizations ALTER COLUMN id SET DEFAULT nextval('public.category_localizations_id_seq'::regclass);


--
-- Name: category_moderation_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_moderation_groups ALTER COLUMN id SET DEFAULT nextval('public.category_moderation_groups_id_seq'::regclass);


--
-- Name: category_posting_review_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_posting_review_groups ALTER COLUMN id SET DEFAULT nextval('public.category_posting_review_groups_id_seq'::regclass);


--
-- Name: category_required_tag_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_required_tag_groups ALTER COLUMN id SET DEFAULT nextval('public.category_required_tag_groups_id_seq'::regclass);


--
-- Name: category_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_settings ALTER COLUMN id SET DEFAULT nextval('public.category_settings_id_seq'::regclass);


--
-- Name: category_tag_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_tag_groups ALTER COLUMN id SET DEFAULT nextval('public.category_tag_groups_id_seq'::regclass);


--
-- Name: category_tag_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_tag_stats ALTER COLUMN id SET DEFAULT nextval('public.category_tag_stats_id_seq'::regclass);


--
-- Name: category_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_tags ALTER COLUMN id SET DEFAULT nextval('public.category_tags_id_seq'::regclass);


--
-- Name: category_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_users ALTER COLUMN id SET DEFAULT nextval('public.category_users_id_seq'::regclass);


--
-- Name: chat_channel_archives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_channel_archives ALTER COLUMN id SET DEFAULT nextval('public.chat_channel_archives_id_seq'::regclass);


--
-- Name: chat_channel_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_channel_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.chat_channel_custom_fields_id_seq'::regclass);


--
-- Name: chat_channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_channels ALTER COLUMN id SET DEFAULT nextval('public.chat_channels_id_seq'::regclass);


--
-- Name: chat_drafts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_drafts ALTER COLUMN id SET DEFAULT nextval('public.chat_drafts_id_seq'::regclass);


--
-- Name: chat_mentions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_mentions ALTER COLUMN id SET DEFAULT nextval('public.chat_mentions_id_seq'::regclass);


--
-- Name: chat_message_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.chat_message_custom_fields_id_seq'::regclass);


--
-- Name: chat_message_custom_prompts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_custom_prompts ALTER COLUMN id SET DEFAULT nextval('public.chat_message_custom_prompts_id_seq'::regclass);


--
-- Name: chat_message_interactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_interactions ALTER COLUMN id SET DEFAULT nextval('public.chat_message_interactions_id_seq'::regclass);


--
-- Name: chat_message_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_links ALTER COLUMN id SET DEFAULT nextval('public.chat_message_links_id_seq'::regclass);


--
-- Name: chat_message_reactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_reactions ALTER COLUMN id SET DEFAULT nextval('public.chat_message_reactions_id_seq'::regclass);


--
-- Name: chat_message_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_revisions ALTER COLUMN id SET DEFAULT nextval('public.chat_message_revisions_id_seq'::regclass);


--
-- Name: chat_message_search_data chat_message_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_search_data ALTER COLUMN chat_message_id SET DEFAULT nextval('public.chat_message_search_data_chat_message_id_seq'::regclass);


--
-- Name: chat_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);


--
-- Name: chat_pinned_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_pinned_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_pinned_messages_id_seq'::regclass);


--
-- Name: chat_thread_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_thread_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.chat_thread_custom_fields_id_seq'::regclass);


--
-- Name: chat_threads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_threads ALTER COLUMN id SET DEFAULT nextval('public.chat_threads_id_seq'::regclass);


--
-- Name: chat_webhook_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_webhook_events ALTER COLUMN id SET DEFAULT nextval('public.chat_webhook_events_id_seq'::regclass);


--
-- Name: child_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.child_themes ALTER COLUMN id SET DEFAULT nextval('public.child_themes_id_seq'::regclass);


--
-- Name: classification_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_results ALTER COLUMN id SET DEFAULT nextval('public.classification_results_id_seq'::regclass);


--
-- Name: color_scheme_colors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.color_scheme_colors ALTER COLUMN id SET DEFAULT nextval('public.color_scheme_colors_id_seq'::regclass);


--
-- Name: color_schemes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.color_schemes ALTER COLUMN id SET DEFAULT nextval('public.color_schemes_id_seq'::regclass);


--
-- Name: completion_prompts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.completion_prompts ALTER COLUMN id SET DEFAULT nextval('public.completion_prompts_id_seq'::regclass);


--
-- Name: custom_emojis id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_emojis ALTER COLUMN id SET DEFAULT nextval('public.custom_emojis_id_seq'::regclass);


--
-- Name: data_explorer_queries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_explorer_queries ALTER COLUMN id SET DEFAULT nextval('public.data_explorer_queries_id_seq'::regclass);


--
-- Name: data_explorer_query_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_explorer_query_groups ALTER COLUMN id SET DEFAULT nextval('public.data_explorer_query_groups_id_seq'::regclass);


--
-- Name: developers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.developers ALTER COLUMN id SET DEFAULT nextval('public.developers_id_seq'::regclass);


--
-- Name: direct_message_channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_message_channels ALTER COLUMN id SET DEFAULT nextval('public.direct_message_channels_id_seq'::regclass);


--
-- Name: direct_message_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_message_users ALTER COLUMN id SET DEFAULT nextval('public.direct_message_users_id_seq'::regclass);


--
-- Name: directory_columns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_columns ALTER COLUMN id SET DEFAULT nextval('public.directory_columns_id_seq'::regclass);


--
-- Name: directory_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_items ALTER COLUMN id SET DEFAULT nextval('public.directory_items_id_seq'::regclass);


--
-- Name: discourse_ai_ai_bot_conversation_stars id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_ai_ai_bot_conversation_stars ALTER COLUMN id SET DEFAULT nextval('public.discourse_ai_ai_bot_conversation_stars_id_seq'::regclass);


--
-- Name: discourse_automation_automations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_automations ALTER COLUMN id SET DEFAULT nextval('public.discourse_automation_automations_id_seq'::regclass);


--
-- Name: discourse_automation_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_fields ALTER COLUMN id SET DEFAULT nextval('public.discourse_automation_fields_id_seq'::regclass);


--
-- Name: discourse_automation_pending_automations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_pending_automations ALTER COLUMN id SET DEFAULT nextval('public.discourse_automation_pending_automations_id_seq'::regclass);


--
-- Name: discourse_automation_pending_pms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_pending_pms ALTER COLUMN id SET DEFAULT nextval('public.discourse_automation_pending_pms_id_seq'::regclass);


--
-- Name: discourse_automation_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_stats ALTER COLUMN id SET DEFAULT nextval('public.discourse_automation_stats_id_seq'::regclass);


--
-- Name: discourse_automation_user_global_notices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_user_global_notices ALTER COLUMN id SET DEFAULT nextval('public.discourse_automation_user_global_notices_id_seq'::regclass);


--
-- Name: discourse_calendar_disabled_holidays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_calendar_disabled_holidays ALTER COLUMN id SET DEFAULT nextval('public.discourse_calendar_disabled_holidays_id_seq'::regclass);


--
-- Name: discourse_calendar_post_event_dates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_calendar_post_event_dates ALTER COLUMN id SET DEFAULT nextval('public.discourse_calendar_post_event_dates_id_seq'::regclass);


--
-- Name: discourse_post_event_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_post_event_events ALTER COLUMN id SET DEFAULT nextval('public.discourse_post_event_events_id_seq'::regclass);


--
-- Name: discourse_post_event_invitees id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_post_event_invitees ALTER COLUMN id SET DEFAULT nextval('public.discourse_post_event_invitees_id_seq'::regclass);


--
-- Name: discourse_reactions_reaction_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_reactions_reaction_users ALTER COLUMN id SET DEFAULT nextval('public.discourse_reactions_reaction_users_id_seq'::regclass);


--
-- Name: discourse_reactions_reactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_reactions_reactions ALTER COLUMN id SET DEFAULT nextval('public.discourse_reactions_reactions_id_seq'::regclass);


--
-- Name: discourse_rss_polling_rss_feeds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_rss_polling_rss_feeds ALTER COLUMN id SET DEFAULT nextval('public.discourse_rss_polling_rss_feeds_id_seq'::regclass);


--
-- Name: discourse_solved_shared_issues id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_solved_shared_issues ALTER COLUMN id SET DEFAULT nextval('public.discourse_solved_shared_issues_id_seq'::regclass);


--
-- Name: discourse_solved_solved_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_solved_solved_topics ALTER COLUMN id SET DEFAULT nextval('public.discourse_solved_solved_topics_id_seq'::regclass);


--
-- Name: discourse_solved_topic_answers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_solved_topic_answers ALTER COLUMN id SET DEFAULT nextval('public.discourse_solved_topic_answers_id_seq'::regclass);


--
-- Name: discourse_subscriptions_customers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_subscriptions_customers ALTER COLUMN id SET DEFAULT nextval('public.discourse_subscriptions_customers_id_seq'::regclass);


--
-- Name: discourse_subscriptions_products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_subscriptions_products ALTER COLUMN id SET DEFAULT nextval('public.discourse_subscriptions_products_id_seq'::regclass);


--
-- Name: discourse_subscriptions_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_subscriptions_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.discourse_subscriptions_subscriptions_id_seq'::regclass);


--
-- Name: discourse_templates_usage_count id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_templates_usage_count ALTER COLUMN id SET DEFAULT nextval('public.discourse_templates_usage_count_id_seq'::regclass);


--
-- Name: discourse_workflows_ai_authoring_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_ai_authoring_sessions ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_ai_authoring_sessions_id_seq'::regclass);


--
-- Name: discourse_workflows_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_credentials ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_credentials_id_seq'::regclass);


--
-- Name: discourse_workflows_data_tables id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_data_tables ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_data_tables_id_seq'::regclass);


--
-- Name: discourse_workflows_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_executions ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_executions_id_seq'::regclass);


--
-- Name: discourse_workflows_variables id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_variables ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_variables_id_seq'::regclass);


--
-- Name: discourse_workflows_webhooks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_webhooks ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_webhooks_id_seq'::regclass);


--
-- Name: discourse_workflows_workflow_call_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflow_call_runs ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_workflow_call_runs_id_seq'::regclass);


--
-- Name: discourse_workflows_workflow_dependencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflow_dependencies ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_workflow_dependencies_id_seq'::regclass);


--
-- Name: discourse_workflows_workflow_publish_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflow_publish_history ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_workflow_publish_history_id_seq'::regclass);


--
-- Name: discourse_workflows_workflows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflows ALTER COLUMN id SET DEFAULT nextval('public.discourse_workflows_workflows_id_seq'::regclass);


--
-- Name: dismissed_topic_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dismissed_topic_users ALTER COLUMN id SET DEFAULT nextval('public.dismissed_topic_users_id_seq'::regclass);


--
-- Name: do_not_disturb_timings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.do_not_disturb_timings ALTER COLUMN id SET DEFAULT nextval('public.do_not_disturb_timings_id_seq'::regclass);


--
-- Name: draft_sequences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.draft_sequences ALTER COLUMN id SET DEFAULT nextval('public.draft_sequences_id_seq'::regclass);


--
-- Name: drafts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drafts ALTER COLUMN id SET DEFAULT nextval('public.drafts_id_seq'::regclass);


--
-- Name: email_change_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_change_requests ALTER COLUMN id SET DEFAULT nextval('public.email_change_requests_id_seq'::regclass);


--
-- Name: email_login_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_login_codes ALTER COLUMN id SET DEFAULT nextval('public.email_login_codes_id_seq'::regclass);


--
-- Name: email_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_logs ALTER COLUMN id SET DEFAULT nextval('public.email_logs_id_seq'::regclass);


--
-- Name: email_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_tokens ALTER COLUMN id SET DEFAULT nextval('public.email_tokens_id_seq'::regclass);


--
-- Name: embeddable_host_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embeddable_host_tags ALTER COLUMN id SET DEFAULT nextval('public.embeddable_host_tags_id_seq'::regclass);


--
-- Name: embeddable_hosts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embeddable_hosts ALTER COLUMN id SET DEFAULT nextval('public.embeddable_hosts_id_seq'::regclass);


--
-- Name: embedding_definitions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_definitions ALTER COLUMN id SET DEFAULT nextval('public.embedding_definitions_id_seq'::regclass);


--
-- Name: external_upload_stubs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_upload_stubs ALTER COLUMN id SET DEFAULT nextval('public.external_upload_stubs_id_seq'::regclass);


--
-- Name: flags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags ALTER COLUMN id SET DEFAULT nextval('public.flags_id_seq'::regclass);


--
-- Name: form_templates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_templates ALTER COLUMN id SET DEFAULT nextval('public.form_templates_id_seq'::regclass);


--
-- Name: gamification_leaderboard_scores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gamification_leaderboard_scores ALTER COLUMN id SET DEFAULT nextval('public.gamification_leaderboard_scores_id_seq'::regclass);


--
-- Name: gamification_leaderboards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gamification_leaderboards ALTER COLUMN id SET DEFAULT nextval('public.gamification_leaderboards_id_seq'::regclass);


--
-- Name: gamification_score_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gamification_score_events ALTER COLUMN id SET DEFAULT nextval('public.gamification_score_events_id_seq'::regclass);


--
-- Name: gamification_scores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gamification_scores ALTER COLUMN id SET DEFAULT nextval('public.gamification_scores_id_seq'::regclass);


--
-- Name: github_commits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.github_commits ALTER COLUMN id SET DEFAULT nextval('public.github_commits_id_seq'::regclass);


--
-- Name: github_repos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.github_repos ALTER COLUMN id SET DEFAULT nextval('public.github_repos_id_seq'::regclass);


--
-- Name: group_archived_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_archived_messages ALTER COLUMN id SET DEFAULT nextval('public.group_archived_messages_id_seq'::regclass);


--
-- Name: group_associated_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_associated_groups ALTER COLUMN id SET DEFAULT nextval('public.group_associated_groups_id_seq'::regclass);


--
-- Name: group_category_notification_defaults id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_category_notification_defaults ALTER COLUMN id SET DEFAULT nextval('public.group_category_notification_defaults_id_seq'::regclass);


--
-- Name: group_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.group_custom_fields_id_seq'::regclass);


--
-- Name: group_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_histories ALTER COLUMN id SET DEFAULT nextval('public.group_histories_id_seq'::regclass);


--
-- Name: group_mentions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_mentions ALTER COLUMN id SET DEFAULT nextval('public.group_mentions_id_seq'::regclass);


--
-- Name: group_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_requests ALTER COLUMN id SET DEFAULT nextval('public.group_requests_id_seq'::regclass);


--
-- Name: group_tag_notification_defaults id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_tag_notification_defaults ALTER COLUMN id SET DEFAULT nextval('public.group_tag_notification_defaults_id_seq'::regclass);


--
-- Name: group_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_users ALTER COLUMN id SET DEFAULT nextval('public.group_users_id_seq'::regclass);


--
-- Name: groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups ALTER COLUMN id SET DEFAULT nextval('public.groups_id_seq'::regclass);


--
-- Name: ignored_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ignored_users ALTER COLUMN id SET DEFAULT nextval('public.ignored_users_id_seq'::regclass);


--
-- Name: incoming_chat_webhooks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_chat_webhooks ALTER COLUMN id SET DEFAULT nextval('public.incoming_chat_webhooks_id_seq'::regclass);


--
-- Name: incoming_domains id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_domains ALTER COLUMN id SET DEFAULT nextval('public.incoming_domains_id_seq'::regclass);


--
-- Name: incoming_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_emails ALTER COLUMN id SET DEFAULT nextval('public.incoming_emails_id_seq'::regclass);


--
-- Name: incoming_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_links ALTER COLUMN id SET DEFAULT nextval('public.incoming_links_id_seq'::regclass);


--
-- Name: incoming_referers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_referers ALTER COLUMN id SET DEFAULT nextval('public.incoming_referers_id_seq'::regclass);


--
-- Name: inferred_concepts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inferred_concepts ALTER COLUMN id SET DEFAULT nextval('public.inferred_concepts_id_seq'::regclass);


--
-- Name: invited_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invited_groups ALTER COLUMN id SET DEFAULT nextval('public.invited_groups_id_seq'::regclass);


--
-- Name: invited_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invited_users ALTER COLUMN id SET DEFAULT nextval('public.invited_users_id_seq'::regclass);


--
-- Name: invites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites ALTER COLUMN id SET DEFAULT nextval('public.invites_id_seq'::regclass);


--
-- Name: javascript_caches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.javascript_caches ALTER COLUMN id SET DEFAULT nextval('public.javascript_caches_id_seq'::regclass);


--
-- Name: linked_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.linked_topics ALTER COLUMN id SET DEFAULT nextval('public.linked_topics_id_seq'::regclass);


--
-- Name: livestream_topic_chat_channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.livestream_topic_chat_channels ALTER COLUMN id SET DEFAULT nextval('public.livestream_topic_chat_channels_id_seq'::regclass);


--
-- Name: llm_credit_allocations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_credit_allocations ALTER COLUMN id SET DEFAULT nextval('public.llm_credit_allocations_id_seq'::regclass);


--
-- Name: llm_credit_daily_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_credit_daily_usages ALTER COLUMN id SET DEFAULT nextval('public.llm_credit_daily_usages_id_seq'::regclass);


--
-- Name: llm_feature_credit_costs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_feature_credit_costs ALTER COLUMN id SET DEFAULT nextval('public.llm_feature_credit_costs_id_seq'::regclass);


--
-- Name: llm_models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_models ALTER COLUMN id SET DEFAULT nextval('public.llm_models_id_seq'::regclass);


--
-- Name: llm_quota_usages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_quota_usages ALTER COLUMN id SET DEFAULT nextval('public.llm_quota_usages_id_seq'::regclass);


--
-- Name: llm_quotas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_quotas ALTER COLUMN id SET DEFAULT nextval('public.llm_quotas_id_seq'::regclass);


--
-- Name: message_bus id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_bus ALTER COLUMN id SET DEFAULT nextval('public.message_bus_id_seq'::regclass);


--
-- Name: model_accuracies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.model_accuracies ALTER COLUMN id SET DEFAULT nextval('public.model_accuracies_id_seq'::regclass);


--
-- Name: moved_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moved_posts ALTER COLUMN id SET DEFAULT nextval('public.moved_posts_id_seq'::regclass);


--
-- Name: muted_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muted_users ALTER COLUMN id SET DEFAULT nextval('public.muted_users_id_seq'::regclass);


--
-- Name: nested_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nested_topics ALTER COLUMN id SET DEFAULT nextval('public.nested_topics_id_seq'::regclass);


--
-- Name: nested_view_post_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nested_view_post_stats ALTER COLUMN id SET DEFAULT nextval('public.nested_view_post_stats_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: oauth2_user_infos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_user_infos ALTER COLUMN id SET DEFAULT nextval('public.oauth2_user_infos_id_seq'::regclass);


--
-- Name: onceoff_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.onceoff_logs ALTER COLUMN id SET DEFAULT nextval('public.onceoff_logs_id_seq'::regclass);


--
-- Name: optimized_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.optimized_images ALTER COLUMN id SET DEFAULT nextval('public.optimized_images_id_seq'::regclass);


--
-- Name: optimized_videos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.optimized_videos ALTER COLUMN id SET DEFAULT nextval('public.optimized_videos_id_seq'::regclass);


--
-- Name: permalinks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permalinks ALTER COLUMN id SET DEFAULT nextval('public.permalinks_id_seq'::regclass);


--
-- Name: plugin_store_rows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plugin_store_rows ALTER COLUMN id SET DEFAULT nextval('public.plugin_store_rows_id_seq'::regclass);


--
-- Name: policy_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_users ALTER COLUMN id SET DEFAULT nextval('public.policy_users_id_seq'::regclass);


--
-- Name: poll_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options ALTER COLUMN id SET DEFAULT nextval('public.poll_options_id_seq'::regclass);


--
-- Name: polls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls ALTER COLUMN id SET DEFAULT nextval('public.polls_id_seq'::regclass);


--
-- Name: post_action_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_action_types ALTER COLUMN id SET DEFAULT nextval('public.post_action_types_id_seq'::regclass);


--
-- Name: post_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_actions ALTER COLUMN id SET DEFAULT nextval('public.post_actions_id_seq'::regclass);


--
-- Name: post_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.post_custom_fields_id_seq'::regclass);


--
-- Name: post_custom_prompts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_custom_prompts ALTER COLUMN id SET DEFAULT nextval('public.post_custom_prompts_id_seq'::regclass);


--
-- Name: post_details id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_details ALTER COLUMN id SET DEFAULT nextval('public.post_details_id_seq'::regclass);


--
-- Name: post_hotlinked_media id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_hotlinked_media ALTER COLUMN id SET DEFAULT nextval('public.post_hotlinked_media_id_seq'::regclass);


--
-- Name: post_localizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_localizations ALTER COLUMN id SET DEFAULT nextval('public.post_localizations_id_seq'::regclass);


--
-- Name: post_policies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_policies ALTER COLUMN id SET DEFAULT nextval('public.post_policies_id_seq'::regclass);


--
-- Name: post_policy_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_policy_groups ALTER COLUMN id SET DEFAULT nextval('public.post_policy_groups_id_seq'::regclass);


--
-- Name: post_reply_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reply_keys ALTER COLUMN id SET DEFAULT nextval('public.post_reply_keys_id_seq'::regclass);


--
-- Name: post_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_revisions ALTER COLUMN id SET DEFAULT nextval('public.post_revisions_id_seq'::regclass);


--
-- Name: post_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_stats ALTER COLUMN id SET DEFAULT nextval('public.post_stats_id_seq'::regclass);


--
-- Name: post_voting_comment_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_voting_comment_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.post_voting_comment_custom_fields_id_seq'::regclass);


--
-- Name: post_voting_comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_voting_comments ALTER COLUMN id SET DEFAULT nextval('public.post_voting_comments_id_seq'::regclass);


--
-- Name: post_voting_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_voting_votes ALTER COLUMN id SET DEFAULT nextval('public.post_voting_votes_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: problem_check_trackers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.problem_check_trackers ALTER COLUMN id SET DEFAULT nextval('public.problem_check_trackers_id_seq'::regclass);


--
-- Name: published_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.published_pages ALTER COLUMN id SET DEFAULT nextval('public.published_pages_id_seq'::regclass);


--
-- Name: push_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.push_subscriptions_id_seq'::regclass);


--
-- Name: quoted_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quoted_posts ALTER COLUMN id SET DEFAULT nextval('public.quoted_posts_id_seq'::regclass);


--
-- Name: rag_document_fragments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rag_document_fragments ALTER COLUMN id SET DEFAULT nextval('public.rag_document_fragments_id_seq'::regclass);


--
-- Name: redelivering_webhook_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.redelivering_webhook_events ALTER COLUMN id SET DEFAULT nextval('public.redelivering_webhook_events_id_seq'::regclass);


--
-- Name: remote_themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remote_themes ALTER COLUMN id SET DEFAULT nextval('public.remote_themes_id_seq'::regclass);


--
-- Name: reviewable_claimed_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_claimed_topics ALTER COLUMN id SET DEFAULT nextval('public.reviewable_claimed_topics_id_seq'::regclass);


--
-- Name: reviewable_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_histories ALTER COLUMN id SET DEFAULT nextval('public.reviewable_histories_id_seq'::regclass);


--
-- Name: reviewable_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_notes ALTER COLUMN id SET DEFAULT nextval('public.reviewable_notes_id_seq'::regclass);


--
-- Name: reviewable_scores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_scores ALTER COLUMN id SET DEFAULT nextval('public.reviewable_scores_id_seq'::regclass);


--
-- Name: reviewables id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewables ALTER COLUMN id SET DEFAULT nextval('public.reviewables_id_seq'::regclass);


--
-- Name: scheduler_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduler_stats ALTER COLUMN id SET DEFAULT nextval('public.scheduler_stats_id_seq'::regclass);


--
-- Name: schema_migration_details id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migration_details ALTER COLUMN id SET DEFAULT nextval('public.schema_migration_details_id_seq'::regclass);


--
-- Name: screened_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.screened_emails ALTER COLUMN id SET DEFAULT nextval('public.screened_emails_id_seq'::regclass);


--
-- Name: screened_ip_addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.screened_ip_addresses ALTER COLUMN id SET DEFAULT nextval('public.screened_ip_addresses_id_seq'::regclass);


--
-- Name: screened_urls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.screened_urls ALTER COLUMN id SET DEFAULT nextval('public.screened_urls_id_seq'::regclass);


--
-- Name: search_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_logs ALTER COLUMN id SET DEFAULT nextval('public.search_logs_id_seq'::regclass);


--
-- Name: shared_ai_conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_ai_conversations ALTER COLUMN id SET DEFAULT nextval('public.shared_ai_conversations_id_seq'::regclass);


--
-- Name: shared_drafts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_drafts ALTER COLUMN id SET DEFAULT nextval('public.shared_drafts_id_seq'::regclass);


--
-- Name: shelved_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shelved_notifications ALTER COLUMN id SET DEFAULT nextval('public.shelved_notifications_id_seq'::regclass);


--
-- Name: sidebar_section_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_section_links ALTER COLUMN id SET DEFAULT nextval('public.sidebar_section_links_id_seq'::regclass);


--
-- Name: sidebar_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_sections ALTER COLUMN id SET DEFAULT nextval('public.sidebar_sections_id_seq'::regclass);


--
-- Name: sidebar_urls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_urls ALTER COLUMN id SET DEFAULT nextval('public.sidebar_urls_id_seq'::regclass);


--
-- Name: silenced_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.silenced_assignments ALTER COLUMN id SET DEFAULT nextval('public.silenced_assignments_id_seq'::regclass);


--
-- Name: single_sign_on_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.single_sign_on_records ALTER COLUMN id SET DEFAULT nextval('public.single_sign_on_records_id_seq'::regclass);


--
-- Name: site_setting_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_setting_groups ALTER COLUMN id SET DEFAULT nextval('public.site_setting_groups_id_seq'::regclass);


--
-- Name: site_setting_localizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_setting_localizations ALTER COLUMN id SET DEFAULT nextval('public.site_setting_localizations_id_seq'::regclass);


--
-- Name: site_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_settings ALTER COLUMN id SET DEFAULT nextval('public.site_settings_id_seq'::regclass);


--
-- Name: sitemaps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sitemaps ALTER COLUMN id SET DEFAULT nextval('public.sitemaps_id_seq'::regclass);


--
-- Name: skipped_email_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skipped_email_logs ALTER COLUMN id SET DEFAULT nextval('public.skipped_email_logs_id_seq'::regclass);


--
-- Name: stylesheet_cache id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stylesheet_cache ALTER COLUMN id SET DEFAULT nextval('public.stylesheet_cache_id_seq'::regclass);


--
-- Name: summary_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.summary_sections ALTER COLUMN id SET DEFAULT nextval('public.summary_sections_id_seq'::regclass);


--
-- Name: tag_group_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_group_memberships ALTER COLUMN id SET DEFAULT nextval('public.tag_group_memberships_id_seq'::regclass);


--
-- Name: tag_group_permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_group_permissions ALTER COLUMN id SET DEFAULT nextval('public.tag_group_permissions_id_seq'::regclass);


--
-- Name: tag_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_groups ALTER COLUMN id SET DEFAULT nextval('public.tag_groups_id_seq'::regclass);


--
-- Name: tag_localizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_localizations ALTER COLUMN id SET DEFAULT nextval('public.tag_localizations_id_seq'::regclass);


--
-- Name: tag_search_data tag_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_search_data ALTER COLUMN tag_id SET DEFAULT nextval('public.tag_search_data_tag_id_seq'::regclass);


--
-- Name: tag_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_users ALTER COLUMN id SET DEFAULT nextval('public.tag_users_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: theme_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_fields ALTER COLUMN id SET DEFAULT nextval('public.theme_fields_id_seq'::regclass);


--
-- Name: theme_modifier_sets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_modifier_sets ALTER COLUMN id SET DEFAULT nextval('public.theme_modifier_sets_id_seq'::regclass);


--
-- Name: theme_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_settings ALTER COLUMN id SET DEFAULT nextval('public.theme_settings_id_seq'::regclass);


--
-- Name: theme_settings_migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_settings_migrations ALTER COLUMN id SET DEFAULT nextval('public.theme_settings_migrations_id_seq'::regclass);


--
-- Name: theme_site_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_site_settings ALTER COLUMN id SET DEFAULT nextval('public.theme_site_settings_id_seq'::regclass);


--
-- Name: theme_svg_sprites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_svg_sprites ALTER COLUMN id SET DEFAULT nextval('public.theme_svg_sprites_id_seq'::regclass);


--
-- Name: theme_translation_overrides id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_translation_overrides ALTER COLUMN id SET DEFAULT nextval('public.theme_translation_overrides_id_seq'::regclass);


--
-- Name: themes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.themes ALTER COLUMN id SET DEFAULT nextval('public.themes_id_seq'::regclass);


--
-- Name: top_topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.top_topics ALTER COLUMN id SET DEFAULT nextval('public.top_topics_id_seq'::regclass);


--
-- Name: topic_allowed_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_allowed_groups ALTER COLUMN id SET DEFAULT nextval('public.topic_allowed_groups_id_seq'::regclass);


--
-- Name: topic_allowed_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_allowed_users ALTER COLUMN id SET DEFAULT nextval('public.topic_allowed_users_id_seq'::regclass);


--
-- Name: topic_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.topic_custom_fields_id_seq'::regclass);


--
-- Name: topic_embeds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_embeds ALTER COLUMN id SET DEFAULT nextval('public.topic_embeds_id_seq'::regclass);


--
-- Name: topic_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_groups ALTER COLUMN id SET DEFAULT nextval('public.topic_groups_id_seq'::regclass);


--
-- Name: topic_hot_scores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_hot_scores ALTER COLUMN id SET DEFAULT nextval('public.topic_hot_scores_id_seq'::regclass);


--
-- Name: topic_invites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_invites ALTER COLUMN id SET DEFAULT nextval('public.topic_invites_id_seq'::regclass);


--
-- Name: topic_link_clicks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_link_clicks ALTER COLUMN id SET DEFAULT nextval('public.topic_link_clicks_id_seq'::regclass);


--
-- Name: topic_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_links ALTER COLUMN id SET DEFAULT nextval('public.topic_links_id_seq'::regclass);


--
-- Name: topic_localizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_localizations ALTER COLUMN id SET DEFAULT nextval('public.topic_localizations_id_seq'::regclass);


--
-- Name: topic_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_tags ALTER COLUMN id SET DEFAULT nextval('public.topic_tags_id_seq'::regclass);


--
-- Name: topic_thumbnails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_thumbnails ALTER COLUMN id SET DEFAULT nextval('public.topic_thumbnails_id_seq'::regclass);


--
-- Name: topic_timers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_timers ALTER COLUMN id SET DEFAULT nextval('public.topic_timers_id_seq'::regclass);


--
-- Name: topic_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_users ALTER COLUMN id SET DEFAULT nextval('public.topic_users_id_seq'::regclass);


--
-- Name: topic_view_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_view_stats ALTER COLUMN id SET DEFAULT nextval('public.topic_view_stats_id_seq'::regclass);


--
-- Name: topic_voting_category_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_voting_category_settings ALTER COLUMN id SET DEFAULT nextval('public.topic_voting_category_settings_id_seq'::regclass);


--
-- Name: topic_voting_topic_vote_count id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_voting_topic_vote_count ALTER COLUMN id SET DEFAULT nextval('public.topic_voting_topic_vote_count_id_seq'::regclass);


--
-- Name: topic_voting_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_voting_votes ALTER COLUMN id SET DEFAULT nextval('public.topic_voting_votes_id_seq'::regclass);


--
-- Name: topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics ALTER COLUMN id SET DEFAULT nextval('public.topics_id_seq'::regclass);


--
-- Name: translation_overrides id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_overrides ALTER COLUMN id SET DEFAULT nextval('public.translation_overrides_id_seq'::regclass);


--
-- Name: upcoming_change_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upcoming_change_events ALTER COLUMN id SET DEFAULT nextval('public.upcoming_change_events_id_seq'::regclass);


--
-- Name: upload_references id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_references ALTER COLUMN id SET DEFAULT nextval('public.upload_references_id_seq'::regclass);


--
-- Name: uploads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads ALTER COLUMN id SET DEFAULT nextval('public.uploads_id_seq'::regclass);


--
-- Name: user_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_actions ALTER COLUMN id SET DEFAULT nextval('public.user_actions_id_seq'::regclass);


--
-- Name: user_api_key_client_scopes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_key_client_scopes ALTER COLUMN id SET DEFAULT nextval('public.user_api_key_client_scopes_id_seq'::regclass);


--
-- Name: user_api_key_clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_key_clients ALTER COLUMN id SET DEFAULT nextval('public.user_api_key_clients_id_seq'::regclass);


--
-- Name: user_api_key_scopes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_key_scopes ALTER COLUMN id SET DEFAULT nextval('public.user_api_key_scopes_id_seq'::regclass);


--
-- Name: user_api_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_keys ALTER COLUMN id SET DEFAULT nextval('public.user_api_keys_id_seq'::regclass);


--
-- Name: user_archived_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_archived_messages ALTER COLUMN id SET DEFAULT nextval('public.user_archived_messages_id_seq'::regclass);


--
-- Name: user_associated_accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_associated_accounts ALTER COLUMN id SET DEFAULT nextval('public.user_associated_accounts_id_seq'::regclass);


--
-- Name: user_associated_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_associated_groups ALTER COLUMN id SET DEFAULT nextval('public.user_associated_groups_id_seq'::regclass);


--
-- Name: user_auth_token_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_token_logs ALTER COLUMN id SET DEFAULT nextval('public.user_auth_token_logs_id_seq'::regclass);


--
-- Name: user_auth_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_tokens ALTER COLUMN id SET DEFAULT nextval('public.user_auth_tokens_id_seq'::regclass);


--
-- Name: user_avatars id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_avatars ALTER COLUMN id SET DEFAULT nextval('public.user_avatars_id_seq'::regclass);


--
-- Name: user_badges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges ALTER COLUMN id SET DEFAULT nextval('public.user_badges_id_seq'::regclass);


--
-- Name: user_chat_channel_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_chat_channel_memberships ALTER COLUMN id SET DEFAULT nextval('public.user_chat_channel_memberships_id_seq'::regclass);


--
-- Name: user_chat_thread_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_chat_thread_memberships ALTER COLUMN id SET DEFAULT nextval('public.user_chat_thread_memberships_id_seq'::regclass);


--
-- Name: user_custom_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_custom_fields ALTER COLUMN id SET DEFAULT nextval('public.user_custom_fields_id_seq'::regclass);


--
-- Name: user_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_emails ALTER COLUMN id SET DEFAULT nextval('public.user_emails_id_seq'::regclass);


--
-- Name: user_exports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_exports ALTER COLUMN id SET DEFAULT nextval('public.user_exports_id_seq'::regclass);


--
-- Name: user_field_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_field_options ALTER COLUMN id SET DEFAULT nextval('public.user_field_options_id_seq'::regclass);


--
-- Name: user_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fields ALTER COLUMN id SET DEFAULT nextval('public.user_fields_id_seq'::regclass);


--
-- Name: user_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_histories ALTER COLUMN id SET DEFAULT nextval('public.user_histories_id_seq'::regclass);


--
-- Name: user_ip_address_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ip_address_histories ALTER COLUMN id SET DEFAULT nextval('public.user_ip_address_histories_id_seq'::regclass);


--
-- Name: user_notification_schedules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notification_schedules ALTER COLUMN id SET DEFAULT nextval('public.user_notification_schedules_id_seq'::regclass);


--
-- Name: user_open_ids id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_open_ids ALTER COLUMN id SET DEFAULT nextval('public.user_open_ids_id_seq'::regclass);


--
-- Name: user_passwords id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passwords ALTER COLUMN id SET DEFAULT nextval('public.user_passwords_id_seq'::regclass);


--
-- Name: user_profile_views id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_views ALTER COLUMN id SET DEFAULT nextval('public.user_profile_views_id_seq'::regclass);


--
-- Name: user_required_fields_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_required_fields_versions ALTER COLUMN id SET DEFAULT nextval('public.user_required_fields_versions_id_seq'::regclass);


--
-- Name: user_second_factors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_second_factors ALTER COLUMN id SET DEFAULT nextval('public.user_second_factors_id_seq'::regclass);


--
-- Name: user_security_keys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_security_keys ALTER COLUMN id SET DEFAULT nextval('public.user_security_keys_id_seq'::regclass);


--
-- Name: user_statuses user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_statuses ALTER COLUMN user_id SET DEFAULT nextval('public.user_statuses_user_id_seq'::regclass);


--
-- Name: user_uploads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_uploads ALTER COLUMN id SET DEFAULT nextval('public.user_uploads_id_seq'::regclass);


--
-- Name: user_visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_visits ALTER COLUMN id SET DEFAULT nextval('public.user_visits_id_seq'::regclass);


--
-- Name: user_warnings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_warnings ALTER COLUMN id SET DEFAULT nextval('public.user_warnings_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: watched_word_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watched_word_groups ALTER COLUMN id SET DEFAULT nextval('public.watched_word_groups_id_seq'::regclass);


--
-- Name: watched_words id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watched_words ALTER COLUMN id SET DEFAULT nextval('public.watched_words_id_seq'::regclass);


--
-- Name: web_crawler_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_crawler_requests ALTER COLUMN id SET DEFAULT nextval('public.web_crawler_requests_id_seq'::regclass);


--
-- Name: web_hook_event_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_hook_event_types ALTER COLUMN id SET DEFAULT nextval('public.web_hook_event_types_id_seq'::regclass);


--
-- Name: web_hook_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_hook_events ALTER COLUMN id SET DEFAULT nextval('public.web_hook_events_id_seq'::regclass);


--
-- Name: web_hook_events_daily_aggregates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_hook_events_daily_aggregates ALTER COLUMN id SET DEFAULT nextval('public.web_hook_events_daily_aggregates_id_seq'::regclass);


--
-- Name: web_hooks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_hooks ALTER COLUMN id SET DEFAULT nextval('public.web_hooks_id_seq'::regclass);


--
-- Name: access_control_lists access_control_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_control_lists
    ADD CONSTRAINT access_control_lists_pkey PRIMARY KEY (id);


--
-- Name: ad_plugin_house_ads ad_plugin_house_ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_house_ads
    ADD CONSTRAINT ad_plugin_house_ads_pkey PRIMARY KEY (id);


--
-- Name: ad_plugin_impressions ad_plugin_impressions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_impressions
    ADD CONSTRAINT ad_plugin_impressions_pkey PRIMARY KEY (id);


--
-- Name: admin_dashboard_reports admin_dashboard_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_dashboard_reports
    ADD CONSTRAINT admin_dashboard_reports_pkey PRIMARY KEY (id);


--
-- Name: admin_dashboard_sections admin_dashboard_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_dashboard_sections
    ADD CONSTRAINT admin_dashboard_sections_pkey PRIMARY KEY (id);


--
-- Name: admin_notices admin_notices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_notices
    ADD CONSTRAINT admin_notices_pkey PRIMARY KEY (id);


--
-- Name: ai_agent_mcp_servers ai_agent_mcp_servers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_agent_mcp_servers
    ADD CONSTRAINT ai_agent_mcp_servers_pkey PRIMARY KEY (id);


--
-- Name: ai_agents ai_agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_agents
    ADD CONSTRAINT ai_agents_pkey PRIMARY KEY (id);


--
-- Name: ai_api_audit_logs ai_api_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_api_audit_logs
    ADD CONSTRAINT ai_api_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: ai_api_request_stats ai_api_request_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_api_request_stats
    ADD CONSTRAINT ai_api_request_stats_pkey PRIMARY KEY (id);


--
-- Name: ai_artifact_key_values ai_artifact_key_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_artifact_key_values
    ADD CONSTRAINT ai_artifact_key_values_pkey PRIMARY KEY (id);


--
-- Name: ai_artifact_versions ai_artifact_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_artifact_versions
    ADD CONSTRAINT ai_artifact_versions_pkey PRIMARY KEY (id);


--
-- Name: ai_artifacts ai_artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_artifacts
    ADD CONSTRAINT ai_artifacts_pkey PRIMARY KEY (id);


--
-- Name: ai_mcp_oauth_tokens ai_mcp_oauth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_mcp_oauth_tokens
    ADD CONSTRAINT ai_mcp_oauth_tokens_pkey PRIMARY KEY (id);


--
-- Name: ai_mcp_servers ai_mcp_servers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_mcp_servers
    ADD CONSTRAINT ai_mcp_servers_pkey PRIMARY KEY (id);


--
-- Name: ai_moderation_settings ai_moderation_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_moderation_settings
    ADD CONSTRAINT ai_moderation_settings_pkey PRIMARY KEY (id);


--
-- Name: ai_secrets ai_secrets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_secrets
    ADD CONSTRAINT ai_secrets_pkey PRIMARY KEY (id);


--
-- Name: ai_spam_logs ai_spam_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_spam_logs
    ADD CONSTRAINT ai_spam_logs_pkey PRIMARY KEY (id);


--
-- Name: ai_summaries ai_summaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_summaries
    ADD CONSTRAINT ai_summaries_pkey PRIMARY KEY (id);


--
-- Name: ai_tool_actions ai_tool_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tool_actions
    ADD CONSTRAINT ai_tool_actions_pkey PRIMARY KEY (id);


--
-- Name: ai_tool_secret_bindings ai_tool_secret_bindings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tool_secret_bindings
    ADD CONSTRAINT ai_tool_secret_bindings_pkey PRIMARY KEY (id);


--
-- Name: ai_tools ai_tools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tools
    ADD CONSTRAINT ai_tools_pkey PRIMARY KEY (id);


--
-- Name: allowed_pm_users allowed_pm_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.allowed_pm_users
    ADD CONSTRAINT allowed_pm_users_pkey PRIMARY KEY (id);


--
-- Name: anonymous_users anonymous_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.anonymous_users
    ADD CONSTRAINT anonymous_users_pkey PRIMARY KEY (id);


--
-- Name: api_key_scopes api_key_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_key_scopes
    ADD CONSTRAINT api_key_scopes_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: application_requests application_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_requests
    ADD CONSTRAINT application_requests_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: assignments assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_pkey PRIMARY KEY (id);


--
-- Name: associated_groups associated_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.associated_groups
    ADD CONSTRAINT associated_groups_pkey PRIMARY KEY (id);


--
-- Name: backup_draft_posts backup_draft_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backup_draft_posts
    ADD CONSTRAINT backup_draft_posts_pkey PRIMARY KEY (id);


--
-- Name: backup_draft_topics backup_draft_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backup_draft_topics
    ADD CONSTRAINT backup_draft_topics_pkey PRIMARY KEY (id);


--
-- Name: backup_metadata backup_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.backup_metadata
    ADD CONSTRAINT backup_metadata_pkey PRIMARY KEY (id);


--
-- Name: badge_groupings badge_groupings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_groupings
    ADD CONSTRAINT badge_groupings_pkey PRIMARY KEY (id);


--
-- Name: badge_types badge_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_types
    ADD CONSTRAINT badge_types_pkey PRIMARY KEY (id);


--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);


--
-- Name: bookmarks bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (id);


--
-- Name: browser_pageview_country_daily_rollups browser_pageview_country_daily_rollups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_country_daily_rollups
    ADD CONSTRAINT browser_pageview_country_daily_rollups_pkey PRIMARY KEY (id);


--
-- Name: browser_pageview_event_scores browser_pageview_event_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_event_scores
    ADD CONSTRAINT browser_pageview_event_scores_pkey PRIMARY KEY (id);


--
-- Name: browser_pageview_events browser_pageview_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_events
    ADD CONSTRAINT browser_pageview_events_pkey PRIMARY KEY (id);


--
-- Name: browser_pageview_referrer_daily_rollups browser_pageview_referrer_daily_rollups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_referrer_daily_rollups
    ADD CONSTRAINT browser_pageview_referrer_daily_rollups_pkey PRIMARY KEY (id);


--
-- Name: browser_pageview_session_engagements browser_pageview_session_engagements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.browser_pageview_session_engagements
    ADD CONSTRAINT browser_pageview_session_engagements_pkey PRIMARY KEY (id);


--
-- Name: calendar_events calendar_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calendar_events
    ADD CONSTRAINT calendar_events_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: category_search_data categories_search_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_search_data
    ADD CONSTRAINT categories_search_pkey PRIMARY KEY (category_id);


--
-- Name: category_custom_fields category_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_custom_fields
    ADD CONSTRAINT category_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: category_featured_topics category_featured_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_featured_topics
    ADD CONSTRAINT category_featured_topics_pkey PRIMARY KEY (id);


--
-- Name: category_form_templates category_form_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_form_templates
    ADD CONSTRAINT category_form_templates_pkey PRIMARY KEY (id);


--
-- Name: category_groups category_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_groups
    ADD CONSTRAINT category_groups_pkey PRIMARY KEY (id);


--
-- Name: category_localizations category_localizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_localizations
    ADD CONSTRAINT category_localizations_pkey PRIMARY KEY (id);


--
-- Name: category_moderation_groups category_moderation_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_moderation_groups
    ADD CONSTRAINT category_moderation_groups_pkey PRIMARY KEY (id);


--
-- Name: category_posting_review_groups category_posting_review_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_posting_review_groups
    ADD CONSTRAINT category_posting_review_groups_pkey PRIMARY KEY (id);


--
-- Name: category_required_tag_groups category_required_tag_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_required_tag_groups
    ADD CONSTRAINT category_required_tag_groups_pkey PRIMARY KEY (id);


--
-- Name: category_settings category_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_settings
    ADD CONSTRAINT category_settings_pkey PRIMARY KEY (id);


--
-- Name: category_tag_groups category_tag_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_tag_groups
    ADD CONSTRAINT category_tag_groups_pkey PRIMARY KEY (id);


--
-- Name: category_tag_stats category_tag_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_tag_stats
    ADD CONSTRAINT category_tag_stats_pkey PRIMARY KEY (id);


--
-- Name: category_tags category_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_tags
    ADD CONSTRAINT category_tags_pkey PRIMARY KEY (id);


--
-- Name: category_users category_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_users
    ADD CONSTRAINT category_users_pkey PRIMARY KEY (id);


--
-- Name: chat_channel_archives chat_channel_archives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_channel_archives
    ADD CONSTRAINT chat_channel_archives_pkey PRIMARY KEY (id);


--
-- Name: chat_channel_custom_fields chat_channel_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_channel_custom_fields
    ADD CONSTRAINT chat_channel_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: chat_channels chat_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_channels
    ADD CONSTRAINT chat_channels_pkey PRIMARY KEY (id);


--
-- Name: chat_drafts chat_drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_drafts
    ADD CONSTRAINT chat_drafts_pkey PRIMARY KEY (id);


--
-- Name: chat_mentions chat_mentions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_mentions
    ADD CONSTRAINT chat_mentions_pkey PRIMARY KEY (id);


--
-- Name: chat_message_custom_fields chat_message_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_custom_fields
    ADD CONSTRAINT chat_message_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: chat_message_custom_prompts chat_message_custom_prompts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_custom_prompts
    ADD CONSTRAINT chat_message_custom_prompts_pkey PRIMARY KEY (id);


--
-- Name: chat_message_interactions chat_message_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_interactions
    ADD CONSTRAINT chat_message_interactions_pkey PRIMARY KEY (id);


--
-- Name: chat_message_links chat_message_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_links
    ADD CONSTRAINT chat_message_links_pkey PRIMARY KEY (id);


--
-- Name: chat_message_reactions chat_message_reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_reactions
    ADD CONSTRAINT chat_message_reactions_pkey PRIMARY KEY (id);


--
-- Name: chat_message_revisions chat_message_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_revisions
    ADD CONSTRAINT chat_message_revisions_pkey PRIMARY KEY (id);


--
-- Name: chat_message_search_data chat_message_search_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_search_data
    ADD CONSTRAINT chat_message_search_data_pkey PRIMARY KEY (chat_message_id);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: chat_pinned_messages chat_pinned_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_pinned_messages
    ADD CONSTRAINT chat_pinned_messages_pkey PRIMARY KEY (id);


--
-- Name: chat_thread_custom_fields chat_thread_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_thread_custom_fields
    ADD CONSTRAINT chat_thread_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: chat_threads chat_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_threads
    ADD CONSTRAINT chat_threads_pkey PRIMARY KEY (id);


--
-- Name: chat_webhook_events chat_webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_webhook_events
    ADD CONSTRAINT chat_webhook_events_pkey PRIMARY KEY (id);


--
-- Name: child_themes child_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.child_themes
    ADD CONSTRAINT child_themes_pkey PRIMARY KEY (id);


--
-- Name: classification_results classification_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_results
    ADD CONSTRAINT classification_results_pkey PRIMARY KEY (id);


--
-- Name: color_scheme_colors color_scheme_colors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.color_scheme_colors
    ADD CONSTRAINT color_scheme_colors_pkey PRIMARY KEY (id);


--
-- Name: color_schemes color_schemes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.color_schemes
    ADD CONSTRAINT color_schemes_pkey PRIMARY KEY (id);


--
-- Name: completion_prompts completion_prompts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.completion_prompts
    ADD CONSTRAINT completion_prompts_pkey PRIMARY KEY (id);


--
-- Name: custom_emojis custom_emojis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_emojis
    ADD CONSTRAINT custom_emojis_pkey PRIMARY KEY (id);


--
-- Name: data_explorer_queries data_explorer_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_explorer_queries
    ADD CONSTRAINT data_explorer_queries_pkey PRIMARY KEY (id);


--
-- Name: data_explorer_query_groups data_explorer_query_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_explorer_query_groups
    ADD CONSTRAINT data_explorer_query_groups_pkey PRIMARY KEY (id);


--
-- Name: developers developers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.developers
    ADD CONSTRAINT developers_pkey PRIMARY KEY (id);


--
-- Name: unsubscribe_keys digest_unsubscribe_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unsubscribe_keys
    ADD CONSTRAINT digest_unsubscribe_keys_pkey PRIMARY KEY (key);


--
-- Name: direct_message_channels direct_message_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_message_channels
    ADD CONSTRAINT direct_message_channels_pkey PRIMARY KEY (id);


--
-- Name: direct_message_users direct_message_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.direct_message_users
    ADD CONSTRAINT direct_message_users_pkey PRIMARY KEY (id);


--
-- Name: directory_columns directory_columns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_columns
    ADD CONSTRAINT directory_columns_pkey PRIMARY KEY (id);


--
-- Name: directory_items directory_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.directory_items
    ADD CONSTRAINT directory_items_pkey PRIMARY KEY (id);


--
-- Name: discourse_ai_ai_bot_conversation_stars discourse_ai_ai_bot_conversation_stars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_ai_ai_bot_conversation_stars
    ADD CONSTRAINT discourse_ai_ai_bot_conversation_stars_pkey PRIMARY KEY (id);


--
-- Name: discourse_automation_automations discourse_automation_automations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_automations
    ADD CONSTRAINT discourse_automation_automations_pkey PRIMARY KEY (id);


--
-- Name: discourse_automation_fields discourse_automation_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_fields
    ADD CONSTRAINT discourse_automation_fields_pkey PRIMARY KEY (id);


--
-- Name: discourse_automation_pending_automations discourse_automation_pending_automations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_pending_automations
    ADD CONSTRAINT discourse_automation_pending_automations_pkey PRIMARY KEY (id);


--
-- Name: discourse_automation_pending_pms discourse_automation_pending_pms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_pending_pms
    ADD CONSTRAINT discourse_automation_pending_pms_pkey PRIMARY KEY (id);


--
-- Name: discourse_automation_stats discourse_automation_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_stats
    ADD CONSTRAINT discourse_automation_stats_pkey PRIMARY KEY (id);


--
-- Name: discourse_automation_user_global_notices discourse_automation_user_global_notices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_automation_user_global_notices
    ADD CONSTRAINT discourse_automation_user_global_notices_pkey PRIMARY KEY (id);


--
-- Name: discourse_calendar_disabled_holidays discourse_calendar_disabled_holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_calendar_disabled_holidays
    ADD CONSTRAINT discourse_calendar_disabled_holidays_pkey PRIMARY KEY (id);


--
-- Name: discourse_calendar_post_event_dates discourse_calendar_post_event_dates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_calendar_post_event_dates
    ADD CONSTRAINT discourse_calendar_post_event_dates_pkey PRIMARY KEY (id);


--
-- Name: discourse_post_event_events discourse_post_event_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_post_event_events
    ADD CONSTRAINT discourse_post_event_events_pkey PRIMARY KEY (id);


--
-- Name: discourse_post_event_invitees discourse_post_event_invitees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_post_event_invitees
    ADD CONSTRAINT discourse_post_event_invitees_pkey PRIMARY KEY (id);


--
-- Name: discourse_reactions_reaction_users discourse_reactions_reaction_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_reactions_reaction_users
    ADD CONSTRAINT discourse_reactions_reaction_users_pkey PRIMARY KEY (id);


--
-- Name: discourse_reactions_reactions discourse_reactions_reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_reactions_reactions
    ADD CONSTRAINT discourse_reactions_reactions_pkey PRIMARY KEY (id);


--
-- Name: discourse_rss_polling_rss_feeds discourse_rss_polling_rss_feeds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_rss_polling_rss_feeds
    ADD CONSTRAINT discourse_rss_polling_rss_feeds_pkey PRIMARY KEY (id);


--
-- Name: discourse_solved_shared_issues discourse_solved_shared_issues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_solved_shared_issues
    ADD CONSTRAINT discourse_solved_shared_issues_pkey PRIMARY KEY (id);


--
-- Name: discourse_solved_solved_topics discourse_solved_solved_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_solved_solved_topics
    ADD CONSTRAINT discourse_solved_solved_topics_pkey PRIMARY KEY (id);


--
-- Name: discourse_solved_topic_answers discourse_solved_topic_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_solved_topic_answers
    ADD CONSTRAINT discourse_solved_topic_answers_pkey PRIMARY KEY (id);


--
-- Name: discourse_subscriptions_customers discourse_subscriptions_customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_subscriptions_customers
    ADD CONSTRAINT discourse_subscriptions_customers_pkey PRIMARY KEY (id);


--
-- Name: discourse_subscriptions_products discourse_subscriptions_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_subscriptions_products
    ADD CONSTRAINT discourse_subscriptions_products_pkey PRIMARY KEY (id);


--
-- Name: discourse_subscriptions_subscriptions discourse_subscriptions_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_subscriptions_subscriptions
    ADD CONSTRAINT discourse_subscriptions_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: discourse_templates_usage_count discourse_templates_usage_count_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_templates_usage_count
    ADD CONSTRAINT discourse_templates_usage_count_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_ai_authoring_sessions discourse_workflows_ai_authoring_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_ai_authoring_sessions
    ADD CONSTRAINT discourse_workflows_ai_authoring_sessions_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_credentials discourse_workflows_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_credentials
    ADD CONSTRAINT discourse_workflows_credentials_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_data_tables discourse_workflows_data_tables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_data_tables
    ADD CONSTRAINT discourse_workflows_data_tables_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_executions discourse_workflows_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_executions
    ADD CONSTRAINT discourse_workflows_executions_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_variables discourse_workflows_variables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_variables
    ADD CONSTRAINT discourse_workflows_variables_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_webhooks discourse_workflows_webhooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_webhooks
    ADD CONSTRAINT discourse_workflows_webhooks_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_workflow_call_runs discourse_workflows_workflow_call_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflow_call_runs
    ADD CONSTRAINT discourse_workflows_workflow_call_runs_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_workflow_dependencies discourse_workflows_workflow_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflow_dependencies
    ADD CONSTRAINT discourse_workflows_workflow_dependencies_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_workflow_publish_history discourse_workflows_workflow_publish_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflow_publish_history
    ADD CONSTRAINT discourse_workflows_workflow_publish_history_pkey PRIMARY KEY (id);


--
-- Name: discourse_workflows_workflow_versions discourse_workflows_workflow_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflow_versions
    ADD CONSTRAINT discourse_workflows_workflow_versions_pkey PRIMARY KEY (version_id);


--
-- Name: discourse_workflows_workflows discourse_workflows_workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discourse_workflows_workflows
    ADD CONSTRAINT discourse_workflows_workflows_pkey PRIMARY KEY (id);


--
-- Name: dismissed_topic_users dismissed_topic_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dismissed_topic_users
    ADD CONSTRAINT dismissed_topic_users_pkey PRIMARY KEY (id);


--
-- Name: do_not_disturb_timings do_not_disturb_timings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.do_not_disturb_timings
    ADD CONSTRAINT do_not_disturb_timings_pkey PRIMARY KEY (id);


--
-- Name: draft_sequences draft_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.draft_sequences
    ADD CONSTRAINT draft_sequences_pkey PRIMARY KEY (id);


--
-- Name: drafts drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.drafts
    ADD CONSTRAINT drafts_pkey PRIMARY KEY (id);


--
-- Name: email_change_requests email_change_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_change_requests
    ADD CONSTRAINT email_change_requests_pkey PRIMARY KEY (id);


--
-- Name: email_login_codes email_login_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_login_codes
    ADD CONSTRAINT email_login_codes_pkey PRIMARY KEY (id);


--
-- Name: email_logs email_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_logs
    ADD CONSTRAINT email_logs_pkey PRIMARY KEY (id);


--
-- Name: email_tokens email_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_tokens
    ADD CONSTRAINT email_tokens_pkey PRIMARY KEY (id);


--
-- Name: embeddable_host_tags embeddable_host_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embeddable_host_tags
    ADD CONSTRAINT embeddable_host_tags_pkey PRIMARY KEY (id);


--
-- Name: embeddable_hosts embeddable_hosts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embeddable_hosts
    ADD CONSTRAINT embeddable_hosts_pkey PRIMARY KEY (id);


--
-- Name: embedding_definitions embedding_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.embedding_definitions
    ADD CONSTRAINT embedding_definitions_pkey PRIMARY KEY (id);


--
-- Name: external_upload_stubs external_upload_stubs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_upload_stubs
    ADD CONSTRAINT external_upload_stubs_pkey PRIMARY KEY (id);


--
-- Name: flags flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags
    ADD CONSTRAINT flags_pkey PRIMARY KEY (id);


--
-- Name: form_templates form_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.form_templates
    ADD CONSTRAINT form_templates_pkey PRIMARY KEY (id);


--
-- Name: gamification_leaderboard_scores gamification_leaderboard_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gamification_leaderboard_scores
    ADD CONSTRAINT gamification_leaderboard_scores_pkey PRIMARY KEY (id);


--
-- Name: gamification_leaderboards gamification_leaderboards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gamification_leaderboards
    ADD CONSTRAINT gamification_leaderboards_pkey PRIMARY KEY (id);


--
-- Name: gamification_score_events gamification_score_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gamification_score_events
    ADD CONSTRAINT gamification_score_events_pkey PRIMARY KEY (id);


--
-- Name: gamification_scores gamification_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gamification_scores
    ADD CONSTRAINT gamification_scores_pkey PRIMARY KEY (id);


--
-- Name: github_commits github_commits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.github_commits
    ADD CONSTRAINT github_commits_pkey PRIMARY KEY (id);


--
-- Name: github_repos github_repos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.github_repos
    ADD CONSTRAINT github_repos_pkey PRIMARY KEY (id);


--
-- Name: group_archived_messages group_archived_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_archived_messages
    ADD CONSTRAINT group_archived_messages_pkey PRIMARY KEY (id);


--
-- Name: group_associated_groups group_associated_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_associated_groups
    ADD CONSTRAINT group_associated_groups_pkey PRIMARY KEY (id);


--
-- Name: group_category_notification_defaults group_category_notification_defaults_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_category_notification_defaults
    ADD CONSTRAINT group_category_notification_defaults_pkey PRIMARY KEY (id);


--
-- Name: group_custom_fields group_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_custom_fields
    ADD CONSTRAINT group_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: group_histories group_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_histories
    ADD CONSTRAINT group_histories_pkey PRIMARY KEY (id);


--
-- Name: group_mentions group_mentions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_mentions
    ADD CONSTRAINT group_mentions_pkey PRIMARY KEY (id);


--
-- Name: group_requests group_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_requests
    ADD CONSTRAINT group_requests_pkey PRIMARY KEY (id);


--
-- Name: group_tag_notification_defaults group_tag_notification_defaults_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_tag_notification_defaults
    ADD CONSTRAINT group_tag_notification_defaults_pkey PRIMARY KEY (id);


--
-- Name: group_users group_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_users
    ADD CONSTRAINT group_users_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: ignored_users ignored_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ignored_users
    ADD CONSTRAINT ignored_users_pkey PRIMARY KEY (id);


--
-- Name: incoming_chat_webhooks incoming_chat_webhooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_chat_webhooks
    ADD CONSTRAINT incoming_chat_webhooks_pkey PRIMARY KEY (id);


--
-- Name: incoming_domains incoming_domains_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_domains
    ADD CONSTRAINT incoming_domains_pkey PRIMARY KEY (id);


--
-- Name: incoming_emails incoming_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_emails
    ADD CONSTRAINT incoming_emails_pkey PRIMARY KEY (id);


--
-- Name: incoming_links incoming_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_links
    ADD CONSTRAINT incoming_links_pkey PRIMARY KEY (id);


--
-- Name: incoming_referers incoming_referers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incoming_referers
    ADD CONSTRAINT incoming_referers_pkey PRIMARY KEY (id);


--
-- Name: inferred_concepts inferred_concepts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inferred_concepts
    ADD CONSTRAINT inferred_concepts_pkey PRIMARY KEY (id);


--
-- Name: invited_groups invited_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invited_groups
    ADD CONSTRAINT invited_groups_pkey PRIMARY KEY (id);


--
-- Name: invited_users invited_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invited_users
    ADD CONSTRAINT invited_users_pkey PRIMARY KEY (id);


--
-- Name: invites invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


--
-- Name: javascript_caches javascript_caches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.javascript_caches
    ADD CONSTRAINT javascript_caches_pkey PRIMARY KEY (id);


--
-- Name: linked_topics linked_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.linked_topics
    ADD CONSTRAINT linked_topics_pkey PRIMARY KEY (id);


--
-- Name: livestream_topic_chat_channels livestream_topic_chat_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.livestream_topic_chat_channels
    ADD CONSTRAINT livestream_topic_chat_channels_pkey PRIMARY KEY (id);


--
-- Name: llm_credit_allocations llm_credit_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_credit_allocations
    ADD CONSTRAINT llm_credit_allocations_pkey PRIMARY KEY (id);


--
-- Name: llm_credit_daily_usages llm_credit_daily_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_credit_daily_usages
    ADD CONSTRAINT llm_credit_daily_usages_pkey PRIMARY KEY (id);


--
-- Name: llm_feature_credit_costs llm_feature_credit_costs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_feature_credit_costs
    ADD CONSTRAINT llm_feature_credit_costs_pkey PRIMARY KEY (id);


--
-- Name: llm_models llm_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_models
    ADD CONSTRAINT llm_models_pkey PRIMARY KEY (id);


--
-- Name: llm_quota_usages llm_quota_usages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_quota_usages
    ADD CONSTRAINT llm_quota_usages_pkey PRIMARY KEY (id);


--
-- Name: llm_quotas llm_quotas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_quotas
    ADD CONSTRAINT llm_quotas_pkey PRIMARY KEY (id);


--
-- Name: message_bus message_bus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_bus
    ADD CONSTRAINT message_bus_pkey PRIMARY KEY (id);


--
-- Name: model_accuracies model_accuracies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.model_accuracies
    ADD CONSTRAINT model_accuracies_pkey PRIMARY KEY (id);


--
-- Name: moved_posts moved_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moved_posts
    ADD CONSTRAINT moved_posts_pkey PRIMARY KEY (id);


--
-- Name: muted_users muted_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.muted_users
    ADD CONSTRAINT muted_users_pkey PRIMARY KEY (id);


--
-- Name: nested_topics nested_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nested_topics
    ADD CONSTRAINT nested_topics_pkey PRIMARY KEY (id);


--
-- Name: nested_view_post_stats nested_view_post_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nested_view_post_stats
    ADD CONSTRAINT nested_view_post_stats_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: oauth2_user_infos oauth2_user_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth2_user_infos
    ADD CONSTRAINT oauth2_user_infos_pkey PRIMARY KEY (id);


--
-- Name: onceoff_logs onceoff_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.onceoff_logs
    ADD CONSTRAINT onceoff_logs_pkey PRIMARY KEY (id);


--
-- Name: optimized_images optimized_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.optimized_images
    ADD CONSTRAINT optimized_images_pkey PRIMARY KEY (id);


--
-- Name: optimized_videos optimized_videos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.optimized_videos
    ADD CONSTRAINT optimized_videos_pkey PRIMARY KEY (id);


--
-- Name: permalinks permalinks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permalinks
    ADD CONSTRAINT permalinks_pkey PRIMARY KEY (id);


--
-- Name: plugin_store_rows plugin_store_rows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.plugin_store_rows
    ADD CONSTRAINT plugin_store_rows_pkey PRIMARY KEY (id);


--
-- Name: policy_users policy_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.policy_users
    ADD CONSTRAINT policy_users_pkey PRIMARY KEY (id);


--
-- Name: poll_options poll_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT poll_options_pkey PRIMARY KEY (id);


--
-- Name: polls polls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT polls_pkey PRIMARY KEY (id);


--
-- Name: post_action_types post_action_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_action_types
    ADD CONSTRAINT post_action_types_pkey PRIMARY KEY (id);


--
-- Name: post_actions post_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_actions
    ADD CONSTRAINT post_actions_pkey PRIMARY KEY (id);


--
-- Name: post_custom_fields post_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_custom_fields
    ADD CONSTRAINT post_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: post_custom_prompts post_custom_prompts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_custom_prompts
    ADD CONSTRAINT post_custom_prompts_pkey PRIMARY KEY (id);


--
-- Name: post_details post_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_details
    ADD CONSTRAINT post_details_pkey PRIMARY KEY (id);


--
-- Name: post_hotlinked_media post_hotlinked_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_hotlinked_media
    ADD CONSTRAINT post_hotlinked_media_pkey PRIMARY KEY (id);


--
-- Name: post_localizations post_localizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_localizations
    ADD CONSTRAINT post_localizations_pkey PRIMARY KEY (id);


--
-- Name: post_policies post_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_policies
    ADD CONSTRAINT post_policies_pkey PRIMARY KEY (id);


--
-- Name: post_policy_groups post_policy_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_policy_groups
    ADD CONSTRAINT post_policy_groups_pkey PRIMARY KEY (id);


--
-- Name: post_reply_keys post_reply_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_reply_keys
    ADD CONSTRAINT post_reply_keys_pkey PRIMARY KEY (id);


--
-- Name: post_revisions post_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_revisions
    ADD CONSTRAINT post_revisions_pkey PRIMARY KEY (id);


--
-- Name: post_stats post_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_stats
    ADD CONSTRAINT post_stats_pkey PRIMARY KEY (id);


--
-- Name: post_voting_comment_custom_fields post_voting_comment_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_voting_comment_custom_fields
    ADD CONSTRAINT post_voting_comment_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: post_voting_comments post_voting_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_voting_comments
    ADD CONSTRAINT post_voting_comments_pkey PRIMARY KEY (id);


--
-- Name: post_voting_votes post_voting_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_voting_votes
    ADD CONSTRAINT post_voting_votes_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: post_search_data posts_search_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_search_data
    ADD CONSTRAINT posts_search_pkey PRIMARY KEY (post_id);


--
-- Name: problem_check_trackers problem_check_trackers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.problem_check_trackers
    ADD CONSTRAINT problem_check_trackers_pkey PRIMARY KEY (id);


--
-- Name: published_pages published_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.published_pages
    ADD CONSTRAINT published_pages_pkey PRIMARY KEY (id);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: quoted_posts quoted_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quoted_posts
    ADD CONSTRAINT quoted_posts_pkey PRIMARY KEY (id);


--
-- Name: rag_document_fragments rag_document_fragments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rag_document_fragments
    ADD CONSTRAINT rag_document_fragments_pkey PRIMARY KEY (id);


--
-- Name: redelivering_webhook_events redelivering_webhook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.redelivering_webhook_events
    ADD CONSTRAINT redelivering_webhook_events_pkey PRIMARY KEY (id);


--
-- Name: remote_themes remote_themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remote_themes
    ADD CONSTRAINT remote_themes_pkey PRIMARY KEY (id);


--
-- Name: reviewable_claimed_topics reviewable_claimed_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_claimed_topics
    ADD CONSTRAINT reviewable_claimed_topics_pkey PRIMARY KEY (id);


--
-- Name: reviewable_histories reviewable_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_histories
    ADD CONSTRAINT reviewable_histories_pkey PRIMARY KEY (id);


--
-- Name: reviewable_notes reviewable_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_notes
    ADD CONSTRAINT reviewable_notes_pkey PRIMARY KEY (id);


--
-- Name: reviewable_scores reviewable_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_scores
    ADD CONSTRAINT reviewable_scores_pkey PRIMARY KEY (id);


--
-- Name: reviewables reviewables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewables
    ADD CONSTRAINT reviewables_pkey PRIMARY KEY (id);


--
-- Name: scheduler_stats scheduler_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scheduler_stats
    ADD CONSTRAINT scheduler_stats_pkey PRIMARY KEY (id);


--
-- Name: schema_migration_details schema_migration_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migration_details
    ADD CONSTRAINT schema_migration_details_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: screened_emails screened_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.screened_emails
    ADD CONSTRAINT screened_emails_pkey PRIMARY KEY (id);


--
-- Name: screened_ip_addresses screened_ip_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.screened_ip_addresses
    ADD CONSTRAINT screened_ip_addresses_pkey PRIMARY KEY (id);


--
-- Name: screened_urls screened_urls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.screened_urls
    ADD CONSTRAINT screened_urls_pkey PRIMARY KEY (id);


--
-- Name: search_logs search_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_logs
    ADD CONSTRAINT search_logs_pkey PRIMARY KEY (id);


--
-- Name: shared_ai_conversations shared_ai_conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_ai_conversations
    ADD CONSTRAINT shared_ai_conversations_pkey PRIMARY KEY (id);


--
-- Name: shared_drafts shared_drafts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_drafts
    ADD CONSTRAINT shared_drafts_pkey PRIMARY KEY (id);


--
-- Name: shelved_notifications shelved_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shelved_notifications
    ADD CONSTRAINT shelved_notifications_pkey PRIMARY KEY (id);


--
-- Name: sidebar_section_links sidebar_section_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_section_links
    ADD CONSTRAINT sidebar_section_links_pkey PRIMARY KEY (id);


--
-- Name: sidebar_sections sidebar_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_sections
    ADD CONSTRAINT sidebar_sections_pkey PRIMARY KEY (id);


--
-- Name: sidebar_urls sidebar_urls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sidebar_urls
    ADD CONSTRAINT sidebar_urls_pkey PRIMARY KEY (id);


--
-- Name: silenced_assignments silenced_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.silenced_assignments
    ADD CONSTRAINT silenced_assignments_pkey PRIMARY KEY (id);


--
-- Name: single_sign_on_records single_sign_on_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.single_sign_on_records
    ADD CONSTRAINT single_sign_on_records_pkey PRIMARY KEY (id);


--
-- Name: site_setting_groups site_setting_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_setting_groups
    ADD CONSTRAINT site_setting_groups_pkey PRIMARY KEY (id);


--
-- Name: site_setting_localizations site_setting_localizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_setting_localizations
    ADD CONSTRAINT site_setting_localizations_pkey PRIMARY KEY (id);


--
-- Name: site_settings site_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_settings
    ADD CONSTRAINT site_settings_pkey PRIMARY KEY (id);


--
-- Name: sitemaps sitemaps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sitemaps
    ADD CONSTRAINT sitemaps_pkey PRIMARY KEY (id);


--
-- Name: skipped_email_logs skipped_email_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skipped_email_logs
    ADD CONSTRAINT skipped_email_logs_pkey PRIMARY KEY (id);


--
-- Name: stylesheet_cache stylesheet_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stylesheet_cache
    ADD CONSTRAINT stylesheet_cache_pkey PRIMARY KEY (id);


--
-- Name: summary_sections summary_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.summary_sections
    ADD CONSTRAINT summary_sections_pkey PRIMARY KEY (id);


--
-- Name: tag_group_memberships tag_group_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_group_memberships
    ADD CONSTRAINT tag_group_memberships_pkey PRIMARY KEY (id);


--
-- Name: tag_group_permissions tag_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_group_permissions
    ADD CONSTRAINT tag_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: tag_groups tag_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_groups
    ADD CONSTRAINT tag_groups_pkey PRIMARY KEY (id);


--
-- Name: tag_localizations tag_localizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_localizations
    ADD CONSTRAINT tag_localizations_pkey PRIMARY KEY (id);


--
-- Name: tag_search_data tag_search_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_search_data
    ADD CONSTRAINT tag_search_data_pkey PRIMARY KEY (tag_id);


--
-- Name: tag_users tag_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_users
    ADD CONSTRAINT tag_users_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: theme_fields theme_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_fields
    ADD CONSTRAINT theme_fields_pkey PRIMARY KEY (id);


--
-- Name: theme_modifier_sets theme_modifier_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_modifier_sets
    ADD CONSTRAINT theme_modifier_sets_pkey PRIMARY KEY (id);


--
-- Name: theme_settings_migrations theme_settings_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_settings_migrations
    ADD CONSTRAINT theme_settings_migrations_pkey PRIMARY KEY (id);


--
-- Name: theme_settings theme_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_settings
    ADD CONSTRAINT theme_settings_pkey PRIMARY KEY (id);


--
-- Name: theme_site_settings theme_site_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_site_settings
    ADD CONSTRAINT theme_site_settings_pkey PRIMARY KEY (id);


--
-- Name: theme_svg_sprites theme_svg_sprites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_svg_sprites
    ADD CONSTRAINT theme_svg_sprites_pkey PRIMARY KEY (id);


--
-- Name: theme_translation_overrides theme_translation_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.theme_translation_overrides
    ADD CONSTRAINT theme_translation_overrides_pkey PRIMARY KEY (id);


--
-- Name: themes themes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.themes
    ADD CONSTRAINT themes_pkey PRIMARY KEY (id);


--
-- Name: top_topics top_topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.top_topics
    ADD CONSTRAINT top_topics_pkey PRIMARY KEY (id);


--
-- Name: topic_allowed_groups topic_allowed_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_allowed_groups
    ADD CONSTRAINT topic_allowed_groups_pkey PRIMARY KEY (id);


--
-- Name: topic_allowed_users topic_allowed_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_allowed_users
    ADD CONSTRAINT topic_allowed_users_pkey PRIMARY KEY (id);


--
-- Name: topic_custom_fields topic_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_custom_fields
    ADD CONSTRAINT topic_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: topic_embeds topic_embeds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_embeds
    ADD CONSTRAINT topic_embeds_pkey PRIMARY KEY (id);


--
-- Name: topic_groups topic_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_groups
    ADD CONSTRAINT topic_groups_pkey PRIMARY KEY (id);


--
-- Name: topic_hot_scores topic_hot_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_hot_scores
    ADD CONSTRAINT topic_hot_scores_pkey PRIMARY KEY (id);


--
-- Name: topic_invites topic_invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_invites
    ADD CONSTRAINT topic_invites_pkey PRIMARY KEY (id);


--
-- Name: topic_link_clicks topic_link_clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_link_clicks
    ADD CONSTRAINT topic_link_clicks_pkey PRIMARY KEY (id);


--
-- Name: topic_links topic_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_links
    ADD CONSTRAINT topic_links_pkey PRIMARY KEY (id);


--
-- Name: topic_localizations topic_localizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_localizations
    ADD CONSTRAINT topic_localizations_pkey PRIMARY KEY (id);


--
-- Name: topic_search_data topic_search_data_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_search_data
    ADD CONSTRAINT topic_search_data_pkey PRIMARY KEY (topic_id);


--
-- Name: topic_tags topic_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_tags
    ADD CONSTRAINT topic_tags_pkey PRIMARY KEY (id);


--
-- Name: topic_thumbnails topic_thumbnails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_thumbnails
    ADD CONSTRAINT topic_thumbnails_pkey PRIMARY KEY (id);


--
-- Name: topic_timers topic_timers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_timers
    ADD CONSTRAINT topic_timers_pkey PRIMARY KEY (id);


--
-- Name: topic_users topic_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_users
    ADD CONSTRAINT topic_users_pkey PRIMARY KEY (id);


--
-- Name: topic_view_stats topic_view_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_view_stats
    ADD CONSTRAINT topic_view_stats_pkey PRIMARY KEY (id);


--
-- Name: topic_voting_category_settings topic_voting_category_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_voting_category_settings
    ADD CONSTRAINT topic_voting_category_settings_pkey PRIMARY KEY (id);


--
-- Name: topic_voting_topic_vote_count topic_voting_topic_vote_count_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_voting_topic_vote_count
    ADD CONSTRAINT topic_voting_topic_vote_count_pkey PRIMARY KEY (id);


--
-- Name: topic_voting_votes topic_voting_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_voting_votes
    ADD CONSTRAINT topic_voting_votes_pkey PRIMARY KEY (id);


--
-- Name: topics topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_pkey PRIMARY KEY (id);


--
-- Name: translation_overrides translation_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.translation_overrides
    ADD CONSTRAINT translation_overrides_pkey PRIMARY KEY (id);


--
-- Name: upcoming_change_events upcoming_change_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upcoming_change_events
    ADD CONSTRAINT upcoming_change_events_pkey PRIMARY KEY (id);


--
-- Name: upload_references upload_references_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.upload_references
    ADD CONSTRAINT upload_references_pkey PRIMARY KEY (id);


--
-- Name: uploads uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.uploads
    ADD CONSTRAINT uploads_pkey PRIMARY KEY (id);


--
-- Name: user_actions user_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_actions
    ADD CONSTRAINT user_actions_pkey PRIMARY KEY (id);


--
-- Name: user_api_key_client_scopes user_api_key_client_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_key_client_scopes
    ADD CONSTRAINT user_api_key_client_scopes_pkey PRIMARY KEY (id);


--
-- Name: user_api_key_clients user_api_key_clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_key_clients
    ADD CONSTRAINT user_api_key_clients_pkey PRIMARY KEY (id);


--
-- Name: user_api_key_scopes user_api_key_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_key_scopes
    ADD CONSTRAINT user_api_key_scopes_pkey PRIMARY KEY (id);


--
-- Name: user_api_keys user_api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_api_keys
    ADD CONSTRAINT user_api_keys_pkey PRIMARY KEY (id);


--
-- Name: user_archived_messages user_archived_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_archived_messages
    ADD CONSTRAINT user_archived_messages_pkey PRIMARY KEY (id);


--
-- Name: user_associated_accounts user_associated_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_associated_accounts
    ADD CONSTRAINT user_associated_accounts_pkey PRIMARY KEY (id);


--
-- Name: user_associated_groups user_associated_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_associated_groups
    ADD CONSTRAINT user_associated_groups_pkey PRIMARY KEY (id);


--
-- Name: user_auth_token_logs user_auth_token_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_token_logs
    ADD CONSTRAINT user_auth_token_logs_pkey PRIMARY KEY (id);


--
-- Name: user_auth_tokens user_auth_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_auth_tokens
    ADD CONSTRAINT user_auth_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_avatars user_avatars_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_avatars
    ADD CONSTRAINT user_avatars_pkey PRIMARY KEY (id);


--
-- Name: user_badges user_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_pkey PRIMARY KEY (id);


--
-- Name: user_chat_channel_memberships user_chat_channel_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_chat_channel_memberships
    ADD CONSTRAINT user_chat_channel_memberships_pkey PRIMARY KEY (id);


--
-- Name: user_chat_thread_memberships user_chat_thread_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_chat_thread_memberships
    ADD CONSTRAINT user_chat_thread_memberships_pkey PRIMARY KEY (id);


--
-- Name: user_custom_fields user_custom_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_custom_fields
    ADD CONSTRAINT user_custom_fields_pkey PRIMARY KEY (id);


--
-- Name: user_emails user_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_emails
    ADD CONSTRAINT user_emails_pkey PRIMARY KEY (id);


--
-- Name: user_exports user_exports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_exports
    ADD CONSTRAINT user_exports_pkey PRIMARY KEY (id);


--
-- Name: user_field_options user_field_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_field_options
    ADD CONSTRAINT user_field_options_pkey PRIMARY KEY (id);


--
-- Name: user_fields user_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fields
    ADD CONSTRAINT user_fields_pkey PRIMARY KEY (id);


--
-- Name: user_histories user_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_histories
    ADD CONSTRAINT user_histories_pkey PRIMARY KEY (id);


--
-- Name: user_ip_address_histories user_ip_address_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ip_address_histories
    ADD CONSTRAINT user_ip_address_histories_pkey PRIMARY KEY (id);


--
-- Name: user_notification_schedules user_notification_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notification_schedules
    ADD CONSTRAINT user_notification_schedules_pkey PRIMARY KEY (id);


--
-- Name: user_open_ids user_open_ids_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_open_ids
    ADD CONSTRAINT user_open_ids_pkey PRIMARY KEY (id);


--
-- Name: user_passwords user_passwords_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passwords
    ADD CONSTRAINT user_passwords_pkey PRIMARY KEY (id);


--
-- Name: user_profile_views user_profile_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_views
    ADD CONSTRAINT user_profile_views_pkey PRIMARY KEY (id);


--
-- Name: user_profiles user_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);


--
-- Name: user_required_fields_versions user_required_fields_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_required_fields_versions
    ADD CONSTRAINT user_required_fields_versions_pkey PRIMARY KEY (id);


--
-- Name: user_second_factors user_second_factors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_second_factors
    ADD CONSTRAINT user_second_factors_pkey PRIMARY KEY (id);


--
-- Name: user_security_keys user_security_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_security_keys
    ADD CONSTRAINT user_security_keys_pkey PRIMARY KEY (id);


--
-- Name: user_stats user_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_pkey PRIMARY KEY (user_id);


--
-- Name: user_statuses user_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_statuses
    ADD CONSTRAINT user_statuses_pkey PRIMARY KEY (user_id);


--
-- Name: user_uploads user_uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_uploads
    ADD CONSTRAINT user_uploads_pkey PRIMARY KEY (id);


--
-- Name: user_visits user_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_visits
    ADD CONSTRAINT user_visits_pkey PRIMARY KEY (id);


--
-- Name: user_warnings user_warnings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_warnings
    ADD CONSTRAINT user_warnings_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: user_search_data users_search_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_search_data
    ADD CONSTRAINT users_search_pkey PRIMARY KEY (user_id);


--
-- Name: watched_word_groups watched_word_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watched_word_groups
    ADD CONSTRAINT watched_word_groups_pkey PRIMARY KEY (id);


--
-- Name: watched_words watched_words_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.watched_words
    ADD CONSTRAINT watched_words_pkey PRIMARY KEY (id);


--
-- Name: web_crawler_requests web_crawler_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_crawler_requests
    ADD CONSTRAINT web_crawler_requests_pkey PRIMARY KEY (id);


--
-- Name: web_hook_event_types web_hook_event_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_hook_event_types
    ADD CONSTRAINT web_hook_event_types_pkey PRIMARY KEY (id);


--
-- Name: web_hook_events_daily_aggregates web_hook_events_daily_aggregates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_hook_events_daily_aggregates
    ADD CONSTRAINT web_hook_events_daily_aggregates_pkey PRIMARY KEY (id);


--
-- Name: web_hook_events web_hook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_hook_events
    ADD CONSTRAINT web_hook_events_pkey PRIMARY KEY (id);


--
-- Name: web_hooks web_hooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_hooks
    ADD CONSTRAINT web_hooks_pkey PRIMARY KEY (id);


--
-- Name: associated_accounts_provider_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX associated_accounts_provider_uid ON public.user_associated_accounts USING btree (provider_name, provider_uid);


--
-- Name: associated_accounts_provider_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX associated_accounts_provider_user ON public.user_associated_accounts USING btree (provider_name, user_id);


--
-- Name: associated_groups_provider_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX associated_groups_provider_id ON public.associated_groups USING btree (provider_name, provider_id);


--
-- Name: by_link; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX by_link ON public.topic_link_clicks USING btree (topic_link_id);


--
-- Name: cat_featured_threads; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX cat_featured_threads ON public.category_featured_topics USING btree (category_id, topic_id);


--
-- Name: chat_message_reactions_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX chat_message_reactions_index ON public.chat_message_reactions USING btree (chat_message_id, user_id, emoji);


--
-- Name: chat_webhook_events_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX chat_webhook_events_index ON public.chat_webhook_events USING btree (chat_message_id, incoming_chat_webhook_id);


--
-- Name: direct_message_users_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX direct_message_users_index ON public.direct_message_users USING btree (direct_message_channel_id, user_id);


--
-- Name: directory_column_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX directory_column_index ON public.directory_columns USING btree (enabled, "position", user_field_id);


--
-- Name: discourse_post_event_invitees_post_id_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX discourse_post_event_invitees_post_id_user_id_idx ON public.discourse_post_event_invitees USING btree (post_id, user_id);


--
-- Name: idx_access_control_lists_allowed_group_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_access_control_lists_allowed_group_ids ON public.access_control_lists USING gin (allowed_group_ids);


--
-- Name: idx_access_control_lists_allowed_user_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_access_control_lists_allowed_user_ids ON public.access_control_lists USING gin (allowed_user_ids);


--
-- Name: idx_ai_bot_conversation_stars_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_bot_conversation_stars_topic_id ON public.discourse_ai_ai_bot_conversation_stars USING btree (topic_id);


--
-- Name: idx_ai_bot_conversation_stars_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_bot_conversation_stars_user_created ON public.discourse_ai_ai_bot_conversation_stars USING btree (user_id, created_at);


--
-- Name: idx_ai_bot_conversation_stars_user_topic; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ai_bot_conversation_stars_user_topic ON public.discourse_ai_ai_bot_conversation_stars USING btree (user_id, topic_id);


--
-- Name: idx_bookmarks_user_polymorphic_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bookmarks_user_polymorphic_unique ON public.bookmarks USING btree (user_id, bookmarkable_type, bookmarkable_id);


--
-- Name: idx_bpcd_rollups_date_country_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bpcd_rollups_date_country_unique ON public.browser_pageview_country_daily_rollups USING btree (date, country_code) NULLS NOT DISTINCT;


--
-- Name: idx_bpe_created_at_country_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bpe_created_at_country_code ON public.browser_pageview_events USING btree (created_at, country_code);


--
-- Name: idx_bpe_created_at_normalized_referrer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bpe_created_at_normalized_referrer ON public.browser_pageview_events USING btree (created_at, normalized_referrer);


--
-- Name: idx_bpe_ip_ua_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bpe_ip_ua_created_at ON public.browser_pageview_events USING btree (ip_address, user_agent, created_at);


--
-- Name: idx_bpe_normalized_referrer_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bpe_normalized_referrer_version ON public.browser_pageview_events USING btree (normalized_referrer_version) WHERE (referrer IS NOT NULL);


--
-- Name: idx_bpe_session_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bpe_session_created_at ON public.browser_pageview_events USING btree (session_id, created_at);


--
-- Name: idx_bprd_rollups_date_referrer_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_bprd_rollups_date_referrer_unique ON public.browser_pageview_referrer_daily_rollups USING btree (date, normalized_referrer) NULLS NOT DISTINCT;


--
-- Name: idx_category_posting_review_groups_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_category_posting_review_groups_unique ON public.category_posting_review_groups USING btree (category_id, group_id, post_type);


--
-- Name: idx_category_required_tag_groups; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_category_required_tag_groups ON public.category_required_tag_groups USING btree (category_id, tag_group_id);


--
-- Name: idx_category_tag_groups_ix1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_category_tag_groups_ix1 ON public.category_tag_groups USING btree (category_id, tag_group_id);


--
-- Name: idx_category_tags_ix1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_category_tags_ix1 ON public.category_tags USING btree (category_id, tag_id);


--
-- Name: idx_category_tags_ix2; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_category_tags_ix2 ON public.category_tags USING btree (tag_id, category_id);


--
-- Name: idx_category_users_category_id_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_category_users_category_id_user_id ON public.category_users USING btree (category_id, user_id);


--
-- Name: idx_category_users_user_id_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_category_users_user_id_category_id ON public.category_users USING btree (user_id, category_id);


--
-- Name: idx_chat_messages_by_created_at_not_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_messages_by_created_at_not_deleted ON public.chat_messages USING btree (created_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_chat_messages_by_thread_id_not_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_messages_by_thread_id_not_deleted ON public.chat_messages USING btree (thread_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_chat_messages_thread_id_id_user_id_not_deleted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_messages_thread_id_id_user_id_not_deleted ON public.chat_messages USING btree (thread_id, id) INCLUDE (user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_chat_pinned_messages_channel_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_pinned_messages_channel_created ON public.chat_pinned_messages USING btree (chat_channel_id, created_at DESC);


--
-- Name: idx_discourse_automation_user_global_notices; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_discourse_automation_user_global_notices ON public.discourse_automation_user_global_notices USING btree (user_id, identifier);


--
-- Name: idx_discourse_calendar_post_event_dates_event_id_starts_at_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_discourse_calendar_post_event_dates_event_id_starts_at_uniq ON public.discourse_calendar_post_event_dates USING btree (event_id, starts_at);


--
-- Name: idx_dwf_ai_sessions_on_status_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_ai_sessions_on_status_updated_at ON public.discourse_workflows_ai_authoring_sessions USING btree (status, updated_at);


--
-- Name: idx_dwf_ai_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_ai_sessions_on_user_id ON public.discourse_workflows_ai_authoring_sessions USING btree (user_id);


--
-- Name: idx_dwf_ai_sessions_on_workflow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_ai_sessions_on_workflow_id ON public.discourse_workflows_ai_authoring_sessions USING btree (workflow_id);


--
-- Name: idx_dwf_call_runs_on_child_execution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dwf_call_runs_on_child_execution_id ON public.discourse_workflows_workflow_call_runs USING btree (child_execution_id) WHERE (child_execution_id IS NOT NULL);


--
-- Name: idx_dwf_call_runs_on_parent_execution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_call_runs_on_parent_execution_id ON public.discourse_workflows_workflow_call_runs USING btree (parent_execution_id);


--
-- Name: idx_dwf_credentials_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_credentials_on_created_by_id ON public.discourse_workflows_credentials USING btree (created_by_id);


--
-- Name: idx_dwf_credentials_on_credential_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_credentials_on_credential_type ON public.discourse_workflows_credentials USING btree (credential_type);


--
-- Name: idx_dwf_credentials_on_name_credential_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dwf_credentials_on_name_credential_type ON public.discourse_workflows_credentials USING btree (name, credential_type);


--
-- Name: idx_dwf_credentials_on_updated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_credentials_on_updated_by_id ON public.discourse_workflows_credentials USING btree (updated_by_id);


--
-- Name: idx_dwf_data_tables_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_data_tables_on_created_by_id ON public.discourse_workflows_data_tables USING btree (created_by_id);


--
-- Name: idx_dwf_data_tables_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dwf_data_tables_on_name ON public.discourse_workflows_data_tables USING btree (name);


--
-- Name: idx_dwf_data_tables_on_updated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_data_tables_on_updated_by_id ON public.discourse_workflows_data_tables USING btree (updated_by_id);


--
-- Name: idx_dwf_deps_on_type_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_deps_on_type_key ON public.discourse_workflows_workflow_dependencies USING btree (dependency_type, dependency_key);


--
-- Name: idx_dwf_deps_on_workflow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_deps_on_workflow_id ON public.discourse_workflows_workflow_dependencies USING btree (workflow_id);


--
-- Name: idx_dwf_deps_on_workflow_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_deps_on_workflow_version_id ON public.discourse_workflows_workflow_dependencies USING btree (workflow_version_id);


--
-- Name: idx_dwf_execution_data_on_execution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dwf_execution_data_on_execution_id ON public.discourse_workflows_execution_data USING btree (execution_id);


--
-- Name: idx_dwf_executions_on_resume_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_executions_on_resume_token ON public.discourse_workflows_executions USING btree (resume_token) WHERE (resume_token IS NOT NULL);


--
-- Name: idx_dwf_executions_on_retention; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_executions_on_retention ON public.discourse_workflows_executions USING btree (created_at) WHERE (status = ANY (ARRAY[2, 3, 5, 6]));


--
-- Name: idx_dwf_executions_on_status_waiting_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_executions_on_status_waiting_until ON public.discourse_workflows_executions USING btree (status, waiting_until);


--
-- Name: idx_dwf_executions_on_waiting_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_executions_on_waiting_until ON public.discourse_workflows_executions USING btree (waiting_until) WHERE ((waiting_until IS NOT NULL) AND (status = 4));


--
-- Name: idx_dwf_executions_on_workflow_created_at_id_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_executions_on_workflow_created_at_id_desc ON public.discourse_workflows_executions USING btree (workflow_id, created_at DESC, id DESC);


--
-- Name: idx_dwf_executions_on_workflow_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_executions_on_workflow_version_id ON public.discourse_workflows_executions USING btree (workflow_version_id);


--
-- Name: idx_dwf_publish_history_on_workflow_created_at_id_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_publish_history_on_workflow_created_at_id_desc ON public.discourse_workflows_workflow_publish_history USING btree (workflow_id, created_at DESC, id DESC);


--
-- Name: idx_dwf_variables_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_variables_on_created_by_id ON public.discourse_workflows_variables USING btree (created_by_id);


--
-- Name: idx_dwf_variables_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dwf_variables_on_key ON public.discourse_workflows_variables USING btree (key);


--
-- Name: idx_dwf_versions_on_workflow_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_versions_on_workflow_created_at ON public.discourse_workflows_workflow_versions USING btree (workflow_id, created_at DESC);


--
-- Name: idx_dwf_versions_on_workflow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_versions_on_workflow_id ON public.discourse_workflows_workflow_versions USING btree (workflow_id);


--
-- Name: idx_dwf_versions_on_workflow_version_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dwf_versions_on_workflow_version_number ON public.discourse_workflows_workflow_versions USING btree (workflow_id, version_number);


--
-- Name: idx_dwf_webhooks_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_webhooks_on_expires_at ON public.discourse_workflows_webhooks USING btree (expires_at) WHERE (expires_at IS NOT NULL);


--
-- Name: idx_dwf_webhooks_on_method_path_test; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dwf_webhooks_on_method_path_test ON public.discourse_workflows_webhooks USING btree (http_method, webhook_path, test_webhook);


--
-- Name: idx_dwf_webhooks_on_webhook_id_method_test; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_webhooks_on_webhook_id_method_test ON public.discourse_workflows_webhooks USING btree (webhook_id, http_method, test_webhook) WHERE (webhook_id IS NOT NULL);


--
-- Name: idx_dwf_webhooks_on_workflow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_webhooks_on_workflow_id ON public.discourse_workflows_webhooks USING btree (workflow_id);


--
-- Name: idx_dwf_webhooks_on_workflow_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_webhooks_on_workflow_version_id ON public.discourse_workflows_webhooks USING btree (workflow_version_id);


--
-- Name: idx_dwf_workflows_on_active_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_workflows_on_active_version_id ON public.discourse_workflows_workflows USING btree (active_version_id);


--
-- Name: idx_dwf_workflows_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_workflows_on_created_by_id ON public.discourse_workflows_workflows USING btree (created_by_id);


--
-- Name: idx_dwf_workflows_on_error_workflow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_workflows_on_error_workflow_id ON public.discourse_workflows_workflows USING btree (error_workflow_id);


--
-- Name: idx_dwf_workflows_on_updated_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dwf_workflows_on_updated_by_id ON public.discourse_workflows_workflows USING btree (updated_by_id);


--
-- Name: idx_dwf_workflows_on_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_dwf_workflows_on_version_id ON public.discourse_workflows_workflows USING btree (version_id);


--
-- Name: idx_email_change_requests_on_requested_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_email_change_requests_on_requested_by ON public.email_change_requests USING btree (requested_by_user_id);


--
-- Name: idx_group_category_notification_defaults_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_group_category_notification_defaults_unique ON public.group_category_notification_defaults USING btree (group_id, category_id);


--
-- Name: idx_group_tag_notification_defaults_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_group_tag_notification_defaults_unique ON public.group_tag_notification_defaults USING btree (group_id, tag_id);


--
-- Name: idx_leaderboard_scores_lb_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_leaderboard_scores_lb_date ON public.gamification_leaderboard_scores USING btree (leaderboard_id, date);


--
-- Name: idx_leaderboard_scores_lb_user_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_leaderboard_scores_lb_user_date ON public.gamification_leaderboard_scores USING btree (leaderboard_id, user_id, date);


--
-- Name: idx_notifications_speedup_unread_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_speedup_unread_count ON public.notifications USING btree (user_id, notification_type) WHERE (NOT read);


--
-- Name: idx_on_llm_model_id_feature_name_2b0b794b27; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_llm_model_id_feature_name_2b0b794b27 ON public.llm_feature_credit_costs USING btree (llm_model_id, feature_name);


--
-- Name: idx_on_target_id_target_type_summary_type_3355609fbb; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_target_id_target_type_summary_type_3355609fbb ON public.ai_summaries USING btree (target_id, target_type, summary_type);


--
-- Name: idx_on_target_type_target_id_permission_f472902150; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_target_type_target_id_permission_f472902150 ON public.access_control_lists USING btree (target_type, target_id, permission);


--
-- Name: idx_post_voting_comment_custom_fields; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_post_voting_comment_custom_fields ON public.post_voting_comment_custom_fields USING btree (post_voting_comment_id, name);


--
-- Name: idx_posts_created_at_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_created_at_topic_id ON public.posts USING btree (created_at, topic_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_posts_deleted_posts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_deleted_posts ON public.posts USING btree (topic_id, post_number) WHERE (deleted_at IS NOT NULL);


--
-- Name: idx_posts_user_id_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_user_id_deleted_at ON public.posts USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_reviewables_score_desc_created_at_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviewables_score_desc_created_at_desc ON public.reviewables USING btree (score DESC, created_at DESC);


--
-- Name: idx_search_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_search_category ON public.category_search_data USING gin (search_data);


--
-- Name: idx_search_chat_message; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_search_chat_message ON public.chat_message_search_data USING gin (search_data);


--
-- Name: idx_search_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_search_post ON public.post_search_data USING gin (search_data);


--
-- Name: idx_search_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_search_tag ON public.tag_search_data USING gin (search_data);


--
-- Name: idx_search_topic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_search_topic ON public.topic_search_data USING gin (search_data);


--
-- Name: idx_search_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_search_user ON public.user_search_data USING gin (search_data);


--
-- Name: idx_shared_ai_conversations_user_target; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_shared_ai_conversations_user_target ON public.shared_ai_conversations USING btree (user_id, target_id, target_type);


--
-- Name: idx_sidebar_section_links_on_sidebar_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_sidebar_section_links_on_sidebar_section_id ON public.sidebar_section_links USING btree (sidebar_section_id, user_id, "position");


--
-- Name: idx_timerable_id_public_type_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_timerable_id_public_type_deleted_at ON public.topic_timers USING btree (timerable_id) WHERE ((public_type = true) AND (deleted_at IS NULL) AND ((type)::text = 'TopicTimer'::text));


--
-- Name: idx_topic_custom_fields_accepted_answer; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_topic_custom_fields_accepted_answer ON public.topic_custom_fields USING btree (topic_id) WHERE ((name)::text = 'accepted_answer_post_id'::text);


--
-- Name: idx_topic_custom_fields_auto_responder_triggered_ids_partial; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_topic_custom_fields_auto_responder_triggered_ids_partial ON public.topic_custom_fields USING btree (topic_id, value) WHERE ((name)::text = 'auto_responder_triggered_ids'::text);


--
-- Name: idx_topic_custom_fields_topic_post_event_all_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_topic_custom_fields_topic_post_event_all_day ON public.topic_custom_fields USING btree (name, topic_id) WHERE ((name)::text = 'TopicEventAllDay'::text);


--
-- Name: idx_topic_custom_fields_topic_post_event_ends_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_topic_custom_fields_topic_post_event_ends_at ON public.topic_custom_fields USING btree (name, topic_id) WHERE ((name)::text = 'TopicEventEndsAt'::text);


--
-- Name: idx_topic_custom_fields_topic_post_event_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_topic_custom_fields_topic_post_event_starts_at ON public.topic_custom_fields USING btree (name, topic_id) WHERE ((name)::text = 'TopicEventStartsAt'::text);


--
-- Name: idx_topic_id_public_type_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_topic_id_public_type_deleted_at ON public.topic_timers USING btree (topic_id) WHERE ((public_type = true) AND (deleted_at IS NULL) AND ((type)::text = 'TopicTimer'::text));


--
-- Name: idx_topics_front_page; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_topics_front_page ON public.topics USING btree (deleted_at, visible, archetype, category_id, id);


--
-- Name: idx_topics_user_id_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_topics_user_id_deleted_at ON public.topics USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_unique_actions; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_actions ON public.post_actions USING btree (user_id, post_action_type_id, post_id, targets_topic) WHERE ((deleted_at IS NULL) AND (disagreed_at IS NULL) AND (deferred_at IS NULL));


--
-- Name: idx_unique_flags; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_flags ON public.post_actions USING btree (user_id, post_id, targets_topic) WHERE ((deleted_at IS NULL) AND (disagreed_at IS NULL) AND (deferred_at IS NULL) AND (post_action_type_id = ANY (ARRAY[3, 4, 7, 8])));


--
-- Name: idx_unique_rows; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_rows ON public.user_actions USING btree (action_type, user_id, target_topic_id, target_post_id, acting_user_id);


--
-- Name: idx_unique_sidebar_section_links; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_unique_sidebar_section_links ON public.sidebar_section_links USING btree (user_id, linkable_type, linkable_id);


--
-- Name: idx_upcoming_change_events_unique_once_off; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_upcoming_change_events_unique_once_off ON public.upcoming_change_events USING btree (upcoming_change_name, event_type) WHERE (event_type = ANY (ARRAY[0, 1, 6, 7]));


--
-- Name: idx_uploads_on_verification_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_uploads_on_verification_status ON public.uploads USING btree (verification_status);


--
-- Name: idx_user_actions_speed_up_user_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_actions_speed_up_user_all ON public.user_actions USING btree (user_id, created_at, action_type);


--
-- Name: idx_user_chat_thread_memberships_on_thread_id_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_chat_thread_memberships_on_thread_id_user_id ON public.user_chat_thread_memberships USING btree (thread_id, user_id);


--
-- Name: idx_user_custom_fields_last_reminded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_custom_fields_last_reminded_at ON public.user_custom_fields USING btree (name, user_id) WHERE ((name)::text = 'last_reminded_at'::text);


--
-- Name: idx_user_custom_fields_on_holiday; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_custom_fields_on_holiday ON public.user_custom_fields USING btree (name, user_id) WHERE ((name)::text = 'on_holiday'::text);


--
-- Name: idx_user_custom_fields_remind_assigns_frequency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_custom_fields_remind_assigns_frequency ON public.user_custom_fields USING btree (name, user_id) WHERE ((name)::text = 'remind_assigns_frequency'::text);


--
-- Name: idx_user_custom_fields_user_notes_count; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_custom_fields_user_notes_count ON public.user_custom_fields USING btree (name, user_id) WHERE ((name)::text = 'user_notes_count'::text);


--
-- Name: idx_users_admin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_admin ON public.users USING btree (id) WHERE admin;


--
-- Name: idx_users_ip_address; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_ip_address ON public.users USING btree (ip_address);


--
-- Name: idx_users_moderator; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_moderator ON public.users USING btree (id) WHERE moderator;


--
-- Name: idx_web_hook_event_types_hooks_on_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_web_hook_event_types_hooks_on_ids ON public.web_hook_event_types_hooks USING btree (web_hook_event_type_id, web_hook_id);


--
-- Name: idxtopicslug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idxtopicslug ON public.topics USING btree (slug) WHERE ((deleted_at IS NULL) AND (slug IS NOT NULL));


--
-- Name: index_ad_plugin_house_ads_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ad_plugin_house_ads_on_name ON public.ad_plugin_house_ads USING btree (name);


--
-- Name: index_ad_plugin_house_ads_on_visible_to_anons; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_plugin_house_ads_on_visible_to_anons ON public.ad_plugin_house_ads USING btree (visible_to_anons);


--
-- Name: index_ad_plugin_house_ads_on_visible_to_logged_in_users; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_plugin_house_ads_on_visible_to_logged_in_users ON public.ad_plugin_house_ads USING btree (visible_to_logged_in_users);


--
-- Name: index_ad_plugin_impressions_on_ad_plugin_house_ad_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_plugin_impressions_on_ad_plugin_house_ad_id ON public.ad_plugin_impressions USING btree (ad_plugin_house_ad_id);


--
-- Name: index_ad_plugin_impressions_on_ad_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_plugin_impressions_on_ad_type ON public.ad_plugin_impressions USING btree (ad_type);


--
-- Name: index_ad_plugin_impressions_on_ad_type_and_placement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_plugin_impressions_on_ad_type_and_placement ON public.ad_plugin_impressions USING btree (ad_type, placement);


--
-- Name: index_ad_plugin_impressions_on_clicked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_plugin_impressions_on_clicked_at ON public.ad_plugin_impressions USING btree (clicked_at);


--
-- Name: index_ad_plugin_impressions_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_plugin_impressions_on_created_at ON public.ad_plugin_impressions USING btree (created_at);


--
-- Name: index_ad_plugin_impressions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_plugin_impressions_on_user_id ON public.ad_plugin_impressions USING btree (user_id);


--
-- Name: index_admin_dashboard_reports_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_dashboard_reports_on_position ON public.admin_dashboard_reports USING btree ("position");


--
-- Name: index_admin_dashboard_reports_on_source_and_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admin_dashboard_reports_on_source_and_identifier ON public.admin_dashboard_reports USING btree (source, identifier);


--
-- Name: index_admin_dashboard_sections_on_section_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admin_dashboard_sections_on_section_id ON public.admin_dashboard_sections USING btree (section_id);


--
-- Name: index_admin_notices_on_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_notices_on_identifier ON public.admin_notices USING btree (identifier);


--
-- Name: index_admin_notices_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_admin_notices_on_subject ON public.admin_notices USING btree (subject);


--
-- Name: index_ai_agent_mcp_servers_on_ai_agent_id_and_ai_mcp_server_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_agent_mcp_servers_on_ai_agent_id_and_ai_mcp_server_id ON public.ai_agent_mcp_servers USING btree (ai_agent_id, ai_mcp_server_id);


--
-- Name: index_ai_agent_mcp_servers_on_ai_mcp_server_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_agent_mcp_servers_on_ai_mcp_server_id ON public.ai_agent_mcp_servers USING btree (ai_mcp_server_id);


--
-- Name: index_ai_agents_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_agents_on_name ON public.ai_agents USING btree (name);


--
-- Name: index_ai_api_audit_logs_on_created_at_and_feature_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_audit_logs_on_created_at_and_feature_name ON public.ai_api_audit_logs USING btree (created_at, feature_name);


--
-- Name: index_ai_api_audit_logs_on_created_at_and_language_model; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_audit_logs_on_created_at_and_language_model ON public.ai_api_audit_logs USING btree (created_at, language_model);


--
-- Name: index_ai_api_audit_logs_on_created_at_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_audit_logs_on_created_at_and_user_id ON public.ai_api_audit_logs USING btree (created_at, user_id);


--
-- Name: index_ai_api_audit_logs_on_llm_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_audit_logs_on_llm_id ON public.ai_api_audit_logs USING btree (llm_id);


--
-- Name: index_ai_api_audit_logs_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_audit_logs_on_post_id ON public.ai_api_audit_logs USING btree (post_id);


--
-- Name: index_ai_api_audit_logs_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_audit_logs_on_topic_id ON public.ai_api_audit_logs USING btree (topic_id);


--
-- Name: index_ai_api_request_stats_on_bucket_date_and_feature_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_request_stats_on_bucket_date_and_feature_name ON public.ai_api_request_stats USING btree (bucket_date, feature_name);


--
-- Name: index_ai_api_request_stats_on_bucket_date_and_language_model; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_request_stats_on_bucket_date_and_language_model ON public.ai_api_request_stats USING btree (bucket_date, language_model);


--
-- Name: index_ai_api_request_stats_on_bucket_date_and_llm_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_request_stats_on_bucket_date_and_llm_id ON public.ai_api_request_stats USING btree (bucket_date, llm_id);


--
-- Name: index_ai_api_request_stats_on_bucket_date_and_rolled_up; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_request_stats_on_bucket_date_and_rolled_up ON public.ai_api_request_stats USING btree (bucket_date, rolled_up) WHERE (rolled_up = false);


--
-- Name: index_ai_api_request_stats_on_bucket_date_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_request_stats_on_bucket_date_and_user_id ON public.ai_api_request_stats USING btree (bucket_date, user_id);


--
-- Name: index_ai_api_request_stats_on_created_at_and_feature_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_request_stats_on_created_at_and_feature_name ON public.ai_api_request_stats USING btree (created_at, feature_name);


--
-- Name: index_ai_api_request_stats_on_created_at_and_language_model; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_request_stats_on_created_at_and_language_model ON public.ai_api_request_stats USING btree (created_at, language_model);


--
-- Name: index_ai_api_request_stats_on_created_at_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_api_request_stats_on_created_at_and_user_id ON public.ai_api_request_stats USING btree (created_at, user_id);


--
-- Name: index_ai_artifact_kv_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_artifact_kv_unique ON public.ai_artifact_key_values USING btree (ai_artifact_id, user_id, key);


--
-- Name: index_ai_artifact_versions_on_ai_artifact_id_and_version_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_artifact_versions_on_ai_artifact_id_and_version_number ON public.ai_artifact_versions USING btree (ai_artifact_id, version_number);


--
-- Name: index_ai_fragments_embeddings_on_model_strategy_fragment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_fragments_embeddings_on_model_strategy_fragment ON public.ai_document_fragments_embeddings USING btree (model_id, strategy_id, rag_document_fragment_id);


--
-- Name: index_ai_mcp_oauth_tokens_on_ai_mcp_server_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_mcp_oauth_tokens_on_ai_mcp_server_id ON public.ai_mcp_oauth_tokens USING btree (ai_mcp_server_id);


--
-- Name: index_ai_mcp_servers_on_ai_secret_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_mcp_servers_on_ai_secret_id ON public.ai_mcp_servers USING btree (ai_secret_id);


--
-- Name: index_ai_mcp_servers_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_mcp_servers_on_name ON public.ai_mcp_servers USING btree (name);


--
-- Name: index_ai_mcp_servers_on_oauth_client_secret_ai_secret_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_mcp_servers_on_oauth_client_secret_ai_secret_id ON public.ai_mcp_servers USING btree (oauth_client_secret_ai_secret_id);


--
-- Name: index_ai_moderation_settings_on_setting_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_moderation_settings_on_setting_type ON public.ai_moderation_settings USING btree (setting_type);


--
-- Name: index_ai_posts_embeddings_on_model_strategy_post; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_posts_embeddings_on_model_strategy_post ON public.ai_posts_embeddings USING btree (model_id, strategy_id, post_id);


--
-- Name: index_ai_secrets_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_secrets_on_name ON public.ai_secrets USING btree (name);


--
-- Name: index_ai_spam_logs_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_spam_logs_on_post_id ON public.ai_spam_logs USING btree (post_id);


--
-- Name: index_ai_summaries_on_target_type_and_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_summaries_on_target_type_and_target_id ON public.ai_summaries USING btree (target_type, target_id);


--
-- Name: index_ai_tool_actions_on_ai_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_tool_actions_on_ai_agent_id ON public.ai_tool_actions USING btree (ai_agent_id);


--
-- Name: index_ai_tool_secret_bindings_on_ai_secret_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_tool_secret_bindings_on_ai_secret_id ON public.ai_tool_secret_bindings USING btree (ai_secret_id);


--
-- Name: index_ai_tool_secret_bindings_on_ai_tool_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_tool_secret_bindings_on_ai_tool_id ON public.ai_tool_secret_bindings USING btree (ai_tool_id);


--
-- Name: index_ai_tool_secret_bindings_on_ai_tool_id_and_alias; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_tool_secret_bindings_on_ai_tool_id_and_alias ON public.ai_tool_secret_bindings USING btree (ai_tool_id, alias);


--
-- Name: index_ai_topics_embeddings_on_model_strategy_topic; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ai_topics_embeddings_on_model_strategy_topic ON public.ai_topics_embeddings USING btree (model_id, strategy_id, topic_id);


--
-- Name: index_ai_topics_embeddings_on_topic_id_and_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_topics_embeddings_on_topic_id_and_model_id ON public.ai_topics_embeddings USING btree (topic_id, model_id);


--
-- Name: index_allowed_pm_users_on_allowed_pm_user_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_allowed_pm_users_on_allowed_pm_user_id_and_user_id ON public.allowed_pm_users USING btree (allowed_pm_user_id, user_id);


--
-- Name: index_allowed_pm_users_on_user_id_and_allowed_pm_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_allowed_pm_users_on_user_id_and_allowed_pm_user_id ON public.allowed_pm_users USING btree (user_id, allowed_pm_user_id);


--
-- Name: index_anonymous_users_on_master_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_anonymous_users_on_master_user_id ON public.anonymous_users USING btree (master_user_id) WHERE active;


--
-- Name: index_anonymous_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_anonymous_users_on_user_id ON public.anonymous_users USING btree (user_id);


--
-- Name: index_api_key_scopes_on_api_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_key_scopes_on_api_key_id ON public.api_key_scopes USING btree (api_key_id);


--
-- Name: index_api_keys_on_key_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_keys_on_key_hash ON public.api_keys USING btree (key_hash);


--
-- Name: index_api_keys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_keys_on_user_id ON public.api_keys USING btree (user_id);


--
-- Name: index_application_requests_on_date_and_req_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_application_requests_on_date_and_req_type ON public.application_requests USING btree (date, req_type);


--
-- Name: index_assignments_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_active ON public.assignments USING btree (active);


--
-- Name: index_assignments_on_assigned_to_id_and_assigned_to_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_assigned_to_id_and_assigned_to_type ON public.assignments USING btree (assigned_to_id, assigned_to_type);


--
-- Name: index_assignments_on_target_id_and_target_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_assignments_on_target_id_and_target_type ON public.assignments USING btree (target_id, target_type);


--
-- Name: index_assignments_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assignments_on_topic_id ON public.assignments USING btree (topic_id);


--
-- Name: index_backup_draft_posts_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_backup_draft_posts_on_post_id ON public.backup_draft_posts USING btree (post_id);


--
-- Name: index_backup_draft_posts_on_user_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_backup_draft_posts_on_user_id_and_key ON public.backup_draft_posts USING btree (user_id, key);


--
-- Name: index_backup_draft_topics_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_backup_draft_topics_on_topic_id ON public.backup_draft_topics USING btree (topic_id);


--
-- Name: index_backup_draft_topics_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_backup_draft_topics_on_user_id ON public.backup_draft_topics USING btree (user_id);


--
-- Name: index_badge_types_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_badge_types_on_name ON public.badge_types USING btree (name);


--
-- Name: index_badges_on_badge_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_badges_on_badge_type_id ON public.badges USING btree (badge_type_id);


--
-- Name: index_badges_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_badges_on_name ON public.badges USING btree (name);


--
-- Name: index_bookmarks_on_reminder_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_reminder_at ON public.bookmarks USING btree (reminder_at);


--
-- Name: index_bookmarks_on_reminder_set_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_reminder_set_at ON public.bookmarks USING btree (reminder_set_at);


--
-- Name: index_bookmarks_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bookmarks_on_user_id ON public.bookmarks USING btree (user_id);


--
-- Name: index_browser_pageview_event_scores_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_browser_pageview_event_scores_on_event_id ON public.browser_pageview_event_scores USING btree (event_id);


--
-- Name: index_browser_pageview_events_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_browser_pageview_events_on_created_at ON public.browser_pageview_events USING brin (created_at);


--
-- Name: index_browser_pageview_events_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_browser_pageview_events_on_topic_id ON public.browser_pageview_events USING btree (topic_id);


--
-- Name: index_browser_pageview_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_browser_pageview_events_on_user_id ON public.browser_pageview_events USING btree (user_id);


--
-- Name: index_browser_pageview_session_engagements_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_browser_pageview_session_engagements_on_created_at ON public.browser_pageview_session_engagements USING brin (created_at);


--
-- Name: index_browser_pageview_session_engagements_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_browser_pageview_session_engagements_on_session_id ON public.browser_pageview_session_engagements USING btree (session_id);


--
-- Name: index_calendar_events_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_post_id ON public.calendar_events USING btree (post_id);


--
-- Name: index_calendar_events_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_topic_id ON public.calendar_events USING btree (topic_id);


--
-- Name: index_calendar_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_calendar_events_on_user_id ON public.calendar_events USING btree (user_id);


--
-- Name: index_categories_on_email_in; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_email_in ON public.categories USING btree (email_in);


--
-- Name: index_categories_on_reviewable_by_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_reviewable_by_group_id ON public.categories USING btree (reviewable_by_group_id);


--
-- Name: index_categories_on_search_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_search_priority ON public.categories USING btree (search_priority);


--
-- Name: index_categories_on_topic_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_categories_on_topic_count ON public.categories USING btree (topic_count);


--
-- Name: index_categories_web_hooks_on_web_hook_id_and_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_web_hooks_on_web_hook_id_and_category_id ON public.categories_web_hooks USING btree (web_hook_id, category_id);


--
-- Name: index_category_custom_fields_on_category_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_custom_fields_on_category_id_and_name ON public.category_custom_fields USING btree (category_id, name);


--
-- Name: index_category_featured_topics_on_category_id_and_rank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_featured_topics_on_category_id_and_rank ON public.category_featured_topics USING btree (category_id, rank);


--
-- Name: index_category_form_templates_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_form_templates_on_category_id ON public.category_form_templates USING btree (category_id);


--
-- Name: index_category_form_templates_on_form_template_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_form_templates_on_form_template_id ON public.category_form_templates USING btree (form_template_id);


--
-- Name: index_category_groups_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_groups_on_group_id ON public.category_groups USING btree (group_id);


--
-- Name: index_category_localizations_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_localizations_on_category_id ON public.category_localizations USING btree (category_id);


--
-- Name: index_category_localizations_on_category_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_localizations_on_category_id_and_locale ON public.category_localizations USING btree (category_id, locale);


--
-- Name: index_category_moderation_groups_on_category_id_and_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_moderation_groups_on_category_id_and_group_id ON public.category_moderation_groups USING btree (category_id, group_id);


--
-- Name: index_category_settings_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_settings_on_category_id ON public.category_settings USING btree (category_id);


--
-- Name: index_category_tag_stats_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_tag_stats_on_category_id ON public.category_tag_stats USING btree (category_id);


--
-- Name: index_category_tag_stats_on_category_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_category_tag_stats_on_category_id_and_tag_id ON public.category_tag_stats USING btree (category_id, tag_id);


--
-- Name: index_category_tag_stats_on_category_id_and_topic_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_tag_stats_on_category_id_and_topic_count ON public.category_tag_stats USING btree (category_id, topic_count);


--
-- Name: index_category_tag_stats_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_tag_stats_on_tag_id ON public.category_tag_stats USING btree (tag_id);


--
-- Name: index_category_users_on_category_id_and_notification_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_users_on_category_id_and_notification_level ON public.category_users USING btree (category_id, notification_level);


--
-- Name: index_category_users_on_user_id_and_last_seen_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_category_users_on_user_id_and_last_seen_at ON public.category_users USING btree (user_id, last_seen_at);


--
-- Name: index_chat_channel_archives_on_chat_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_channel_archives_on_chat_channel_id ON public.chat_channel_archives USING btree (chat_channel_id);


--
-- Name: index_chat_channel_custom_fields_on_channel_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_channel_custom_fields_on_channel_id_and_name ON public.chat_channel_custom_fields USING btree (channel_id, name);


--
-- Name: index_chat_channels_on_chatable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_channels_on_chatable_id ON public.chat_channels USING btree (chatable_id);


--
-- Name: index_chat_channels_on_chatable_id_and_chatable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_channels_on_chatable_id_and_chatable_type ON public.chat_channels USING btree (chatable_id, chatable_type);


--
-- Name: index_chat_channels_on_last_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_channels_on_last_message_id ON public.chat_channels USING btree (last_message_id);


--
-- Name: index_chat_channels_on_messages_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_channels_on_messages_count ON public.chat_channels USING btree (messages_count);


--
-- Name: index_chat_channels_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_channels_on_slug ON public.chat_channels USING btree (slug) WHERE ((slug)::text <> ''::text);


--
-- Name: index_chat_channels_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_channels_on_status ON public.chat_channels USING btree (status);


--
-- Name: index_chat_mention_notifications_on_chat_mention_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_mention_notifications_on_chat_mention_id ON public.chat_mention_notifications USING btree (chat_mention_id);


--
-- Name: index_chat_mention_notifications_on_notification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_mention_notifications_on_notification_id ON public.chat_mention_notifications USING btree (notification_id);


--
-- Name: index_chat_mentions_on_chat_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_mentions_on_chat_message_id ON public.chat_mentions USING btree (chat_message_id);


--
-- Name: index_chat_mentions_on_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_mentions_on_target_id ON public.chat_mentions USING btree (target_id);


--
-- Name: index_chat_message_custom_fields_on_message_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_message_custom_fields_on_message_id_and_name ON public.chat_message_custom_fields USING btree (message_id, name);


--
-- Name: index_chat_message_custom_prompts_on_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_message_custom_prompts_on_message_id ON public.chat_message_custom_prompts USING btree (message_id);


--
-- Name: index_chat_message_interactions_on_chat_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_message_interactions_on_chat_message_id ON public.chat_message_interactions USING btree (chat_message_id);


--
-- Name: index_chat_message_interactions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_message_interactions_on_user_id ON public.chat_message_interactions USING btree (user_id);


--
-- Name: index_chat_message_links_on_chat_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_message_links_on_chat_message_id ON public.chat_message_links USING btree (chat_message_id);


--
-- Name: index_chat_message_links_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_message_links_on_url ON public.chat_message_links USING btree (url);


--
-- Name: index_chat_message_revisions_on_chat_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_message_revisions_on_chat_message_id ON public.chat_message_revisions USING btree (chat_message_id);


--
-- Name: index_chat_message_revisions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_message_revisions_on_user_id ON public.chat_message_revisions USING btree (user_id);


--
-- Name: index_chat_messages_on_chat_channel_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_messages_on_chat_channel_id_and_created_at ON public.chat_messages USING btree (chat_channel_id, created_at);


--
-- Name: index_chat_messages_on_chat_channel_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_messages_on_chat_channel_id_and_id ON public.chat_messages USING btree (chat_channel_id, id) WHERE (deleted_at IS NOT NULL);


--
-- Name: index_chat_messages_on_last_editor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_messages_on_last_editor_id ON public.chat_messages USING btree (last_editor_id);


--
-- Name: index_chat_messages_on_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_messages_on_thread_id ON public.chat_messages USING btree (thread_id);


--
-- Name: index_chat_pinned_messages_on_chat_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_pinned_messages_on_chat_message_id ON public.chat_pinned_messages USING btree (chat_message_id);


--
-- Name: index_chat_thread_custom_fields_on_thread_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_chat_thread_custom_fields_on_thread_id_and_name ON public.chat_thread_custom_fields USING btree (thread_id, name);


--
-- Name: index_chat_threads_on_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_channel_id ON public.chat_threads USING btree (channel_id);


--
-- Name: index_chat_threads_on_channel_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_channel_id_and_status ON public.chat_threads USING btree (channel_id, status);


--
-- Name: index_chat_threads_on_last_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_last_message_id ON public.chat_threads USING btree (last_message_id);


--
-- Name: index_chat_threads_on_original_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_original_message_id ON public.chat_threads USING btree (original_message_id);


--
-- Name: index_chat_threads_on_original_message_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_original_message_user_id ON public.chat_threads USING btree (original_message_user_id);


--
-- Name: index_chat_threads_on_replies_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_replies_count ON public.chat_threads USING btree (replies_count);


--
-- Name: index_chat_threads_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_threads_on_status ON public.chat_threads USING btree (status);


--
-- Name: index_child_themes_on_child_theme_id_and_parent_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_child_themes_on_child_theme_id_and_parent_theme_id ON public.child_themes USING btree (child_theme_id, parent_theme_id);


--
-- Name: index_child_themes_on_parent_theme_id_and_child_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_child_themes_on_parent_theme_id_and_child_theme_id ON public.child_themes USING btree (parent_theme_id, child_theme_id);


--
-- Name: index_color_scheme_colors_on_color_scheme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_color_scheme_colors_on_color_scheme_id ON public.color_scheme_colors USING btree (color_scheme_id);


--
-- Name: index_completion_prompts_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_completion_prompts_on_name ON public.completion_prompts USING btree (name);


--
-- Name: index_custom_emojis_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_custom_emojis_on_name ON public.custom_emojis USING btree (name);


--
-- Name: index_data_explorer_query_groups_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_explorer_query_groups_on_group_id ON public.data_explorer_query_groups USING btree (group_id);


--
-- Name: index_data_explorer_query_groups_on_query_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_data_explorer_query_groups_on_query_id ON public.data_explorer_query_groups USING btree (query_id);


--
-- Name: index_data_explorer_query_groups_on_query_id_and_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_data_explorer_query_groups_on_query_id_and_group_id ON public.data_explorer_query_groups USING btree (query_id, group_id);


--
-- Name: index_developers_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_developers_on_user_id ON public.developers USING btree (user_id);


--
-- Name: index_directory_items_on_days_visited; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_directory_items_on_days_visited ON public.directory_items USING btree (days_visited);


--
-- Name: index_directory_items_on_likes_given; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_directory_items_on_likes_given ON public.directory_items USING btree (likes_given);


--
-- Name: index_directory_items_on_likes_received; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_directory_items_on_likes_received ON public.directory_items USING btree (likes_received);


--
-- Name: index_directory_items_on_period_type_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_directory_items_on_period_type_and_user_id ON public.directory_items USING btree (period_type, user_id);


--
-- Name: index_directory_items_on_post_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_directory_items_on_post_count ON public.directory_items USING btree (post_count);


--
-- Name: index_directory_items_on_posts_read; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_directory_items_on_posts_read ON public.directory_items USING btree (posts_read);


--
-- Name: index_directory_items_on_topic_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_directory_items_on_topic_count ON public.directory_items USING btree (topic_count);


--
-- Name: index_directory_items_on_topics_entered; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_directory_items_on_topics_entered ON public.directory_items USING btree (topics_entered);


--
-- Name: index_disabled_holidays_on_holiday_name_and_region_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_disabled_holidays_on_holiday_name_and_region_code ON public.discourse_calendar_disabled_holidays USING btree (holiday_name, region_code);


--
-- Name: index_discourse_automation_stats_on_automation_id_and_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_discourse_automation_stats_on_automation_id_and_date ON public.discourse_automation_stats USING btree (automation_id, date);


--
-- Name: index_discourse_calendar_post_event_dates_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_calendar_post_event_dates_on_event_id ON public.discourse_calendar_post_event_dates USING btree (event_id);


--
-- Name: index_discourse_calendar_post_event_dates_on_event_id_and_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_calendar_post_event_dates_on_event_id_and_dates ON public.discourse_calendar_post_event_dates USING btree (event_id, finished_at, starts_at DESC, updated_at DESC, id DESC);


--
-- Name: index_discourse_calendar_post_event_dates_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_calendar_post_event_dates_on_finished_at ON public.discourse_calendar_post_event_dates USING btree (finished_at);


--
-- Name: index_discourse_post_event_events_on_image_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_post_event_events_on_image_upload_id ON public.discourse_post_event_events USING btree (image_upload_id);


--
-- Name: index_discourse_reactions_reaction_users_on_reaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_reactions_reaction_users_on_reaction_id ON public.discourse_reactions_reaction_users USING btree (reaction_id);


--
-- Name: index_discourse_reactions_reactions_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_reactions_reactions_on_post_id ON public.discourse_reactions_reactions USING btree (post_id);


--
-- Name: index_discourse_rss_polling_rss_feeds_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_rss_polling_rss_feeds_on_user_id ON public.discourse_rss_polling_rss_feeds USING btree (user_id);


--
-- Name: index_discourse_solved_shared_issues_on_topic_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_discourse_solved_shared_issues_on_topic_id_and_user_id ON public.discourse_solved_shared_issues USING btree (topic_id, user_id);


--
-- Name: index_discourse_solved_shared_issues_on_user_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_solved_shared_issues_on_user_id_and_topic_id ON public.discourse_solved_shared_issues USING btree (user_id, topic_id);


--
-- Name: index_discourse_solved_solved_topics_on_answer_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_discourse_solved_solved_topics_on_answer_post_id ON public.discourse_solved_solved_topics USING btree (answer_post_id);


--
-- Name: index_discourse_solved_solved_topics_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_discourse_solved_solved_topics_on_topic_id ON public.discourse_solved_solved_topics USING btree (topic_id);


--
-- Name: index_discourse_solved_topic_answers_on_answer_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_discourse_solved_topic_answers_on_answer_post_id ON public.discourse_solved_topic_answers USING btree (answer_post_id);


--
-- Name: index_discourse_solved_topic_answers_on_solved_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_solved_topic_answers_on_solved_topic_id ON public.discourse_solved_topic_answers USING btree (solved_topic_id);


--
-- Name: index_discourse_subscriptions_customers_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_subscriptions_customers_on_customer_id ON public.discourse_subscriptions_customers USING btree (customer_id);


--
-- Name: index_discourse_subscriptions_customers_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_subscriptions_customers_on_user_id ON public.discourse_subscriptions_customers USING btree (user_id);


--
-- Name: index_discourse_subscriptions_products_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_subscriptions_products_on_external_id ON public.discourse_subscriptions_products USING btree (external_id);


--
-- Name: index_discourse_subscriptions_subscriptions_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_subscriptions_subscriptions_on_customer_id ON public.discourse_subscriptions_subscriptions USING btree (customer_id);


--
-- Name: index_discourse_subscriptions_subscriptions_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_discourse_subscriptions_subscriptions_on_external_id ON public.discourse_subscriptions_subscriptions USING btree (external_id);


--
-- Name: index_discourse_templates_usage_count_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_discourse_templates_usage_count_on_topic_id ON public.discourse_templates_usage_count USING btree (topic_id);


--
-- Name: index_dismissed_topic_users_on_user_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_dismissed_topic_users_on_user_id_and_topic_id ON public.dismissed_topic_users USING btree (user_id, topic_id);


--
-- Name: index_do_not_disturb_timings_on_ends_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_do_not_disturb_timings_on_ends_at ON public.do_not_disturb_timings USING btree (ends_at);


--
-- Name: index_do_not_disturb_timings_on_scheduled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_do_not_disturb_timings_on_scheduled ON public.do_not_disturb_timings USING btree (scheduled);


--
-- Name: index_do_not_disturb_timings_on_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_do_not_disturb_timings_on_starts_at ON public.do_not_disturb_timings USING btree (starts_at);


--
-- Name: index_do_not_disturb_timings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_do_not_disturb_timings_on_user_id ON public.do_not_disturb_timings USING btree (user_id);


--
-- Name: index_draft_sequences_on_user_id_and_draft_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_draft_sequences_on_user_id_and_draft_key ON public.draft_sequences USING btree (user_id, draft_key);


--
-- Name: index_drafts_on_user_id_and_draft_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_drafts_on_user_id_and_draft_key ON public.drafts USING btree (user_id, draft_key);


--
-- Name: index_email_change_requests_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_change_requests_on_user_id ON public.email_change_requests USING btree (user_id);


--
-- Name: index_email_login_codes_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_login_codes_on_expires_at ON public.email_login_codes USING btree (expires_at);


--
-- Name: index_email_login_codes_on_lower_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_login_codes_on_lower_email ON public.email_login_codes USING btree (lower((email)::text));


--
-- Name: index_email_logs_on_bounce_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_email_logs_on_bounce_key ON public.email_logs USING btree (bounce_key) WHERE (bounce_key IS NOT NULL);


--
-- Name: index_email_logs_on_bounced; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_logs_on_bounced ON public.email_logs USING btree (bounced);


--
-- Name: index_email_logs_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_logs_on_created_at ON public.email_logs USING btree (created_at DESC);


--
-- Name: index_email_logs_on_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_logs_on_message_id ON public.email_logs USING btree (message_id);


--
-- Name: index_email_logs_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_logs_on_post_id ON public.email_logs USING btree (post_id);


--
-- Name: index_email_logs_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_logs_on_topic_id ON public.email_logs USING btree (topic_id) WHERE (topic_id IS NOT NULL);


--
-- Name: index_email_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_logs_on_user_id ON public.email_logs USING btree (user_id);


--
-- Name: index_email_tokens_on_token_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_email_tokens_on_token_hash ON public.email_tokens USING btree (token_hash);


--
-- Name: index_email_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_tokens_on_user_id ON public.email_tokens USING btree (user_id);


--
-- Name: index_embeddable_host_tags_on_embeddable_host_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_embeddable_host_tags_on_embeddable_host_id ON public.embeddable_host_tags USING btree (embeddable_host_id);


--
-- Name: index_embeddable_host_tags_on_embeddable_host_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_embeddable_host_tags_on_embeddable_host_id_and_tag_id ON public.embeddable_host_tags USING btree (embeddable_host_id, tag_id);


--
-- Name: index_embeddable_host_tags_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_embeddable_host_tags_on_tag_id ON public.embeddable_host_tags USING btree (tag_id);


--
-- Name: index_embedding_definitions_on_ai_secret_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_embedding_definitions_on_ai_secret_id ON public.embedding_definitions USING btree (ai_secret_id);


--
-- Name: index_external_upload_stubs_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_external_upload_stubs_on_created_by_id ON public.external_upload_stubs USING btree (created_by_id);


--
-- Name: index_external_upload_stubs_on_external_upload_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_external_upload_stubs_on_external_upload_identifier ON public.external_upload_stubs USING btree (external_upload_identifier);


--
-- Name: index_external_upload_stubs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_external_upload_stubs_on_key ON public.external_upload_stubs USING btree (key);


--
-- Name: index_external_upload_stubs_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_external_upload_stubs_on_status ON public.external_upload_stubs USING btree (status);


--
-- Name: index_flags_on_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flags_on_name_key ON public.flags USING btree (name_key);


--
-- Name: index_for_rebake_old; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_for_rebake_old ON public.posts USING btree (id DESC) WHERE (((baked_version IS NULL) OR (baked_version < 2)) AND (deleted_at IS NULL));


--
-- Name: index_form_templates_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_form_templates_on_name ON public.form_templates USING btree (name);


--
-- Name: index_gamification_leaderboards_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gamification_leaderboards_on_name ON public.gamification_leaderboards USING btree (name);


--
-- Name: index_gamification_score_events_on_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gamification_score_events_on_date ON public.gamification_score_events USING btree (date);


--
-- Name: index_gamification_score_events_on_user_id_and_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gamification_score_events_on_user_id_and_date ON public.gamification_score_events USING btree (user_id, date);


--
-- Name: index_gamification_scores_on_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gamification_scores_on_date ON public.gamification_scores USING btree (date);


--
-- Name: index_gamification_scores_on_user_id_and_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gamification_scores_on_user_id_and_date ON public.gamification_scores USING btree (user_id, date);


--
-- Name: index_github_commits_on_repo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_github_commits_on_repo_id ON public.github_commits USING btree (repo_id);


--
-- Name: index_github_repos_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_github_repos_on_name ON public.github_repos USING btree (name);


--
-- Name: index_given_daily_likes_on_limit_reached_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_given_daily_likes_on_limit_reached_and_user_id ON public.given_daily_likes USING btree (limit_reached, user_id);


--
-- Name: index_given_daily_likes_on_user_id_and_given_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_given_daily_likes_on_user_id_and_given_date ON public.given_daily_likes USING btree (user_id, given_date);


--
-- Name: index_group_archived_messages_on_group_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_archived_messages_on_group_id_and_topic_id ON public.group_archived_messages USING btree (group_id, topic_id);


--
-- Name: index_group_associated_groups; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_associated_groups ON public.group_associated_groups USING btree (group_id, associated_group_id);


--
-- Name: index_group_associated_groups_on_associated_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_associated_groups_on_associated_group_id ON public.group_associated_groups USING btree (associated_group_id);


--
-- Name: index_group_associated_groups_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_associated_groups_on_group_id ON public.group_associated_groups USING btree (group_id);


--
-- Name: index_group_custom_fields_on_group_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_custom_fields_on_group_id_and_name ON public.group_custom_fields USING btree (group_id, name);


--
-- Name: index_group_histories_on_acting_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_histories_on_acting_user_id ON public.group_histories USING btree (acting_user_id);


--
-- Name: index_group_histories_on_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_histories_on_action ON public.group_histories USING btree (action);


--
-- Name: index_group_histories_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_histories_on_group_id ON public.group_histories USING btree (group_id);


--
-- Name: index_group_histories_on_target_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_histories_on_target_user_id ON public.group_histories USING btree (target_user_id);


--
-- Name: index_group_mentions_on_group_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_mentions_on_group_id_and_post_id ON public.group_mentions USING btree (group_id, post_id);


--
-- Name: index_group_mentions_on_post_id_and_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_mentions_on_post_id_and_group_id ON public.group_mentions USING btree (post_id, group_id);


--
-- Name: index_group_requests_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_requests_on_group_id ON public.group_requests USING btree (group_id);


--
-- Name: index_group_requests_on_group_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_requests_on_group_id_and_user_id ON public.group_requests USING btree (group_id, user_id);


--
-- Name: index_group_requests_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_group_requests_on_user_id ON public.group_requests USING btree (user_id);


--
-- Name: index_group_users_on_group_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_users_on_group_id_and_user_id ON public.group_users USING btree (group_id, user_id);


--
-- Name: index_group_users_on_user_id_and_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_group_users_on_user_id_and_group_id ON public.group_users USING btree (user_id, group_id);


--
-- Name: index_groups_on_incoming_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_groups_on_incoming_email ON public.groups USING btree (incoming_email);


--
-- Name: index_groups_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_groups_on_name ON public.groups USING btree (name);


--
-- Name: index_groups_web_hooks_on_web_hook_id_and_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_groups_web_hooks_on_web_hook_id_and_group_id ON public.groups_web_hooks USING btree (web_hook_id, group_id);


--
-- Name: index_house_ads_categories; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_house_ads_categories ON public.ad_plugin_house_ads_categories USING btree (ad_plugin_house_ad_id, category_id);


--
-- Name: index_house_ads_groups; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_house_ads_groups ON public.ad_plugin_house_ads_groups USING btree (ad_plugin_house_ad_id, group_id);


--
-- Name: index_house_ads_pages; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_house_ads_pages ON public.ad_plugin_house_ads_routes USING btree (ad_plugin_house_ad_id, route_name);


--
-- Name: index_ignored_users_on_ignored_user_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ignored_users_on_ignored_user_id_and_user_id ON public.ignored_users USING btree (ignored_user_id, user_id);


--
-- Name: index_ignored_users_on_user_id_and_ignored_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ignored_users_on_user_id_and_ignored_user_id ON public.ignored_users USING btree (user_id, ignored_user_id);


--
-- Name: index_incoming_chat_webhooks_on_key_and_chat_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_chat_webhooks_on_key_and_chat_channel_id ON public.incoming_chat_webhooks USING btree (key, chat_channel_id);


--
-- Name: index_incoming_domains_on_name_and_https_and_port; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_incoming_domains_on_name_and_https_and_port ON public.incoming_domains USING btree (name, https, port);


--
-- Name: index_incoming_emails_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_emails_on_created_at ON public.incoming_emails USING btree (created_at);


--
-- Name: index_incoming_emails_on_error; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_emails_on_error ON public.incoming_emails USING btree (error);


--
-- Name: index_incoming_emails_on_imap_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_emails_on_imap_group_id ON public.incoming_emails USING btree (imap_group_id);


--
-- Name: index_incoming_emails_on_imap_sync; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_emails_on_imap_sync ON public.incoming_emails USING btree (imap_sync);


--
-- Name: index_incoming_emails_on_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_emails_on_message_id ON public.incoming_emails USING btree (message_id);


--
-- Name: index_incoming_emails_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_emails_on_post_id ON public.incoming_emails USING btree (post_id);


--
-- Name: index_incoming_emails_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_emails_on_topic_id ON public.incoming_emails USING btree (topic_id);


--
-- Name: index_incoming_emails_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_emails_on_user_id ON public.incoming_emails USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: index_incoming_links_on_created_at_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_links_on_created_at_and_user_id ON public.incoming_links USING btree (created_at, user_id);


--
-- Name: index_incoming_links_on_current_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_links_on_current_user_id ON public.incoming_links USING btree (current_user_id) WHERE (current_user_id IS NOT NULL);


--
-- Name: index_incoming_links_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_links_on_post_id ON public.incoming_links USING btree (post_id);


--
-- Name: index_incoming_links_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_incoming_links_on_user_id ON public.incoming_links USING btree (user_id) WHERE (user_id IS NOT NULL);


--
-- Name: index_incoming_referers_on_path_and_incoming_domain_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_incoming_referers_on_path_and_incoming_domain_id ON public.incoming_referers USING btree (path, incoming_domain_id);


--
-- Name: index_inferred_concept_posts_on_inferred_concept_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inferred_concept_posts_on_inferred_concept_id ON public.inferred_concept_posts USING btree (inferred_concept_id);


--
-- Name: index_inferred_concept_posts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inferred_concept_posts_uniqueness ON public.inferred_concept_posts USING btree (post_id, inferred_concept_id);


--
-- Name: index_inferred_concept_topics_on_inferred_concept_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inferred_concept_topics_on_inferred_concept_id ON public.inferred_concept_topics USING btree (inferred_concept_id);


--
-- Name: index_inferred_concept_topics_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inferred_concept_topics_uniqueness ON public.inferred_concept_topics USING btree (topic_id, inferred_concept_id);


--
-- Name: index_inferred_concepts_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_inferred_concepts_on_name ON public.inferred_concepts USING btree (name);


--
-- Name: index_invited_groups_on_group_id_and_invite_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invited_groups_on_group_id_and_invite_id ON public.invited_groups USING btree (group_id, invite_id);


--
-- Name: index_invited_users_on_invite_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invited_users_on_invite_id ON public.invited_users USING btree (invite_id);


--
-- Name: index_invited_users_on_user_id_and_invite_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invited_users_on_user_id_and_invite_id ON public.invited_users USING btree (user_id, invite_id) WHERE (user_id IS NOT NULL);


--
-- Name: index_invites_on_email_and_invited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invites_on_email_and_invited_by_id ON public.invites USING btree (email, invited_by_id);


--
-- Name: index_invites_on_emailed_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invites_on_emailed_status ON public.invites USING btree (emailed_status);


--
-- Name: index_invites_on_invite_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invites_on_invite_key ON public.invites USING btree (invite_key);


--
-- Name: index_invites_on_invited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invites_on_invited_by_id ON public.invites USING btree (invited_by_id);


--
-- Name: index_javascript_caches_on_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_javascript_caches_on_digest ON public.javascript_caches USING btree (digest);


--
-- Name: index_javascript_caches_on_theme_field_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_javascript_caches_on_theme_field_id_and_name ON public.javascript_caches USING btree (theme_field_id, name) NULLS NOT DISTINCT WHERE (theme_field_id IS NOT NULL);


--
-- Name: index_javascript_caches_on_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_javascript_caches_on_theme_id ON public.javascript_caches USING btree (theme_id);


--
-- Name: index_linked_topics_on_topic_id_and_original_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_linked_topics_on_topic_id_and_original_topic_id ON public.linked_topics USING btree (topic_id, original_topic_id);


--
-- Name: index_linked_topics_on_topic_id_and_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_linked_topics_on_topic_id_and_sequence ON public.linked_topics USING btree (topic_id, sequence);


--
-- Name: index_llm_credit_allocations_on_llm_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_llm_credit_allocations_on_llm_model_id ON public.llm_credit_allocations USING btree (llm_model_id);


--
-- Name: index_llm_credit_daily_usages_on_llm_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_llm_credit_daily_usages_on_llm_model_id ON public.llm_credit_daily_usages USING btree (llm_model_id);


--
-- Name: index_llm_credit_daily_usages_on_llm_model_id_and_usage_date; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_llm_credit_daily_usages_on_llm_model_id_and_usage_date ON public.llm_credit_daily_usages USING btree (llm_model_id, usage_date);


--
-- Name: index_llm_feature_credit_costs_on_llm_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_llm_feature_credit_costs_on_llm_model_id ON public.llm_feature_credit_costs USING btree (llm_model_id);


--
-- Name: index_llm_models_on_ai_secret_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_llm_models_on_ai_secret_id ON public.llm_models USING btree (ai_secret_id);


--
-- Name: index_llm_quota_usages_on_llm_quota_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_llm_quota_usages_on_llm_quota_id ON public.llm_quota_usages USING btree (llm_quota_id);


--
-- Name: index_llm_quota_usages_on_user_id_and_llm_quota_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_llm_quota_usages_on_user_id_and_llm_quota_id ON public.llm_quota_usages USING btree (user_id, llm_quota_id);


--
-- Name: index_llm_quotas_on_group_id_and_llm_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_llm_quotas_on_group_id_and_llm_model_id ON public.llm_quotas USING btree (group_id, llm_model_id);


--
-- Name: index_llm_quotas_on_llm_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_llm_quotas_on_llm_model_id ON public.llm_quotas USING btree (llm_model_id);


--
-- Name: index_message_bus_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_message_bus_on_created_at ON public.message_bus USING btree (created_at);


--
-- Name: index_model_accuracies_on_model; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_model_accuracies_on_model ON public.model_accuracies USING btree (model);


--
-- Name: index_moved_posts_on_new_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moved_posts_on_new_post_id ON public.moved_posts USING btree (new_post_id);


--
-- Name: index_moved_posts_on_new_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moved_posts_on_new_topic_id ON public.moved_posts USING btree (new_topic_id);


--
-- Name: index_moved_posts_on_new_topic_id_and_post_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moved_posts_on_new_topic_id_and_post_user_id ON public.moved_posts USING btree (new_topic_id, post_user_id);


--
-- Name: index_moved_posts_on_old_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moved_posts_on_old_post_id ON public.moved_posts USING btree (old_post_id);


--
-- Name: index_moved_posts_on_old_post_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moved_posts_on_old_post_number ON public.moved_posts USING btree (old_post_number);


--
-- Name: index_moved_posts_on_old_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moved_posts_on_old_topic_id ON public.moved_posts USING btree (old_topic_id);


--
-- Name: index_muted_users_on_muted_user_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_muted_users_on_muted_user_id_and_user_id ON public.muted_users USING btree (muted_user_id, user_id);


--
-- Name: index_muted_users_on_user_id_and_muted_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_muted_users_on_user_id_and_muted_user_id ON public.muted_users USING btree (user_id, muted_user_id);


--
-- Name: index_nested_topics_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_nested_topics_on_topic_id ON public.nested_topics USING btree (topic_id);


--
-- Name: index_nested_view_post_stats_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_nested_view_post_stats_on_post_id ON public.nested_view_post_stats USING btree (post_id);


--
-- Name: index_notifications_on_data_display_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_data_display_username ON public.notifications USING btree ((((data)::jsonb ->> 'display_username'::text))) WHERE (((data)::jsonb ->> 'display_username'::text) IS NOT NULL);


--
-- Name: index_notifications_on_data_original_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_data_original_username ON public.notifications USING btree ((((data)::jsonb ->> 'original_username'::text))) WHERE (((data)::jsonb ->> 'original_username'::text) IS NOT NULL);


--
-- Name: index_notifications_on_data_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_data_username ON public.notifications USING btree ((((data)::jsonb ->> 'username'::text))) WHERE (((data)::jsonb ->> 'username'::text) IS NOT NULL);


--
-- Name: index_notifications_on_data_username2; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_data_username2 ON public.notifications USING btree ((((data)::jsonb ->> 'username2'::text))) WHERE (((data)::jsonb ->> 'username2'::text) IS NOT NULL);


--
-- Name: index_notifications_on_post_action_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_post_action_id ON public.notifications USING btree (post_action_id);


--
-- Name: index_notifications_on_topic_id_and_post_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_topic_id_and_post_number ON public.notifications USING btree (topic_id, post_number);


--
-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id_and_created_at ON public.notifications USING btree (user_id, created_at);


--
-- Name: index_notifications_on_user_id_and_topic_id_and_post_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id_and_topic_id_and_post_number ON public.notifications USING btree (user_id, topic_id, post_number);


--
-- Name: index_notifications_read_or_not_high_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_read_or_not_high_priority ON public.notifications USING btree (user_id, id DESC, read, topic_id) WHERE (read OR (high_priority = false));


--
-- Name: index_notifications_unique_unread_high_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notifications_unique_unread_high_priority ON public.notifications USING btree (user_id, id) WHERE ((NOT read) AND (high_priority = true));


--
-- Name: index_notifications_user_menu_ordering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_user_menu_ordering ON public.notifications USING btree (user_id, ((high_priority AND (NOT read))) DESC, ((NOT read)) DESC, created_at DESC);


--
-- Name: index_notifications_user_menu_ordering_deprioritized_likes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_user_menu_ordering_deprioritized_likes ON public.notifications USING btree (user_id, ((high_priority AND (NOT read))) DESC, (((NOT read) AND (notification_type <> ALL (ARRAY[5, 19, 25])))) DESC, created_at DESC);


--
-- Name: index_oauth2_user_infos_on_uid_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth2_user_infos_on_uid_and_provider ON public.oauth2_user_infos USING btree (uid, provider);


--
-- Name: index_oauth2_user_infos_on_user_id_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth2_user_infos_on_user_id_and_provider ON public.oauth2_user_infos USING btree (user_id, provider);


--
-- Name: index_onceoff_logs_on_job_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_onceoff_logs_on_job_name ON public.onceoff_logs USING btree (job_name);


--
-- Name: index_optimized_images_on_etag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_optimized_images_on_etag ON public.optimized_images USING btree (etag);


--
-- Name: index_optimized_images_on_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_optimized_images_on_upload_id ON public.optimized_images USING btree (upload_id);


--
-- Name: index_optimized_images_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_optimized_images_unique ON public.optimized_images USING btree (upload_id, width, height, extension);


--
-- Name: index_optimized_videos_on_optimized_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_optimized_videos_on_optimized_upload_id ON public.optimized_videos USING btree (optimized_upload_id);


--
-- Name: index_optimized_videos_on_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_optimized_videos_on_upload_id ON public.optimized_videos USING btree (upload_id);


--
-- Name: index_optimized_videos_on_upload_id_and_adapter; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_optimized_videos_on_upload_id_and_adapter ON public.optimized_videos USING btree (upload_id, adapter);


--
-- Name: index_permalinks_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_permalinks_on_url ON public.permalinks USING btree (url);


--
-- Name: index_plugin_store_rows_on_plugin_name_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_plugin_store_rows_on_plugin_name_and_key ON public.plugin_store_rows USING btree (plugin_name, key);


--
-- Name: index_policy_users_on_post_policy_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_policy_users_on_post_policy_id_and_user_id ON public.policy_users USING btree (post_policy_id, user_id);


--
-- Name: index_poll_options_on_poll_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_poll_options_on_poll_id ON public.poll_options USING btree (poll_id);


--
-- Name: index_poll_options_on_poll_id_and_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_poll_options_on_poll_id_and_digest ON public.poll_options USING btree (poll_id, digest);


--
-- Name: index_poll_votes_on_poll_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_poll_votes_on_poll_id ON public.poll_votes USING btree (poll_id);


--
-- Name: index_poll_votes_on_poll_id_and_poll_option_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_poll_votes_on_poll_id_and_poll_option_id_and_user_id ON public.poll_votes USING btree (poll_id, poll_option_id, user_id);


--
-- Name: index_poll_votes_on_poll_option_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_poll_votes_on_poll_option_id ON public.poll_votes USING btree (poll_option_id);


--
-- Name: index_poll_votes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_poll_votes_on_user_id ON public.poll_votes USING btree (user_id);


--
-- Name: index_polls_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_polls_on_post_id ON public.polls USING btree (post_id);


--
-- Name: index_polls_on_post_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_polls_on_post_id_and_name ON public.polls USING btree (post_id, name);


--
-- Name: index_post_actions_on_agreed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_agreed_by_id ON public.post_actions USING btree (agreed_by_id) WHERE (agreed_by_id IS NOT NULL);


--
-- Name: index_post_actions_on_deferred_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_deferred_by_id ON public.post_actions USING btree (deferred_by_id) WHERE (deferred_by_id IS NOT NULL);


--
-- Name: index_post_actions_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_deleted_by_id ON public.post_actions USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_post_actions_on_disagreed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_disagreed_by_id ON public.post_actions USING btree (disagreed_by_id) WHERE (disagreed_by_id IS NOT NULL);


--
-- Name: index_post_actions_on_post_action_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_post_action_type_id ON public.post_actions USING btree (post_action_type_id);


--
-- Name: index_post_actions_on_post_action_type_id_and_disagreed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_post_action_type_id_and_disagreed_at ON public.post_actions USING btree (post_action_type_id, disagreed_at) WHERE (disagreed_at IS NULL);


--
-- Name: index_post_actions_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_post_id ON public.post_actions USING btree (post_id);


--
-- Name: index_post_actions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_user_id ON public.post_actions USING btree (user_id);


--
-- Name: index_post_actions_on_user_id_and_post_action_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_actions_on_user_id_and_post_action_type_id ON public.post_actions USING btree (user_id, post_action_type_id) WHERE (deleted_at IS NULL);


--
-- Name: index_post_custom_fields_on_name_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_custom_fields_on_name_and_value ON public.post_custom_fields USING btree (name, "left"(value, 200));


--
-- Name: index_post_custom_fields_on_notice; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_custom_fields_on_notice ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'notice'::text);


--
-- Name: index_post_custom_fields_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_custom_fields_on_post_id ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'missing uploads'::text);


--
-- Name: index_post_custom_fields_on_post_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_custom_fields_on_post_id_and_name ON public.post_custom_fields USING btree (post_id, name);


--
-- Name: index_post_custom_fields_on_stalled_wiki_triggered_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_custom_fields_on_stalled_wiki_triggered_at ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'stalled_wiki_triggered_at'::text);


--
-- Name: index_post_custom_prompts_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_custom_prompts_on_post_id ON public.post_custom_prompts USING btree (post_id);


--
-- Name: index_post_details_on_post_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_details_on_post_id_and_key ON public.post_details USING btree (post_id, key);


--
-- Name: index_post_hotlinked_media_on_post_id_and_url_md5; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_hotlinked_media_on_post_id_and_url_md5 ON public.post_hotlinked_media USING btree (post_id, md5((url)::text));


--
-- Name: index_post_id_where_missing_uploads_ignored; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_id_where_missing_uploads_ignored ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'missing uploads ignored'::text);


--
-- Name: index_post_localizations_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_localizations_on_post_id ON public.post_localizations USING btree (post_id);


--
-- Name: index_post_localizations_on_post_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_localizations_on_post_id_and_locale ON public.post_localizations USING btree (post_id, locale);


--
-- Name: index_post_policy_groups_on_post_policy_id_and_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_policy_groups_on_post_policy_id_and_group_id ON public.post_policy_groups USING btree (post_policy_id, group_id);


--
-- Name: index_post_replies_on_post_id_and_reply_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_replies_on_post_id_and_reply_post_id ON public.post_replies USING btree (post_id, reply_post_id);


--
-- Name: index_post_replies_on_reply_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_replies_on_reply_post_id ON public.post_replies USING btree (reply_post_id);


--
-- Name: index_post_reply_keys_on_reply_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_reply_keys_on_reply_key ON public.post_reply_keys USING btree (reply_key);


--
-- Name: index_post_reply_keys_on_user_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_post_reply_keys_on_user_id_and_post_id ON public.post_reply_keys USING btree (user_id, post_id);


--
-- Name: index_post_revisions_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_revisions_on_post_id ON public.post_revisions USING btree (post_id);


--
-- Name: index_post_revisions_on_post_id_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_revisions_on_post_id_and_number ON public.post_revisions USING btree (post_id, number);


--
-- Name: index_post_revisions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_revisions_on_user_id ON public.post_revisions USING btree (user_id);


--
-- Name: index_post_search_data_on_post_id_and_version_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_search_data_on_post_id_and_version_and_locale ON public.post_search_data USING btree (post_id, version, locale);


--
-- Name: index_post_stats_on_composer_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_stats_on_composer_version ON public.post_stats USING btree (composer_version);


--
-- Name: index_post_stats_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_stats_on_post_id ON public.post_stats USING btree (post_id);


--
-- Name: index_post_stats_on_writing_device; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_stats_on_writing_device ON public.post_stats USING btree (writing_device);


--
-- Name: index_post_timings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_timings_on_user_id ON public.post_timings USING btree (user_id);


--
-- Name: index_post_voting_comments_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_voting_comments_on_deleted_by_id ON public.post_voting_comments USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_post_voting_comments_on_last_editor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_voting_comments_on_last_editor_id ON public.post_voting_comments USING btree (last_editor_id);


--
-- Name: index_post_voting_comments_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_voting_comments_on_post_id ON public.post_voting_comments USING btree (post_id);


--
-- Name: index_post_voting_comments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_post_voting_comments_on_user_id ON public.post_voting_comments USING btree (user_id);


--
-- Name: index_posts_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_deleted_by_id ON public.posts USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_posts_on_id_and_baked_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_id_and_baked_version ON public.posts USING btree (id DESC, baked_version) WHERE (deleted_at IS NULL);


--
-- Name: index_posts_on_id_topic_id_where_not_deleted_or_empty; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_id_topic_id_where_not_deleted_or_empty ON public.posts USING btree (id, topic_id) WHERE ((deleted_at IS NULL) AND (raw <> ''::text));


--
-- Name: index_posts_on_image_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_image_upload_id ON public.posts USING btree (image_upload_id);


--
-- Name: index_posts_on_last_editor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_last_editor_id ON public.posts USING btree (last_editor_id) WHERE (last_editor_id IS NOT NULL);


--
-- Name: index_posts_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_locale ON public.posts USING btree (locale);


--
-- Name: index_posts_on_locked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_locked_by_id ON public.posts USING btree (locked_by_id) WHERE (locked_by_id IS NOT NULL);


--
-- Name: index_posts_on_reply_to_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_reply_to_user_id ON public.posts USING btree (reply_to_user_id) WHERE (reply_to_user_id IS NOT NULL);


--
-- Name: index_posts_on_topic_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_topic_id_and_created_at ON public.posts USING btree (topic_id, created_at);


--
-- Name: index_posts_on_topic_id_and_percent_rank; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_topic_id_and_percent_rank ON public.posts USING btree (topic_id, percent_rank);


--
-- Name: index_posts_on_topic_id_and_post_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_topic_id_and_post_number ON public.posts USING btree (topic_id, post_number);


--
-- Name: index_posts_on_topic_id_and_reply_to_post_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_topic_id_and_reply_to_post_number ON public.posts USING btree (topic_id, reply_to_post_number);


--
-- Name: index_posts_on_topic_id_and_sort_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_topic_id_and_sort_order ON public.posts USING btree (topic_id, sort_order);


--
-- Name: index_posts_on_updated_at_for_locale_detection; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_updated_at_for_locale_detection ON public.posts USING btree (updated_at DESC) WHERE ((deleted_at IS NULL) AND (user_id > 0) AND (locale IS NULL));


--
-- Name: index_posts_on_updated_at_for_localization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_updated_at_for_localization ON public.posts USING btree (updated_at DESC) WHERE ((deleted_at IS NULL) AND (user_id > 0) AND (locale IS NOT NULL));


--
-- Name: index_posts_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_user_id_and_created_at ON public.posts USING btree (user_id, created_at);


--
-- Name: index_posts_user_and_likes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_user_and_likes ON public.posts USING btree (user_id, like_count DESC, created_at DESC) WHERE (post_number > 1);


--
-- Name: index_problem_check_trackers_on_identifier_and_target; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_problem_check_trackers_on_identifier_and_target ON public.problem_check_trackers USING btree (identifier, target);


--
-- Name: index_published_pages_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_published_pages_on_slug ON public.published_pages USING btree (slug);


--
-- Name: index_published_pages_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_published_pages_on_topic_id ON public.published_pages USING btree (topic_id);


--
-- Name: index_quoted_posts_on_post_id_and_quoted_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quoted_posts_on_post_id_and_quoted_post_id ON public.quoted_posts USING btree (post_id, quoted_post_id);


--
-- Name: index_quoted_posts_on_quoted_post_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_quoted_posts_on_quoted_post_id_and_post_id ON public.quoted_posts USING btree (quoted_post_id, post_id);


--
-- Name: index_rag_document_fragments_on_target_type_and_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rag_document_fragments_on_target_type_and_target_id ON public.rag_document_fragments USING btree (target_type, target_id);


--
-- Name: index_redelivering_webhook_events_on_web_hook_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_redelivering_webhook_events_on_web_hook_event_id ON public.redelivering_webhook_events USING btree (web_hook_event_id);


--
-- Name: index_reviewable_claimed_topics_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reviewable_claimed_topics_on_topic_id ON public.reviewable_claimed_topics USING btree (topic_id);


--
-- Name: index_reviewable_histories_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewable_histories_on_created_by_id ON public.reviewable_histories USING btree (created_by_id);


--
-- Name: index_reviewable_histories_on_reviewable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewable_histories_on_reviewable_id ON public.reviewable_histories USING btree (reviewable_id);


--
-- Name: index_reviewable_notes_on_reviewable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewable_notes_on_reviewable_id ON public.reviewable_notes USING btree (reviewable_id);


--
-- Name: index_reviewable_notes_on_reviewable_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewable_notes_on_reviewable_id_and_created_at ON public.reviewable_notes USING btree (reviewable_id, created_at);


--
-- Name: index_reviewable_notes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewable_notes_on_user_id ON public.reviewable_notes USING btree (user_id);


--
-- Name: index_reviewable_scores_on_reviewable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewable_scores_on_reviewable_id ON public.reviewable_scores USING btree (reviewable_id);


--
-- Name: index_reviewable_scores_on_reviewable_score_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewable_scores_on_reviewable_score_type ON public.reviewable_scores USING btree (reviewable_score_type);


--
-- Name: index_reviewable_scores_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewable_scores_on_user_id ON public.reviewable_scores USING btree (user_id);


--
-- Name: index_reviewables_on_reviewable_by_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewables_on_reviewable_by_group_id ON public.reviewables USING btree (reviewable_by_group_id);


--
-- Name: index_reviewables_on_status_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewables_on_status_and_created_at ON public.reviewables USING btree (status, created_at);


--
-- Name: index_reviewables_on_status_and_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewables_on_status_and_score ON public.reviewables USING btree (status, score);


--
-- Name: index_reviewables_on_status_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewables_on_status_and_type ON public.reviewables USING btree (status, type);


--
-- Name: index_reviewables_on_target_id_where_post_type_eq_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewables_on_target_id_where_post_type_eq_post ON public.reviewables USING btree (target_id) WHERE ((target_type)::text = 'Post'::text);


--
-- Name: index_reviewables_on_topic_id_and_status_and_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reviewables_on_topic_id_and_status_and_created_by_id ON public.reviewables USING btree (topic_id, status, created_by_id);


--
-- Name: index_reviewables_on_type_and_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reviewables_on_type_and_target_id ON public.reviewables USING btree (type, target_id);


--
-- Name: index_schema_migration_details_on_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schema_migration_details_on_version ON public.schema_migration_details USING btree (version);


--
-- Name: index_screened_emails_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_screened_emails_on_email ON public.screened_emails USING btree (email);


--
-- Name: index_screened_emails_on_last_match_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_screened_emails_on_last_match_at ON public.screened_emails USING btree (last_match_at);


--
-- Name: index_screened_ip_addresses_on_ip_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_screened_ip_addresses_on_ip_address ON public.screened_ip_addresses USING btree (ip_address);


--
-- Name: index_screened_ip_addresses_on_last_match_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_screened_ip_addresses_on_last_match_at ON public.screened_ip_addresses USING btree (last_match_at);


--
-- Name: index_screened_urls_on_last_match_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_screened_urls_on_last_match_at ON public.screened_urls USING btree (last_match_at);


--
-- Name: index_screened_urls_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_screened_urls_on_url ON public.screened_urls USING btree (url);


--
-- Name: index_search_logs_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_logs_on_created_at ON public.search_logs USING btree (created_at);


--
-- Name: index_search_logs_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_search_logs_on_user_id_and_created_at ON public.search_logs USING btree (user_id, created_at) WHERE (user_id IS NOT NULL);


--
-- Name: index_shared_ai_conversations_on_share_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shared_ai_conversations_on_share_key ON public.shared_ai_conversations USING btree (share_key);


--
-- Name: index_shared_ai_conversations_on_target_id_and_target_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shared_ai_conversations_on_target_id_and_target_type ON public.shared_ai_conversations USING btree (target_id, target_type);


--
-- Name: index_shared_drafts_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shared_drafts_on_category_id ON public.shared_drafts USING btree (category_id);


--
-- Name: index_shared_drafts_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shared_drafts_on_topic_id ON public.shared_drafts USING btree (topic_id);


--
-- Name: index_shelved_notifications_on_notification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shelved_notifications_on_notification_id ON public.shelved_notifications USING btree (notification_id);


--
-- Name: index_sidebar_section_links_on_linkable_type_and_linkable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sidebar_section_links_on_linkable_type_and_linkable_id ON public.sidebar_section_links USING btree (linkable_type, linkable_id);


--
-- Name: index_sidebar_sections_on_section_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sidebar_sections_on_section_type ON public.sidebar_sections USING btree (section_type);


--
-- Name: index_sidebar_sections_on_user_id_and_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sidebar_sections_on_user_id_and_title ON public.sidebar_sections USING btree (user_id, title);


--
-- Name: index_silenced_assignments_on_assignment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_silenced_assignments_on_assignment_id ON public.silenced_assignments USING btree (assignment_id);


--
-- Name: index_single_sign_on_records_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_single_sign_on_records_on_external_id ON public.single_sign_on_records USING btree (external_id);


--
-- Name: index_single_sign_on_records_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_single_sign_on_records_on_user_id ON public.single_sign_on_records USING btree (user_id);


--
-- Name: index_site_setting_groups_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_site_setting_groups_on_name ON public.site_setting_groups USING btree (name);


--
-- Name: index_site_setting_localizations_on_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_site_setting_localizations_on_locale ON public.site_setting_localizations USING btree (locale);


--
-- Name: index_site_setting_localizations_on_setting_name_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_site_setting_localizations_on_setting_name_and_locale ON public.site_setting_localizations USING btree (setting_name, locale);


--
-- Name: index_site_settings_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_site_settings_on_name ON public.site_settings USING btree (name);


--
-- Name: index_sitemaps_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sitemaps_on_name ON public.sitemaps USING btree (name);


--
-- Name: index_skipped_email_logs_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_skipped_email_logs_on_created_at ON public.skipped_email_logs USING btree (created_at);


--
-- Name: index_skipped_email_logs_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_skipped_email_logs_on_post_id ON public.skipped_email_logs USING btree (post_id);


--
-- Name: index_skipped_email_logs_on_reason_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_skipped_email_logs_on_reason_type ON public.skipped_email_logs USING btree (reason_type);


--
-- Name: index_skipped_email_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_skipped_email_logs_on_user_id ON public.skipped_email_logs USING btree (user_id);


--
-- Name: index_stylesheet_cache_on_target_and_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stylesheet_cache_on_target_and_digest ON public.stylesheet_cache USING btree (target, digest);


--
-- Name: index_tag_group_memberships_on_tag_group_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_group_memberships_on_tag_group_id_and_tag_id ON public.tag_group_memberships USING btree (tag_group_id, tag_id);


--
-- Name: index_tag_group_permissions_on_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_group_permissions_on_group_id ON public.tag_group_permissions USING btree (group_id);


--
-- Name: index_tag_group_permissions_on_tag_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_group_permissions_on_tag_group_id ON public.tag_group_permissions USING btree (tag_group_id);


--
-- Name: index_tag_groups_on_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_groups_on_lower_name ON public.tag_groups USING btree (lower((name)::text));


--
-- Name: index_tag_localizations_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_localizations_on_tag_id ON public.tag_localizations USING btree (tag_id);


--
-- Name: index_tag_localizations_on_tag_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_localizations_on_tag_id_and_locale ON public.tag_localizations USING btree (tag_id, locale);


--
-- Name: index_tag_users_on_tag_id_and_user_id_and_notification_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_users_on_tag_id_and_user_id_and_notification_level ON public.tag_users USING btree (tag_id, user_id, notification_level);


--
-- Name: index_tag_users_on_user_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tag_users_on_user_id_and_tag_id ON public.tag_users USING btree (user_id, tag_id);


--
-- Name: index_tag_users_on_user_id_and_tag_id_and_notification_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_users_on_user_id_and_tag_id_and_notification_level ON public.tag_users USING btree (user_id, tag_id, notification_level);


--
-- Name: index_tags_on_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_lower_name ON public.tags USING btree (lower((name)::text));


--
-- Name: index_tags_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_name ON public.tags USING btree (name);


--
-- Name: index_tags_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_slug ON public.tags USING btree (slug) WHERE ((slug)::text <> ''::text);


--
-- Name: index_tags_on_target_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_target_tag_id ON public.tags USING btree (target_tag_id) WHERE (target_tag_id IS NOT NULL);


--
-- Name: index_theme_modifier_sets_on_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_theme_modifier_sets_on_theme_id ON public.theme_modifier_sets USING btree (theme_id);


--
-- Name: index_theme_settings_migrations_on_theme_field_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_theme_settings_migrations_on_theme_field_id ON public.theme_settings_migrations USING btree (theme_field_id);


--
-- Name: index_theme_settings_migrations_on_theme_id_and_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_theme_settings_migrations_on_theme_id_and_version ON public.theme_settings_migrations USING btree (theme_id, version);


--
-- Name: index_theme_site_settings_on_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_theme_site_settings_on_theme_id ON public.theme_site_settings USING btree (theme_id);


--
-- Name: index_theme_site_settings_on_theme_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_theme_site_settings_on_theme_id_and_name ON public.theme_site_settings USING btree (theme_id, name);


--
-- Name: index_theme_svg_sprites_on_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_theme_svg_sprites_on_theme_id ON public.theme_svg_sprites USING btree (theme_id);


--
-- Name: index_theme_translation_overrides_on_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_theme_translation_overrides_on_theme_id ON public.theme_translation_overrides USING btree (theme_id);


--
-- Name: index_themes_on_remote_theme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_themes_on_remote_theme_id ON public.themes USING btree (remote_theme_id);


--
-- Name: index_top_topics_on_all_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_top_topics_on_all_score ON public.top_topics USING btree (all_score);


--
-- Name: index_top_topics_on_daily_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_top_topics_on_daily_score ON public.top_topics USING btree (daily_score);


--
-- Name: index_top_topics_on_monthly_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_top_topics_on_monthly_score ON public.top_topics USING btree (monthly_score);


--
-- Name: index_top_topics_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_top_topics_on_topic_id ON public.top_topics USING btree (topic_id);


--
-- Name: index_top_topics_on_weekly_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_top_topics_on_weekly_score ON public.top_topics USING btree (weekly_score);


--
-- Name: index_top_topics_on_yearly_score; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_top_topics_on_yearly_score ON public.top_topics USING btree (yearly_score);


--
-- Name: index_topic_allowed_groups_on_group_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_allowed_groups_on_group_id_and_topic_id ON public.topic_allowed_groups USING btree (group_id, topic_id);


--
-- Name: index_topic_allowed_groups_on_topic_id_and_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_allowed_groups_on_topic_id_and_group_id ON public.topic_allowed_groups USING btree (topic_id, group_id);


--
-- Name: index_topic_allowed_users_on_topic_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_topic_id_and_user_id ON public.topic_allowed_users USING btree (topic_id, user_id);


--
-- Name: index_topic_allowed_users_on_user_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_allowed_users_on_user_id_and_topic_id ON public.topic_allowed_users USING btree (user_id, topic_id);


--
-- Name: index_topic_custom_fields_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_custom_fields_on_topic_id ON public.topic_custom_fields USING btree (topic_id) WHERE ((name)::text = 'vote_count'::text);


--
-- Name: index_topic_custom_fields_on_topic_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_custom_fields_on_topic_id_and_name ON public.topic_custom_fields USING btree (topic_id, name);


--
-- Name: index_topic_custom_fields_on_topic_id_and_slack_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_custom_fields_on_topic_id_and_slack_thread_id ON public.topic_custom_fields USING btree (topic_id, name) WHERE ((name)::text ~~ 'slack_thread_id_%'::text);


--
-- Name: index_topic_embeds_on_embed_url; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_embeds_on_embed_url ON public.topic_embeds USING btree (embed_url);


--
-- Name: index_topic_groups_on_group_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_groups_on_group_id_and_topic_id ON public.topic_groups USING btree (group_id, topic_id);


--
-- Name: index_topic_hot_scores_on_score_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_hot_scores_on_score_and_topic_id ON public.topic_hot_scores USING btree (score, topic_id);


--
-- Name: index_topic_hot_scores_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_hot_scores_on_topic_id ON public.topic_hot_scores USING btree (topic_id);


--
-- Name: index_topic_invites_on_invite_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_invites_on_invite_id ON public.topic_invites USING btree (invite_id);


--
-- Name: index_topic_invites_on_topic_id_and_invite_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_invites_on_topic_id_and_invite_id ON public.topic_invites USING btree (topic_id, invite_id);


--
-- Name: index_topic_links_on_extension; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_links_on_extension ON public.topic_links USING btree (extension);


--
-- Name: index_topic_links_on_link_post_id_and_reflection; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_links_on_link_post_id_and_reflection ON public.topic_links USING btree (link_post_id, reflection);


--
-- Name: index_topic_links_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_links_on_post_id ON public.topic_links USING btree (post_id);


--
-- Name: index_topic_links_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_links_on_topic_id ON public.topic_links USING btree (topic_id);


--
-- Name: index_topic_links_on_user_and_clicks; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_links_on_user_and_clicks ON public.topic_links USING btree (user_id, clicks DESC, created_at DESC) WHERE ((NOT reflection) AND (NOT quote) AND (NOT internal));


--
-- Name: index_topic_links_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_links_on_user_id ON public.topic_links USING btree (user_id);


--
-- Name: index_topic_localizations_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_localizations_on_topic_id ON public.topic_localizations USING btree (topic_id);


--
-- Name: index_topic_localizations_on_topic_id_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_localizations_on_topic_id_and_locale ON public.topic_localizations USING btree (topic_id, locale);


--
-- Name: index_topic_search_data_on_topic_id_and_version_and_locale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_search_data_on_topic_id_and_version_and_locale ON public.topic_search_data USING btree (topic_id, version, locale);


--
-- Name: index_topic_tags_on_tag_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_tags_on_tag_id_and_topic_id ON public.topic_tags USING btree (tag_id, topic_id);


--
-- Name: index_topic_tags_on_topic_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_tags_on_topic_id_and_tag_id ON public.topic_tags USING btree (topic_id, tag_id);


--
-- Name: index_topic_thumbnails_on_optimized_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_thumbnails_on_optimized_image_id ON public.topic_thumbnails USING btree (optimized_image_id);


--
-- Name: index_topic_thumbnails_on_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_thumbnails_on_upload_id ON public.topic_thumbnails USING btree (upload_id);


--
-- Name: index_topic_timers_on_timerable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_timers_on_timerable_id ON public.topic_timers USING btree (timerable_id) WHERE (deleted_at IS NULL);


--
-- Name: index_topic_timers_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_timers_on_topic_id ON public.topic_timers USING btree (topic_id) WHERE (deleted_at IS NULL);


--
-- Name: index_topic_timers_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_timers_on_user_id ON public.topic_timers USING btree (user_id);


--
-- Name: index_topic_users_on_topic_id_and_notification_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_users_on_topic_id_and_notification_level ON public.topic_users USING btree (topic_id, notification_level);


--
-- Name: index_topic_users_on_topic_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_users_on_topic_id_and_user_id ON public.topic_users USING btree (topic_id, user_id);


--
-- Name: index_topic_users_on_user_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_users_on_user_id_and_topic_id ON public.topic_users USING btree (user_id, topic_id);


--
-- Name: index_topic_view_stats_on_topic_id_and_viewed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_view_stats_on_topic_id_and_viewed_at ON public.topic_view_stats USING btree (topic_id, viewed_at);


--
-- Name: index_topic_view_stats_on_viewed_at_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_view_stats_on_viewed_at_and_topic_id ON public.topic_view_stats USING btree (viewed_at, topic_id);


--
-- Name: index_topic_views_on_topic_id_and_viewed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_views_on_topic_id_and_viewed_at ON public.topic_views USING btree (topic_id, viewed_at);


--
-- Name: index_topic_views_on_user_id_and_viewed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_views_on_user_id_and_viewed_at ON public.topic_views USING btree (user_id, viewed_at);


--
-- Name: index_topic_views_on_viewed_at_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_views_on_viewed_at_and_topic_id ON public.topic_views USING btree (viewed_at, topic_id);


--
-- Name: index_topic_voting_topic_vote_count_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_voting_topic_vote_count_on_topic_id ON public.topic_voting_topic_vote_count USING btree (topic_id);


--
-- Name: index_topic_voting_topic_vote_count_on_votes_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_voting_topic_vote_count_on_votes_count ON public.topic_voting_topic_vote_count USING btree (votes_count);


--
-- Name: index_topic_voting_votes_on_topic_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_voting_votes_on_topic_id_and_created_at ON public.topic_voting_votes USING btree (topic_id, created_at);


--
-- Name: index_topics_on_bannered_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_bannered_until ON public.topics USING btree (bannered_until) WHERE (bannered_until IS NOT NULL);


--
-- Name: index_topics_on_bumped_at_public; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_bumped_at_public ON public.topics USING btree (bumped_at) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text));


--
-- Name: index_topics_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_category_id ON public.topics USING btree (category_id) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text));


--
-- Name: index_topics_on_created_at_and_visible; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_created_at_and_visible ON public.topics USING btree (created_at, visible) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text));


--
-- Name: index_topics_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topics_on_external_id ON public.topics USING btree (external_id) WHERE (external_id IS NOT NULL);


--
-- Name: index_topics_on_id_and_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_id_and_deleted_at ON public.topics USING btree (id, deleted_at);


--
-- Name: index_topics_on_id_filtered_banner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topics_on_id_filtered_banner ON public.topics USING btree (id) WHERE (((archetype)::text = 'banner'::text) AND (deleted_at IS NULL));


--
-- Name: index_topics_on_image_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_image_upload_id ON public.topics USING btree (image_upload_id);


--
-- Name: index_topics_on_lower_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_lower_title ON public.topics USING btree (lower((title)::text));


--
-- Name: index_topics_on_pinned_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_pinned_at ON public.topics USING btree (pinned_at) WHERE (pinned_at IS NOT NULL);


--
-- Name: index_topics_on_pinned_globally; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_pinned_globally ON public.topics USING btree (pinned_globally) WHERE pinned_globally;


--
-- Name: index_topics_on_pinned_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_pinned_until ON public.topics USING btree (pinned_until) WHERE (pinned_until IS NOT NULL);


--
-- Name: index_topics_on_timestamps_private; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_timestamps_private ON public.topics USING btree (bumped_at, created_at, updated_at) WHERE ((deleted_at IS NULL) AND ((archetype)::text = 'private_message'::text));


--
-- Name: index_topics_on_updated_at_for_locale_detection; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_updated_at_for_locale_detection ON public.topics USING btree (updated_at DESC) WHERE ((deleted_at IS NULL) AND (user_id > 0) AND (locale IS NULL));


--
-- Name: index_topics_on_updated_at_for_localization; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_updated_at_for_localization ON public.topics USING btree (updated_at DESC) WHERE ((deleted_at IS NULL) AND (user_id > 0) AND (locale IS NOT NULL));


--
-- Name: index_topics_on_updated_at_public; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_updated_at_public ON public.topics USING btree (updated_at, visible, highest_staff_post_number, highest_post_number, category_id, created_at, id) WHERE (((archetype)::text <> 'private_message'::text) AND (deleted_at IS NULL));


--
-- Name: index_translation_overrides_on_locale_and_translation_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_translation_overrides_on_locale_and_translation_key ON public.translation_overrides USING btree (locale, translation_key);


--
-- Name: index_unsubscribe_keys_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_unsubscribe_keys_on_created_at ON public.unsubscribe_keys USING btree (created_at);


--
-- Name: index_upcoming_change_events_on_event_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upcoming_change_events_on_event_type ON public.upcoming_change_events USING btree (event_type);


--
-- Name: index_upcoming_change_events_on_upcoming_change_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upcoming_change_events_on_upcoming_change_name ON public.upcoming_change_events USING btree (upcoming_change_name);


--
-- Name: index_upload_references_on_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_references_on_target ON public.upload_references USING btree (target_type, target_id);


--
-- Name: index_upload_references_on_upload_and_target; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_upload_references_on_upload_and_target ON public.upload_references USING btree (upload_id, target_type, target_id);


--
-- Name: index_upload_references_on_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_upload_references_on_upload_id ON public.upload_references USING btree (upload_id);


--
-- Name: index_uploads_on_access_control_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_access_control_post_id ON public.uploads USING btree (access_control_post_id);


--
-- Name: index_uploads_on_etag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_etag ON public.uploads USING btree (etag);


--
-- Name: index_uploads_on_extension; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_extension ON public.uploads USING btree (lower((extension)::text));


--
-- Name: index_uploads_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_id ON public.uploads USING btree (id) WHERE (dominant_color IS NULL);


--
-- Name: index_uploads_on_id_and_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_id_and_url ON public.uploads USING btree (id, url);


--
-- Name: index_uploads_on_original_sha1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_original_sha1 ON public.uploads USING btree (original_sha1);


--
-- Name: index_uploads_on_sha1; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_uploads_on_sha1 ON public.uploads USING btree (sha1);


--
-- Name: index_uploads_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_url ON public.uploads USING btree (url);


--
-- Name: index_uploads_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_uploads_on_user_id ON public.uploads USING btree (user_id);


--
-- Name: index_user_actions_on_acting_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_actions_on_acting_user_id ON public.user_actions USING btree (acting_user_id);


--
-- Name: index_user_actions_on_action_type_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_actions_on_action_type_and_created_at ON public.user_actions USING btree (action_type, created_at, user_id);


--
-- Name: index_user_actions_on_target_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_actions_on_target_post_id ON public.user_actions USING btree (target_post_id);


--
-- Name: index_user_actions_on_target_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_actions_on_target_user_id ON public.user_actions USING btree (target_user_id) WHERE (target_user_id IS NOT NULL);


--
-- Name: index_user_actions_on_user_id_and_action_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_actions_on_user_id_and_action_type ON public.user_actions USING btree (user_id, action_type);


--
-- Name: index_user_api_key_clients_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_api_key_clients_on_client_id ON public.user_api_key_clients USING btree (client_id);


--
-- Name: index_user_api_key_scopes_on_user_api_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_api_key_scopes_on_user_api_key_id ON public.user_api_key_scopes USING btree (user_api_key_id);


--
-- Name: index_user_api_keys_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_api_keys_on_client_id ON public.user_api_keys USING btree (client_id);


--
-- Name: index_user_api_keys_on_key_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_api_keys_on_key_hash ON public.user_api_keys USING btree (key_hash);


--
-- Name: index_user_api_keys_on_user_api_key_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_api_keys_on_user_api_key_client_id ON public.user_api_keys USING btree (user_api_key_client_id);


--
-- Name: index_user_api_keys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_api_keys_on_user_id ON public.user_api_keys USING btree (user_id);


--
-- Name: index_user_archived_messages_on_user_id_and_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_archived_messages_on_user_id_and_topic_id ON public.user_archived_messages USING btree (user_id, topic_id);


--
-- Name: index_user_associated_groups; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_associated_groups ON public.user_associated_groups USING btree (user_id, associated_group_id);


--
-- Name: index_user_associated_groups_on_associated_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_associated_groups_on_associated_group_id ON public.user_associated_groups USING btree (associated_group_id);


--
-- Name: index_user_associated_groups_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_associated_groups_on_user_id ON public.user_associated_groups USING btree (user_id);


--
-- Name: index_user_auth_token_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_auth_token_logs_on_user_id ON public.user_auth_token_logs USING btree (user_id);


--
-- Name: index_user_auth_tokens_on_auth_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_auth_tokens_on_auth_token ON public.user_auth_tokens USING btree (auth_token);


--
-- Name: index_user_auth_tokens_on_impersonation_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_auth_tokens_on_impersonation_expires_at ON public.user_auth_tokens USING btree (impersonation_expires_at) WHERE (impersonation_expires_at IS NOT NULL);


--
-- Name: index_user_auth_tokens_on_prev_auth_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_auth_tokens_on_prev_auth_token ON public.user_auth_tokens USING btree (prev_auth_token);


--
-- Name: index_user_auth_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_auth_tokens_on_user_id ON public.user_auth_tokens USING btree (user_id);


--
-- Name: index_user_avatars_on_custom_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_avatars_on_custom_upload_id ON public.user_avatars USING btree (custom_upload_id);


--
-- Name: index_user_avatars_on_gravatar_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_avatars_on_gravatar_upload_id ON public.user_avatars USING btree (gravatar_upload_id);


--
-- Name: index_user_avatars_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_avatars_on_user_id ON public.user_avatars USING btree (user_id);


--
-- Name: index_user_badges_on_badge_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_badges_on_badge_id_and_user_id ON public.user_badges USING btree (badge_id, user_id);


--
-- Name: index_user_badges_on_badge_id_and_user_id_and_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_badges_on_badge_id_and_user_id_and_post_id ON public.user_badges USING btree (badge_id, user_id, post_id) WHERE (post_id IS NOT NULL);


--
-- Name: index_user_badges_on_badge_id_and_user_id_and_seq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_badges_on_badge_id_and_user_id_and_seq ON public.user_badges USING btree (badge_id, user_id, seq) WHERE (post_id IS NULL);


--
-- Name: index_user_badges_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_badges_on_user_id ON public.user_badges USING btree (user_id);


--
-- Name: index_user_chat_channel_memberships_on_user_id_and_starred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_chat_channel_memberships_on_user_id_and_starred ON public.user_chat_channel_memberships USING btree (user_id, starred);


--
-- Name: index_user_custom_fields_on_user_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_custom_fields_on_user_id_and_name ON public.user_custom_fields USING btree (user_id, name);


--
-- Name: index_user_custom_fields_on_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_custom_fields_on_value ON public.user_custom_fields USING btree (value) WHERE ((name)::text = 'ai-stream-conversation-unique-id'::text);


--
-- Name: index_user_emails_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_emails_on_email ON public.user_emails USING btree (lower((email)::text));


--
-- Name: index_user_emails_on_normalized_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_emails_on_normalized_email ON public.user_emails USING btree (lower((normalized_email)::text));


--
-- Name: index_user_emails_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_emails_on_user_id ON public.user_emails USING btree (user_id);


--
-- Name: index_user_emails_on_user_id_and_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_emails_on_user_id_and_primary ON public.user_emails USING btree (user_id, "primary") WHERE "primary";


--
-- Name: index_user_histories_on_acting_user_id_and_action_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_histories_on_acting_user_id_and_action_and_id ON public.user_histories USING btree (acting_user_id, action, id);


--
-- Name: index_user_histories_on_action_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_histories_on_action_and_id ON public.user_histories USING btree (action, id);


--
-- Name: index_user_histories_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_histories_on_category_id ON public.user_histories USING btree (category_id);


--
-- Name: index_user_histories_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_histories_on_post_id ON public.user_histories USING btree (post_id);


--
-- Name: index_user_histories_on_reviewable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_histories_on_reviewable_id ON public.user_histories USING btree (reviewable_id);


--
-- Name: index_user_histories_on_subject_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_histories_on_subject_and_id ON public.user_histories USING btree (subject, id);


--
-- Name: index_user_histories_on_target_user_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_histories_on_target_user_id_and_id ON public.user_histories USING btree (target_user_id, id);


--
-- Name: index_user_histories_on_topic_id_and_target_user_id_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_histories_on_topic_id_and_target_user_id_and_action ON public.user_histories USING btree (topic_id, target_user_id, action);


--
-- Name: index_user_ip_address_histories_on_user_id_and_ip_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_ip_address_histories_on_user_id_and_ip_address ON public.user_ip_address_histories USING btree (user_id, ip_address);


--
-- Name: index_user_notification_schedules_on_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_notification_schedules_on_enabled ON public.user_notification_schedules USING btree (enabled);


--
-- Name: index_user_notification_schedules_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_notification_schedules_on_user_id ON public.user_notification_schedules USING btree (user_id);


--
-- Name: index_user_open_ids_on_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_open_ids_on_url ON public.user_open_ids USING btree (url);


--
-- Name: index_user_options_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_options_on_user_id ON public.user_options USING btree (user_id);


--
-- Name: index_user_options_on_user_id_and_default_calendar; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_options_on_user_id_and_default_calendar ON public.user_options USING btree (user_id, default_calendar);


--
-- Name: index_user_options_on_watched_precedence_over_muted; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_options_on_watched_precedence_over_muted ON public.user_options USING btree (watched_precedence_over_muted);


--
-- Name: index_user_passwords_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_passwords_on_user_id ON public.user_passwords USING btree (user_id);


--
-- Name: index_user_profile_views_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_profile_views_on_user_id ON public.user_profile_views USING btree (user_id);


--
-- Name: index_user_profile_views_on_user_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_profile_views_on_user_profile_id ON public.user_profile_views USING btree (user_profile_id);


--
-- Name: index_user_profiles_on_bio_cooked_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_profiles_on_bio_cooked_version ON public.user_profiles USING btree (bio_cooked_version);


--
-- Name: index_user_profiles_on_card_background_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_profiles_on_card_background_upload_id ON public.user_profiles USING btree (card_background_upload_id);


--
-- Name: index_user_profiles_on_granted_title_badge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_profiles_on_granted_title_badge_id ON public.user_profiles USING btree (granted_title_badge_id);


--
-- Name: index_user_profiles_on_profile_background_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_profiles_on_profile_background_upload_id ON public.user_profiles USING btree (profile_background_upload_id);


--
-- Name: index_user_second_factors_on_method_and_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_second_factors_on_method_and_enabled ON public.user_second_factors USING btree (method, enabled);


--
-- Name: index_user_second_factors_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_second_factors_on_user_id ON public.user_second_factors USING btree (user_id);


--
-- Name: index_user_security_keys_on_credential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_security_keys_on_credential_id ON public.user_security_keys USING btree (credential_id);


--
-- Name: index_user_security_keys_on_factor_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_security_keys_on_factor_type ON public.user_security_keys USING btree (factor_type);


--
-- Name: index_user_security_keys_on_factor_type_and_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_security_keys_on_factor_type_and_enabled ON public.user_security_keys USING btree (factor_type, enabled);


--
-- Name: index_user_security_keys_on_last_used; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_security_keys_on_last_used ON public.user_security_keys USING btree (last_used);


--
-- Name: index_user_security_keys_on_public_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_security_keys_on_public_key ON public.user_security_keys USING btree (public_key);


--
-- Name: index_user_security_keys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_security_keys_on_user_id ON public.user_security_keys USING btree (user_id);


--
-- Name: index_user_uploads_on_upload_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_uploads_on_upload_id_and_user_id ON public.user_uploads USING btree (upload_id, user_id);


--
-- Name: index_user_uploads_on_user_id_and_upload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_uploads_on_user_id_and_upload_id ON public.user_uploads USING btree (user_id, upload_id);


--
-- Name: index_user_visits_on_user_id_and_visited_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_visits_on_user_id_and_visited_at ON public.user_visits USING btree (user_id, visited_at);


--
-- Name: index_user_visits_on_user_id_and_visited_at_and_time_read; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_visits_on_user_id_and_visited_at_and_time_read ON public.user_visits USING btree (user_id, visited_at, time_read);


--
-- Name: index_user_visits_on_visited_at_and_mobile; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_visits_on_visited_at_and_mobile ON public.user_visits USING btree (visited_at, mobile);


--
-- Name: index_user_warnings_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_warnings_on_topic_id ON public.user_warnings USING btree (topic_id);


--
-- Name: index_user_warnings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_warnings_on_user_id ON public.user_warnings USING btree (user_id);


--
-- Name: index_users_on_last_posted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_last_posted_at ON public.users USING btree (last_posted_at);


--
-- Name: index_users_on_last_seen_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_last_seen_at ON public.users USING btree (last_seen_at);


--
-- Name: index_users_on_secure_identifier; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_secure_identifier ON public.users USING btree (secure_identifier);


--
-- Name: index_users_on_uploaded_avatar_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_uploaded_avatar_id ON public.users USING btree (uploaded_avatar_id);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: index_users_on_username_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_username_lower ON public.users USING btree (username_lower);


--
-- Name: index_watched_words_on_action_and_word; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_watched_words_on_action_and_word ON public.watched_words USING btree (action, word);


--
-- Name: index_watched_words_on_watched_word_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_watched_words_on_watched_word_group_id ON public.watched_words USING btree (watched_word_group_id);


--
-- Name: index_web_crawler_requests_on_date_and_user_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_web_crawler_requests_on_date_and_user_agent ON public.web_crawler_requests USING btree (date, user_agent);


--
-- Name: index_web_hook_events_daily_aggregates_on_web_hook_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_web_hook_events_daily_aggregates_on_web_hook_id ON public.web_hook_events_daily_aggregates USING btree (web_hook_id);


--
-- Name: index_web_hook_events_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_web_hook_events_on_created_at ON public.web_hook_events USING btree (created_at);


--
-- Name: index_web_hook_events_on_web_hook_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_web_hook_events_on_web_hook_id ON public.web_hook_events USING btree (web_hook_id);


--
-- Name: post_timings_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX post_timings_unique ON public.post_timings USING btree (topic_id, post_number, user_id);


--
-- Name: post_voting_comments_deleted_by_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_voting_comments_deleted_by_id_idx ON public.post_voting_comments USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: post_voting_comments_post_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_voting_comments_post_id_idx ON public.post_voting_comments USING btree (post_id);


--
-- Name: post_voting_comments_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX post_voting_comments_user_id_idx ON public.post_voting_comments USING btree (user_id);


--
-- Name: post_voting_votes_votable_type_and_votable_id_and_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX post_voting_votes_votable_type_and_votable_id_and_user_id_idx ON public.post_voting_votes USING btree (votable_type, votable_id, user_id);


--
-- Name: post_voting_votes_votable_type_votable_id_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX post_voting_votes_votable_type_votable_id_user_id_idx ON public.post_voting_votes USING btree (votable_type, votable_id, user_id);


--
-- Name: reaction_id_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX reaction_id_user_id ON public.discourse_reactions_reaction_users USING btree (reaction_id, user_id);


--
-- Name: reaction_type_reaction_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX reaction_type_reaction_value ON public.discourse_reactions_reactions USING btree (post_id, reaction_type, reaction_value);


--
-- Name: theme_field_unique_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX theme_field_unique_index ON public.theme_fields USING btree (theme_id, target_id, type_id, name);


--
-- Name: theme_translation_overrides_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX theme_translation_overrides_unique ON public.theme_translation_overrides USING btree (theme_id, locale, translation_key);


--
-- Name: topic_custom_fields_value_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX topic_custom_fields_value_key_idx ON public.topic_custom_fields USING btree (value, name) WHERE ((value IS NOT NULL) AND (char_length(value) < 400));


--
-- Name: topic_voting_category_settings_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX topic_voting_category_settings_category_id_idx ON public.topic_voting_category_settings USING btree (category_id);


--
-- Name: topic_voting_topic_vote_count_topic_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX topic_voting_topic_vote_count_topic_id_idx ON public.topic_voting_topic_vote_count USING btree (topic_id);


--
-- Name: topic_voting_votes_user_id_topic_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX topic_voting_votes_user_id_topic_id_idx ON public.topic_voting_votes USING btree (user_id, topic_id);


--
-- Name: uniq_ip_or_user_id_topic_views; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_ip_or_user_id_topic_views ON public.topic_views USING btree (user_id, ip_address, topic_id);


--
-- Name: unique_chat_message_links; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_chat_message_links ON public.chat_message_links USING btree (chat_message_id, url);


--
-- Name: unique_classification_target_per_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_classification_target_per_type ON public.classification_results USING btree (target_id, target_type, model_used);


--
-- Name: unique_index_categories_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_index_categories_on_name ON public.categories USING btree (COALESCE(parent_category_id, '-1'::integer), name);


--
-- Name: unique_index_categories_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_index_categories_on_slug ON public.categories USING btree (COALESCE(parent_category_id, '-1'::integer), lower((slug)::text)) WHERE ((slug)::text <> ''::text);


--
-- Name: unique_livestream_topic_chat_channels; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_livestream_topic_chat_channels ON public.livestream_topic_chat_channels USING btree (topic_id, chat_channel_id);


--
-- Name: unique_post_links; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_post_links ON public.topic_links USING btree (topic_id, post_id, url);


--
-- Name: unique_profile_view_user_or_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_profile_view_user_or_ip ON public.user_profile_views USING btree (viewed_at, user_id, ip_address, user_profile_id);


--
-- Name: unique_target_and_assigned; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_target_and_assigned ON public.assignments USING btree (assigned_to_id, assigned_to_type, target_id, target_type);


--
-- Name: unique_topic_thumbnails; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_topic_thumbnails ON public.topic_thumbnails USING btree (upload_id, max_width, max_height);


--
-- Name: user_chat_channel_memberships_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_chat_channel_memberships_index ON public.user_chat_channel_memberships USING btree (user_id, chat_channel_id, notification_level, following);


--
-- Name: user_chat_channel_unique_memberships; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_chat_channel_unique_memberships ON public.user_chat_channel_memberships USING btree (user_id, chat_channel_id);


--
-- Name: user_chat_thread_unique_memberships; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_chat_thread_unique_memberships ON public.user_chat_thread_memberships USING btree (user_id, thread_id);


--
-- Name: user_id_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_id_post_id ON public.discourse_reactions_reaction_users USING btree (user_id, post_id);


--
-- Name: web_hooks_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX web_hooks_tags ON public.tags_web_hooks USING btree (web_hook_id, tag_id);


--
-- Name: category_settings category_settings_require_reply_approval_readonly; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER category_settings_require_reply_approval_readonly BEFORE INSERT OR UPDATE OF require_reply_approval ON public.category_settings FOR EACH ROW WHEN ((new.require_reply_approval IS NOT NULL)) EXECUTE FUNCTION discourse_functions.raise_category_settings_require_reply_approval_readonly();


--
-- Name: category_settings category_settings_require_topic_approval_readonly; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER category_settings_require_topic_approval_readonly BEFORE INSERT OR UPDATE OF require_topic_approval ON public.category_settings FOR EACH ROW WHEN ((new.require_topic_approval IS NOT NULL)) EXECUTE FUNCTION discourse_functions.raise_category_settings_require_topic_approval_readonly();


--
-- Name: discourse_rss_polling_rss_feeds discourse_rss_polling_rss_feeds_author_readonly; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER discourse_rss_polling_rss_feeds_author_readonly BEFORE INSERT OR UPDATE OF author ON public.discourse_rss_polling_rss_feeds FOR EACH ROW WHEN ((new.author IS NOT NULL)) EXECUTE FUNCTION discourse_functions.raise_discourse_rss_polling_rss_feeds_author_readonly();


--
-- Name: topic_timers topic_timers_topic_id_readonly; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER topic_timers_topic_id_readonly BEFORE INSERT OR UPDATE OF topic_id ON public.topic_timers FOR EACH ROW WHEN ((new.topic_id IS NOT NULL)) EXECUTE FUNCTION discourse_functions.raise_topic_timers_topic_id_readonly();


--
-- Name: user_profiles fk_rails_1d362f2e97; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT fk_rails_1d362f2e97 FOREIGN KEY (profile_background_upload_id) REFERENCES public.uploads(id);


--
-- Name: reviewable_notes fk_rails_2fe5fa5cd0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_notes
    ADD CONSTRAINT fk_rails_2fe5fa5cd0 FOREIGN KEY (reviewable_id) REFERENCES public.reviewables(id);


--
-- Name: user_profiles fk_rails_38ea484ed4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT fk_rails_38ea484ed4 FOREIGN KEY (granted_title_badge_id) REFERENCES public.badges(id);


--
-- Name: ad_plugin_impressions fk_rails_45ce2c4d3c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_impressions
    ADD CONSTRAINT fk_rails_45ce2c4d3c FOREIGN KEY (ad_plugin_house_ad_id) REFERENCES public.ad_plugin_house_ads(id) ON DELETE CASCADE;


--
-- Name: ad_plugin_house_ads_groups fk_rails_4973d7060d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_house_ads_groups
    ADD CONSTRAINT fk_rails_4973d7060d FOREIGN KEY (ad_plugin_house_ad_id) REFERENCES public.ad_plugin_house_ads(id) ON DELETE CASCADE;


--
-- Name: javascript_caches fk_rails_58f94aecc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.javascript_caches
    ADD CONSTRAINT fk_rails_58f94aecc4 FOREIGN KEY (theme_id) REFERENCES public.themes(id) ON DELETE CASCADE;


--
-- Name: optimized_videos fk_rails_7c76beeaf4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.optimized_videos
    ADD CONSTRAINT fk_rails_7c76beeaf4 FOREIGN KEY (optimized_upload_id) REFERENCES public.uploads(id);


--
-- Name: poll_votes fk_rails_848ece0184; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT fk_rails_848ece0184 FOREIGN KEY (poll_option_id) REFERENCES public.poll_options(id);


--
-- Name: optimized_videos fk_rails_84f2496311; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.optimized_videos
    ADD CONSTRAINT fk_rails_84f2496311 FOREIGN KEY (upload_id) REFERENCES public.uploads(id);


--
-- Name: user_security_keys fk_rails_90999b0454; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_security_keys
    ADD CONSTRAINT fk_rails_90999b0454 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: reviewable_notes fk_rails_9ea278a8aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewable_notes
    ADD CONSTRAINT fk_rails_9ea278a8aa FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: poll_votes fk_rails_a6e6974b7e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT fk_rails_a6e6974b7e FOREIGN KEY (poll_id) REFERENCES public.polls(id);


--
-- Name: poll_options fk_rails_aa85becb42; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT fk_rails_aa85becb42 FOREIGN KEY (poll_id) REFERENCES public.polls(id);


--
-- Name: ad_plugin_house_ads_routes fk_rails_b126a33930; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_house_ads_routes
    ADD CONSTRAINT fk_rails_b126a33930 FOREIGN KEY (ad_plugin_house_ad_id) REFERENCES public.ad_plugin_house_ads(id);


--
-- Name: polls fk_rails_b50b782d08; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT fk_rails_b50b782d08 FOREIGN KEY (post_id) REFERENCES public.posts(id);


--
-- Name: poll_votes fk_rails_b64de9b025; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT fk_rails_b64de9b025 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: ai_tool_actions fk_rails_bf8a76772d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_tool_actions
    ADD CONSTRAINT fk_rails_bf8a76772d FOREIGN KEY (ai_agent_id) REFERENCES public.ai_agents(id);


--
-- Name: ad_plugin_house_ads_categories fk_rails_c6e88d8af5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_house_ads_categories
    ADD CONSTRAINT fk_rails_c6e88d8af5 FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: user_profiles fk_rails_ca64aa462b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT fk_rails_ca64aa462b FOREIGN KEY (card_background_upload_id) REFERENCES public.uploads(id);


--
-- Name: ad_plugin_house_ads_categories fk_rails_ea323de4ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_house_ads_categories
    ADD CONSTRAINT fk_rails_ea323de4ce FOREIGN KEY (ad_plugin_house_ad_id) REFERENCES public.ad_plugin_house_ads(id) ON DELETE CASCADE;


--
-- Name: javascript_caches fk_rails_ed33506dbd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.javascript_caches
    ADD CONSTRAINT fk_rails_ed33506dbd FOREIGN KEY (theme_field_id) REFERENCES public.theme_fields(id) ON DELETE CASCADE;


--
-- Name: ad_plugin_impressions fk_rails_f446846ed4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_impressions
    ADD CONSTRAINT fk_rails_f446846ed4 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: ad_plugin_house_ads_groups fk_rails_fcbec7868d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_plugin_house_ads_groups
    ADD CONSTRAINT fk_rails_fcbec7868d FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260630034050'),
('20260629233141'),
('20260629081606'),
('20260629022603'),
('20260626055145'),
('20260624140945'),
('20260623090824'),
('20260623052745'),
('20260622201006'),
('20260622201005'),
('20260622140747'),
('20260617180115'),
('20260617104005'),
('20260617053237'),
('20260616114637'),
('20260615084100'),
('20260615082047'),
('20260612092612'),
('20260610205840'),
('20260610075829'),
('20260610064425'),
('20260609050938'),
('20260608104742'),
('20260607161322'),
('20260604052235'),
('20260603115312'),
('20260603115200'),
('20260603013342'),
('20260602104726'),
('20260601063855'),
('20260601043020'),
('20260528074731'),
('20260528074719'),
('20260525105009'),
('20260525105006'),
('20260522043337'),
('20260520090937'),
('20260518104900'),
('20260518072818'),
('20260518054805'),
('20260514055648'),
('20260514043815'),
('20260513162531'),
('20260513105516'),
('20260513101242'),
('20260513055222'),
('20260513024004'),
('20260512061336'),
('20260511145109'),
('20260511080033'),
('20260511044542'),
('20260510232238'),
('20260507083943'),
('20260505161704'),
('20260504214551'),
('20260504211108'),
('20260430172653'),
('20260430142946'),
('20260429122035'),
('20260428072232'),
('20260424004343'),
('20260422144944'),
('20260422135650'),
('20260422130653'),
('20260422102523'),
('20260422062938'),
('20260422000000'),
('20260421061908'),
('20260420014648'),
('20260415082426'),
('20260409225129'),
('20260408214007'),
('20260408165014'),
('20260407093145'),
('20260402141924'),
('20260402141912'),
('20260402023645'),
('20260331024139'),
('20260330161714'),
('20260327040745'),
('20260326000000'),
('20260325120000'),
('20260324200000'),
('20260324004457'),
('20260323145627'),
('20260319120000'),
('20260319070000'),
('20260319055039'),
('20260319054731'),
('20260319054730'),
('20260319054026'),
('20260319033623'),
('20260319000001'),
('20260319000000'),
('20260316154328'),
('20260316071737'),
('20260316071736'),
('20260316071735'),
('20260312000000'),
('20260311161955'),
('20260311064518'),
('20260311021412'),
('20260310121613'),
('20260310121612'),
('20260310120000'),
('20260310072759'),
('20260310072550'),
('20260310001245'),
('20260309032553'),
('20260306183220'),
('20260306000002'),
('20260306000001'),
('20260304063335'),
('20260223032030'),
('20260218104617'),
('20260218000000'),
('20260217064339'),
('20260211051130'),
('20260210223628'),
('20260209031949'),
('20260206013737'),
('20260206013736'),
('20260206013735'),
('20260206000939'),
('20260206000938'),
('20260206000937'),
('20260206000936'),
('20260205065417'),
('20260126204830'),
('20260122214226'),
('20260122134202'),
('20260119164737'),
('20260112082200'),
('20260112032646'),
('20260109041508'),
('20260108133149'),
('20260108060111'),
('20260108044513'),
('20260108002529'),
('20260106102330'),
('20260106060808'),
('20260106060807'),
('20260105171226'),
('20260105171115'),
('20251231190601'),
('20251227224408'),
('20251217030751'),
('20251216094828'),
('20251215125122'),
('20251212144720'),
('20251211081539'),
('20251210065956'),
('20251209180201'),
('20251209012613'),
('20251207190710'),
('20251205140527'),
('20251203180046'),
('20251203115747'),
('20251203000005'),
('20251202101647'),
('20251202090012'),
('20251201225946'),
('20251201225314'),
('20251201155027'),
('20251127125226'),
('20251127001422'),
('20251125202538'),
('20251125101809'),
('20251124000000'),
('20251122000000'),
('20251121131136'),
('20251121083103'),
('20251120090500'),
('20251120090000'),
('20251119101732'),
('20251119100000'),
('20251119033712'),
('20251118002306'),
('20251118000500'),
('20251118000001'),
('20251117002948'),
('20251117000003'),
('20251117000002'),
('20251117000001'),
('20251114164217'),
('20251113174215'),
('20251113174112'),
('20251113040028'),
('20251113040027'),
('20251111091231'),
('20251111073356'),
('20251107123438'),
('20251106143458'),
('20251105174003'),
('20251105174002'),
('20251104121943'),
('20251104121942'),
('20251104121941'),
('20251029072625'),
('20251024020353'),
('20251024015907'),
('20251023042602'),
('20251017150024'),
('20251017115448'),
('20251016143343'),
('20251016013505'),
('20251013091641'),
('20251009141725'),
('20251008050307'),
('20251007123645'),
('20251003120819'),
('20251002171950'),
('20251001000001'),
('20250925182715'),
('20250925061202'),
('20250919094856'),
('20250919061654'),
('20250919010400'),
('20250917185050'),
('20250916082012'),
('20250903091723'),
('20250902221035'),
('20250902072941'),
('20250902020536'),
('20250902014817'),
('20250828181952'),
('20250828011415'),
('20250827065400'),
('20250826012802'),
('20250825094818'),
('20250821155615'),
('20250821155127'),
('20250821150220'),
('20250820052343'),
('20250819123418'),
('20250819123417'),
('20250818063631'),
('20250817090000'),
('20250812033430'),
('20250811132217'),
('20250811120000'),
('20250811070948'),
('20250808064354'),
('20250807042048'),
('20250805134853'),
('20250804021210'),
('20250804005557'),
('20250729044139'),
('20250724012518'),
('20250723122719'),
('20250722101702'),
('20250722074045'),
('20250721192556'),
('20250721192555'),
('20250721192554'),
('20250721192553'),
('20250721080444'),
('20250721043317'),
('20250718043910'),
('20250718035714'),
('20250717093505'),
('20250717075002'),
('20250716005855'),
('20250716005451'),
('20250715165701'),
('20250715094001'),
('20250714030525'),
('20250714010001'),
('20250710215720'),
('20250710181656'),
('20250710180401'),
('20250710173803'),
('20250710074447'),
('20250709051949'),
('20250708031631'),
('20250707084732'),
('20250704072726'),
('20250702133530'),
('20250702082232'),
('20250702073222'),
('20250627022651'),
('20250626090725'),
('20250620073222'),
('20250620033435'),
('20250620025548'),
('20250619140858'),
('20250619140809'),
('20250619140739'),
('20250619140551'),
('20250619105705'),
('20250617085536'),
('20250617064103'),
('20250616101945'),
('20250616101944'),
('20250614020437'),
('20250609115711'),
('20250607071239'),
('20250606170129'),
('20250603051201'),
('20250602114410'),
('20250529021721'),
('20250528030212'),
('20250527101351'),
('20250526164734'),
('20250526154632'),
('20250526063633'),
('20250521053324'),
('20250520042223'),
('20250514162335'),
('20250513161753'),
('20250509000001'),
('20250508183456'),
('20250508182047'),
('20250508154953'),
('20250507110205'),
('20250507013646'),
('20250505050610'),
('20250501002657'),
('20250429083152'),
('20250429060311'),
('20250424163718'),
('20250424054313'),
('20250424054312'),
('20250424035234'),
('20250421074012'),
('20250417194503'),
('20250417043438'),
('20250416215039'),
('20250416012407'),
('20250415224422'),
('20250411121705'),
('20250409035119'),
('20250407125756'),
('20250407042814'),
('20250407040934'),
('20250404045050'),
('20250325074111'),
('20250321143553'),
('20250319232839'),
('20250319052218'),
('20250319024514'),
('20250318025147'),
('20250318024954'),
('20250318024953'),
('20250318024824'),
('20250314110738'),
('20250314102616'),
('20250313045010'),
('20250313044812'),
('20250313000000'),
('20250311073009'),
('20250311041851'),
('20250310172527'),
('20250307185912'),
('20250307034117'),
('20250307031538'),
('20250305233449'),
('20250304074934'),
('20250304054720'),
('20250304034313'),
('20250225131523'),
('20250220090521'),
('20250220045740'),
('20250217003916'),
('20250212045125'),
('20250212044021'),
('20250211021037'),
('20250210133038'),
('20250210032351'),
('20250210032345'),
('20250210024600'),
('20250206010037'),
('20250205174221'),
('20250205104150'),
('20250130205841'),
('20250127145305'),
('20250125162658'),
('20250124062108'),
('20250122131007'),
('20250122003035'),
('20250121180125'),
('20250121162520'),
('20250120115539'),
('20250119222805'),
('20250117065027'),
('20250116024516'),
('20250115181147'),
('20250115173456'),
('20250115130542'),
('20250115031117'),
('20250114184356'),
('20250114160500'),
('20250114160446'),
('20250114160417'),
('20250113171444'),
('20250110114305'),
('20250102185307'),
('20250102035341'),
('20241230153301'),
('20241230153300'),
('20241226162229'),
('20241224191732'),
('20241217164540'),
('20241212113000'),
('20241211222608'),
('20241211030039'),
('20241210081242'),
('20241206121401'),
('20241206115958'),
('20241206051225'),
('20241206030229'),
('20241206002425'),
('20241205162117'),
('20241205035402'),
('20241204085540'),
('20241203125523'),
('20241203125415'),
('20241130003808'),
('20241129190708'),
('20241128010221'),
('20241127072350'),
('20241127034553'),
('20241126033812'),
('20241125132452'),
('20241121000131'),
('20241120182858'),
('20241112145744'),
('20241112124552'),
('20241111022618'),
('20241110120303'),
('20241108154026'),
('20241105211601'),
('20241104132424'),
('20241104053309'),
('20241104053017'),
('20241101141701'),
('20241031180044'),
('20241031145203'),
('20241031050638'),
('20241031041242'),
('20241030210727'),
('20241029192512'),
('20241028034232'),
('20241028021339'),
('20241025135522'),
('20241025133536'),
('20241025132600'),
('20241025045928'),
('20241024102733'),
('20241024093027'),
('20241023041242'),
('20241023041126'),
('20241023033955'),
('20241022022326'),
('20241020010245'),
('20241018031851'),
('20241016174732'),
('20241014041242'),
('20241014010245'),
('20241011080517'),
('20241011054348'),
('20241011033602'),
('20241010155139'),
('20241009230724'),
('20241009161603'),
('20241009160105'),
('20241009155340'),
('20241008055831'),
('20241008054440'),
('20241003122030'),
('20240913054440'),
('20240912212253'),
('20240912210450'),
('20240912061806'),
('20240912061702'),
('20240912055831'),
('20240912052713'),
('20240910090759'),
('20240909180908'),
('20240909121255'),
('20240906233304'),
('20240906142121'),
('20240903184807'),
('20240903024311'),
('20240903024211'),
('20240903024157'),
('20240829140227'),
('20240829140226'),
('20240829083823'),
('20240828191047'),
('20240827064121'),
('20240827063908'),
('20240827063715'),
('20240827040811'),
('20240827040810'),
('20240827040550'),
('20240827040131'),
('20240826121507'),
('20240826121506'),
('20240826121505'),
('20240826121504'),
('20240826121503'),
('20240826121502'),
('20240826121501'),
('20240820123406'),
('20240820123405'),
('20240820123404'),
('20240820123403'),
('20240820123402'),
('20240820123401'),
('20240819130737'),
('20240818113758'),
('20240815234500'),
('20240809163303'),
('20240809162837'),
('20240808175526'),
('20240807150605'),
('20240807024301'),
('20240807020209'),
('20240731190511'),
('20240731143458'),
('20240729202857'),
('20240729084803'),
('20240726164937'),
('20240725042522'),
('20240724174343'),
('20240724021732'),
('20240723030506'),
('20240722025822'),
('20240719143453'),
('20240717171840'),
('20240717071658'),
('20240717053710'),
('20240715073605'),
('20240715021442'),
('20240714231516'),
('20240714231226'),
('20240712050324'),
('20240711154622'),
('20240711153837'),
('20240711123755'),
('20240711102255'),
('20240709015048'),
('20240709010639'),
('20240708193243'),
('20240707170311'),
('20240705153533'),
('20240705134114'),
('20240704020102'),
('20240703135444'),
('20240627155730'),
('20240627125112'),
('20240624202602'),
('20240624135356'),
('20240620024938'),
('20240619211337'),
('20240619193057'),
('20240619123052'),
('20240618080148'),
('20240612073116'),
('20240612063735'),
('20240611170906'),
('20240611170905'),
('20240611170904'),
('20240610232546'),
('20240610232040'),
('20240610150449'),
('20240609232736'),
('20240609061418'),
('20240606152117'),
('20240606151348'),
('20240606003822'),
('20240603234529'),
('20240603143158'),
('20240603133432'),
('20240531205234'),
('20240531053226'),
('20240528144216'),
('20240528132059'),
('20240527055057'),
('20240527054218'),
('20240527015009'),
('20240521032001'),
('20240520060901'),
('20240517051933'),
('20240517014119'),
('20240516145911'),
('20240514171609'),
('20240514001334'),
('20240513140542'),
('20240510073417'),
('20240507112951'),
('20240507112851'),
('20240507112751'),
('20240507112651'),
('20240506125839'),
('20240506035024'),
('20240504222307'),
('20240503042558'),
('20240503034946'),
('20240430185434'),
('20240430163338'),
('20240430052017'),
('20240430051551'),
('20240429065155'),
('20240425133407'),
('20240424220101'),
('20240423054323'),
('20240423013808'),
('20240422042830'),
('20240422015830'),
('20240416105733'),
('20240410170000'),
('20240410130000'),
('20240409093348'),
('20240409060201'),
('20240409035951'),
('20240408140000'),
('20240404034232'),
('20240404000838'),
('20240401054228'),
('20240327043323'),
('20240327000440'),
('20240326200232'),
('20240322035907'),
('20240313165121'),
('20240311015942'),
('20240309034752'),
('20240309034751'),
('20240307231053'),
('20240306063428'),
('20240304030429'),
('20240301100413'),
('20240301033753'),
('20240223052820'),
('20240219012001'),
('20240216073624'),
('20240214135517'),
('20240213175713'),
('20240213051213'),
('20240212034010'),
('20240209044519'),
('20240208195104'),
('20240208195103'),
('20240208195102'),
('20240208195101'),
('20240208195100'),
('20240207144910'),
('20240204204532'),
('20240202204030'),
('20240202052058'),
('20240202032242'),
('20240202010752'),
('20240201170412'),
('20240126013358'),
('20240122015930'),
('20240122015630'),
('20240122015626'),
('20240119152348'),
('20240118195159'),
('20240118195158'),
('20240118195157'),
('20240118195156'),
('20240118195155'),
('20240118120825'),
('20240117093148'),
('20240117090801'),
('20240116182229'),
('20240116100023'),
('20240116043702'),
('20240112073149'),
('20240112043325'),
('20240112021335'),
('20240110040813'),
('20240108022138'),
('20240104155715'),
('20240104013944'),
('20231228213036'),
('20231227223301'),
('20231227160005'),
('20231227160004'),
('20231227160003'),
('20231227160002'),
('20231227160001'),
('20231222030024'),
('20231220043117'),
('20231220042344'),
('20231218171020'),
('20231218081901'),
('20231214180002'),
('20231214180001'),
('20231214180000'),
('20231214061615'),
('20231214031754'),
('20231214023728'),
('20231214020814'),
('20231213103248'),
('20231213060822'),
('20231212044856'),
('20231207135641'),
('20231207011238'),
('20231206041353'),
('20231205013029'),
('20231204161807'),
('20231202013850'),
('20231128151234'),
('20231127165331'),
('20231124021939'),
('20231123233308'),
('20231123224203'),
('20231122212122'),
('20231122152552'),
('20231122043756'),
('20231120190818'),
('20231120033747'),
('20231117182638'),
('20231117050928'),
('20231111201253'),
('20231110214451'),
('20231109011155'),
('20231107055903'),
('20231107014123'),
('20231103060018'),
('20231031050538'),
('20231024034031'),
('20231022224833'),
('20231018225833'),
('20231017175757'),
('20231017044708'),
('20231011152903'),
('20231006161051'),
('20231006160650'),
('20231004020328'),
('20231003155701'),
('20230926165821'),
('20230913194832'),
('20230910021213'),
('20230908045625'),
('20230907225057'),
('20230906030920'),
('20230904155318'),
('20230831153649'),
('20230831033812'),
('20230823100627'),
('20230823095931'),
('20230819193312'),
('20230817174049'),
('20230816211907'),
('20230807040058'),
('20230807033021'),
('20230728055813'),
('20230727170222'),
('20230727015254'),
('20230727015030'),
('20230722124044'),
('20230721025249'),
('20230712013248'),
('20230712011946'),
('20230710171143'),
('20230710171142'),
('20230710171141'),
('20230710040640'),
('20230708011310'),
('20230707082645'),
('20230707031122'),
('20230707025733'),
('20230703035052'),
('20230628062236'),
('20230627060104'),
('20230627044755'),
('20230620050614'),
('20230618041123'),
('20230618041001'),
('20230614041219'),
('20230614011419'),
('20230614011312'),
('20230612134421'),
('20230608163854'),
('20230607091233'),
('20230602034711'),
('20230528134326'),
('20230523073109'),
('20230519003106'),
('20230515131111'),
('20230515103515'),
('20230510142249'),
('20230509214723'),
('20230505113906'),
('20230501022508'),
('20230424055354'),
('20230420185415'),
('20230419001801'),
('20230413121500'),
('20230412120414'),
('20230411032053'),
('20230411031520'),
('20230411031428'),
('20230411023340'),
('20230411023246'),
('20230411012630'),
('20230406135943'),
('20230405121454'),
('20230405121453'),
('20230404064728'),
('20230403094936'),
('20230403063113'),
('20230403012844'),
('20230328034956'),
('20230322142028'),
('20230320191928'),
('20230320185619'),
('20230320122645'),
('20230319115620'),
('20230318130154'),
('20230317194217'),
('20230316160714'),
('20230314184514'),
('20230308042434'),
('20230307125342'),
('20230307051200'),
('20230303015952'),
('20230301071240'),
('20230228105851'),
('20230228062442'),
('20230227172543'),
('20230227102505'),
('20230227050149'),
('20230227050148'),
('20230227050147'),
('20230227050146'),
('20230224225129'),
('20230224193734'),
('20230224165056'),
('20230214044350'),
('20230213234415'),
('20230209222225'),
('20230208020404'),
('20230207093514'),
('20230207042719'),
('20230206033907'),
('20230202204937'),
('20230202173641'),
('20230202021414'),
('20230201192925'),
('20230201012734'),
('20230130053144'),
('20230127173249'),
('20230123025112'),
('20230123020036'),
('20230119094939'),
('20230119091939'),
('20230119024157'),
('20230119000943'),
('20230118042740'),
('20230118020114'),
('20230117143451'),
('20230117002110'),
('20230116090324'),
('20230115233416'),
('20230113110559'),
('20230113025043'),
('20230113002617'),
('20230112033741'),
('20230111223803'),
('20230105153520'),
('20230104054426'),
('20230104054425'),
('20230103004613'),
('20221223210225'),
('20221214133921'),
('20221212234948'),
('20221211142629'),
('20221205225450'),
('20221202043755'),
('20221202032006'),
('20221201035918'),
('20221201032830'),
('20221201024458'),
('20221125173217'),
('20221125001635'),
('20221122070108'),
('20221122010538'),
('20221121223417'),
('20221121165352'),
('20221118104708'),
('20221117142910'),
('20221117052348'),
('20221114215902'),
('20221110175456'),
('20221108032233'),
('20221107034541'),
('20221104054957'),
('20221103051248'),
('20221101181505'),
('20221101140632'),
('20221101061319'),
('20221027090832'),
('20221026043851'),
('20221026035440'),
('20221025153038'),
('20221019171131'),
('20221018100550'),
('20221018091412'),
('20221017223309'),
('20221014145803'),
('20221014005208'),
('20221013045158'),
('20221006130454'),
('20221005143622'),
('20221004122343'),
('20221004122254'),
('20220927171707'),
('20220927065328'),
('20220923212549'),
('20220920044310'),
('20220915132547'),
('20220901034107'),
('20220825054405'),
('20220825005115'),
('20220818171849'),
('20220811170600'),
('20220802014549'),
('20220801044610'),
('20220729032237'),
('20220728171436'),
('20220727085001'),
('20220727040437'),
('20220726164831'),
('20220724130519'),
('20220714022309'),
('20220712040959'),
('20220706114835'),
('20220701195731'),
('20220630074200'),
('20220629190633'),
('20220628031850'),
('20220623182333'),
('20220621164914'),
('20220617151846'),
('20220613073844'),
('20220609017748'),
('20220609014748'),
('20220607150432'),
('20220606061813'),
('20220604200919'),
('20220531105951'),
('20220526203356'),
('20220526135414'),
('20220519190829'),
('20220518180642'),
('20220518140004'),
('20220516142658'),
('20220512011531'),
('20220512011522'),
('20220510131525'),
('20220506221447'),
('20220505191131'),
('20220505133851'),
('20220504080457'),
('20220429164301'),
('20220429110203'),
('20220428094027'),
('20220428094026'),
('20220428025825'),
('20220419124720'),
('20220407195246'),
('20220404212716'),
('20220404204439'),
('20220404203356'),
('20220404201949'),
('20220404195635'),
('20220401140745'),
('20220401130745'),
('20220331204447'),
('20220331203401'),
('20220330164740'),
('20220330160757'),
('20220330160754'),
('20220330160751'),
('20220330160747'),
('20220330160740'),
('20220328142120'),
('20220325064954'),
('20220324210218'),
('20220324062937'),
('20220323141645'),
('20220322024216'),
('20220321235638'),
('20220316150247'),
('20220315172912'),
('20220314190045'),
('20220309174820'),
('20220309132720'),
('20220309132719'),
('20220308201942'),
('20220308165620'),
('20220304162250'),
('20220303012356'),
('20220302171443'),
('20220302163246'),
('20220228163400'),
('20220228051724'),
('20220220234155'),
('20220218023859'),
('20220215103720'),
('20220215015538'),
('20220214233625'),
('20220214224506'),
('20220209210449'),
('20220209070445'),
('20220208071734'),
('20220203204003'),
('20220203204002'),
('20220202225716'),
('20220202223955'),
('20220201162748'),
('20220130192155'),
('20220126052157'),
('20220125052845'),
('20220124003259'),
('20220119170535'),
('20220118065658'),
('20220112091339'),
('20220105024605'),
('20220104051326'),
('20211230152430'),
('20211230151700'),
('20211224111749'),
('20211224011511'),
('20211224010204'),
('20211222153716'),
('20211221164540'),
('20211220023034'),
('20211217221026'),
('20211216191224'),
('20211216124303'),
('20211213150607'),
('20211213060445'),
('20211210191830'),
('20211208073658'),
('20211207130646'),
('20211206205455'),
('20211206160212'),
('20211206160211'),
('20211206081254'),
('20211206060512'),
('20211202141030'),
('20211202140128'),
('20211202134547'),
('20211202120030'),
('20211201221028'),
('20211201171813'),
('20211129171229'),
('20211126031104'),
('20211124161346'),
('20211123144714'),
('20211123033311'),
('20211119142000'),
('20211119103353'),
('20211116225901'),
('20211108023921'),
('20211106085605'),
('20211106085527'),
('20211106085344'),
('20211104141254'),
('20211029145508'),
('20211022154420'),
('20211022151713'),
('20211020062413'),
('20211019152356'),
('20211019092048'),
('20211018234219'),
('20211015092049'),
('20211015092048'),
('20211015092047'),
('20211014043735'),
('20211013092406'),
('20211006223156'),
('20211005163152'),
('20210930144333'),
('20210929215543'),
('20210928161912'),
('20210922064213'),
('20210920044353'),
('20210915222124'),
('20210915215952'),
('20210915142958'),
('20210914152002'),
('20210914011037'),
('20210913032326'),
('20210909041448'),
('20210908060141'),
('20210901130308'),
('20210830024453'),
('20210824203421'),
('20210823160357'),
('20210819202912'),
('20210819152920'),
('20210813141741'),
('20210812145801'),
('20210812033033'),
('20210805204149'),
('20210802131421'),
('20210730134847'),
('20210729134042'),
('20210724143804'),
('20210720221817'),
('20210714173022'),
('20210713092503'),
('20210709101534'),
('20210709053030'),
('20210709042135'),
('20210708035538'),
('20210708035525'),
('20210706214013'),
('20210706091905'),
('20210702204007'),
('20210702084757'),
('20210701233509'),
('20210628035905'),
('20210627100932'),
('20210625203049'),
('20210624080131'),
('20210624023831'),
('20210621234939'),
('20210621190335'),
('20210621103509'),
('20210621002201'),
('20210618142654'),
('20210618135229'),
('20210617202227'),
('20210617183010'),
('20210614232334'),
('20210603135629'),
('20210601002145'),
('20210530122334'),
('20210530122323'),
('20210528203310'),
('20210528144647'),
('20210528003603'),
('20210527131318'),
('20210527114834'),
('20210526053611'),
('20210525112226'),
('20210517073211'),
('20210517061815'),
('20210513125608'),
('20210512090204'),
('20210429154322'),
('20210429154321'),
('20210429154319'),
('20210426193009'),
('20210420015635'),
('20210414013318'),
('20210409142455'),
('20210406060434'),
('20210403025854'),
('20210328233843'),
('20210324043327'),
('20210323142518'),
('20210318020143'),
('20210315173137'),
('20210311070755'),
('20210311022303'),
('20210308195916'),
('20210308010745'),
('20210302164429'),
('20210225230057'),
('20210224162050'),
('20210219171329'),
('20210218144656'),
('20210218022739'),
('20210218022053'),
('20210215231312'),
('20210207232853'),
('20210204195932'),
('20210204135429'),
('20210203031628'),
('20210201034048'),
('20210131221311'),
('20210128021147'),
('20210127140730'),
('20210127013637'),
('20210126222142'),
('20210125100452'),
('20210121001720'),
('20210120125607'),
('20210119005647'),
('20210111025920'),
('20210108134117'),
('20210107005832'),
('20210106181418'),
('20210105165605'),
('20201229031635'),
('20201223071241'),
('20201218000001'),
('20201218000000'),
('20201217062343'),
('20201217062324'),
('20201217062301'),
('20201210151635'),
('20201210032852'),
('20201117212328'),
('20201116132948'),
('20201112142419'),
('20201111005205'),
('20201110225115'),
('20201110110952'),
('20201109170951'),
('20201105190351'),
('20201103103401'),
('20201102162044'),
('20201027110546'),
('20201009190955'),
('20201008105539'),
('20201007124955'),
('20201006021020'),
('20201005165544'),
('20201003141123'),
('20200926144256'),
('20200918095554'),
('20200917041108'),
('20200916085541'),
('20200911031738'),
('20200910051633'),
('20200910020909'),
('20200903045539'),
('20200902225712'),
('20200902082203'),
('20200902054531'),
('20200820232017'),
('20200820174703'),
('20200819203846'),
('20200819030609'),
('20200819021210'),
('20200818084329'),
('20200814081437'),
('20200813051337'),
('20200813044955'),
('20200812193122'),
('20200811004537'),
('20200810220841'),
('20200810194943'),
('20200810190429'),
('20200810185432'),
('20200810053843'),
('20200809154642'),
('20200805163400'),
('20200805151752'),
('20200805133257'),
('20200805073343'),
('20200804144550'),
('20200730205554'),
('20200729094848'),
('20200729042607'),
('20200728222920'),
('20200728072038'),
('20200728022830'),
('20200728004302'),
('20200728000854'),
('20200727220143'),
('20200724060632'),
('20200718154308'),
('20200717193118'),
('20200715045152'),
('20200715044833'),
('20200715030908'),
('20200714105027'),
('20200714105026'),
('20200713071305'),
('20200710013237'),
('20200709094846'),
('20200709032247'),
('20200708051009'),
('20200708035330'),
('20200707183007'),
('20200707154522'),
('20200707122325'),
('20200706202436'),
('20200703082449'),
('20200618175923'),
('20200617144300'),
('20200611104600'),
('20200610150900'),
('20200602153813'),
('20200601130900'),
('20200601111500'),
('20200525072638'),
('20200524181959'),
('20200522204356'),
('20200522004855'),
('20200520124359'),
('20200520015508'),
('20200520001619'),
('20200518145424'),
('20200517140915'),
('20200514175537'),
('20200513185052'),
('20200512064023'),
('20200511043818'),
('20200508141209'),
('20200507234409'),
('20200506044956'),
('20200505060712'),
('20200430072846'),
('20200430010528'),
('20200429095035'),
('20200429095034'),
('20200429045956'),
('20200428102014'),
('20200428014005'),
('20200427222624'),
('20200424032633'),
('20200417183143'),
('20200415140830'),
('20200409181607'),
('20200409120815'),
('20200409102643'),
('20200409102642'),
('20200409102641'),
('20200409102640'),
('20200409102639'),
('20200409033412'),
('20200408121834'),
('20200408121312'),
('20200403100259'),
('20200401172023'),
('20200330233427'),
('20200329222246'),
('20200327195549'),
('20200327164420'),
('20200320193612'),
('20200312233001'),
('20200312122846'),
('20200311135425'),
('20200310200000'),
('20200306060737'),
('20200302120829'),
('20200227073837'),
('20200226183018'),
('20200203061927'),
('20200130115859'),
('20200121120800'),
('20200120140900'),
('20200120131338'),
('20200117174646'),
('20200117172135'),
('20200117141138'),
('20200116140132'),
('20200116092259'),
('20200109130028'),
('20200107161405'),
('20191230055237'),
('20191220134101'),
('20191219112000'),
('20191217035630'),
('20191211170000'),
('20191211152404'),
('20191209095548'),
('20191206123012'),
('20191205100434'),
('20191203014808'),
('20191202202212'),
('20191129144706'),
('20191128222140'),
('20191120015344'),
('20191119174425'),
('20191114160613'),
('20191113193141'),
('20191108000414'),
('20191107190330'),
('20191107032231'),
('20191107025140'),
('20191107025041'),
('20191101113230'),
('20191101001705'),
('20191031052711'),
('20191031042212'),
('20191030155530'),
('20191030112559'),
('20191025005204'),
('20191022161944'),
('20191022155215'),
('20191017044811'),
('20191016124059'),
('20191014224419'),
('20191013212445'),
('20191011131041'),
('20191008124357'),
('20191007140446'),
('20190917100006'),
('20190908234054'),
('20190908233325'),
('20190904104533'),
('20190903073730'),
('20190820192341'),
('20190817010201'),
('20190817010101'),
('20190812141433'),
('20190807194043'),
('20190731090219'),
('20190725020422'),
('20190724200243'),
('20190724181542'),
('20190724162522'),
('20190724055909'),
('20190718152804'),
('20190718144722'),
('20190717133743'),
('20190716173854'),
('20190716124050'),
('20190716014949'),
('20190711154946'),
('20190705173948'),
('20190704133453'),
('20190630165003'),
('20190625085735'),
('20190621095105'),
('20190618183340'),
('20190618174229'),
('20190617035051'),
('20190603134013'),
('20190603112536'),
('20190601000001'),
('20190531101648'),
('20190531044744'),
('20190529002752'),
('20190523093215'),
('20190522194332'),
('20190514055014'),
('20190513143015'),
('20190508193900'),
('20190508141824'),
('20190508141327'),
('20190508135348'),
('20190503180839'),
('20190503145428'),
('20190502223613'),
('20190430135846'),
('20190427211829'),
('20190426123658'),
('20190426123026'),
('20190426074404'),
('20190426011148'),
('20190424065841'),
('20190423112954'),
('20190422200243'),
('20190418113814'),
('20190417203622'),
('20190417135049'),
('20190414162753'),
('20190412161430'),
('20190411144545'),
('20190411121312'),
('20190410122835'),
('20190410102915'),
('20190410055459'),
('20190409054736'),
('20190408082101'),
('20190408072550'),
('20190405044140'),
('20190403202001'),
('20190403180142'),
('20190402142223'),
('20190402024053'),
('20190327205525'),
('20190327090918'),
('20190326123708'),
('20190325162154'),
('20190322152347'),
('20190321072029'),
('20190320104640'),
('20190320091323'),
('20190315174428'),
('20190315170411'),
('20190314144755'),
('20190314082018'),
('20190313205652'),
('20190313171338'),
('20190313134642'),
('20190312194528'),
('20190312181641'),
('20190306184409'),
('20190306154335'),
('20190304170931'),
('20190227210035'),
('20190227150413'),
('20190225133654'),
('20190215204033'),
('20190208144706'),
('20190205104116'),
('20190130163001'),
('20190130163000'),
('20190130013015'),
('20190125153345'),
('20190125103246'),
('20190123171817'),
('20190122132732'),
('20190121203023'),
('20190121202656'),
('20190117191606'),
('20190111183409'),
('20190111170824'),
('20190110212005'),
('20190110201340'),
('20190108110630'),
('20190106041015'),
('20190103185626'),
('20190103160533'),
('20190103065652'),
('20190103060819'),
('20190103051737'),
('20181221121805'),
('20181220115844'),
('20181218071253'),
('20181210122522'),
('20181207141900'),
('20181204193426'),
('20181204123042'),
('20181129094518'),
('20181128140547'),
('20181120140552'),
('20181112013117'),
('20181108115009'),
('20181031165343'),
('20181012123001'),
('20181010150631'),
('20181005144357'),
('20181005084357'),
('20180928105835'),
('20180927135248'),
('20180920042415'),
('20180920023559'),
('20180917034056'),
('20180917024729'),
('20180916195601'),
('20180913200027'),
('20180907075713'),
('20180831182853'),
('20180828065005'),
('20180827053514'),
('20180820080623'),
('20180820073549'),
('20180813074843'),
('20180812150839'),
('20180803085321'),
('20180729092926'),
('20180727042448'),
('20180724070554'),
('20180720054856'),
('20180719103905'),
('20180718062728'),
('20180717084758'),
('20180717025038'),
('20180716200103'),
('20180716140323'),
('20180716072125'),
('20180716062405'),
('20180716062012'),
('20180710172959'),
('20180710075119'),
('20180706054922'),
('20180621013807'),
('20180607095414'),
('20180521191418'),
('20180521190040'),
('20180521184439'),
('20180521175611'),
('20180519053933'),
('20180514133440'),
('20180508142711'),
('20180425185749'),
('20180425152503'),
('20180420141134'),
('20180419095326'),
('20180331125522'),
('20180328180317'),
('20180323161659'),
('20180323154826'),
('20180320190339'),
('20180316165104'),
('20180316092939'),
('20180309014014'),
('20180308071922'),
('20180223222415'),
('20180223041147'),
('20180221215641'),
('20180207163946'),
('20180207161422'),
('20180131052859'),
('20180127005644'),
('20180125185717'),
('20180118215249'),
('20180111092141'),
('20180109222722'),
('20171228122834'),
('20171220181249'),
('20171214040346'),
('20171213105921'),
('20171128172835'),
('20171123200157'),
('20171115170858'),
('20171113214725'),
('20171113175414'),
('20171110174413'),
('20171026014317'),
('20171006030028'),
('20171003180951'),
('20170831180419'),
('20170824172615'),
('20170823173427'),
('20170818191909'),
('20170803123704'),
('20170731075604'),
('20170728012754'),
('20170725075535'),
('20170717084947'),
('20170713164357'),
('20170704142141'),
('20170703144855'),
('20170703115216'),
('20170630083540'),
('20170628152322'),
('20170609115401'),
('20170605014820'),
('20170602132735'),
('20170515203721'),
('20170515152725'),
('20170512185227'),
('20170512153318'),
('20170511184842'),
('20170511080007'),
('20170511071355'),
('20170508183819'),
('20170505035229'),
('20170501191912'),
('20170425172415'),
('20170425083011'),
('20170420163628'),
('20170419193714'),
('20170417164715'),
('20170413043152'),
('20170410170923'),
('20170407154510'),
('20170403062717'),
('20170330041605'),
('20170328203122'),
('20170328163918'),
('20170324144456'),
('20170324032913'),
('20170322191305'),
('20170322155537'),
('20170322065911'),
('20170313192741'),
('20170308201552'),
('20170307181800'),
('20170303070706'),
('20170301215150'),
('20170227211458'),
('20170222173036'),
('20170221204204'),
('20170215151505'),
('20170213180857'),
('20170201085745'),
('20170124181409'),
('20161216101352'),
('20161215201907'),
('20161213073938'),
('20161212123649'),
('20161208064834'),
('20161207030057'),
('20161205065743'),
('20161205001727'),
('20161202034856'),
('20161202011139'),
('20161124020918'),
('20161102024920'),
('20161102024900'),
('20161102024838'),
('20161102024818'),
('20161102024700'),
('20161031183811'),
('20161029181306'),
('20161025083648'),
('20161014171034'),
('20161013012136'),
('20161010230853'),
('20160930123330'),
('20160920165833'),
('20160919054014'),
('20160919003141'),
('20160906200439'),
('20160905092148'),
('20160905091958'),
('20160905085445'),
('20160905084502'),
('20160905082248'),
('20160905082217'),
('20160826195018'),
('20160823171911'),
('20160816063534'),
('20160816052836'),
('20160815210156'),
('20160815002002'),
('20160727233044'),
('20160725015749'),
('20160722071221'),
('20160719002225'),
('20160716112354'),
('20160707195549'),
('20160627104436'),
('20160615165447'),
('20160615024524'),
('20160609203508'),
('20160607213656'),
('20160606204319'),
('20160602164008'),
('20160530203810'),
('20160530003739'),
('20160527191614'),
('20160527015355'),
('20160520022627'),
('20160514100852'),
('20160503205953'),
('20160427202222'),
('20160425141954'),
('20160420172330'),
('20160418065403'),
('20160408175727'),
('20160408131959'),
('20160407180149'),
('20160407160756'),
('20160405172827'),
('20160329101122'),
('20160326001747'),
('20160321164925'),
('20160317201955'),
('20160317174357'),
('20160309073132'),
('20160308193142'),
('20160307190919'),
('20160303234317'),
('20160303183607'),
('20160302170230'),
('20160302104253'),
('20160302063432'),
('20160225095306'),
('20160225050320'),
('20160225050319'),
('20160225050318'),
('20160225050317'),
('20160224033122'),
('20160215075528'),
('20160206210202'),
('20160201181320'),
('20160127222802'),
('20160127105314'),
('20160118233631'),
('20160118174335'),
('20160113160742'),
('20160112104733'),
('20160112101818'),
('20160112025852'),
('20160110053003'),
('20160108051129'),
('20151220232725'),
('20151219045559'),
('20151218232200'),
('20151214165852'),
('20151201161726'),
('20151201035631'),
('20151127011837'),
('20151126233623'),
('20151126173356'),
('20151125194322'),
('20151124192339'),
('20151124172631'),
('20151117165756'),
('20151113205046'),
('20151109124147'),
('20151107042241'),
('20151107041044'),
('20151105181635'),
('20151103233815'),
('20151016163051'),
('20150925000915'),
('20150924022040'),
('20150918004206'),
('20150917071017'),
('20150914034541'),
('20150914021445'),
('20150901192313'),
('20150828155137'),
('20150822141540'),
('20150818190757'),
('20150806210727'),
('20150802233112'),
('20150731225331'),
('20150730154830'),
('20150729150523'),
('20150728210202'),
('20150728004647'),
('20150727230537'),
('20150727210748'),
('20150727210019'),
('20150727193414'),
('20150724182342'),
('20150724165259'),
('20150713203955'),
('20150709021818'),
('20150707163251'),
('20150706215111'),
('20150702201926'),
('20150617234511'),
('20150617233018'),
('20150617080349'),
('20150609163211'),
('20150525151759'),
('20150514043155'),
('20150514023016'),
('20150513094042'),
('20150505044154'),
('20150501152228'),
('20150422160235'),
('20150421190714'),
('20150421085850'),
('20150410002551'),
('20150410002033'),
('20150325190959'),
('20150325183400'),
('20150324184222'),
('20150323234856'),
('20150323062322'),
('20150323034933'),
('20150318143915'),
('20150306050437'),
('20150301224250'),
('20150227043622'),
('20150224004420'),
('20150213174159'),
('20150206004143'),
('20150205172051'),
('20150205032808'),
('20150203041207'),
('20150129204520'),
('20150123145128'),
('20150119192813'),
('20150115172310'),
('20150114093325'),
('20150112172259'),
('20150112172258'),
('20150108221703'),
('20150108211557'),
('20150108202057'),
('20150108002354'),
('20150106215342'),
('20150102113309'),
('20141228151019'),
('20141223145058'),
('20141222230707'),
('20141222224220'),
('20141222051622'),
('20141211114517'),
('20141120043401'),
('20141120035016'),
('20141118011735'),
('20141110150304'),
('20141030222425'),
('20141020174120'),
('20141020164816'),
('20141020154935'),
('20141020153415'),
('20141016183307'),
('20141015060145'),
('20141014191645'),
('20141014032859'),
('20141008192526'),
('20141008192525'),
('20141008181228'),
('20141008152953'),
('20141007224814'),
('20141002181613'),
('20141001101041'),
('20140929204155'),
('20140929181930'),
('20140925173220'),
('20140924192418'),
('20140923042349'),
('20140913192733'),
('20140911065449'),
('20140910130155'),
('20140908191429'),
('20140908165716'),
('20140905171733'),
('20140905055251'),
('20140904215629'),
('20140904160015'),
('20140904055702'),
('20140831191346'),
('20140828200231'),
('20140828172407'),
('20140827044811'),
('20140826234625'),
('20140818023700'),
('20140817011612'),
('20140815215618'),
('20140815191556'),
('20140815183851'),
('20140813175357'),
('20140811094300'),
('20140809224243'),
('20140808051823'),
('20140807033123'),
('20140806003116'),
('20140805061612'),
('20140804075613'),
('20140804072504'),
('20140804060439'),
('20140804030041'),
('20140804010803'),
('20140801170444'),
('20140801052028'),
('20140731011328'),
('20140730203029'),
('20140729092525'),
('20140728152804'),
('20140728144308'),
('20140728120708'),
('20140727030954'),
('20140725172830'),
('20140725050636'),
('20140723011456'),
('20140721162307'),
('20140721161249'),
('20140721063820'),
('20140718041445'),
('20140717024528'),
('20140716063802'),
('20140715190552'),
('20140715160720'),
('20140715055242'),
('20140715051412'),
('20140715013018'),
('20140714060646'),
('20140711233329'),
('20140711193923'),
('20140711143146'),
('20140711063215'),
('20140710224658'),
('20140710005023'),
('20140707071913'),
('20140705081453'),
('20140703022838'),
('20140627193814'),
('20140624044600'),
('20140623195618'),
('20140620184031'),
('20140618163511'),
('20140618001820'),
('20140617193351'),
('20140617080955'),
('20140617053829'),
('20140612010718'),
('20140610034314'),
('20140610012833'),
('20140610012414'),
('20140607035234'),
('20140604145431'),
('20140530043913'),
('20140530002535'),
('20140529045508'),
('20140528015354'),
('20140527233225'),
('20140527163207'),
('20140526201939'),
('20140526185749'),
('20140525233953'),
('20140522003151'),
('20140521220115'),
('20140521192142'),
('20140520063859'),
('20140520062826'),
('20140515220111'),
('20140508053815'),
('20140507173327'),
('20140506200235'),
('20140505145918'),
('20140504174212'),
('20140429175951'),
('20140425172618'),
('20140425135354'),
('20140425125742'),
('20140422195623'),
('20140421235646'),
('20140416235757'),
('20140416202801'),
('20140416202746'),
('20140415054717'),
('20140408152401'),
('20140408061512'),
('20140407202158'),
('20140407055830'),
('20140404143501'),
('20140402201432'),
('20140320042653'),
('20140318203559'),
('20140318150412'),
('20140306223522'),
('20140305100909'),
('20140304201403'),
('20140304200606'),
('20140303185354'),
('20140228205743'),
('20140228173431'),
('20140228005443'),
('20140227201005'),
('20140227104930'),
('20140224232913'),
('20140224232712'),
('20140220163213'),
('20140220160510'),
('20140214151255'),
('20140211234523'),
('20140211230222'),
('20140210194146'),
('20140206215029'),
('20140206195001'),
('20140206044818'),
('20140129164541'),
('20140124202427'),
('20140122043508'),
('20140121204628'),
('20140120155706'),
('20140116170655'),
('20140109205940'),
('20140107220141'),
('20140102194802'),
('20140102104229'),
('20140101235747'),
('20131230010239'),
('20131229221725'),
('20131227164338'),
('20131223171005'),
('20131219203905'),
('20131217174004'),
('20131216164557'),
('20131212225511'),
('20131210234530'),
('20131210181901'),
('20131210163702'),
('20131209091742'),
('20131209091702'),
('20131206200009'),
('20131122064921'),
('20131120055018'),
('20131118173159'),
('20131115165105'),
('20131114185225'),
('20131107154900'),
('20131105101051'),
('20131023163509'),
('20131022151218'),
('20131022045114'),
('20131018050738'),
('20131017205954'),
('20131017030605'),
('20131017014509'),
('20131015131652'),
('20131014203951'),
('20131003061137'),
('20131002070347'),
('20131001060630'),
('20130917174738'),
('20130913210454'),
('20130912185218'),
('20130911182437'),
('20130910220317'),
('20130910040235'),
('20130906171631'),
('20130906081326'),
('20130904181208'),
('20130903154323'),
('20130828192526'),
('20130826011521'),
('20130823201420'),
('20130822213513'),
('20130820174431'),
('20130819192358'),
('20130816024250'),
('20130813224817'),
('20130813204212'),
('20130809211409'),
('20130809204732'),
('20130809160751'),
('20130807202516'),
('20130731163035'),
('20130728172550'),
('20130725213613'),
('20130724201552'),
('20130723212758'),
('20130712163509'),
('20130712041133'),
('20130710201248'),
('20130709184941'),
('20130625201113'),
('20130625170842'),
('20130625022454'),
('20130624203206'),
('20130622110348'),
('20130621042855'),
('20130619063902'),
('20130617181804'),
('20130617180009'),
('20130617014127'),
('20130616082327'),
('20130615075557'),
('20130615073305'),
('20130615064344'),
('20130613212230'),
('20130613211700'),
('20130612200846'),
('20130610201033'),
('20130606190601'),
('20130603192412'),
('20130531210816'),
('20130528174147'),
('20130527152648'),
('20130522193615'),
('20130521210140'),
('20130515193551'),
('20130509041351'),
('20130509040248'),
('20130508040235'),
('20130506185042'),
('20130506020935'),
('20130501105651'),
('20130430052751'),
('20130429000101'),
('20130428194335'),
('20130426052257'),
('20130426044914'),
('20130424055025'),
('20130424015746'),
('20130422050626'),
('20130419195746'),
('20130416170855'),
('20130416004933'),
('20130416004607'),
('20130412020156'),
('20130412015502'),
('20130411205132'),
('20130404232558'),
('20130404143437'),
('20130402210723'),
('20130328182433'),
('20130328162943'),
('20130327185852'),
('20130326210101'),
('20130322183614'),
('20130321154905'),
('20130320024345'),
('20130320012100'),
('20130319122248'),
('20130315180637'),
('20130314093434'),
('20130313004922'),
('20130311181327'),
('20130306180148'),
('20130226015336'),
('20130221215017'),
('20130213203300'),
('20130213021450'),
('20130208220635'),
('20130207200019'),
('20130205021905'),
('20130204000159'),
('20130203204338'),
('20130201023409'),
('20130201000828'),
('20130131055710'),
('20130130154611'),
('20130129174845'),
('20130129163244'),
('20130129010625'),
('20130128182013'),
('20130127213646'),
('20130125031122'),
('20130125030305'),
('20130125002652'),
('20130123070909'),
('20130122232825'),
('20130122051134'),
('20130121231352'),
('20130120222728'),
('20130116151829'),
('20130115043603'),
('20130115021937'),
('20130115012140'),
('20130108195847'),
('20130107165207'),
('20121228192219'),
('20121224100650'),
('20121224095139'),
('20121224072204'),
('20121218205642'),
('20121216230719'),
('20121211233131'),
('20121207000741'),
('20121205162143'),
('20121204193747'),
('20121204183855'),
('20121203181719'),
('20121202225421'),
('20121130191818'),
('20121130010400'),
('20121129184948'),
('20121129160035'),
('20121123063630'),
('20121123054127'),
('20121122033316'),
('20121121205215'),
('20121121202035'),
('20121119200843'),
('20121119190529'),
('20121116212424'),
('20121115172544'),
('20121113200845'),
('20121113200844'),
('20121109164630'),
('20121108193516'),
('20121106015500'),
('20121018182709'),
('20121018133039'),
('20121018103721'),
('20121017162924'),
('20121011155904'),
('20121009161116'),
('20120928170023'),
('20120925190802'),
('20120925171620'),
('20120924182031'),
('20120924182000'),
('20120921163606'),
('20120921162512'),
('20120921155050'),
('20120921055428'),
('20120919152846'),
('20120918205931'),
('20120918152319'),
('20120910171504'),
('20120830182736'),
('20120828204624'),
('20120828204209'),
('20120824171908'),
('20120823205956'),
('20120821191616'),
('20120820191804'),
('20120816205538'),
('20120816205537'),
('20120816050526'),
('20120815204733'),
('20120815180106'),
('20120815004411'),
('20120813201426'),
('20120813042912'),
('20120813004347'),
('20120812235417'),
('20120810064839'),
('20120809201855'),
('20120809175110'),
('20120809174649'),
('20120809154750'),
('20120809053414'),
('20120809030647'),
('20120809020415'),
('20120807223020'),
('20120806062617'),
('20120806030641'),
('20120803191426'),
('20120802151210'),
('20120727213543'),
('20120727150428'),
('20120727005556'),
('20120726235129'),
('20120726201830'),
('20120725183347'),
('20120724234711'),
('20120724234502'),
('20120723051512'),
('20120720162422'),
('20120720044246'),
('20120720013733'),
('20120719004636'),
('20120718044955'),
('20120716173544'),
('20120716020835'),
('20120713201324'),
('20120712151934'),
('20120712150500'),
('20120708210305'),
('20120705181724'),
('20120704201743'),
('20120704160659'),
('20120703210004'),
('20120703203623'),
('20120703201312'),
('20120703184734'),
('20120702211427'),
('20120629182637'),
('20120629151243'),
('20120629150253'),
('20120629143908'),
('20120625195326'),
('20120625174544'),
('20120625162318'),
('20120625145714'),
('20120622200242'),
('20120621190310'),
('20120621155351'),
('20120619172714'),
('20120619153349'),
('20120619150807'),
('20120618214856'),
('20120618212349'),
('20120618152946'),
('20120615180517'),
('20120614202024'),
('20120614190726'),
('20120530212912'),
('20120530200724'),
('20120530160745'),
('20120530150726'),
('20120529202707'),
('20120529175956'),
('20120525194845'),
('20120523201329'),
('20120523184307'),
('20120523180723'),
('20120519182212'),
('20120518200115'),
('20120517200130'),
('20120514204934'),
('20120514173920'),
('20120514144549'),
('20120507144222'),
('20120507144132'),
('20120503205521'),
('20120502192121'),
('20120502183240'),
('20120427172031'),
('20120427154330'),
('20120427151452'),
('20120427150624'),
('20120425145456'),
('20120423151548'),
('20120423142820'),
('20120423140906'),
('20120420183447'),
('20120416201606'),
('20120311210245'),
('20120311201341'),
('20120311170118'),
('20120311164326'),
('20120311163914'),
('20000225050318');

