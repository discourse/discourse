-- This file is auto-generated from the IntermediateDB schema. To make changes,
-- update the "config/intermediate_db.yml" configuration file and then run
-- `bin/cli schema generate` to regenerate this file.

CREATE TABLE badge_groupings
(
    original_id NUMERIC  NOT NULL PRIMARY KEY,
    created_at  DATETIME,
    description TEXT,
    name        TEXT     NOT NULL,
    position    INTEGER  NOT NULL
);

CREATE TABLE badges
(
    original_id         NUMERIC  NOT NULL PRIMARY KEY,
    allow_title         BOOLEAN,
    auto_revoke         BOOLEAN,
    badge_grouping_id   NUMERIC,
    badge_type_id       NUMERIC  NOT NULL,
    created_at          DATETIME,
    description         TEXT,
    enabled             BOOLEAN,
    existing_id         NUMERIC,
    icon                TEXT,
    image_upload_id     TEXT,
    listable            BOOLEAN,
    long_description    TEXT,
    multiple_grant      BOOLEAN,
    name                TEXT     NOT NULL,
    "query"             TEXT,
    show_in_post_header BOOLEAN,
    show_posts          BOOLEAN,
    target_posts        BOOLEAN,
    "trigger"           INTEGER
);

CREATE TABLE categories
(
    original_id                               NUMERIC  NOT NULL PRIMARY KEY,
    about_topic_title                         TEXT,
    all_topics_wiki                           BOOLEAN,
    allow_badges                              BOOLEAN,
    allow_global_tags                         BOOLEAN,
    allow_unlimited_owner_edits_on_first_post BOOLEAN,
    auto_close_based_on_last_post             BOOLEAN,
    auto_close_hours                          FLOAT,
    color                                     TEXT,
    created_at                                DATETIME,
    default_list_filter                       TEXT,
    default_slow_mode_seconds                 INTEGER,
    default_top_period                        TEXT,
    default_view                              TEXT,
    description                               TEXT,
    email_in                                  TEXT,
    email_in_allow_strangers                  BOOLEAN,
    emoji                                     TEXT,
    existing_id                               NUMERIC,
    icon                                      TEXT,
    locale                                    TEXT,
    mailinglist_mirror                        BOOLEAN,
    minimum_required_tags                     INTEGER,
    name                                      TEXT     NOT NULL,
    navigate_to_first_post_after_read         BOOLEAN,
    num_featured_topics                       INTEGER,
    parent_category_id                        NUMERIC,
    position                                  INTEGER,
    read_only_banner                          TEXT,
    read_restricted                           BOOLEAN,
    search_priority                           INTEGER,
    show_subcategory_list                     BOOLEAN,
    slug                                      TEXT     NOT NULL,
    sort_ascending                            BOOLEAN,
    sort_order                                TEXT,
    style_type                                INTEGER,
    subcategory_list_style                    TEXT,
    text_color                                TEXT,
    topic_featured_link_allowed               BOOLEAN,
    topic_id                                  NUMERIC,
    topic_template                            TEXT,
    uploaded_background_dark_id               TEXT,
    uploaded_background_id                    TEXT,
    uploaded_logo_dark_id                     TEXT,
    uploaded_logo_id                          TEXT,
    user_id                                   NUMERIC  NOT NULL
);

CREATE TABLE category_custom_fields
(
    category_id NUMERIC NOT NULL,
    name        TEXT    NOT NULL,
    value       TEXT,
    PRIMARY KEY (category_id, name)
);

CREATE TABLE category_users
(
    category_id        NUMERIC  NOT NULL,
    user_id            NUMERIC  NOT NULL,
    last_seen_at       DATETIME,
    notification_level INTEGER  NOT NULL,
    PRIMARY KEY (category_id, user_id)
);

CREATE TABLE group_users
(
    group_id           NUMERIC  NOT NULL,
    user_id            NUMERIC  NOT NULL,
    created_at         DATETIME,
    notification_level INTEGER,
    owner              BOOLEAN,
    PRIMARY KEY (group_id, user_id)
);

