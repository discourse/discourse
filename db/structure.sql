SET statement_timeout = 0;
SET lock_timeout = 0;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;

-- Name: discourse_functions; Type: SCHEMA

CREATE SCHEMA discourse_functions;

-- Name: plpgsql; Type: EXTENSION

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;

-- Name: EXTENSION plpgsql; Type: COMMENT

-- Name: hstore; Type: EXTENSION

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;

-- Name: EXTENSION hstore; Type: COMMENT

-- Name: pg_trgm; Type: EXTENSION

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

-- Name: EXTENSION pg_trgm; Type: COMMENT

-- Name: raise_topic_status_updates_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -

CREATE FUNCTION discourse_functions.raise_topic_status_updates_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: topic_status_updates is read only';
  END
$$;

-- Name: raise_user_profiles_card_background_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -

CREATE FUNCTION discourse_functions.raise_user_profiles_card_background_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: card_background in user_profiles is readonly';
  END
$$;

-- Name: raise_user_profiles_profile_background_readonly(); Type: FUNCTION; Schema: discourse_functions; Owner: -

CREATE FUNCTION discourse_functions.raise_user_profiles_profile_background_readonly() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    RAISE EXCEPTION 'Discourse: profile_background in user_profiles is readonly';
  END
$$;

SET default_tablespace = '';

SET default_with_oids = false;

-- Name: api_keys; Type: TABLE

CREATE TABLE public.api_keys (
    id SERIAL PRIMARY KEY,
    key character varying(64) NOT NULL,
    user_id integer,
    created_by_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    allowed_ips inet[],
    hidden boolean DEFAULT false NOT NULL
);

-- Name: application_requests; Type: TABLE

CREATE TABLE public.application_requests (
    id SERIAL PRIMARY KEY,
    date date NOT NULL,
    req_type integer NOT NULL,
    count integer DEFAULT 0 NOT NULL
);

-- Name: ar_internal_metadata; Type: TABLE

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: badge_groupings; Type: TABLE