CREATE TABLE "groups"
(
    original_id                        NUMERIC  NOT NULL PRIMARY KEY,
    allow_membership_requests          BOOLEAN,
    allow_unknown_sender_topic_replies BOOLEAN,
    automatic_membership_email_domains TEXT,
    bio_raw                            TEXT,
    created_at                         DATETIME,
    default_notification_level         INTEGER,
    existing_id                        NUMERIC,
    flair_bg_color                     TEXT,
    flair_color                        TEXT,
    flair_icon                         TEXT,
    flair_upload_id                    TEXT,
    full_name                          TEXT,
    grant_trust_level                  INTEGER,
    members_visibility_level           INTEGER,
    membership_request_template        TEXT,
    mentionable_level                  INTEGER,
    messageable_level                  INTEGER,
    name                               TEXT     NOT NULL,
    primary_group                      BOOLEAN,
    public_admission                   BOOLEAN,
    public_exit                        BOOLEAN,
    publish_read_state                 BOOLEAN,
    title                              TEXT,
    visibility_level                   INTEGER
);

CREATE TABLE muted_users
(
    created_at    DATETIME,
    muted_user_id NUMERIC  NOT NULL,
    user_id       NUMERIC  NOT NULL
);

CREATE TABLE tag_group_memberships
(
    tag_group_id NUMERIC  NOT NULL,
    tag_id       NUMERIC  NOT NULL,
    created_at   DATETIME,
    PRIMARY KEY (tag_group_id, tag_id)
);

CREATE TABLE tag_group_permissions
(
    group_id        NUMERIC  NOT NULL,
    permission_type INTEGER,
    tag_group_id    NUMERIC  NOT NULL,
    created_at      DATETIME,
    PRIMARY KEY (tag_group_id, group_id, permission_type)
);

CREATE TABLE tag_groups
(
    original_id   NUMERIC  NOT NULL PRIMARY KEY,
    created_at    DATETIME,
    name          TEXT     NOT NULL,
    one_per_topic BOOLEAN,
    parent_tag_id NUMERIC
);

CREATE TABLE tag_users
(
    tag_id             NUMERIC  NOT NULL,
    user_id            NUMERIC  NOT NULL,
    created_at         DATETIME,
    notification_level INTEGER  NOT NULL,
    PRIMARY KEY (tag_id, user_id)
);

CREATE TABLE tags
(
    original_id NUMERIC  NOT NULL PRIMARY KEY,
    created_at  DATETIME,
    description TEXT,
    name        TEXT     NOT NULL
);

CREATE TABLE user_associated_accounts
(
    provider_name TEXT      NOT NULL,
    user_id       NUMERIC,
    created_at    DATETIME,
    info          JSON_TEXT,
    last_used     DATETIME,
    provider_uid  TEXT      NOT NULL,
    PRIMARY KEY (user_id, provider_name)
);

CREATE TABLE user_emails
(
    email      TEXT     NOT NULL,
    user_id    NUMERIC  NOT NULL,
    created_at DATETIME,
    "primary"  BOOLEAN,
    PRIMARY KEY (user_id, email)
);

CREATE TABLE user_field_options
(
    user_field_id NUMERIC  NOT NULL,
    value         TEXT     NOT NULL,
    created_at    DATETIME,
    PRIMARY KEY (user_field_id, value)
);

CREATE TABLE user_fields
(
    original_id       NUMERIC  NOT NULL PRIMARY KEY,
    created_at        DATETIME,
    description       TEXT     NOT NULL,
    editable          BOOLEAN,
    external_name     TEXT,
    external_type     TEXT,
    field_type_enum   INTEGER  NOT NULL,
    name              TEXT     NOT NULL,
    position          INTEGER,
    requirement       INTEGER,
    searchable        BOOLEAN,
    show_on_profile   BOOLEAN,
    show_on_user_card BOOLEAN
);