CREATE TABLE public.badge_groupings (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    "position" integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: categories; Type: TABLE

CREATE TABLE public.categories (
    id SERIAL PRIMARY KEY,
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
    suppress_from_latest boolean DEFAULT false,
    minimum_required_tags integer DEFAULT 0 NOT NULL,
    navigate_to_first_post_after_read boolean DEFAULT false NOT NULL,
    search_priority integer DEFAULT 0,
    allow_global_tags boolean DEFAULT false NOT NULL,
    reviewable_by_group_id integer
);

-- Name: posts; Type: TABLE

CREATE TABLE public.posts (
    id SERIAL PRIMARY KEY,
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
    avg_time integer,
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
    image_url character varying,
    locked_by_id integer
);

-- Name: TABLE posts; Type: COMMENT

COMMENT ON TABLE public.posts IS 'If you want to query public posts only, use the badge_posts view.';

-- Name: COLUMN posts.post_number; Type: COMMENT

COMMENT ON COLUMN public.posts.post_number IS 'The position of this post in the topic. The pair (topic_id, post_number) forms a natural key on the posts table.';

-- Name: COLUMN posts.raw; Type: COMMENT

COMMENT ON COLUMN public.posts.raw IS 'The raw Markdown that the user entered into the composer.';

-- Name: COLUMN posts.cooked; Type: COMMENT

COMMENT ON COLUMN public.posts.cooked IS 'The processed HTML that is presented in a topic.';

-- Name: COLUMN posts.reply_to_post_number; Type: COMMENT

COMMENT ON COLUMN public.posts.reply_to_post_number IS 'If this post is a reply to another, this column is the post_number of the post it''s replying to. [FKEY posts.topic_id, posts.post_number]';

-- Name: COLUMN posts.reply_quoted; Type: COMMENT

COMMENT ON COLUMN public.posts.reply_quoted IS 'This column is true if the post contains a quote-reply, which causes the in-reply-to indicator to be absent.';

-- Name: topics; Type: TABLE

CREATE TABLE public.topics (
    id SERIAL PRIMARY KEY,
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
    avg_time integer,
    deleted_at timestamp without time zone,
    highest_post_number integer DEFAULT 0 NOT NULL,
    image_url character varying,
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
    excerpt character varying(1000),
    pinned_globally boolean DEFAULT false NOT NULL,
    pinned_until timestamp without time zone,
    fancy_title character varying(400),
    highest_staff_post_number integer DEFAULT 0 NOT NULL,
    featured_link character varying,
    reviewable_score double precision DEFAULT 0.0 NOT NULL,
    CONSTRAINT has_category_id CHECK (((category_id IS NOT NULL) OR ((archetype)::text <> 'regular'::text))),
    CONSTRAINT pm_has_no_category CHECK (((category_id IS NULL) OR ((archetype)::text <> 'private_message'::text)))
);

-- Name: TABLE topics; Type: COMMENT

COMMENT ON TABLE public.topics IS 'To query public topics only: SELECT ... FROM topics t LEFT INNER JOIN categories c ON (t.category_id = c.id AND c.read_restricted = false)';

-- Name: badge_posts; Type: VIEW

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
    p.avg_time,
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
    p.image_url,
    p.locked_by_id
   FROM ((public.posts p
     JOIN public.topics t ON ((t.id = p.topic_id)))
     JOIN public.categories c ON ((c.id = t.category_id)))
  WHERE (c.allow_badges AND (p.deleted_at IS NULL) AND (t.deleted_at IS NULL) AND (NOT c.read_restricted) AND t.visible AND (p.post_type = ANY (ARRAY[1, 2, 3])));

-- Name: badge_types; Type: TABLE

CREATE TABLE public.badge_types (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: badges; Type: TABLE

CREATE TABLE public.badges (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    description text,
    badge_type_id integer NOT NULL,
    grant_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    allow_title boolean DEFAULT false NOT NULL,
    multiple_grant boolean DEFAULT false NOT NULL,
    icon character varying DEFAULT 'fa-certificate'::character varying,
    listable boolean DEFAULT true,
    target_posts boolean DEFAULT false,
    query text,
    enabled boolean DEFAULT true NOT NULL,
    auto_revoke boolean DEFAULT true NOT NULL,
    badge_grouping_id integer DEFAULT 5 NOT NULL,
    trigger integer,
    show_posts boolean DEFAULT false NOT NULL,
    system boolean DEFAULT false NOT NULL,
    image character varying(255),
    long_description text
);

CREATE SEQUENCE public.badges_id_seq
    AS integer
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Name: categories_web_hooks; Type: TABLE

CREATE TABLE public.categories_web_hooks (
    web_hook_id integer NOT NULL,
    category_id integer NOT NULL
);

-- Name: category_custom_fields; Type: TABLE

CREATE TABLE public.category_custom_fields (
    id SERIAL PRIMARY KEY,
    category_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: category_featured_topics; Type: TABLE

CREATE TABLE public.category_featured_topics (
    category_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    rank integer DEFAULT 0 NOT NULL,
    id SERIAL PRIMARY KEY
);

-- Name: category_groups; Type: TABLE

CREATE TABLE public.category_groups (
    id SERIAL PRIMARY KEY,
    category_id integer NOT NULL,
    group_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    permission_type integer DEFAULT 1
);

-- Name: category_search_data; Type: TABLE

CREATE TABLE public.category_search_data (
    category_id integer NOT NULL,
    search_data tsvector,
    raw_data text,
    locale text,
    version integer DEFAULT 0
);

-- Name: category_tag_groups; Type: TABLE

CREATE TABLE public.category_tag_groups (
    id SERIAL PRIMARY KEY,
    category_id integer NOT NULL,
    tag_group_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: category_tag_stats; Type: TABLE

CREATE TABLE public.category_tag_stats (
    id BIGSERIAL PRIMARY KEY,
    category_id bigint NOT NULL,
    tag_id bigint NOT NULL,
    topic_count integer DEFAULT 0 NOT NULL
);

-- Name: category_tags; Type: TABLE

CREATE TABLE public.category_tags (
    id SERIAL PRIMARY KEY,
    category_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: category_users; Type: TABLE

CREATE TABLE public.category_users (
    id SERIAL PRIMARY KEY,
    category_id integer NOT NULL,
    user_id integer NOT NULL,
    notification_level integer NOT NULL
);

-- Name: child_themes; Type: TABLE

CREATE TABLE public.child_themes (
    id SERIAL PRIMARY KEY,
    parent_theme_id integer,
    child_theme_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: color_scheme_colors; Type: TABLE

CREATE TABLE public.color_scheme_colors (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    hex character varying NOT NULL,
    color_scheme_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: color_schemes; Type: TABLE

CREATE TABLE public.color_schemes (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    via_wizard boolean DEFAULT false NOT NULL,
    base_scheme_id character varying,
    theme_id integer
);

-- Name: custom_emojis; Type: TABLE

CREATE TABLE public.custom_emojis (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    upload_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: developers; Type: TABLE

CREATE TABLE public.developers (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL
);

-- Name: directory_items; Type: TABLE

CREATE TABLE public.directory_items (
    id SERIAL PRIMARY KEY,
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
    posts_read integer DEFAULT 0 NOT NULL
);

-- Name: draft_sequences; Type: TABLE

CREATE TABLE public.draft_sequences (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    draft_key character varying NOT NULL,
    sequence integer NOT NULL
);

-- Name: drafts; Type: TABLE

CREATE TABLE public.drafts (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    draft_key character varying NOT NULL,
    data text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    sequence integer DEFAULT 0 NOT NULL,
    revisions integer DEFAULT 1 NOT NULL
);

-- Name: email_change_requests; Type: TABLE

CREATE TABLE public.email_change_requests (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    old_email character varying NOT NULL,
    new_email character varying NOT NULL,
    old_email_token_id integer,
    new_email_token_id integer,
    change_state integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: email_logs; Type: TABLE

CREATE TABLE public.email_logs (
    id SERIAL PRIMARY KEY,
    to_address character varying NOT NULL,
    email_type character varying NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    post_id integer,
    bounce_key uuid,
    bounced boolean DEFAULT false NOT NULL,
    message_id character varying
);

-- Name: email_tokens; Type: TABLE

CREATE TABLE public.email_tokens (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    email character varying NOT NULL,
    token character varying NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    expired boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: embeddable_hosts; Type: TABLE

CREATE TABLE public.embeddable_hosts (
    id SERIAL PRIMARY KEY,
    host character varying NOT NULL,
    category_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    path_whitelist character varying,
    class_name character varying
);

-- Name: github_user_infos; Type: TABLE

CREATE TABLE public.github_user_infos (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    screen_name character varying NOT NULL,
    github_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: given_daily_likes; Type: TABLE

CREATE TABLE public.given_daily_likes (
    user_id integer NOT NULL,
    likes_given integer NOT NULL,
    given_date date NOT NULL,
    limit_reached boolean DEFAULT false NOT NULL
);

-- Name: google_user_infos; Type: TABLE

CREATE TABLE public.google_user_infos (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    google_user_id character varying NOT NULL,
    first_name character varying,
    last_name character varying,
    email character varying,
    gender character varying,
    name character varying,
    link character varying,
    profile_link character varying,
    picture character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: group_archived_messages; Type: TABLE

CREATE TABLE public.group_archived_messages (
    id SERIAL PRIMARY KEY,
    group_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: group_custom_fields; Type: TABLE

CREATE TABLE public.group_custom_fields (
    id SERIAL PRIMARY KEY,
    group_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: group_histories; Type: TABLE

CREATE TABLE public.group_histories (
    id SERIAL PRIMARY KEY,
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

-- Name: group_mentions; Type: TABLE

CREATE TABLE public.group_mentions (
    id SERIAL PRIMARY KEY,
    post_id integer,
    group_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: group_requests; Type: TABLE

CREATE TABLE public.group_requests (
    id BIGSERIAL PRIMARY KEY,
    group_id integer,
    user_id integer,
    reason text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: group_users; Type: TABLE

CREATE TABLE public.group_users (
    id SERIAL PRIMARY KEY,
    group_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    owner boolean DEFAULT false NOT NULL,
    notification_level integer DEFAULT 2 NOT NULL
);

-- Name: groups; Type: TABLE

CREATE TABLE public.groups (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    automatic boolean DEFAULT false NOT NULL,
    user_count integer DEFAULT 0 NOT NULL,
    automatic_membership_email_domains text,
    automatic_membership_retroactive boolean DEFAULT false,
    primary_group boolean DEFAULT false NOT NULL,
    title character varying,
    grant_trust_level integer,
    incoming_email character varying,
    has_messages boolean DEFAULT false NOT NULL,
    flair_url character varying,
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
    mentionable_level integer DEFAULT 0
);

CREATE SEQUENCE public.groups_id_seq
    AS integer
    START WITH 100
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Name: groups_web_hooks; Type: TABLE

CREATE TABLE public.groups_web_hooks (
    web_hook_id integer NOT NULL,
    group_id integer NOT NULL
);

-- Name: ignored_users; Type: TABLE

CREATE TABLE public.ignored_users (
    id BIGSERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    ignored_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    summarized_at timestamp without time zone,
    expiring_at timestamp without time zone
);

-- Name: incoming_domains; Type: TABLE

CREATE TABLE public.incoming_domains (
    id SERIAL PRIMARY KEY,
    name character varying(100) NOT NULL,
    https boolean DEFAULT false NOT NULL,
    port integer NOT NULL
);

-- Name: incoming_emails; Type: TABLE

CREATE TABLE public.incoming_emails (
    id SERIAL PRIMARY KEY,
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
    is_bounce boolean DEFAULT false NOT NULL
);

-- Name: incoming_links; Type: TABLE

CREATE TABLE public.incoming_links (
    id SERIAL PRIMARY KEY,
    created_at timestamp without time zone NOT NULL,
    user_id integer,
    ip_address inet,
    current_user_id integer,
    post_id integer NOT NULL,
    incoming_referer_id integer
);

-- Name: incoming_referers; Type: TABLE

CREATE TABLE public.incoming_referers (
    id SERIAL PRIMARY KEY,
    path character varying(1000) NOT NULL,
    incoming_domain_id integer NOT NULL
);

-- Name: instagram_user_infos; Type: TABLE

CREATE TABLE public.instagram_user_infos (
    id SERIAL PRIMARY KEY,
    user_id integer,
    screen_name character varying,
    instagram_user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: invited_groups; Type: TABLE

CREATE TABLE public.invited_groups (
    id SERIAL PRIMARY KEY,
    group_id integer,
    invite_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: invites; Type: TABLE

CREATE TABLE public.invites (
    id SERIAL PRIMARY KEY,
    invite_key character varying(32) NOT NULL,
    email character varying,
    invited_by_id integer NOT NULL,
    user_id integer,
    redeemed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by_id integer,
    invalidated_at timestamp without time zone,
    moderator boolean DEFAULT false NOT NULL,
    custom_message text,
    via_email boolean DEFAULT false NOT NULL
);

-- Name: javascript_caches; Type: TABLE

CREATE TABLE public.javascript_caches (
    id BIGSERIAL PRIMARY KEY,
    theme_field_id bigint NOT NULL,
    digest character varying,
    content text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: message_bus; Type: TABLE

CREATE TABLE public.message_bus (
    id SERIAL PRIMARY KEY,
    name character varying,
    context character varying,
    data text,
    created_at timestamp without time zone NOT NULL
);

-- Name: muted_users; Type: TABLE

CREATE TABLE public.muted_users (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    muted_user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: notifications; Type: TABLE

CREATE TABLE public.notifications (
    id SERIAL PRIMARY KEY,
    notification_type integer NOT NULL,
    user_id integer NOT NULL,
    data character varying(1000) NOT NULL,
    read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    topic_id integer,
    post_number integer,
    post_action_id integer
);

-- Name: oauth2_user_infos; Type: TABLE

CREATE TABLE public.oauth2_user_infos (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    uid character varying NOT NULL,
    provider character varying NOT NULL,
    email character varying,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: onceoff_logs; Type: TABLE

CREATE TABLE public.onceoff_logs (
    id SERIAL PRIMARY KEY,
    job_name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: optimized_images; Type: TABLE

CREATE TABLE public.optimized_images (
    id SERIAL PRIMARY KEY,
    sha1 character varying(40) NOT NULL,
    extension character varying(10) NOT NULL,
    width integer NOT NULL,
    height integer NOT NULL,
    upload_id integer NOT NULL,
    url character varying NOT NULL,
    filesize integer,
    etag character varying,
    version integer
);

-- Name: permalinks; Type: TABLE

CREATE TABLE public.permalinks (
    id SERIAL PRIMARY KEY,
    url character varying(1000) NOT NULL,
    topic_id integer,
    post_id integer,
    category_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_url character varying(1000)
);

-- Name: plugin_store_rows; Type: TABLE

CREATE TABLE public.plugin_store_rows (
    id SERIAL PRIMARY KEY,
    plugin_name character varying NOT NULL,
    key character varying NOT NULL,
    type_name character varying NOT NULL,
    value text
);

-- Name: poll_options; Type: TABLE

CREATE TABLE public.poll_options (
    id BIGSERIAL PRIMARY KEY,
    poll_id bigint,
    digest character varying NOT NULL,
    html text NOT NULL,
    anonymous_votes integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: poll_votes; Type: TABLE

CREATE TABLE public.poll_votes (
    poll_id bigint,
    poll_option_id bigint,
    user_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: polls; Type: TABLE

CREATE TABLE public.polls (
    id BIGSERIAL PRIMARY KEY,
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
    updated_at timestamp without time zone NOT NULL
);

-- Name: post_action_types; Type: TABLE

CREATE TABLE public.post_action_types (
    name_key character varying(50) NOT NULL,
    is_flag boolean DEFAULT false NOT NULL,
    icon character varying(20),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id SERIAL PRIMARY KEY,
    "position" integer DEFAULT 0 NOT NULL,
    score_bonus double precision DEFAULT 0.0 NOT NULL
);

-- Name: post_actions; Type: TABLE

CREATE TABLE public.post_actions (
    id SERIAL PRIMARY KEY,
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

-- Name: post_custom_fields; Type: TABLE

CREATE TABLE public.post_custom_fields (
    id SERIAL PRIMARY KEY,
    post_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: post_details; Type: TABLE

CREATE TABLE public.post_details (
    id SERIAL PRIMARY KEY,
    post_id integer,
    key character varying,
    value character varying,
    extra text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: post_replies; Type: TABLE

CREATE TABLE public.post_replies (
    post_id integer,
    reply_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: post_reply_keys; Type: TABLE

CREATE TABLE public.post_reply_keys (
    id BIGSERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    reply_key uuid NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: post_revisions; Type: TABLE

CREATE TABLE public.post_revisions (
    id SERIAL PRIMARY KEY,
    user_id integer,
    post_id integer,
    modifications text,
    number integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    hidden boolean DEFAULT false NOT NULL
);

-- Name: post_search_data; Type: TABLE

CREATE TABLE public.post_search_data (
    post_id integer NOT NULL,
    search_data tsvector,
    raw_data text,
    locale character varying,
    version integer DEFAULT 0
);

-- Name: post_stats; Type: TABLE

CREATE TABLE public.post_stats (
    id SERIAL PRIMARY KEY,
    post_id integer,
    drafts_saved integer,
    typing_duration_msecs integer,
    composer_open_duration_msecs integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: post_timings; Type: TABLE

CREATE TABLE public.post_timings (
    topic_id integer NOT NULL,
    post_number integer NOT NULL,
    user_id integer NOT NULL,
    msecs integer NOT NULL
);

-- Name: post_uploads; Type: TABLE

CREATE TABLE public.post_uploads (
    id SERIAL PRIMARY KEY,
    post_id integer NOT NULL,
    upload_id integer NOT NULL
);

-- Name: push_subscriptions; Type: TABLE

CREATE TABLE public.push_subscriptions (
    id BIGSERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    data character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: quoted_posts; Type: TABLE

CREATE TABLE public.quoted_posts (
    id SERIAL PRIMARY KEY,
    post_id integer NOT NULL,
    quoted_post_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: remote_themes; Type: TABLE

CREATE TABLE public.remote_themes (
    id SERIAL PRIMARY KEY,
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
    maximum_discourse_version character varying
);

-- Name: reviewable_claimed_topics; Type: TABLE

CREATE TABLE public.reviewable_claimed_topics (
    id BIGSERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: reviewable_histories; Type: TABLE

CREATE TABLE public.reviewable_histories (
    id BIGSERIAL PRIMARY KEY,
    reviewable_id integer NOT NULL,
    reviewable_history_type integer NOT NULL,
    status integer NOT NULL,
    created_by_id integer NOT NULL,
    edited json,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: reviewable_scores; Type: TABLE

CREATE TABLE public.reviewable_scores (
    id BIGSERIAL PRIMARY KEY,
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
    reason character varying
);

-- Name: reviewables; Type: TABLE

CREATE TABLE public.reviewables (
    id BIGSERIAL PRIMARY KEY,
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
    updated_at timestamp without time zone NOT NULL
);

-- Name: scheduler_stats; Type: TABLE

CREATE TABLE public.scheduler_stats (
    id SERIAL PRIMARY KEY,
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

-- Name: schema_migration_details; Type: TABLE

CREATE TABLE public.schema_migration_details (
    id SERIAL PRIMARY KEY,
    version character varying NOT NULL,
    name character varying,
    hostname character varying,
    git_version character varying,
    rails_version character varying,
    duration integer,
    direction character varying,
    created_at timestamp without time zone NOT NULL
);

-- Name: schema_migrations; Type: TABLE

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);

-- Name: screened_emails; Type: TABLE

CREATE TABLE public.screened_emails (
    id SERIAL PRIMARY KEY,
    email character varying NOT NULL,
    action_type integer NOT NULL,
    match_count integer DEFAULT 0 NOT NULL,
    last_match_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    ip_address inet
);

-- Name: screened_ip_addresses; Type: TABLE

CREATE TABLE public.screened_ip_addresses (
    id SERIAL PRIMARY KEY,
    ip_address inet NOT NULL,
    action_type integer NOT NULL,
    match_count integer DEFAULT 0 NOT NULL,
    last_match_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: screened_urls; Type: TABLE

CREATE TABLE public.screened_urls (
    id SERIAL PRIMARY KEY,
    url character varying NOT NULL,
    domain character varying NOT NULL,
    action_type integer NOT NULL,
    match_count integer DEFAULT 0 NOT NULL,
    last_match_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    ip_address inet
);

-- Name: search_logs; Type: TABLE

CREATE TABLE public.search_logs (
    id SERIAL PRIMARY KEY,
    term character varying NOT NULL,
    user_id integer,
    ip_address inet,
    search_result_id integer,
    search_type integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    search_result_type integer
);

-- Name: shared_drafts; Type: TABLE

CREATE TABLE public.shared_drafts (
    topic_id integer NOT NULL,
    category_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    id BIGSERIAL PRIMARY KEY
);

-- Name: single_sign_on_records; Type: TABLE

CREATE TABLE public.single_sign_on_records (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    external_id character varying NOT NULL,
    last_payload text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    external_username character varying,
    external_email character varying,
    external_name character varying,
    external_avatar_url character varying(1000),
    external_profile_background_url character varying,
    external_card_background_url character varying
);

-- Name: site_settings; Type: TABLE

CREATE TABLE public.site_settings (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    data_type integer NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: skipped_email_logs; Type: TABLE

CREATE TABLE public.skipped_email_logs (
    id BIGSERIAL PRIMARY KEY,
    email_type character varying NOT NULL,
    to_address character varying NOT NULL,
    user_id integer,
    post_id integer,
    reason_type integer NOT NULL,
    custom_reason text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: stylesheet_cache; Type: TABLE

CREATE TABLE public.stylesheet_cache (
    id SERIAL PRIMARY KEY,
    target character varying NOT NULL,
    digest character varying NOT NULL,
    content text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    theme_id integer DEFAULT '-1'::integer NOT NULL,
    source_map text
);

-- Name: tag_group_memberships; Type: TABLE

CREATE TABLE public.tag_group_memberships (
    id SERIAL PRIMARY KEY,
    tag_id integer NOT NULL,
    tag_group_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: tag_group_permissions; Type: TABLE

CREATE TABLE public.tag_group_permissions (
    id BIGSERIAL PRIMARY KEY,
    tag_group_id bigint NOT NULL,
    group_id bigint NOT NULL,
    permission_type integer DEFAULT 1 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: tag_groups; Type: TABLE

CREATE TABLE public.tag_groups (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    parent_tag_id integer,
    one_per_topic boolean DEFAULT false
);

-- Name: tag_search_data; Type: TABLE

CREATE TABLE public.tag_search_data (
    tag_id integer NOT NULL,
    search_data tsvector,
    raw_data text,
    locale text,
    version integer DEFAULT 0
);

-- Name: tag_users; Type: TABLE

CREATE TABLE public.tag_users (
    id SERIAL PRIMARY KEY,
    tag_id integer NOT NULL,
    user_id integer NOT NULL,
    notification_level integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: tags; Type: TABLE

CREATE TABLE public.tags (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    topic_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    pm_topic_count integer DEFAULT 0 NOT NULL
);

-- Name: tags_web_hooks; Type: TABLE

CREATE TABLE public.tags_web_hooks (
    web_hook_id bigint NOT NULL,
    tag_id bigint NOT NULL
);

-- Name: theme_fields; Type: TABLE

CREATE TABLE public.theme_fields (
    id SERIAL PRIMARY KEY,
    theme_id integer NOT NULL,
    target_id integer NOT NULL,
    name character varying(255) NOT NULL,
    value text NOT NULL,
    value_baked text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    compiler_version integer DEFAULT 0 NOT NULL,
    error character varying,
    upload_id integer,
    type_id integer DEFAULT 0 NOT NULL
);

-- Name: theme_settings; Type: TABLE

CREATE TABLE public.theme_settings (
    id BIGSERIAL PRIMARY KEY,
    name character varying(255) NOT NULL,
    data_type integer NOT NULL,
    value text,
    theme_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: theme_translation_overrides; Type: TABLE

CREATE TABLE public.theme_translation_overrides (
    id BIGSERIAL PRIMARY KEY,
    theme_id integer NOT NULL,
    locale character varying NOT NULL,
    translation_key character varying NOT NULL,
    value character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: themes; Type: TABLE

CREATE TABLE public.themes (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    compiler_version integer DEFAULT 0 NOT NULL,
    user_selectable boolean DEFAULT false NOT NULL,
    hidden boolean DEFAULT false NOT NULL,
    color_scheme_id integer,
    remote_theme_id integer,
    component boolean DEFAULT false NOT NULL
);

-- Name: top_topics; Type: TABLE

CREATE TABLE public.top_topics (
    id SERIAL PRIMARY KEY,
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

-- Name: topic_allowed_groups; Type: TABLE

CREATE TABLE public.topic_allowed_groups (
    id SERIAL PRIMARY KEY,
    group_id integer NOT NULL,
    topic_id integer NOT NULL
);

-- Name: topic_allowed_users; Type: TABLE

CREATE TABLE public.topic_allowed_users (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: topic_custom_fields; Type: TABLE

CREATE TABLE public.topic_custom_fields (
    id SERIAL PRIMARY KEY,
    topic_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: topic_embeds; Type: TABLE

CREATE TABLE public.topic_embeds (
    id SERIAL PRIMARY KEY,
    topic_id integer NOT NULL,
    post_id integer NOT NULL,
    embed_url character varying(1000) NOT NULL,
    content_sha1 character varying(40),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by_id integer
);

-- Name: topic_invites; Type: TABLE

CREATE TABLE public.topic_invites (
    id SERIAL PRIMARY KEY,
    topic_id integer NOT NULL,
    invite_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: topic_link_clicks; Type: TABLE

CREATE TABLE public.topic_link_clicks (
    id SERIAL PRIMARY KEY,
    topic_link_id integer NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    ip_address inet
);

-- Name: topic_links; Type: TABLE

CREATE TABLE public.topic_links (
    id SERIAL PRIMARY KEY,
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
    link_post_id integer,
    title character varying,
    crawled_at timestamp without time zone,
    quote boolean DEFAULT false NOT NULL,
    extension character varying(10)
);

-- Name: topic_search_data; Type: TABLE

CREATE TABLE public.topic_search_data (
    topic_id integer NOT NULL,
    raw_data text,
    locale character varying NOT NULL,
    search_data tsvector,
    version integer DEFAULT 0
);

-- Name: topic_tags; Type: TABLE

CREATE TABLE public.topic_tags (
    id SERIAL PRIMARY KEY,
    topic_id integer NOT NULL,
    tag_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: topic_timers; Type: TABLE

CREATE TABLE public.topic_timers (
    id SERIAL PRIMARY KEY,
    execute_at timestamp without time zone NOT NULL,
    status_type integer NOT NULL,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    based_on_last_post boolean DEFAULT false NOT NULL,
    deleted_at timestamp without time zone,
    deleted_by_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    category_id integer,
    public_type boolean DEFAULT true
);

-- Name: topic_users; Type: TABLE

CREATE TABLE public.topic_users (
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    posted boolean DEFAULT false NOT NULL,
    last_read_post_number integer,
    highest_seen_post_number integer,
    last_visited_at timestamp without time zone,
    first_visited_at timestamp without time zone,
    notification_level integer DEFAULT 1 NOT NULL,
    notifications_changed_at timestamp without time zone,
    notifications_reason_id integer,
    total_msecs_viewed integer DEFAULT 0 NOT NULL,
    cleared_pinned_at timestamp without time zone,
    id SERIAL PRIMARY KEY,
    last_emailed_post_number integer,
    liked boolean DEFAULT false,
    bookmarked boolean DEFAULT false
);

-- Name: topic_views; Type: TABLE

CREATE TABLE public.topic_views (
    topic_id integer NOT NULL,
    viewed_at date NOT NULL,
    user_id integer,
    ip_address inet
);

-- Name: translation_overrides; Type: TABLE

CREATE TABLE public.translation_overrides (
    id SERIAL PRIMARY KEY,
    locale character varying NOT NULL,
    translation_key character varying NOT NULL,
    value character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    compiled_js text
);

-- Name: unsubscribe_keys; Type: TABLE

CREATE TABLE public.unsubscribe_keys (
    key character varying(64) NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    unsubscribe_key_type character varying,
    topic_id integer,
    post_id integer
);

-- Name: uploads; Type: TABLE

CREATE TABLE public.uploads (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    original_filename character varying NOT NULL,
    filesize integer NOT NULL,
    width integer,
    height integer,
    url character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    sha1 character varying(40),
    origin character varying(1000),
    retain_hours integer,
    extension character varying(10),
    thumbnail_width integer,
    thumbnail_height integer,
    etag character varying
);

-- Name: user_actions; Type: TABLE

CREATE TABLE public.user_actions (
    id SERIAL PRIMARY KEY,
    action_type integer NOT NULL,
    user_id integer NOT NULL,
    target_topic_id integer,
    target_post_id integer,
    target_user_id integer,
    acting_user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: user_api_keys; Type: TABLE

CREATE TABLE public.user_api_keys (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    client_id character varying NOT NULL,
    key character varying NOT NULL,
    application_name character varying NOT NULL,
    push_url character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    revoked_at timestamp without time zone,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    last_used_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Name: user_archived_messages; Type: TABLE

CREATE TABLE public.user_archived_messages (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    topic_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: user_associated_accounts; Type: TABLE

CREATE TABLE public.user_associated_accounts (
    id BIGSERIAL PRIMARY KEY,
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

-- Name: user_auth_token_logs; Type: TABLE

CREATE TABLE public.user_auth_token_logs (
    id SERIAL PRIMARY KEY,
    action character varying NOT NULL,
    user_auth_token_id integer,
    user_id integer,
    client_ip inet,
    user_agent character varying,
    auth_token character varying,
    created_at timestamp without time zone,
    path character varying
);

-- Name: user_auth_tokens; Type: TABLE

CREATE TABLE public.user_auth_tokens (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    auth_token character varying NOT NULL,
    prev_auth_token character varying NOT NULL,
    user_agent character varying,
    auth_token_seen boolean DEFAULT false NOT NULL,
    client_ip inet,
    rotated_at timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    seen_at timestamp without time zone
);

-- Name: user_avatars; Type: TABLE

CREATE TABLE public.user_avatars (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    custom_upload_id integer,
    gravatar_upload_id integer,
    last_gravatar_download_attempt timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: user_badges; Type: TABLE

CREATE TABLE public.user_badges (
    id SERIAL PRIMARY KEY,
    badge_id integer NOT NULL,
    user_id integer NOT NULL,
    granted_at timestamp without time zone NOT NULL,
    granted_by_id integer NOT NULL,
    post_id integer,
    notification_id integer,
    seq integer DEFAULT 0 NOT NULL
);

-- Name: user_custom_fields; Type: TABLE

CREATE TABLE public.user_custom_fields (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    name character varying(256) NOT NULL,
    value text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: user_emails; Type: TABLE

CREATE TABLE public.user_emails (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    email character varying(513) NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: user_exports; Type: TABLE

CREATE TABLE public.user_exports (
    id SERIAL PRIMARY KEY,
    file_name character varying NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    upload_id integer
);

-- Name: user_field_options; Type: TABLE

CREATE TABLE public.user_field_options (
    id SERIAL PRIMARY KEY,
    user_field_id integer NOT NULL,
    value character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: user_fields; Type: TABLE

CREATE TABLE public.user_fields (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL,
    field_type character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    editable boolean DEFAULT false NOT NULL,
    description character varying NOT NULL,
    required boolean DEFAULT true NOT NULL,
    show_on_profile boolean DEFAULT false NOT NULL,
    "position" integer DEFAULT 0,
    show_on_user_card boolean DEFAULT false NOT NULL,
    external_name character varying,
    external_type character varying
);

-- Name: user_histories; Type: TABLE

CREATE TABLE public.user_histories (
    id SERIAL PRIMARY KEY,
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
    category_id integer
);

-- Name: user_open_ids; Type: TABLE

CREATE TABLE public.user_open_ids (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    email character varying NOT NULL,
    url character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    active boolean NOT NULL
);

-- Name: user_options; Type: TABLE

CREATE TABLE public.user_options (
    user_id integer NOT NULL,
    mailing_list_mode boolean DEFAULT false NOT NULL,
    email_digests boolean,
    external_links_in_new_tab boolean DEFAULT false NOT NULL,
    enable_quoting boolean DEFAULT true NOT NULL,
    dynamic_favicon boolean DEFAULT false NOT NULL,
    disable_jump_reply boolean DEFAULT false NOT NULL,
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
    title_count_mode_key integer DEFAULT 0 NOT NULL
);

-- Name: user_profile_views; Type: TABLE

CREATE TABLE public.user_profile_views (
    id SERIAL PRIMARY KEY,
    user_profile_id integer NOT NULL,
    viewed_at timestamp without time zone NOT NULL,
    ip_address inet,
    user_id integer
);

-- Name: user_profiles; Type: TABLE

CREATE TABLE public.user_profiles (
    user_id integer NOT NULL,
    location character varying,
    website character varying,
    bio_raw text,
    bio_cooked text,
    profile_background character varying(255),
    dismissed_banner_key integer,
    bio_cooked_version integer,
    badge_granted_title boolean DEFAULT false,
    card_background character varying(255),
    views integer DEFAULT 0 NOT NULL,
    profile_background_upload_id integer,
    card_background_upload_id integer
);

-- Name: user_search_data; Type: TABLE

CREATE TABLE public.user_search_data (
    user_id integer NOT NULL,
    search_data tsvector,
    raw_data text,
    locale text,
    version integer DEFAULT 0
);

-- Name: user_second_factors; Type: TABLE

CREATE TABLE public.user_second_factors (
    id BIGSERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    method integer NOT NULL,
    data character varying NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    last_used timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: user_stats; Type: TABLE

CREATE TABLE public.user_stats (
    user_id integer NOT NULL,
    topics_entered integer DEFAULT 0 NOT NULL,
    time_read integer DEFAULT 0 NOT NULL,
    days_visited integer DEFAULT 0 NOT NULL,
    posts_read_count integer DEFAULT 0 NOT NULL,
    likes_given integer DEFAULT 0 NOT NULL,
    likes_received integer DEFAULT 0 NOT NULL,
    topic_reply_count integer DEFAULT 0 NOT NULL,
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
    first_unread_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Name: user_uploads; Type: TABLE

CREATE TABLE public.user_uploads (
    id BIGSERIAL PRIMARY KEY,
    upload_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL
);

-- Name: user_visits; Type: TABLE

CREATE TABLE public.user_visits (
    id SERIAL PRIMARY KEY,
    user_id integer NOT NULL,
    visited_at date NOT NULL,
    posts_read integer DEFAULT 0,
    mobile boolean DEFAULT false,
    time_read integer DEFAULT 0 NOT NULL
);

-- Name: user_warnings; Type: TABLE

CREATE TABLE public.user_warnings (
    id SERIAL PRIMARY KEY,
    topic_id integer NOT NULL,
    user_id integer NOT NULL,
    created_by_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: users; Type: TABLE

CREATE TABLE public.users (
    id SERIAL PRIMARY KEY,
    username character varying(60) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    name character varying,
    seen_notification_id integer DEFAULT 0 NOT NULL,
    last_posted_at timestamp without time zone,
    password_hash character varying(64),
    salt character varying(32),
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
    manual_locked_trust_level integer
);

-- Name: watched_words; Type: TABLE

CREATE TABLE public.watched_words (
    id SERIAL PRIMARY KEY,
    word character varying NOT NULL,
    action integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);

-- Name: web_crawler_requests; Type: TABLE

CREATE TABLE public.web_crawler_requests (
    id BIGSERIAL PRIMARY KEY,
    date date NOT NULL,
    user_agent character varying NOT NULL,
    count integer DEFAULT 0 NOT NULL
);

-- Name: web_hook_event_types; Type: TABLE

CREATE TABLE public.web_hook_event_types (
    id SERIAL PRIMARY KEY,
    name character varying NOT NULL
);

-- Name: web_hook_event_types_hooks; Type: TABLE

CREATE TABLE public.web_hook_event_types_hooks (
    web_hook_id integer NOT NULL,
    web_hook_event_type_id integer NOT NULL
);

-- Name: web_hook_events; Type: TABLE

CREATE TABLE public.web_hook_events (
    id SERIAL PRIMARY KEY,
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

-- Name: web_hooks; Type: TABLE

CREATE TABLE public.web_hooks (
    id SERIAL PRIMARY KEY,
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

-- Name: tag_search_data tag_id; Type: DEFAULT

ALTER TABLE ONLY public.tag_search_data ALTER COLUMN tag_id SET DEFAULT nextval('public.tag_search_data_tag_id_seq'::regclass);

-- Name: topic_search_data topic_id; Type: DEFAULT

ALTER TABLE ONLY public.topic_search_data ALTER COLUMN topic_id SET DEFAULT nextval('public.topic_search_data_topic_id_seq'::regclass);

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);

ALTER TABLE ONLY public.category_search_data
    ADD CONSTRAINT categories_search_pkey PRIMARY KEY (category_id);

ALTER TABLE ONLY public.unsubscribe_keys
    ADD CONSTRAINT digest_unsubscribe_keys_pkey PRIMARY KEY (key);

ALTER TABLE ONLY public.post_search_data
    ADD CONSTRAINT posts_search_pkey PRIMARY KEY (post_id);

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);

ALTER TABLE ONLY public.tag_search_data
    ADD CONSTRAINT tag_search_data_pkey PRIMARY KEY (tag_id);

ALTER TABLE ONLY public.topic_search_data
    ADD CONSTRAINT topic_search_data_pkey PRIMARY KEY (topic_id);

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.user_search_data
    ADD CONSTRAINT users_search_pkey PRIMARY KEY (user_id);

-- Name: associated_accounts_provider_uid; Type: INDEX

CREATE UNIQUE INDEX associated_accounts_provider_uid ON public.user_associated_accounts USING btree (provider_name, provider_uid);

-- Name: associated_accounts_provider_user; Type: INDEX

CREATE UNIQUE INDEX associated_accounts_provider_user ON public.user_associated_accounts USING btree (provider_name, user_id);

-- Name: by_link; Type: INDEX

CREATE INDEX by_link ON public.topic_link_clicks USING btree (topic_link_id);

-- Name: cat_featured_threads; Type: INDEX

CREATE UNIQUE INDEX cat_featured_threads ON public.category_featured_topics USING btree (category_id, topic_id);

-- Name: idx_category_tag_groups_ix1; Type: INDEX

CREATE UNIQUE INDEX idx_category_tag_groups_ix1 ON public.category_tag_groups USING btree (category_id, tag_group_id);

-- Name: idx_category_tags_ix1; Type: INDEX

CREATE UNIQUE INDEX idx_category_tags_ix1 ON public.category_tags USING btree (category_id, tag_id);

-- Name: idx_category_tags_ix2; Type: INDEX

CREATE UNIQUE INDEX idx_category_tags_ix2 ON public.category_tags USING btree (tag_id, category_id);

-- Name: idx_category_users_u1; Type: INDEX

CREATE UNIQUE INDEX idx_category_users_u1 ON public.category_users USING btree (user_id, category_id, notification_level);

-- Name: idx_category_users_u2; Type: INDEX

CREATE UNIQUE INDEX idx_category_users_u2 ON public.category_users USING btree (category_id, user_id, notification_level);

-- Name: idx_notifications_speedup_unread_count; Type: INDEX

CREATE INDEX idx_notifications_speedup_unread_count ON public.notifications USING btree (user_id, notification_type) WHERE (NOT read);

-- Name: idx_post_custom_fields_akismet; Type: INDEX

CREATE INDEX idx_post_custom_fields_akismet ON public.post_custom_fields USING btree (post_id) WHERE (((name)::text = 'AKISMET_STATE'::text) AND (value = 'needs_review'::text));

-- Name: idx_posts_created_at_topic_id; Type: INDEX

CREATE INDEX idx_posts_created_at_topic_id ON public.posts USING btree (created_at, topic_id) WHERE (deleted_at IS NULL);

-- Name: idx_posts_deleted_posts; Type: INDEX

CREATE INDEX idx_posts_deleted_posts ON public.posts USING btree (topic_id, post_number) WHERE (deleted_at IS NOT NULL);

-- Name: idx_posts_user_id_deleted_at; Type: INDEX

CREATE INDEX idx_posts_user_id_deleted_at ON public.posts USING btree (user_id) WHERE (deleted_at IS NULL);

-- Name: idx_search_category; Type: INDEX

CREATE INDEX idx_search_category ON public.category_search_data USING gin (search_data);

-- Name: idx_search_post; Type: INDEX

CREATE INDEX idx_search_post ON public.post_search_data USING gin (search_data);

-- Name: idx_search_tag; Type: INDEX

CREATE INDEX idx_search_tag ON public.tag_search_data USING gin (search_data);

-- Name: idx_search_topic; Type: INDEX

CREATE INDEX idx_search_topic ON public.topic_search_data USING gin (search_data);

-- Name: idx_search_user; Type: INDEX

CREATE INDEX idx_search_user ON public.user_search_data USING gin (search_data);

-- Name: idx_tag_users_ix1; Type: INDEX

CREATE UNIQUE INDEX idx_tag_users_ix1 ON public.tag_users USING btree (user_id, tag_id, notification_level);

-- Name: idx_tag_users_ix2; Type: INDEX

CREATE UNIQUE INDEX idx_tag_users_ix2 ON public.tag_users USING btree (tag_id, user_id, notification_level);

-- Name: idx_topic_id_public_type_deleted_at; Type: INDEX

CREATE UNIQUE INDEX idx_topic_id_public_type_deleted_at ON public.topic_timers USING btree (topic_id) WHERE ((public_type = true) AND (deleted_at IS NULL));

-- Name: idx_topics_front_page; Type: INDEX

CREATE INDEX idx_topics_front_page ON public.topics USING btree (deleted_at, visible, archetype, category_id, id);

-- Name: idx_topics_user_id_deleted_at; Type: INDEX

CREATE INDEX idx_topics_user_id_deleted_at ON public.topics USING btree (user_id) WHERE (deleted_at IS NULL);

-- Name: idx_unique_actions; Type: INDEX

CREATE UNIQUE INDEX idx_unique_actions ON public.post_actions USING btree (user_id, post_action_type_id, post_id, targets_topic) WHERE ((deleted_at IS NULL) AND (disagreed_at IS NULL) AND (deferred_at IS NULL));

-- Name: idx_unique_flags; Type: INDEX

CREATE UNIQUE INDEX idx_unique_flags ON public.post_actions USING btree (user_id, post_id, targets_topic) WHERE ((deleted_at IS NULL) AND (disagreed_at IS NULL) AND (deferred_at IS NULL) AND (post_action_type_id = ANY (ARRAY[3, 4, 7, 8])));

-- Name: idx_unique_post_uploads; Type: INDEX

CREATE UNIQUE INDEX idx_unique_post_uploads ON public.post_uploads USING btree (post_id, upload_id);

-- Name: idx_unique_rows; Type: INDEX

CREATE UNIQUE INDEX idx_unique_rows ON public.user_actions USING btree (action_type, user_id, target_topic_id, target_post_id, acting_user_id);

-- Name: idx_user_actions_speed_up_user_all; Type: INDEX

CREATE INDEX idx_user_actions_speed_up_user_all ON public.user_actions USING btree (user_id, created_at, action_type);

-- Name: idx_user_custom_fields_last_reminded_at; Type: INDEX

CREATE UNIQUE INDEX idx_user_custom_fields_last_reminded_at ON public.user_custom_fields USING btree (name, user_id) WHERE ((name)::text = 'last_reminded_at'::text);

-- Name: idx_users_admin; Type: INDEX

CREATE INDEX idx_users_admin ON public.users USING btree (id) WHERE admin;

-- Name: idx_users_moderator; Type: INDEX

CREATE INDEX idx_users_moderator ON public.users USING btree (id) WHERE moderator;

-- Name: idx_web_hook_event_types_hooks_on_ids; Type: INDEX

CREATE UNIQUE INDEX idx_web_hook_event_types_hooks_on_ids ON public.web_hook_event_types_hooks USING btree (web_hook_event_type_id, web_hook_id);

-- Name: idxtopicslug; Type: INDEX

CREATE INDEX idxtopicslug ON public.topics USING btree (slug) WHERE ((deleted_at IS NULL) AND (slug IS NOT NULL));

-- Name: index_api_keys_on_key; Type: INDEX

CREATE INDEX index_api_keys_on_key ON public.api_keys USING btree (key);

-- Name: index_api_keys_on_user_id; Type: INDEX

CREATE UNIQUE INDEX index_api_keys_on_user_id ON public.api_keys USING btree (user_id);

-- Name: index_application_requests_on_date_and_req_type; Type: INDEX

CREATE UNIQUE INDEX index_application_requests_on_date_and_req_type ON public.application_requests USING btree (date, req_type);

-- Name: index_badge_types_on_name; Type: INDEX

CREATE UNIQUE INDEX index_badge_types_on_name ON public.badge_types USING btree (name);

-- Name: index_badges_on_badge_type_id; Type: INDEX

CREATE INDEX index_badges_on_badge_type_id ON public.badges USING btree (badge_type_id);

-- Name: index_badges_on_name; Type: INDEX

CREATE UNIQUE INDEX index_badges_on_name ON public.badges USING btree (name);

-- Name: index_categories_on_email_in; Type: INDEX

CREATE UNIQUE INDEX index_categories_on_email_in ON public.categories USING btree (email_in);

-- Name: index_categories_on_reviewable_by_group_id; Type: INDEX

CREATE INDEX index_categories_on_reviewable_by_group_id ON public.categories USING btree (reviewable_by_group_id);

-- Name: index_categories_on_search_priority; Type: INDEX

CREATE INDEX index_categories_on_search_priority ON public.categories USING btree (search_priority);

-- Name: index_categories_on_topic_count; Type: INDEX

CREATE INDEX index_categories_on_topic_count ON public.categories USING btree (topic_count);

-- Name: index_categories_web_hooks_on_web_hook_id_and_category_id; Type: INDEX

CREATE UNIQUE INDEX index_categories_web_hooks_on_web_hook_id_and_category_id ON public.categories_web_hooks USING btree (web_hook_id, category_id);

-- Name: index_category_custom_fields_on_category_id_and_name; Type: INDEX

CREATE INDEX index_category_custom_fields_on_category_id_and_name ON public.category_custom_fields USING btree (category_id, name);

-- Name: index_category_featured_topics_on_category_id_and_rank; Type: INDEX

CREATE INDEX index_category_featured_topics_on_category_id_and_rank ON public.category_featured_topics USING btree (category_id, rank);

-- Name: index_category_tag_stats_on_category_id; Type: INDEX

CREATE INDEX index_category_tag_stats_on_category_id ON public.category_tag_stats USING btree (category_id);

-- Name: index_category_tag_stats_on_category_id_and_tag_id; Type: INDEX

CREATE UNIQUE INDEX index_category_tag_stats_on_category_id_and_tag_id ON public.category_tag_stats USING btree (category_id, tag_id);

-- Name: index_category_tag_stats_on_category_id_and_topic_count; Type: INDEX

CREATE INDEX index_category_tag_stats_on_category_id_and_topic_count ON public.category_tag_stats USING btree (category_id, topic_count);

-- Name: index_category_tag_stats_on_tag_id; Type: INDEX

CREATE INDEX index_category_tag_stats_on_tag_id ON public.category_tag_stats USING btree (tag_id);

-- Name: index_child_themes_on_child_theme_id_and_parent_theme_id; Type: INDEX

CREATE UNIQUE INDEX index_child_themes_on_child_theme_id_and_parent_theme_id ON public.child_themes USING btree (child_theme_id, parent_theme_id);

-- Name: index_child_themes_on_parent_theme_id_and_child_theme_id; Type: INDEX

CREATE UNIQUE INDEX index_child_themes_on_parent_theme_id_and_child_theme_id ON public.child_themes USING btree (parent_theme_id, child_theme_id);

-- Name: index_color_scheme_colors_on_color_scheme_id; Type: INDEX

CREATE INDEX index_color_scheme_colors_on_color_scheme_id ON public.color_scheme_colors USING btree (color_scheme_id);

-- Name: index_custom_emojis_on_name; Type: INDEX

CREATE UNIQUE INDEX index_custom_emojis_on_name ON public.custom_emojis USING btree (name);

-- Name: index_directory_items_on_days_visited; Type: INDEX

CREATE INDEX index_directory_items_on_days_visited ON public.directory_items USING btree (days_visited);

-- Name: index_directory_items_on_likes_given; Type: INDEX

CREATE INDEX index_directory_items_on_likes_given ON public.directory_items USING btree (likes_given);

-- Name: index_directory_items_on_likes_received; Type: INDEX

CREATE INDEX index_directory_items_on_likes_received ON public.directory_items USING btree (likes_received);

-- Name: index_directory_items_on_period_type_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_directory_items_on_period_type_and_user_id ON public.directory_items USING btree (period_type, user_id);

-- Name: index_directory_items_on_post_count; Type: INDEX

CREATE INDEX index_directory_items_on_post_count ON public.directory_items USING btree (post_count);

-- Name: index_directory_items_on_posts_read; Type: INDEX

CREATE INDEX index_directory_items_on_posts_read ON public.directory_items USING btree (posts_read);

-- Name: index_directory_items_on_topic_count; Type: INDEX

CREATE INDEX index_directory_items_on_topic_count ON public.directory_items USING btree (topic_count);

-- Name: index_directory_items_on_topics_entered; Type: INDEX

CREATE INDEX index_directory_items_on_topics_entered ON public.directory_items USING btree (topics_entered);

-- Name: index_draft_sequences_on_user_id_and_draft_key; Type: INDEX

CREATE UNIQUE INDEX index_draft_sequences_on_user_id_and_draft_key ON public.draft_sequences USING btree (user_id, draft_key);

-- Name: index_drafts_on_user_id_and_draft_key; Type: INDEX

CREATE INDEX index_drafts_on_user_id_and_draft_key ON public.drafts USING btree (user_id, draft_key);

-- Name: index_email_change_requests_on_user_id; Type: INDEX

CREATE INDEX index_email_change_requests_on_user_id ON public.email_change_requests USING btree (user_id);

-- Name: index_email_logs_on_bounce_key; Type: INDEX

CREATE UNIQUE INDEX index_email_logs_on_bounce_key ON public.email_logs USING btree (bounce_key) WHERE (bounce_key IS NOT NULL);

-- Name: index_email_logs_on_bounced; Type: INDEX

CREATE INDEX index_email_logs_on_bounced ON public.email_logs USING btree (bounced);

-- Name: index_email_logs_on_created_at; Type: INDEX

CREATE INDEX index_email_logs_on_created_at ON public.email_logs USING btree (created_at DESC);

-- Name: index_email_logs_on_message_id; Type: INDEX

CREATE INDEX index_email_logs_on_message_id ON public.email_logs USING btree (message_id);

-- Name: index_email_logs_on_post_id; Type: INDEX

CREATE INDEX index_email_logs_on_post_id ON public.email_logs USING btree (post_id);

-- Name: index_email_logs_on_user_id; Type: INDEX

CREATE INDEX index_email_logs_on_user_id ON public.email_logs USING btree (user_id);

-- Name: index_email_tokens_on_token; Type: INDEX

CREATE UNIQUE INDEX index_email_tokens_on_token ON public.email_tokens USING btree (token);

-- Name: index_email_tokens_on_user_id; Type: INDEX

CREATE INDEX index_email_tokens_on_user_id ON public.email_tokens USING btree (user_id);

-- Name: index_for_rebake_old; Type: INDEX

CREATE INDEX index_for_rebake_old ON public.posts USING btree (id DESC) WHERE (((baked_version IS NULL) OR (baked_version < 2)) AND (deleted_at IS NULL));

-- Name: index_github_user_infos_on_github_user_id; Type: INDEX

CREATE UNIQUE INDEX index_github_user_infos_on_github_user_id ON public.github_user_infos USING btree (github_user_id);

-- Name: index_github_user_infos_on_user_id; Type: INDEX

CREATE UNIQUE INDEX index_github_user_infos_on_user_id ON public.github_user_infos USING btree (user_id);

-- Name: index_given_daily_likes_on_limit_reached_and_user_id; Type: INDEX

CREATE INDEX index_given_daily_likes_on_limit_reached_and_user_id ON public.given_daily_likes USING btree (limit_reached, user_id);

-- Name: index_given_daily_likes_on_user_id_and_given_date; Type: INDEX

CREATE UNIQUE INDEX index_given_daily_likes_on_user_id_and_given_date ON public.given_daily_likes USING btree (user_id, given_date);

-- Name: index_google_user_infos_on_google_user_id; Type: INDEX

CREATE UNIQUE INDEX index_google_user_infos_on_google_user_id ON public.google_user_infos USING btree (google_user_id);

-- Name: index_google_user_infos_on_user_id; Type: INDEX

CREATE UNIQUE INDEX index_google_user_infos_on_user_id ON public.google_user_infos USING btree (user_id);

-- Name: index_group_archived_messages_on_group_id_and_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_group_archived_messages_on_group_id_and_topic_id ON public.group_archived_messages USING btree (group_id, topic_id);

-- Name: index_group_custom_fields_on_group_id_and_name; Type: INDEX

CREATE INDEX index_group_custom_fields_on_group_id_and_name ON public.group_custom_fields USING btree (group_id, name);

-- Name: index_group_histories_on_acting_user_id; Type: INDEX

CREATE INDEX index_group_histories_on_acting_user_id ON public.group_histories USING btree (acting_user_id);

-- Name: index_group_histories_on_action; Type: INDEX

CREATE INDEX index_group_histories_on_action ON public.group_histories USING btree (action);

-- Name: index_group_histories_on_group_id; Type: INDEX

CREATE INDEX index_group_histories_on_group_id ON public.group_histories USING btree (group_id);

-- Name: index_group_histories_on_target_user_id; Type: INDEX

CREATE INDEX index_group_histories_on_target_user_id ON public.group_histories USING btree (target_user_id);

-- Name: index_group_mentions_on_group_id_and_post_id; Type: INDEX

CREATE UNIQUE INDEX index_group_mentions_on_group_id_and_post_id ON public.group_mentions USING btree (group_id, post_id);

-- Name: index_group_mentions_on_post_id_and_group_id; Type: INDEX

CREATE UNIQUE INDEX index_group_mentions_on_post_id_and_group_id ON public.group_mentions USING btree (post_id, group_id);

-- Name: index_group_requests_on_group_id; Type: INDEX

CREATE INDEX index_group_requests_on_group_id ON public.group_requests USING btree (group_id);

-- Name: index_group_requests_on_group_id_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_group_requests_on_group_id_and_user_id ON public.group_requests USING btree (group_id, user_id);

-- Name: index_group_requests_on_user_id; Type: INDEX

CREATE INDEX index_group_requests_on_user_id ON public.group_requests USING btree (user_id);

-- Name: index_group_users_on_group_id_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_group_users_on_group_id_and_user_id ON public.group_users USING btree (group_id, user_id);

-- Name: index_group_users_on_user_id_and_group_id; Type: INDEX

CREATE UNIQUE INDEX index_group_users_on_user_id_and_group_id ON public.group_users USING btree (user_id, group_id);

-- Name: index_groups_on_incoming_email; Type: INDEX

CREATE UNIQUE INDEX index_groups_on_incoming_email ON public.groups USING btree (incoming_email);

-- Name: index_groups_on_name; Type: INDEX

CREATE UNIQUE INDEX index_groups_on_name ON public.groups USING btree (name);

-- Name: index_groups_web_hooks_on_web_hook_id_and_group_id; Type: INDEX

CREATE UNIQUE INDEX index_groups_web_hooks_on_web_hook_id_and_group_id ON public.groups_web_hooks USING btree (web_hook_id, group_id);

-- Name: index_ignored_users_on_ignored_user_id_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_ignored_users_on_ignored_user_id_and_user_id ON public.ignored_users USING btree (ignored_user_id, user_id);

-- Name: index_ignored_users_on_user_id_and_ignored_user_id; Type: INDEX

CREATE UNIQUE INDEX index_ignored_users_on_user_id_and_ignored_user_id ON public.ignored_users USING btree (user_id, ignored_user_id);

-- Name: index_incoming_domains_on_name_and_https_and_port; Type: INDEX

CREATE UNIQUE INDEX index_incoming_domains_on_name_and_https_and_port ON public.incoming_domains USING btree (name, https, port);

-- Name: index_incoming_emails_on_created_at; Type: INDEX

CREATE INDEX index_incoming_emails_on_created_at ON public.incoming_emails USING btree (created_at);

-- Name: index_incoming_emails_on_error; Type: INDEX

CREATE INDEX index_incoming_emails_on_error ON public.incoming_emails USING btree (error);

-- Name: index_incoming_emails_on_message_id; Type: INDEX

CREATE INDEX index_incoming_emails_on_message_id ON public.incoming_emails USING btree (message_id);

-- Name: index_incoming_emails_on_post_id; Type: INDEX

CREATE INDEX index_incoming_emails_on_post_id ON public.incoming_emails USING btree (post_id);

-- Name: index_incoming_emails_on_user_id; Type: INDEX

CREATE INDEX index_incoming_emails_on_user_id ON public.incoming_emails USING btree (user_id) WHERE (user_id IS NOT NULL);

-- Name: index_incoming_links_on_created_at_and_user_id; Type: INDEX

CREATE INDEX index_incoming_links_on_created_at_and_user_id ON public.incoming_links USING btree (created_at, user_id);

-- Name: index_incoming_links_on_post_id; Type: INDEX

CREATE INDEX index_incoming_links_on_post_id ON public.incoming_links USING btree (post_id);

-- Name: index_incoming_referers_on_path_and_incoming_domain_id; Type: INDEX

CREATE UNIQUE INDEX index_incoming_referers_on_path_and_incoming_domain_id ON public.incoming_referers USING btree (path, incoming_domain_id);

-- Name: index_invites_on_email_and_invited_by_id; Type: INDEX

CREATE INDEX index_invites_on_email_and_invited_by_id ON public.invites USING btree (email, invited_by_id);

-- Name: index_invites_on_invite_key; Type: INDEX

CREATE UNIQUE INDEX index_invites_on_invite_key ON public.invites USING btree (invite_key);

-- Name: index_javascript_caches_on_digest; Type: INDEX

CREATE INDEX index_javascript_caches_on_digest ON public.javascript_caches USING btree (digest);

-- Name: index_javascript_caches_on_theme_field_id; Type: INDEX

CREATE INDEX index_javascript_caches_on_theme_field_id ON public.javascript_caches USING btree (theme_field_id);

-- Name: index_message_bus_on_created_at; Type: INDEX

CREATE INDEX index_message_bus_on_created_at ON public.message_bus USING btree (created_at);

-- Name: index_muted_users_on_muted_user_id_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_muted_users_on_muted_user_id_and_user_id ON public.muted_users USING btree (muted_user_id, user_id);

-- Name: index_muted_users_on_user_id_and_muted_user_id; Type: INDEX

CREATE UNIQUE INDEX index_muted_users_on_user_id_and_muted_user_id ON public.muted_users USING btree (user_id, muted_user_id);

-- Name: index_notifications_on_post_action_id; Type: INDEX

CREATE INDEX index_notifications_on_post_action_id ON public.notifications USING btree (post_action_id);

-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX

CREATE INDEX index_notifications_on_user_id_and_created_at ON public.notifications USING btree (user_id, created_at);

-- Name: index_notifications_on_user_id_and_id; Type: INDEX

CREATE UNIQUE INDEX index_notifications_on_user_id_and_id ON public.notifications USING btree (user_id, id) WHERE ((notification_type = 6) AND (NOT read));

-- Name: index_notifications_on_user_id_and_topic_id_and_post_number; Type: INDEX

CREATE INDEX index_notifications_on_user_id_and_topic_id_and_post_number ON public.notifications USING btree (user_id, topic_id, post_number);

-- Name: index_oauth2_user_infos_on_uid_and_provider; Type: INDEX

CREATE UNIQUE INDEX index_oauth2_user_infos_on_uid_and_provider ON public.oauth2_user_infos USING btree (uid, provider);

-- Name: index_onceoff_logs_on_job_name; Type: INDEX

CREATE INDEX index_onceoff_logs_on_job_name ON public.onceoff_logs USING btree (job_name);

-- Name: index_optimized_images_on_etag; Type: INDEX

CREATE INDEX index_optimized_images_on_etag ON public.optimized_images USING btree (etag);

-- Name: index_optimized_images_on_upload_id; Type: INDEX

CREATE INDEX index_optimized_images_on_upload_id ON public.optimized_images USING btree (upload_id);

-- Name: index_optimized_images_on_upload_id_and_width_and_height; Type: INDEX

CREATE UNIQUE INDEX index_optimized_images_on_upload_id_and_width_and_height ON public.optimized_images USING btree (upload_id, width, height);

-- Name: index_permalinks_on_url; Type: INDEX

CREATE UNIQUE INDEX index_permalinks_on_url ON public.permalinks USING btree (url);

-- Name: index_plugin_store_rows_on_plugin_name_and_key; Type: INDEX

CREATE UNIQUE INDEX index_plugin_store_rows_on_plugin_name_and_key ON public.plugin_store_rows USING btree (plugin_name, key);

-- Name: index_poll_options_on_poll_id; Type: INDEX

CREATE INDEX index_poll_options_on_poll_id ON public.poll_options USING btree (poll_id);

-- Name: index_poll_options_on_poll_id_and_digest; Type: INDEX

CREATE UNIQUE INDEX index_poll_options_on_poll_id_and_digest ON public.poll_options USING btree (poll_id, digest);

-- Name: index_poll_votes_on_poll_id; Type: INDEX

CREATE INDEX index_poll_votes_on_poll_id ON public.poll_votes USING btree (poll_id);

-- Name: index_poll_votes_on_poll_id_and_poll_option_id_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_poll_votes_on_poll_id_and_poll_option_id_and_user_id ON public.poll_votes USING btree (poll_id, poll_option_id, user_id);

-- Name: index_poll_votes_on_poll_option_id; Type: INDEX

CREATE INDEX index_poll_votes_on_poll_option_id ON public.poll_votes USING btree (poll_option_id);

-- Name: index_poll_votes_on_user_id; Type: INDEX

CREATE INDEX index_poll_votes_on_user_id ON public.poll_votes USING btree (user_id);

-- Name: index_polls_on_post_id; Type: INDEX

CREATE INDEX index_polls_on_post_id ON public.polls USING btree (post_id);

-- Name: index_polls_on_post_id_and_name; Type: INDEX

CREATE UNIQUE INDEX index_polls_on_post_id_and_name ON public.polls USING btree (post_id, name);

-- Name: index_post_actions_on_post_action_type_id_and_disagreed_at; Type: INDEX

CREATE INDEX index_post_actions_on_post_action_type_id_and_disagreed_at ON public.post_actions USING btree (post_action_type_id, disagreed_at) WHERE (disagreed_at IS NULL);

-- Name: index_post_actions_on_post_id; Type: INDEX

CREATE INDEX index_post_actions_on_post_id ON public.post_actions USING btree (post_id);

-- Name: index_post_actions_on_user_id; Type: INDEX

CREATE INDEX index_post_actions_on_user_id ON public.post_actions USING btree (user_id);

-- Name: index_post_actions_on_user_id_and_post_action_type_id; Type: INDEX

CREATE INDEX index_post_actions_on_user_id_and_post_action_type_id ON public.post_actions USING btree (user_id, post_action_type_id) WHERE (deleted_at IS NULL);

-- Name: index_post_custom_fields_on_name_and_value; Type: INDEX

CREATE INDEX index_post_custom_fields_on_name_and_value ON public.post_custom_fields USING btree (name, "left"(value, 200));

-- Name: index_post_custom_fields_on_notice_args; Type: INDEX

CREATE UNIQUE INDEX index_post_custom_fields_on_notice_args ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'notice_args'::text);

-- Name: index_post_custom_fields_on_notice_type; Type: INDEX

CREATE UNIQUE INDEX index_post_custom_fields_on_notice_type ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'notice_type'::text);

-- Name: index_post_custom_fields_on_post_id; Type: INDEX

CREATE UNIQUE INDEX index_post_custom_fields_on_post_id ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'missing uploads'::text);

-- Name: index_post_custom_fields_on_post_id_and_name; Type: INDEX

CREATE INDEX index_post_custom_fields_on_post_id_and_name ON public.post_custom_fields USING btree (post_id, name);

-- Name: index_post_details_on_post_id_and_key; Type: INDEX

CREATE UNIQUE INDEX index_post_details_on_post_id_and_key ON public.post_details USING btree (post_id, key);

-- Name: index_post_id_where_missing_uploads_ignored; Type: INDEX

CREATE UNIQUE INDEX index_post_id_where_missing_uploads_ignored ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'missing uploads ignored'::text);

-- Name: index_post_replies_on_post_id_and_reply_id; Type: INDEX

CREATE UNIQUE INDEX index_post_replies_on_post_id_and_reply_id ON public.post_replies USING btree (post_id, reply_id);

-- Name: index_post_replies_on_reply_id; Type: INDEX

CREATE INDEX index_post_replies_on_reply_id ON public.post_replies USING btree (reply_id);

-- Name: index_post_reply_keys_on_reply_key; Type: INDEX

CREATE UNIQUE INDEX index_post_reply_keys_on_reply_key ON public.post_reply_keys USING btree (reply_key);

-- Name: index_post_reply_keys_on_user_id_and_post_id; Type: INDEX

CREATE UNIQUE INDEX index_post_reply_keys_on_user_id_and_post_id ON public.post_reply_keys USING btree (user_id, post_id);

-- Name: index_post_revisions_on_post_id; Type: INDEX

CREATE INDEX index_post_revisions_on_post_id ON public.post_revisions USING btree (post_id);

-- Name: index_post_revisions_on_post_id_and_number; Type: INDEX

CREATE INDEX index_post_revisions_on_post_id_and_number ON public.post_revisions USING btree (post_id, number);

-- Name: index_post_search_data_on_post_id_and_version_and_locale; Type: INDEX

CREATE INDEX index_post_search_data_on_post_id_and_version_and_locale ON public.post_search_data USING btree (post_id, version, locale);

-- Name: index_post_stats_on_post_id; Type: INDEX

CREATE INDEX index_post_stats_on_post_id ON public.post_stats USING btree (post_id);

-- Name: index_post_timings_on_user_id; Type: INDEX

CREATE INDEX index_post_timings_on_user_id ON public.post_timings USING btree (user_id);

-- Name: index_post_uploads_on_post_id; Type: INDEX

CREATE INDEX index_post_uploads_on_post_id ON public.post_uploads USING btree (post_id);

-- Name: index_post_uploads_on_upload_id; Type: INDEX

CREATE INDEX index_post_uploads_on_upload_id ON public.post_uploads USING btree (upload_id);

-- Name: index_posts_on_id_and_baked_version; Type: INDEX

CREATE INDEX index_posts_on_id_and_baked_version ON public.posts USING btree (id DESC, baked_version) WHERE (deleted_at IS NULL);

-- Name: index_posts_on_reply_to_post_number; Type: INDEX

CREATE INDEX index_posts_on_reply_to_post_number ON public.posts USING btree (reply_to_post_number);

-- Name: index_posts_on_topic_id_and_percent_rank; Type: INDEX

CREATE INDEX index_posts_on_topic_id_and_percent_rank ON public.posts USING btree (topic_id, percent_rank);

-- Name: index_posts_on_topic_id_and_post_number; Type: INDEX

CREATE UNIQUE INDEX index_posts_on_topic_id_and_post_number ON public.posts USING btree (topic_id, post_number);

-- Name: index_posts_on_topic_id_and_sort_order; Type: INDEX

CREATE INDEX index_posts_on_topic_id_and_sort_order ON public.posts USING btree (topic_id, sort_order);

-- Name: index_posts_on_user_id_and_created_at; Type: INDEX

CREATE INDEX index_posts_on_user_id_and_created_at ON public.posts USING btree (user_id, created_at);

-- Name: index_quoted_posts_on_post_id_and_quoted_post_id; Type: INDEX

CREATE UNIQUE INDEX index_quoted_posts_on_post_id_and_quoted_post_id ON public.quoted_posts USING btree (post_id, quoted_post_id);

-- Name: index_quoted_posts_on_quoted_post_id_and_post_id; Type: INDEX

CREATE UNIQUE INDEX index_quoted_posts_on_quoted_post_id_and_post_id ON public.quoted_posts USING btree (quoted_post_id, post_id);

-- Name: index_reviewable_claimed_topics_on_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_reviewable_claimed_topics_on_topic_id ON public.reviewable_claimed_topics USING btree (topic_id);

-- Name: index_reviewable_histories_on_created_by_id; Type: INDEX

CREATE INDEX index_reviewable_histories_on_created_by_id ON public.reviewable_histories USING btree (created_by_id);

-- Name: index_reviewable_histories_on_reviewable_id; Type: INDEX

CREATE INDEX index_reviewable_histories_on_reviewable_id ON public.reviewable_histories USING btree (reviewable_id);

-- Name: index_reviewable_scores_on_reviewable_id; Type: INDEX

CREATE INDEX index_reviewable_scores_on_reviewable_id ON public.reviewable_scores USING btree (reviewable_id);

-- Name: index_reviewable_scores_on_user_id; Type: INDEX

CREATE INDEX index_reviewable_scores_on_user_id ON public.reviewable_scores USING btree (user_id);

-- Name: index_reviewables_on_reviewable_by_group_id; Type: INDEX

CREATE INDEX index_reviewables_on_reviewable_by_group_id ON public.reviewables USING btree (reviewable_by_group_id);

-- Name: index_reviewables_on_status_and_created_at; Type: INDEX

CREATE INDEX index_reviewables_on_status_and_created_at ON public.reviewables USING btree (status, created_at);

-- Name: index_reviewables_on_status_and_score; Type: INDEX

CREATE INDEX index_reviewables_on_status_and_score ON public.reviewables USING btree (status, score);

-- Name: index_reviewables_on_status_and_type; Type: INDEX

CREATE INDEX index_reviewables_on_status_and_type ON public.reviewables USING btree (status, type);

-- Name: index_reviewables_on_topic_id_and_status_and_created_by_id; Type: INDEX

CREATE INDEX index_reviewables_on_topic_id_and_status_and_created_by_id ON public.reviewables USING btree (topic_id, status, created_by_id);

-- Name: index_reviewables_on_type_and_target_id; Type: INDEX

CREATE UNIQUE INDEX index_reviewables_on_type_and_target_id ON public.reviewables USING btree (type, target_id);

-- Name: index_schema_migration_details_on_version; Type: INDEX

CREATE INDEX index_schema_migration_details_on_version ON public.schema_migration_details USING btree (version);

-- Name: index_screened_emails_on_email; Type: INDEX

CREATE UNIQUE INDEX index_screened_emails_on_email ON public.screened_emails USING btree (email);

-- Name: index_screened_emails_on_last_match_at; Type: INDEX

CREATE INDEX index_screened_emails_on_last_match_at ON public.screened_emails USING btree (last_match_at);

-- Name: index_screened_ip_addresses_on_ip_address; Type: INDEX

CREATE UNIQUE INDEX index_screened_ip_addresses_on_ip_address ON public.screened_ip_addresses USING btree (ip_address);

-- Name: index_screened_ip_addresses_on_last_match_at; Type: INDEX

CREATE INDEX index_screened_ip_addresses_on_last_match_at ON public.screened_ip_addresses USING btree (last_match_at);

-- Name: index_screened_urls_on_last_match_at; Type: INDEX

CREATE INDEX index_screened_urls_on_last_match_at ON public.screened_urls USING btree (last_match_at);

-- Name: index_screened_urls_on_url; Type: INDEX

CREATE UNIQUE INDEX index_screened_urls_on_url ON public.screened_urls USING btree (url);

-- Name: index_search_logs_on_created_at; Type: INDEX

CREATE INDEX index_search_logs_on_created_at ON public.search_logs USING btree (created_at);

-- Name: index_shared_drafts_on_category_id; Type: INDEX

CREATE INDEX index_shared_drafts_on_category_id ON public.shared_drafts USING btree (category_id);

-- Name: index_shared_drafts_on_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_shared_drafts_on_topic_id ON public.shared_drafts USING btree (topic_id);

-- Name: index_single_sign_on_records_on_external_id; Type: INDEX

CREATE UNIQUE INDEX index_single_sign_on_records_on_external_id ON public.single_sign_on_records USING btree (external_id);

-- Name: index_single_sign_on_records_on_user_id; Type: INDEX

CREATE INDEX index_single_sign_on_records_on_user_id ON public.single_sign_on_records USING btree (user_id);

-- Name: index_site_settings_on_name; Type: INDEX

CREATE UNIQUE INDEX index_site_settings_on_name ON public.site_settings USING btree (name);

-- Name: index_skipped_email_logs_on_created_at; Type: INDEX

CREATE INDEX index_skipped_email_logs_on_created_at ON public.skipped_email_logs USING btree (created_at);

-- Name: index_skipped_email_logs_on_post_id; Type: INDEX

CREATE INDEX index_skipped_email_logs_on_post_id ON public.skipped_email_logs USING btree (post_id);

-- Name: index_skipped_email_logs_on_reason_type; Type: INDEX

CREATE INDEX index_skipped_email_logs_on_reason_type ON public.skipped_email_logs USING btree (reason_type);

-- Name: index_skipped_email_logs_on_user_id; Type: INDEX

CREATE INDEX index_skipped_email_logs_on_user_id ON public.skipped_email_logs USING btree (user_id);

-- Name: index_stylesheet_cache_on_target_and_digest; Type: INDEX

CREATE UNIQUE INDEX index_stylesheet_cache_on_target_and_digest ON public.stylesheet_cache USING btree (target, digest);

-- Name: index_tag_group_memberships_on_tag_group_id_and_tag_id; Type: INDEX

CREATE UNIQUE INDEX index_tag_group_memberships_on_tag_group_id_and_tag_id ON public.tag_group_memberships USING btree (tag_group_id, tag_id);

-- Name: index_tag_group_permissions_on_group_id; Type: INDEX

CREATE INDEX index_tag_group_permissions_on_group_id ON public.tag_group_permissions USING btree (group_id);

-- Name: index_tag_group_permissions_on_tag_group_id; Type: INDEX

CREATE INDEX index_tag_group_permissions_on_tag_group_id ON public.tag_group_permissions USING btree (tag_group_id);

-- Name: index_tags_on_lower_name; Type: INDEX

CREATE UNIQUE INDEX index_tags_on_lower_name ON public.tags USING btree (lower((name)::text));

-- Name: index_tags_on_name; Type: INDEX

CREATE UNIQUE INDEX index_tags_on_name ON public.tags USING btree (name);

-- Name: index_theme_translation_overrides_on_theme_id; Type: INDEX

CREATE INDEX index_theme_translation_overrides_on_theme_id ON public.theme_translation_overrides USING btree (theme_id);

-- Name: index_themes_on_remote_theme_id; Type: INDEX

CREATE UNIQUE INDEX index_themes_on_remote_theme_id ON public.themes USING btree (remote_theme_id);

-- Name: index_top_topics_on_all_score; Type: INDEX

CREATE INDEX index_top_topics_on_all_score ON public.top_topics USING btree (all_score);

-- Name: index_top_topics_on_daily_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_daily_likes_count ON public.top_topics USING btree (daily_likes_count DESC);

-- Name: index_top_topics_on_daily_op_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_daily_op_likes_count ON public.top_topics USING btree (daily_op_likes_count);

-- Name: index_top_topics_on_daily_posts_count; Type: INDEX

CREATE INDEX index_top_topics_on_daily_posts_count ON public.top_topics USING btree (daily_posts_count DESC);

-- Name: index_top_topics_on_daily_score; Type: INDEX

CREATE INDEX index_top_topics_on_daily_score ON public.top_topics USING btree (daily_score);

-- Name: index_top_topics_on_daily_views_count; Type: INDEX

CREATE INDEX index_top_topics_on_daily_views_count ON public.top_topics USING btree (daily_views_count DESC);

-- Name: index_top_topics_on_monthly_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_monthly_likes_count ON public.top_topics USING btree (monthly_likes_count DESC);

-- Name: index_top_topics_on_monthly_op_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_monthly_op_likes_count ON public.top_topics USING btree (monthly_op_likes_count);

-- Name: index_top_topics_on_monthly_posts_count; Type: INDEX

CREATE INDEX index_top_topics_on_monthly_posts_count ON public.top_topics USING btree (monthly_posts_count DESC);

-- Name: index_top_topics_on_monthly_score; Type: INDEX

CREATE INDEX index_top_topics_on_monthly_score ON public.top_topics USING btree (monthly_score);

-- Name: index_top_topics_on_monthly_views_count; Type: INDEX

CREATE INDEX index_top_topics_on_monthly_views_count ON public.top_topics USING btree (monthly_views_count DESC);

-- Name: index_top_topics_on_quarterly_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_quarterly_likes_count ON public.top_topics USING btree (quarterly_likes_count);

-- Name: index_top_topics_on_quarterly_op_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_quarterly_op_likes_count ON public.top_topics USING btree (quarterly_op_likes_count);

-- Name: index_top_topics_on_quarterly_posts_count; Type: INDEX

CREATE INDEX index_top_topics_on_quarterly_posts_count ON public.top_topics USING btree (quarterly_posts_count);

-- Name: index_top_topics_on_quarterly_views_count; Type: INDEX

CREATE INDEX index_top_topics_on_quarterly_views_count ON public.top_topics USING btree (quarterly_views_count);

-- Name: index_top_topics_on_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_top_topics_on_topic_id ON public.top_topics USING btree (topic_id);

-- Name: index_top_topics_on_weekly_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_weekly_likes_count ON public.top_topics USING btree (weekly_likes_count DESC);

-- Name: index_top_topics_on_weekly_op_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_weekly_op_likes_count ON public.top_topics USING btree (weekly_op_likes_count);

-- Name: index_top_topics_on_weekly_posts_count; Type: INDEX

CREATE INDEX index_top_topics_on_weekly_posts_count ON public.top_topics USING btree (weekly_posts_count DESC);

-- Name: index_top_topics_on_weekly_score; Type: INDEX

CREATE INDEX index_top_topics_on_weekly_score ON public.top_topics USING btree (weekly_score);

-- Name: index_top_topics_on_weekly_views_count; Type: INDEX

CREATE INDEX index_top_topics_on_weekly_views_count ON public.top_topics USING btree (weekly_views_count DESC);

-- Name: index_top_topics_on_yearly_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_yearly_likes_count ON public.top_topics USING btree (yearly_likes_count DESC);

-- Name: index_top_topics_on_yearly_op_likes_count; Type: INDEX

CREATE INDEX index_top_topics_on_yearly_op_likes_count ON public.top_topics USING btree (yearly_op_likes_count);

-- Name: index_top_topics_on_yearly_posts_count; Type: INDEX

CREATE INDEX index_top_topics_on_yearly_posts_count ON public.top_topics USING btree (yearly_posts_count DESC);

-- Name: index_top_topics_on_yearly_score; Type: INDEX

CREATE INDEX index_top_topics_on_yearly_score ON public.top_topics USING btree (yearly_score);

-- Name: index_top_topics_on_yearly_views_count; Type: INDEX

CREATE INDEX index_top_topics_on_yearly_views_count ON public.top_topics USING btree (yearly_views_count DESC);

-- Name: index_topic_allowed_groups_on_group_id_and_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_topic_allowed_groups_on_group_id_and_topic_id ON public.topic_allowed_groups USING btree (group_id, topic_id);

-- Name: index_topic_allowed_groups_on_topic_id_and_group_id; Type: INDEX

CREATE UNIQUE INDEX index_topic_allowed_groups_on_topic_id_and_group_id ON public.topic_allowed_groups USING btree (topic_id, group_id);

-- Name: index_topic_allowed_users_on_topic_id_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_topic_allowed_users_on_topic_id_and_user_id ON public.topic_allowed_users USING btree (topic_id, user_id);

-- Name: index_topic_allowed_users_on_user_id_and_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_topic_allowed_users_on_user_id_and_topic_id ON public.topic_allowed_users USING btree (user_id, topic_id);

-- Name: index_topic_custom_fields_on_topic_id_and_name; Type: INDEX

CREATE INDEX index_topic_custom_fields_on_topic_id_and_name ON public.topic_custom_fields USING btree (topic_id, name);

-- Name: index_topic_embeds_on_embed_url; Type: INDEX

CREATE UNIQUE INDEX index_topic_embeds_on_embed_url ON public.topic_embeds USING btree (embed_url);

-- Name: index_topic_invites_on_invite_id; Type: INDEX

CREATE INDEX index_topic_invites_on_invite_id ON public.topic_invites USING btree (invite_id);

-- Name: index_topic_invites_on_topic_id_and_invite_id; Type: INDEX

CREATE UNIQUE INDEX index_topic_invites_on_topic_id_and_invite_id ON public.topic_invites USING btree (topic_id, invite_id);

-- Name: index_topic_links_on_extension; Type: INDEX

CREATE INDEX index_topic_links_on_extension ON public.topic_links USING btree (extension);

-- Name: index_topic_links_on_link_post_id_and_reflection; Type: INDEX

CREATE INDEX index_topic_links_on_link_post_id_and_reflection ON public.topic_links USING btree (link_post_id, reflection);

-- Name: index_topic_links_on_post_id; Type: INDEX

CREATE INDEX index_topic_links_on_post_id ON public.topic_links USING btree (post_id);

-- Name: index_topic_links_on_topic_id; Type: INDEX

CREATE INDEX index_topic_links_on_topic_id ON public.topic_links USING btree (topic_id);

-- Name: index_topic_links_on_user_id; Type: INDEX

CREATE INDEX index_topic_links_on_user_id ON public.topic_links USING btree (user_id);

-- Name: index_topic_search_data_on_topic_id_and_version_and_locale; Type: INDEX

CREATE INDEX index_topic_search_data_on_topic_id_and_version_and_locale ON public.topic_search_data USING btree (topic_id, version, locale);

-- Name: index_topic_tags_on_topic_id_and_tag_id; Type: INDEX

CREATE UNIQUE INDEX index_topic_tags_on_topic_id_and_tag_id ON public.topic_tags USING btree (topic_id, tag_id);

-- Name: index_topic_timers_on_user_id; Type: INDEX

CREATE INDEX index_topic_timers_on_user_id ON public.topic_timers USING btree (user_id);

-- Name: index_topic_users_on_topic_id_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_topic_users_on_topic_id_and_user_id ON public.topic_users USING btree (topic_id, user_id);

-- Name: index_topic_users_on_user_id_and_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_topic_users_on_user_id_and_topic_id ON public.topic_users USING btree (user_id, topic_id);

-- Name: index_topic_views_on_topic_id_and_viewed_at; Type: INDEX

CREATE INDEX index_topic_views_on_topic_id_and_viewed_at ON public.topic_views USING btree (topic_id, viewed_at);

-- Name: index_topic_views_on_user_id_and_viewed_at; Type: INDEX

CREATE INDEX index_topic_views_on_user_id_and_viewed_at ON public.topic_views USING btree (user_id, viewed_at);

-- Name: index_topic_views_on_viewed_at_and_topic_id; Type: INDEX

CREATE INDEX index_topic_views_on_viewed_at_and_topic_id ON public.topic_views USING btree (viewed_at, topic_id);

-- Name: index_topics_on_bumped_at; Type: INDEX

CREATE INDEX index_topics_on_bumped_at ON public.topics USING btree (bumped_at DESC);

-- Name: index_topics_on_created_at_and_visible; Type: INDEX

CREATE INDEX index_topics_on_created_at_and_visible ON public.topics USING btree (created_at, visible) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text));

-- Name: index_topics_on_id_and_deleted_at; Type: INDEX

CREATE INDEX index_topics_on_id_and_deleted_at ON public.topics USING btree (id, deleted_at);

-- Name: index_topics_on_lower_title; Type: INDEX

CREATE INDEX index_topics_on_lower_title ON public.topics USING btree (lower((title)::text));

-- Name: index_topics_on_pinned_at; Type: INDEX

CREATE INDEX index_topics_on_pinned_at ON public.topics USING btree (pinned_at) WHERE (pinned_at IS NOT NULL);

-- Name: index_topics_on_pinned_globally; Type: INDEX

CREATE INDEX index_topics_on_pinned_globally ON public.topics USING btree (pinned_globally) WHERE pinned_globally;

-- Name: index_topics_on_updated_at_public; Type: INDEX

CREATE INDEX index_topics_on_updated_at_public ON public.topics USING btree (updated_at, visible, highest_staff_post_number, highest_post_number, category_id, created_at, id) WHERE (((archetype)::text <> 'private_message'::text) AND (deleted_at IS NULL));

-- Name: index_translation_overrides_on_locale_and_translation_key; Type: INDEX

CREATE UNIQUE INDEX index_translation_overrides_on_locale_and_translation_key ON public.translation_overrides USING btree (locale, translation_key);

-- Name: index_unsubscribe_keys_on_created_at; Type: INDEX

CREATE INDEX index_unsubscribe_keys_on_created_at ON public.unsubscribe_keys USING btree (created_at);

-- Name: index_uploads_on_etag; Type: INDEX

CREATE INDEX index_uploads_on_etag ON public.uploads USING btree (etag);

-- Name: index_uploads_on_extension; Type: INDEX

CREATE INDEX index_uploads_on_extension ON public.uploads USING btree (lower((extension)::text));

-- Name: index_uploads_on_id_and_url; Type: INDEX

CREATE INDEX index_uploads_on_id_and_url ON public.uploads USING btree (id, url);

-- Name: index_uploads_on_sha1; Type: INDEX

CREATE UNIQUE INDEX index_uploads_on_sha1 ON public.uploads USING btree (sha1);

-- Name: index_uploads_on_url; Type: INDEX

CREATE INDEX index_uploads_on_url ON public.uploads USING btree (url);

-- Name: index_uploads_on_user_id; Type: INDEX

CREATE INDEX index_uploads_on_user_id ON public.uploads USING btree (user_id);

-- Name: index_user_actions_on_acting_user_id; Type: INDEX

CREATE INDEX index_user_actions_on_acting_user_id ON public.user_actions USING btree (acting_user_id);

-- Name: index_user_actions_on_action_type_and_created_at; Type: INDEX

CREATE INDEX index_user_actions_on_action_type_and_created_at ON public.user_actions USING btree (action_type, created_at);

-- Name: index_user_actions_on_target_post_id; Type: INDEX

CREATE INDEX index_user_actions_on_target_post_id ON public.user_actions USING btree (target_post_id);

-- Name: index_user_actions_on_target_user_id; Type: INDEX

CREATE INDEX index_user_actions_on_target_user_id ON public.user_actions USING btree (target_user_id) WHERE (target_user_id IS NOT NULL);

-- Name: index_user_actions_on_user_id_and_action_type; Type: INDEX

CREATE INDEX index_user_actions_on_user_id_and_action_type ON public.user_actions USING btree (user_id, action_type);

-- Name: index_user_api_keys_on_client_id; Type: INDEX

CREATE UNIQUE INDEX index_user_api_keys_on_client_id ON public.user_api_keys USING btree (client_id);

-- Name: index_user_api_keys_on_key; Type: INDEX

CREATE UNIQUE INDEX index_user_api_keys_on_key ON public.user_api_keys USING btree (key);

-- Name: index_user_api_keys_on_user_id; Type: INDEX

CREATE INDEX index_user_api_keys_on_user_id ON public.user_api_keys USING btree (user_id);

-- Name: index_user_archived_messages_on_user_id_and_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_user_archived_messages_on_user_id_and_topic_id ON public.user_archived_messages USING btree (user_id, topic_id);

-- Name: index_user_auth_token_logs_on_user_id; Type: INDEX

CREATE INDEX index_user_auth_token_logs_on_user_id ON public.user_auth_token_logs USING btree (user_id);

-- Name: index_user_auth_tokens_on_auth_token; Type: INDEX

CREATE UNIQUE INDEX index_user_auth_tokens_on_auth_token ON public.user_auth_tokens USING btree (auth_token);

-- Name: index_user_auth_tokens_on_prev_auth_token; Type: INDEX

CREATE UNIQUE INDEX index_user_auth_tokens_on_prev_auth_token ON public.user_auth_tokens USING btree (prev_auth_token);

-- Name: index_user_auth_tokens_on_user_id; Type: INDEX

CREATE INDEX index_user_auth_tokens_on_user_id ON public.user_auth_tokens USING btree (user_id);

-- Name: index_user_avatars_on_custom_upload_id; Type: INDEX

CREATE INDEX index_user_avatars_on_custom_upload_id ON public.user_avatars USING btree (custom_upload_id);

-- Name: index_user_avatars_on_gravatar_upload_id; Type: INDEX

CREATE INDEX index_user_avatars_on_gravatar_upload_id ON public.user_avatars USING btree (gravatar_upload_id);

-- Name: index_user_avatars_on_user_id; Type: INDEX

CREATE INDEX index_user_avatars_on_user_id ON public.user_avatars USING btree (user_id);

-- Name: index_user_badges_on_badge_id_and_user_id; Type: INDEX

CREATE INDEX index_user_badges_on_badge_id_and_user_id ON public.user_badges USING btree (badge_id, user_id);

-- Name: index_user_badges_on_badge_id_and_user_id_and_post_id; Type: INDEX

CREATE UNIQUE INDEX index_user_badges_on_badge_id_and_user_id_and_post_id ON public.user_badges USING btree (badge_id, user_id, post_id) WHERE (post_id IS NOT NULL);

-- Name: index_user_badges_on_badge_id_and_user_id_and_seq; Type: INDEX

CREATE UNIQUE INDEX index_user_badges_on_badge_id_and_user_id_and_seq ON public.user_badges USING btree (badge_id, user_id, seq) WHERE (post_id IS NULL);

-- Name: index_user_badges_on_user_id; Type: INDEX

CREATE INDEX index_user_badges_on_user_id ON public.user_badges USING btree (user_id);

-- Name: index_user_custom_fields_on_user_id_and_name; Type: INDEX

CREATE INDEX index_user_custom_fields_on_user_id_and_name ON public.user_custom_fields USING btree (user_id, name);

-- Name: index_user_emails_on_email; Type: INDEX

CREATE UNIQUE INDEX index_user_emails_on_email ON public.user_emails USING btree (lower((email)::text));

-- Name: index_user_emails_on_user_id; Type: INDEX

CREATE INDEX index_user_emails_on_user_id ON public.user_emails USING btree (user_id);

-- Name: index_user_emails_on_user_id_and_primary; Type: INDEX

CREATE UNIQUE INDEX index_user_emails_on_user_id_and_primary ON public.user_emails USING btree (user_id, "primary") WHERE "primary";

-- Name: index_user_histories_on_acting_user_id_and_action_and_id; Type: INDEX

CREATE INDEX index_user_histories_on_acting_user_id_and_action_and_id ON public.user_histories USING btree (acting_user_id, action, id);

-- Name: index_user_histories_on_action_and_id; Type: INDEX

CREATE INDEX index_user_histories_on_action_and_id ON public.user_histories USING btree (action, id);

-- Name: index_user_histories_on_category_id; Type: INDEX

CREATE INDEX index_user_histories_on_category_id ON public.user_histories USING btree (category_id);

-- Name: index_user_histories_on_subject_and_id; Type: INDEX

CREATE INDEX index_user_histories_on_subject_and_id ON public.user_histories USING btree (subject, id);

-- Name: index_user_histories_on_target_user_id_and_id; Type: INDEX

CREATE INDEX index_user_histories_on_target_user_id_and_id ON public.user_histories USING btree (target_user_id, id);

-- Name: index_user_histories_on_topic_id_and_target_user_id_and_action; Type: INDEX

CREATE INDEX index_user_histories_on_topic_id_and_target_user_id_and_action ON public.user_histories USING btree (topic_id, target_user_id, action);

-- Name: index_user_open_ids_on_url; Type: INDEX

CREATE INDEX index_user_open_ids_on_url ON public.user_open_ids USING btree (url);

-- Name: index_user_options_on_user_id; Type: INDEX

CREATE UNIQUE INDEX index_user_options_on_user_id ON public.user_options USING btree (user_id);

-- Name: index_user_profile_views_on_user_id; Type: INDEX

CREATE INDEX index_user_profile_views_on_user_id ON public.user_profile_views USING btree (user_id);

-- Name: index_user_profile_views_on_user_profile_id; Type: INDEX

CREATE INDEX index_user_profile_views_on_user_profile_id ON public.user_profile_views USING btree (user_profile_id);

-- Name: index_user_profiles_on_bio_cooked_version; Type: INDEX

CREATE INDEX index_user_profiles_on_bio_cooked_version ON public.user_profiles USING btree (bio_cooked_version);

-- Name: index_user_profiles_on_card_background; Type: INDEX

CREATE INDEX index_user_profiles_on_card_background ON public.user_profiles USING btree (card_background);

-- Name: index_user_profiles_on_profile_background; Type: INDEX

CREATE INDEX index_user_profiles_on_profile_background ON public.user_profiles USING btree (profile_background);

-- Name: index_user_second_factors_on_method_and_enabled; Type: INDEX

CREATE INDEX index_user_second_factors_on_method_and_enabled ON public.user_second_factors USING btree (method, enabled);

-- Name: index_user_second_factors_on_user_id; Type: INDEX

CREATE INDEX index_user_second_factors_on_user_id ON public.user_second_factors USING btree (user_id);

-- Name: index_user_uploads_on_upload_id_and_user_id; Type: INDEX

CREATE UNIQUE INDEX index_user_uploads_on_upload_id_and_user_id ON public.user_uploads USING btree (upload_id, user_id);

-- Name: index_user_uploads_on_user_id_and_upload_id; Type: INDEX

CREATE INDEX index_user_uploads_on_user_id_and_upload_id ON public.user_uploads USING btree (user_id, upload_id);

-- Name: index_user_visits_on_user_id_and_visited_at; Type: INDEX

CREATE UNIQUE INDEX index_user_visits_on_user_id_and_visited_at ON public.user_visits USING btree (user_id, visited_at);

-- Name: index_user_visits_on_user_id_and_visited_at_and_time_read; Type: INDEX

CREATE INDEX index_user_visits_on_user_id_and_visited_at_and_time_read ON public.user_visits USING btree (user_id, visited_at, time_read);

-- Name: index_user_visits_on_visited_at_and_mobile; Type: INDEX

CREATE INDEX index_user_visits_on_visited_at_and_mobile ON public.user_visits USING btree (visited_at, mobile);

-- Name: index_user_warnings_on_topic_id; Type: INDEX

CREATE UNIQUE INDEX index_user_warnings_on_topic_id ON public.user_warnings USING btree (topic_id);

-- Name: index_user_warnings_on_user_id; Type: INDEX

CREATE INDEX index_user_warnings_on_user_id ON public.user_warnings USING btree (user_id);

-- Name: index_users_on_last_posted_at; Type: INDEX

CREATE INDEX index_users_on_last_posted_at ON public.users USING btree (last_posted_at);

-- Name: index_users_on_last_seen_at; Type: INDEX

CREATE INDEX index_users_on_last_seen_at ON public.users USING btree (last_seen_at);

-- Name: index_users_on_uploaded_avatar_id; Type: INDEX

CREATE INDEX index_users_on_uploaded_avatar_id ON public.users USING btree (uploaded_avatar_id);

-- Name: index_users_on_username; Type: INDEX

CREATE UNIQUE INDEX index_users_on_username ON public.users USING btree (username);

-- Name: index_users_on_username_lower; Type: INDEX

CREATE UNIQUE INDEX index_users_on_username_lower ON public.users USING btree (username_lower);

-- Name: index_watched_words_on_action_and_word; Type: INDEX

CREATE UNIQUE INDEX index_watched_words_on_action_and_word ON public.watched_words USING btree (action, word);

-- Name: index_web_crawler_requests_on_date_and_user_agent; Type: INDEX

CREATE UNIQUE INDEX index_web_crawler_requests_on_date_and_user_agent ON public.web_crawler_requests USING btree (date, user_agent);

-- Name: index_web_hook_events_on_web_hook_id; Type: INDEX

CREATE INDEX index_web_hook_events_on_web_hook_id ON public.web_hook_events USING btree (web_hook_id);

-- Name: post_custom_field_broken_images_idx; Type: INDEX

CREATE UNIQUE INDEX post_custom_field_broken_images_idx ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'broken_images'::text);

-- Name: post_custom_field_downloaded_images_idx; Type: INDEX

CREATE UNIQUE INDEX post_custom_field_downloaded_images_idx ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'downloaded_images'::text);

-- Name: post_custom_field_large_images_idx; Type: INDEX

CREATE UNIQUE INDEX post_custom_field_large_images_idx ON public.post_custom_fields USING btree (post_id) WHERE ((name)::text = 'large_images'::text);

-- Name: post_timings_summary; Type: INDEX

CREATE INDEX post_timings_summary ON public.post_timings USING btree (topic_id, post_number);

-- Name: post_timings_unique; Type: INDEX

CREATE UNIQUE INDEX post_timings_unique ON public.post_timings USING btree (topic_id, post_number, user_id);

-- Name: theme_field_unique_index; Type: INDEX

CREATE UNIQUE INDEX theme_field_unique_index ON public.theme_fields USING btree (theme_id, target_id, type_id, name);

-- Name: theme_translation_overrides_unique; Type: INDEX

CREATE UNIQUE INDEX theme_translation_overrides_unique ON public.theme_translation_overrides USING btree (theme_id, locale, translation_key);

-- Name: topic_custom_fields_value_key_idx; Type: INDEX

CREATE INDEX topic_custom_fields_value_key_idx ON public.topic_custom_fields USING btree (value, name) WHERE ((value IS NOT NULL) AND (char_length(value) < 400));

-- Name: uniq_ip_or_user_id_topic_views; Type: INDEX

CREATE UNIQUE INDEX uniq_ip_or_user_id_topic_views ON public.topic_views USING btree (user_id, ip_address, topic_id);

-- Name: unique_index_categories_on_name; Type: INDEX

CREATE UNIQUE INDEX unique_index_categories_on_name ON public.categories USING btree (COALESCE(parent_category_id, '-1'::integer), name);

-- Name: unique_post_links; Type: INDEX

CREATE UNIQUE INDEX unique_post_links ON public.topic_links USING btree (topic_id, post_id, url);

-- Name: unique_profile_view_user_or_ip; Type: INDEX

CREATE UNIQUE INDEX unique_profile_view_user_or_ip ON public.user_profile_views USING btree (viewed_at, user_id, ip_address, user_profile_id);

-- Name: web_hooks_tags; Type: INDEX

CREATE UNIQUE INDEX web_hooks_tags ON public.tags_web_hooks USING btree (web_hook_id, tag_id);

-- Name: user_profiles user_profiles_card_background_readonly; Type: TRIGGER

CREATE TRIGGER user_profiles_card_background_readonly BEFORE INSERT OR UPDATE OF card_background ON public.user_profiles FOR EACH ROW WHEN ((new.card_background IS NOT NULL)) EXECUTE PROCEDURE discourse_functions.raise_user_profiles_card_background_readonly();

-- Name: user_profiles user_profiles_profile_background_readonly; Type: TRIGGER

CREATE TRIGGER user_profiles_profile_background_readonly BEFORE INSERT OR UPDATE OF profile_background ON public.user_profiles FOR EACH ROW WHEN ((new.profile_background IS NOT NULL)) EXECUTE PROCEDURE discourse_functions.raise_user_profiles_profile_background_readonly();

-- Name: user_profiles fk_rails_1d362f2e97; Type: FK CONSTRAINT

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT fk_rails_1d362f2e97 FOREIGN KEY (profile_background_upload_id) REFERENCES public.uploads(id);

-- Name: poll_votes fk_rails_848ece0184; Type: FK CONSTRAINT

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT fk_rails_848ece0184 FOREIGN KEY (poll_option_id) REFERENCES public.poll_options(id);

-- Name: poll_votes fk_rails_a6e6974b7e; Type: FK CONSTRAINT

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT fk_rails_a6e6974b7e FOREIGN KEY (poll_id) REFERENCES public.polls(id);

-- Name: poll_options fk_rails_aa85becb42; Type: FK CONSTRAINT

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT fk_rails_aa85becb42 FOREIGN KEY (poll_id) REFERENCES public.polls(id);

-- Name: polls fk_rails_b50b782d08; Type: FK CONSTRAINT

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT fk_rails_b50b782d08 FOREIGN KEY (post_id) REFERENCES public.posts(id);

-- Name: poll_votes fk_rails_b64de9b025; Type: FK CONSTRAINT

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT fk_rails_b64de9b025 FOREIGN KEY (user_id) REFERENCES public.users(id);

-- Name: user_profiles fk_rails_ca64aa462b; Type: FK CONSTRAINT

ALTER TABLE ONLY public.user_profiles
    ADD CONSTRAINT fk_rails_ca64aa462b FOREIGN KEY (card_background_upload_id) REFERENCES public.uploads(id);

-- PostgreSQL database dump complete

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20000225050318'),
('20120311163914'),
('20120311164326'),
('20120311170118'),
('20120311201341'),
('20120311210245'),
('20120416201606'),
('20120420183447'),
('20120423140906'),
('20120423142820'),
('20120423151548'),
('20120425145456'),
('20120427150624'),
('20120427151452'),
('20120427154330'),
('20120427172031'),
('20120502183240'),
('20120502192121'),
('20120503205521'),
('20120507144132'),
('20120507144222'),
('20120514144549'),
('20120514173920'),
('20120514204934'),
('20120517200130'),
('20120518200115'),
('20120519182212'),
('20120523180723'),
('20120523184307'),
('20120523201329'),
('20120525194845'),
('20120529175956'),
('20120529202707'),
('20120530150726'),
('20120530160745'),
('20120530200724'),
('20120530212912'),
('20120614190726'),
('20120614202024'),
('20120615180517'),
('20120618152946'),
('20120618212349'),
('20120618214856'),
('20120619150807'),
('20120619153349'),
('20120619172714'),
('20120621155351'),
('20120621190310'),
('20120622200242'),
('20120625145714'),
('20120625162318'),
('20120625174544'),
('20120625195326'),
('20120629143908'),
('20120629150253'),
('20120629151243'),
('20120629182637'),
('20120702211427'),
('20120703184734'),
('20120703201312'),
('20120703203623'),
('20120703210004'),
('20120704160659'),
('20120704201743'),
('20120705181724'),
('20120708210305'),
('20120712150500'),
('20120712151934'),
('20120713201324'),
('20120716020835'),
('20120716173544'),
('20120718044955'),
('20120719004636'),
('20120720013733'),
('20120720044246'),
('20120720162422'),
('20120723051512'),
('20120724234502'),
('20120724234711'),
('20120725183347'),
('20120726201830'),
('20120726235129'),
('20120727005556'),
('20120727150428'),
('20120727213543'),
('20120802151210'),
('20120803191426'),
('20120806030641'),
('20120806062617'),
('20120807223020'),
('20120809020415'),
('20120809030647'),
('20120809053414'),
('20120809154750'),
('20120809174649'),
('20120809175110'),
('20120809201855'),
('20120810064839'),
('20120812235417'),
('20120813004347'),
('20120813042912'),
('20120813201426'),
('20120815004411'),
('20120815180106'),
('20120815204733'),
('20120816050526'),
('20120816205537'),
('20120816205538'),
('20120820191804'),
('20120821191616'),
('20120823205956'),
('20120824171908'),
('20120828204209'),
('20120828204624'),
('20120830182736'),
('20120910171504'),
('20120918152319'),
('20120918205931'),
('20120919152846'),
('20120921055428'),
('20120921155050'),
('20120921162512'),
('20120921163606'),
('20120924182000'),
('20120924182031'),
('20120925171620'),
('20120925190802'),
('20120928170023'),
('20121009161116'),
('20121011155904'),
('20121017162924'),
('20121018103721'),
('20121018133039'),
('20121018182709'),
('20121106015500'),
('20121108193516'),
('20121109164630'),
('20121113200844'),
('20121113200845'),
('20121115172544'),
('20121116212424'),
('20121119190529'),
('20121119200843'),
('20121121202035'),
('20121121205215'),
('20121122033316'),
('20121123054127'),
('20121123063630'),
('20121129160035'),
('20121129184948'),
('20121130010400'),
('20121130191818'),
('20121202225421'),
('20121203181719'),
('20121204183855'),
('20121204193747'),
('20121205162143'),
('20121207000741'),
('20121211233131'),
('20121216230719'),
('20121218205642'),
('20121224072204'),
('20121224095139'),
('20121224100650'),
('20121228192219'),
('20130107165207'),
('20130108195847'),
('20130115012140'),
('20130115021937'),
('20130115043603'),
('20130116151829'),
('20130120222728'),
('20130121231352'),
('20130122051134'),
('20130122232825'),
('20130123070909'),
('20130125002652'),
('20130125030305'),
('20130125031122'),
('20130127213646'),
('20130128182013'),
('20130129010625'),
('20130129163244'),
('20130129174845'),
('20130130154611'),
('20130131055710'),
('20130201000828'),
('20130201023409'),
('20130203204338'),
('20130204000159'),
('20130205021905'),
('20130207200019'),
('20130208220635'),
('20130213021450'),
('20130213203300'),
('20130221215017'),
('20130226015336'),
('20130306180148'),
('20130311181327'),
('20130313004922'),
('20130314093434'),
('20130315180637'),
('20130319122248'),
('20130320012100'),
('20130320024345'),
('20130321154905'),
('20130322183614'),
('20130326210101'),
('20130327185852'),
('20130328162943'),
('20130328182433'),
('20130402210723'),
('20130404143437'),
('20130404232558'),
('20130411205132'),
('20130412015502'),
('20130412020156'),
('20130416004607'),
('20130416004933'),
('20130416170855'),
('20130419195746'),
('20130422050626'),
('20130424015746'),
('20130424055025'),
('20130426044914'),
('20130426052257'),
('20130428194335'),
('20130429000101'),
('20130430052751'),
('20130501105651'),
('20130506020935'),
('20130506185042'),
('20130508040235'),
('20130509040248'),
('20130509041351'),
('20130515193551'),
('20130521210140'),
('20130522193615'),
('20130527152648'),
('20130528174147'),
('20130531210816'),
('20130603192412'),
('20130606190601'),
('20130610201033'),
('20130612200846'),
('20130613211700'),
('20130613212230'),
('20130615064344'),
('20130615073305'),
('20130615075557'),
('20130616082327'),
('20130617014127'),
('20130617180009'),
('20130617181804'),
('20130619063902'),
('20130621042855'),
('20130622110348'),
('20130624203206'),
('20130625022454'),
('20130625170842'),
('20130625201113'),
('20130709184941'),
('20130710201248'),
('20130712041133'),
('20130712163509'),
('20130723212758'),
('20130724201552'),
('20130725213613'),
('20130728172550'),
('20130731163035'),
('20130807202516'),
('20130809160751'),
('20130809204732'),
('20130809211409'),
('20130813204212'),
('20130813224817'),
('20130816024250'),
('20130819192358'),
('20130820174431'),
('20130822213513'),
('20130823201420'),
('20130826011521'),
('20130828192526'),
('20130903154323'),
('20130904181208'),
('20130906081326'),
('20130906171631'),
('20130910040235'),
('20130910220317'),
('20130911182437'),
('20130912185218'),
('20130913210454'),
('20130917174738'),
('20131001060630'),
('20131002070347'),
('20131003061137'),
('20131014203951'),
('20131015131652'),
('20131017014509'),
('20131017030605'),
('20131017205954'),
('20131018050738'),
('20131022045114'),
('20131022151218'),
('20131023163509'),
('20131105101051'),
('20131107154900'),
('20131114185225'),
('20131115165105'),
('20131118173159'),
('20131120055018'),
('20131122064921'),
('20131206200009'),
('20131209091702'),
('20131209091742'),
('20131210163702'),
('20131210181901'),
('20131210234530'),
('20131212225511'),
('20131216164557'),
('20131217174004'),
('20131219203905'),
('20131223171005'),
('20131227164338'),
('20131229221725'),
('20131230010239'),
('20140101235747'),
('20140102104229'),
('20140102194802'),
('20140107220141'),
('20140109205940'),
('20140116170655'),
('20140120155706'),
('20140121204628'),
('20140122043508'),
('20140124202427'),
('20140129164541'),
('20140206044818'),
('20140206195001'),
('20140206215029'),
('20140210194146'),
('20140211230222'),
('20140211234523'),
('20140214151255'),
('20140220160510'),
('20140220163213'),
('20140224232712'),
('20140224232913'),
('20140227104930'),
('20140227201005'),
('20140228005443'),
('20140228173431'),
('20140228205743'),
('20140303185354'),
('20140304200606'),
('20140304201403'),
('20140305100909'),
('20140306223522'),
('20140318150412'),
('20140318203559'),
('20140320042653'),
('20140402201432'),
('20140404143501'),
('20140407055830'),
('20140407202158'),
('20140408061512'),
('20140408152401'),
('20140415054717'),
('20140416202746'),
('20140416202801'),
('20140416235757'),
('20140421235646'),
('20140422195623'),
('20140425125742'),
('20140425135354'),
('20140425172618'),
('20140429175951'),
('20140504174212'),
('20140505145918'),
('20140506200235'),
('20140507173327'),
('20140508053815'),
('20140515220111'),
('20140520062826'),
('20140520063859'),
('20140521192142'),
('20140521220115'),
('20140522003151'),
('20140525233953'),
('20140526185749'),
('20140526201939'),
('20140527163207'),
('20140527233225'),
('20140528015354'),
('20140529045508'),
('20140530002535'),
('20140530043913'),
('20140604145431'),
('20140607035234'),
('20140610012414'),
('20140610012833'),
('20140610034314'),
('20140612010718'),
('20140617053829'),
('20140617080955'),
('20140617193351'),
('20140618001820'),
('20140618163511'),
('20140620184031'),
('20140623195618'),
('20140624044600'),
('20140627193814'),
('20140703022838'),
('20140705081453'),
('20140707071913'),
('20140710005023'),
('20140710224658'),
('20140711063215'),
('20140711143146'),
('20140711193923'),
('20140711233329'),
('20140714060646'),
('20140715013018'),
('20140715051412'),
('20140715055242'),
('20140715160720'),
('20140715190552'),
('20140716063802'),
('20140717024528'),
('20140718041445'),
('20140721063820'),
('20140721161249'),
('20140721162307'),
('20140723011456'),
('20140725050636'),
('20140725172830'),
('20140727030954'),
('20140728120708'),
('20140728144308'),
('20140728152804'),
('20140729092525'),
('20140730203029'),
('20140731011328'),
('20140801052028'),
('20140801170444'),
('20140804010803'),
('20140804030041'),
('20140804060439'),
('20140804072504'),
('20140804075613'),
('20140805061612'),
('20140806003116'),
('20140807033123'),
('20140808051823'),
('20140809224243'),
('20140811094300'),
('20140813175357'),
('20140815183851'),
('20140815191556'),
('20140815215618'),
('20140817011612'),
('20140818023700'),
('20140826234625'),
('20140827044811'),
('20140828172407'),
('20140828200231'),
('20140831191346'),
('20140904055702'),
('20140904160015'),
('20140904215629'),
('20140905055251'),
('20140905171733'),
('20140908165716'),
('20140908191429'),
('20140910130155'),
('20140911065449'),
('20140913192733'),
('20140923042349'),
('20140924192418'),
('20140925173220'),
('20140929181930'),
('20140929204155'),
('20141001101041'),
('20141002181613'),
('20141007224814'),
('20141008152953'),
('20141008181228'),
('20141008192525'),
('20141008192526'),
('20141014032859'),
('20141014191645'),
('20141015060145'),
('20141016183307'),
('20141020153415'),
('20141020154935'),
('20141020164816'),
('20141020174120'),
('20141030222425'),
('20141110150304'),
('20141118011735'),
('20141120035016'),
('20141120043401'),
('20141211114517'),
('20141216112341'),
('20141222051622'),
('20141222224220'),
('20141222230707'),
('20141223145058'),
('20141228151019'),
('20150102113309'),
('20150106215342'),
('20150108002354'),
('20150108202057'),
('20150108211557'),
('20150108221703'),
('20150112172258'),
('20150112172259'),
('20150114093325'),
('20150115172310'),
('20150119192813'),
('20150123145128'),
('20150129204520'),
('20150203041207'),
('20150205032808'),
('20150205172051'),
('20150206004143'),
('20150213174159'),
('20150224004420'),
('20150227043622'),
('20150301224250'),
('20150306050437'),
('20150318143915'),
('20150323034933'),
('20150323062322'),
('20150323234856'),
('20150324184222'),
('20150325183400'),
('20150325190959'),
('20150410002033'),
('20150410002551'),
('20150421085850'),
('20150421190714'),
('20150422160235'),
('20150501152228'),
('20150505044154'),
('20150513094042'),
('20150514023016'),
('20150514043155'),
('20150525151759'),
('20150609163211'),
('20150617080349'),
('20150617233018'),
('20150617234511'),
('20150702201926'),
('20150706215111'),
('20150707163251'),
('20150709021818'),
('20150713203955'),
('20150724165259'),
('20150724182342'),
('20150727193414'),
('20150727210019'),
('20150727210748'),
('20150727230537'),
('20150728004647'),
('20150728210202'),
('20150729150523'),
('20150730154830'),
('20150731225331'),
('20150802233112'),
('20150806210727'),
('20150818190757'),
('20150822141540'),
('20150828155137'),
('20150901192313'),
('20150914021445'),
('20150914034541'),
('20150917071017'),
('20150918004206'),
('20150924022040'),
('20150925000915'),
('20151016163051'),
('20151103233815'),
('20151105181635'),
('20151107041044'),
('20151107042241'),
('20151109124147'),
('20151113205046'),
('20151117165756'),
('20151124172631'),
('20151124192339'),
('20151125194322'),
('20151126173356'),
('20151126233623'),
('20151127011837'),
('20151201035631'),
('20151201161726'),
('20151214165852'),
('20151218232200'),
('20151219045559'),
('20151220232725'),
('20160108051129'),
('20160110053003'),
('20160112025852'),
('20160112101818'),
('20160112104733'),
('20160113160742'),
('20160118174335'),
('20160118233631'),
('20160127105314'),
('20160127222802'),
('20160201181320'),
('20160206210202'),
('20160215075528'),
('20160224033122'),
('20160225050317'),
('20160225050318'),
('20160225050319'),
('20160225050320'),
('20160225095306'),
('20160302063432'),
('20160302104253'),
('20160302170230'),
('20160303183607'),
('20160303234317'),
('20160307190919'),
('20160308193142'),
('20160309073132'),
('20160317174357'),
('20160317201955'),
('20160321164925'),
('20160326001747'),
('20160329101122'),
('20160405172827'),
('20160407160756'),
('20160407180149'),
('20160408131959'),
('20160408175727'),
('20160418065403'),
('20160420172330'),
('20160425141954'),
('20160427202222'),
('20160503205953'),
('20160514100852'),
('20160520022627'),
('20160527015355'),
('20160527191614'),
('20160530003739'),
('20160530203810'),
('20160602164008'),
('20160606204319'),
('20160607213656'),
('20160609203508'),
('20160615024524'),
('20160615165447'),
('20160627104436'),
('20160707195549'),
('20160716112354'),
('20160719002225'),
('20160722071221'),
('20160725015749'),
('20160727233044'),
('20160815002002'),
('20160815210156'),
('20160816052836'),
('20160816063534'),
('20160823171911'),
('20160826195018'),
('20160905082217'),
('20160905082248'),
('20160905084502'),
('20160905085445'),
('20160905091958'),
('20160905092148'),
('20160906200439'),
('20160919003141'),
('20160919054014'),
('20160920165833'),
('20160930123330'),
('20161010230853'),
('20161013012136'),
('20161014171034'),
('20161025083648'),
('20161029181306'),
('20161031183811'),
('20161102024700'),
('20161102024818'),
('20161102024838'),
('20161102024900'),
('20161102024920'),
('20161124020918'),
('20161202011139'),
('20161202034856'),
('20161205001727'),
('20161205065743'),
('20161207030057'),
('20161208064834'),
('20161212123649'),
('20161213073938'),
('20161215201907'),
('20161216101352'),
('20170124181409'),
('20170201085745'),
('20170213180857'),
('20170215151505'),
('20170221204204'),
('20170222173036'),
('20170227211458'),
('20170301215150'),
('20170303070706'),
('20170307181800'),
('20170308201552'),
('20170313192741'),
('20170322065911'),
('20170322155537'),
('20170322191305'),
('20170324032913'),
('20170324144456'),
('20170328163918'),
('20170328203122'),
('20170330041605'),
('20170403062717'),
('20170407154510'),
('20170410170923'),
('20170413043152'),
('20170417164715'),
('20170419193714'),
('20170420163628'),
('20170425083011'),
('20170425172415'),
('20170501191912'),
('20170505035229'),
('20170508183819'),
('20170511071355'),
('20170511080007'),
('20170511184842'),
('20170512153318'),
('20170512185227'),
('20170515152725'),
('20170515203721'),
('20170602132735'),
('20170605014820'),
('20170609115401'),
('20170628152322'),
('20170630083540'),
('20170703115216'),
('20170703144855'),
('20170704142141'),
('20170713164357'),
('20170717084947'),
('20170725075535'),
('20170728012754'),
('20170731075604'),
('20170803123704'),
('20170818191909'),
('20170823173427'),
('20170824172615'),
('20170831180419'),
('20171003180951'),
('20171006030028'),
('20171026014317'),
('20171110174413'),
('20171113175414'),
('20171113214725'),
('20171115170858'),
('20171123200157'),
('20171128172835'),
('20171213105921'),
('20171214040346'),
('20171220181249'),
('20171228122834'),
('20180109222722'),
('20180111092141'),
('20180118215249'),
('20180125185717'),
('20180127005644'),
('20180131052859'),
('20180207161422'),
('20180207163946'),
('20180221215641'),
('20180223041147'),
('20180223222415'),
('20180308071922'),
('20180309014014'),
('20180316092939'),
('20180316165104'),
('20180320190339'),
('20180323154826'),
('20180323161659'),
('20180327062911'),
('20180328180317'),
('20180331125522'),
('20180419095326'),
('20180420141134'),
('20180425152503'),
('20180425185749'),
('20180508142711'),
('20180514133440'),
('20180519053933'),
('20180521175611'),
('20180521184439'),
('20180521190040'),
('20180521191418'),
('20180607095414'),
('20180621013807'),
('20180706054922'),
('20180710075119'),
('20180710172959'),
('20180716062012'),
('20180716062405'),
('20180716072125'),
('20180716140323'),
('20180716200103'),
('20180717025038'),
('20180717084758'),
('20180718062728'),
('20180719103905'),
('20180720054856'),
('20180724070554'),
('20180727042448'),
('20180729092926'),
('20180803085321'),
('20180812150839'),
('20180813074843'),
('20180820073549'),
('20180820080623'),
('20180827053514'),
('20180828065005'),
('20180831182853'),
('20180907075713'),
('20180913200027'),
('20180916195601'),
('20180917024729'),
('20180917034056'),
('20180920023559'),
('20180920042415'),
('20180927135248'),
('20180928105835'),
('20181005084357'),
('20181005144357'),
('20181010150631'),
('20181012123001'),
('20181031165343'),
('20181108115009'),
('20181112013117'),
('20181120140552'),
('20181128140547'),
('20181129094518'),
('20181204123042'),
('20181204193426'),
('20181207141900'),
('20181210122522'),
('20181218071253'),
('20181221121805'),
('20190103051737'),
('20190103060819'),
('20190103065652'),
('20190103160533'),
('20190103185626'),
('20190106041015'),
('20190108110630'),
('20190110142917'),
('20190110201340'),
('20190110212005'),
('20190111170824'),
('20190117191606'),
('20190121202656'),
('20190121203023'),
('20190122132732'),
('20190123171817'),
('20190125103246'),
('20190125153345'),
('20190130013015'),
('20190130163000'),
('20190130163001'),
('20190205104116'),
('20190208144706'),
('20190215204033'),
('20190225133654'),
('20190227150413'),
('20190227210035'),
('20190304170931'),
('20190306154335'),
('20190306184409'),
('20190312181641'),
('20190312194528'),
('20190313134642'),
('20190313171338'),
('20190313205652'),
('20190314082018'),
('20190314144755'),
('20190315025804'),
('20190315055432'),
('20190315170411'),
('20190315174428'),
('20190320091323'),
('20190320104640'),
('20190321072029'),
('20190322152347'),
('20190325162154'),
('20190326123708'),
('20190327090918'),
('20190327205525'),
('20190402024053'),
('20190402142223'),
('20190403180142'),
('20190403202001'),
('20190405044140'),
('20190408072550'),
('20190408082101'),
('20190409054736'),
('20190410055459'),
('20190410102915'),
('20190410122835'),
('20190411121312'),
('20190411144545'),
('20190412161430'),
('20190414162753'),
('20190417135049'),
('20190417203622'),
('20190418113814'),
('20190422200243'),
('20190423112954'),
('20190424065841'),
('20190426011148'),
('20190426074404'),
('20190426123026'),
('20190426123658'),
('20190502223613'),
('20190503180839'),
('20190508135348'),
('20190508141327'),
('20190508141824'),
('20190508193900');