CREATE TABLE user_options
(
    user_id                              NUMERIC  NOT NULL PRIMARY KEY,
    ai_search_discoveries                BOOLEAN,
    allow_private_messages               BOOLEAN,
    auto_image_caption                   BOOLEAN,
    auto_track_topics_after_msecs        INTEGER,
    automatically_unpin_topics           BOOLEAN,
    bookmark_auto_delete_preference      INTEGER,
    chat_email_frequency                 INTEGER,
    chat_enabled                         BOOLEAN,
    chat_header_indicator_preference     INTEGER,
    chat_quick_reaction_type             INTEGER,
    chat_quick_reactions_custom          TEXT,
    chat_send_shortcut                   INTEGER,
    chat_separate_sidebar_mode           INTEGER,
    chat_sound                           TEXT,
    color_scheme_id                      NUMERIC,
    composition_mode                     INTEGER,
    dark_scheme_id                       NUMERIC,
    default_calendar                     INTEGER,
    digest_after_minutes                 INTEGER,
    dismissed_channel_retention_reminder BOOLEAN,
    dismissed_dm_retention_reminder      BOOLEAN,
    dynamic_favicon                      BOOLEAN,
    email_digests                        BOOLEAN,
    email_in_reply_to                    BOOLEAN,
    email_level                          INTEGER,
    email_messages_level                 INTEGER,
    email_previous_replies               INTEGER,
    enable_allowed_pm_users              BOOLEAN,
    enable_defer                         BOOLEAN,
    enable_markdown_monospace_font       BOOLEAN,
    enable_quoting                       BOOLEAN,
    enable_smart_lists                   BOOLEAN,
    external_links_in_new_tab            BOOLEAN,
    hide_presence                        BOOLEAN,
    hide_profile                         BOOLEAN,
    hide_profile_and_presence            BOOLEAN,
    homepage_id                          NUMERIC,
    ignore_channel_wide_mention          BOOLEAN,
    include_tl0_in_digests               BOOLEAN,
    interface_color_mode                 INTEGER,
    last_redirected_to_top_at            DATETIME,
    like_notification_frequency          INTEGER,
    mailing_list_mode                    BOOLEAN,
    mailing_list_mode_frequency          INTEGER,
    new_topic_duration_minutes           INTEGER,
    notification_level_when_assigned     INTEGER,
    notification_level_when_replying     INTEGER,
    oldest_search_log_date               DATETIME,
    only_chat_push_notifications         BOOLEAN,
    policy_email_frequency               INTEGER,
    seen_popups                          INTEGER,
    show_thread_title_prompts            BOOLEAN,
    sidebar_link_to_filtered_list        BOOLEAN,
    sidebar_show_count_of_new_items      BOOLEAN,
    skip_new_user_tips                   BOOLEAN,
    text_size_key                        INTEGER,
    text_size_seq                        INTEGER,
    theme_ids                            INTEGER,
    theme_key_seq                        INTEGER,
    timezone                             TEXT,
    title_count_mode_key                 INTEGER,
    topics_unread_when_closed            BOOLEAN,
    watched_precedence_over_muted        BOOLEAN
);

CREATE TABLE users
(
    original_id               NUMERIC   NOT NULL PRIMARY KEY,
    active                    BOOLEAN,
    admin                     BOOLEAN,
    approved                  BOOLEAN,
    approved_at               DATETIME,
    approved_by_id            NUMERIC,
    avatar_type               INTEGER,
    created_at                DATETIME  NOT NULL,
    date_of_birth             DATE,
    first_seen_at             DATETIME,
    flair_group_id            NUMERIC,
    group_locked_trust_level  INTEGER,
    ip_address                INET_TEXT,
    last_seen_at              DATETIME,
    locale                    TEXT,
    manual_locked_trust_level INTEGER,
    moderator                 BOOLEAN,
    name                      TEXT,
    original_username         TEXT,
    primary_group_id          NUMERIC,
    registration_ip_address   INET_TEXT,
    silenced_till             DATETIME,
    staged                    BOOLEAN,
    title                     TEXT,
    trust_level               INTEGER   NOT NULL,
    uploaded_avatar_id        TEXT,
    username                  TEXT      NOT NULL,
    views                     INTEGER
);

