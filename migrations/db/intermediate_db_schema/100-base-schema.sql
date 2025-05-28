-- This file is auto-generated from the IntermediateDB schema. To make changes,
-- update the "config/intermediate_db.yml" configuration file and then run
-- `bin/cli schema generate` to regenerate this file.

CREATE TABLE badges
(
    original_id         NUMERIC  NOT NULL PRIMARY KEY,
    allow_title         BOOLEAN,
    auto_revoke         BOOLEAN,
    badge_grouping_id   NUMERIC,
    badge_type_id       NUMERIC  NOT NULL,
    created_at          DATETIME NOT NULL,
    description         TEXT,
    enabled             BOOLEAN,
    existing_id         TEXT,
    icon                TEXT,
    image_upload_id     TEXT,
    listable            BOOLEAN,
    long_description    TEXT,
    multiple_grant      BOOLEAN,
    name                TEXT     NOT NULL,
    "query"             TEXT,
    show_in_post_header BOOLEAN,
    show_posts          BOOLEAN,
    system              BOOLEAN,
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
    created_at                                DATETIME NOT NULL,
    default_list_filter                       TEXT,
    default_slow_mode_seconds                 INTEGER,
    default_top_period                        TEXT,
    default_view                              TEXT,
    description                               TEXT,
    email_in                                  TEXT,
    email_in_allow_strangers                  BOOLEAN,
    emoji                                     TEXT,
    existing_id                               TEXT,
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
    reviewable_by_group_id                    NUMERIC,
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

CREATE TABLE chat_channels
(
    original_id                 NUMERIC  NOT NULL PRIMARY KEY,
    allow_channel_wide_mentions BOOLEAN,
    auto_join_users             BOOLEAN,
    chatable_id                 NUMERIC  NOT NULL,
    chatable_type               TEXT     NOT NULL,
    created_at                  DATETIME NOT NULL,
    delete_after_seconds        INTEGER,
    deleted_at                  DATETIME,
    deleted_by_id               NUMERIC,
    description                 TEXT,
    featured_in_category_id     NUMERIC,
    icon_upload_id              TEXT,
    is_group                    BOOLEAN,
    messages_count              INTEGER,
    name                        TEXT,
    slug                        TEXT,
    status                      INTEGER,
    threading_enabled           BOOLEAN,
    type                        TEXT,
    user_count                  INTEGER
);

CREATE TABLE chat_mentions
(
    original_id     NUMERIC  NOT NULL PRIMARY KEY,
    chat_message_id NUMERIC  NOT NULL,
    created_at      DATETIME NOT NULL,
    target_id       NUMERIC,
    type            TEXT     NOT NULL
);

CREATE TABLE chat_message_reactions
(
    chat_message_id NUMERIC,
    emoji           TEXT,
    user_id         NUMERIC,
    created_at      DATETIME NOT NULL,
    PRIMARY KEY (chat_message_id, user_id, emoji)
);

CREATE TABLE chat_messages
(
    original_id      NUMERIC   NOT NULL PRIMARY KEY,
    blocks           JSON_TEXT,
    chat_channel_id  NUMERIC   NOT NULL,
    created_at       DATETIME  NOT NULL,
    created_by_sdk   BOOLEAN,
    deleted_at       DATETIME,
    deleted_by_id    NUMERIC,
    excerpt          TEXT,
    in_reply_to_id   NUMERIC,
    last_editor_id   NUMERIC   NOT NULL,
    message          TEXT,
    original_message TEXT,
    streaming        BOOLEAN,
    thread_id        NUMERIC,
    user_id          NUMERIC
);

CREATE TABLE chat_threads
(
    channel_id               NUMERIC  NOT NULL,
    original_message_id      NUMERIC  NOT NULL,
    original_message_user_id NUMERIC  NOT NULL,
    created_at               DATETIME NOT NULL,
    force                    BOOLEAN,
    last_message_id          NUMERIC,
    original_id              NUMERIC  NOT NULL,
    replies_count            INTEGER,
    status                   INTEGER,
    title                    TEXT,
    PRIMARY KEY (original_id, channel_id, original_message_id, original_message_user_id)
);

CREATE TABLE group_users
(
    group_id           NUMERIC  NOT NULL,
    user_id            NUMERIC  NOT NULL,
    first_unread_pm_at DATETIME NOT NULL,
    notification_level INTEGER,
    owner              BOOLEAN,
    PRIMARY KEY (group_id, user_id)
);

CREATE TABLE "groups"
(
    original_id                        NUMERIC  NOT NULL PRIMARY KEY,
    allow_membership_requests          BOOLEAN,
    allow_unknown_sender_topic_replies BOOLEAN,
    automatic                          BOOLEAN,
    automatic_membership_email_domains TEXT,
    bio_raw                            TEXT,
    created_at                         DATETIME NOT NULL,
    default_notification_level         INTEGER,
    existing_id                        TEXT,
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
    title                              TEXT,
    visibility_level                   INTEGER
);

CREATE TABLE muted_users
(
    muted_user_id NUMERIC  NOT NULL,
    user_id       NUMERIC  NOT NULL,
    created_at    DATETIME NOT NULL,
    PRIMARY KEY (user_id, muted_user_id)
);

CREATE TABLE permalinks
(
    url                       TEXT      NOT NULL PRIMARY KEY,
    category_id               NUMERIC,
    external_url              TEXT,
    external_url_placeholders JSON_TEXT,
    post_id                   NUMERIC,
    tag_id                    NUMERIC,
    topic_id                  NUMERIC,
    user_id                   NUMERIC
);

CREATE TABLE poll_options
(
    original_id     NUMERIC  NOT NULL PRIMARY KEY,
    anonymous_votes INTEGER,
    created_at      DATETIME NOT NULL,
    poll_id         NUMERIC
);

CREATE TABLE poll_votes
(
    poll_option_id NUMERIC,
    user_id        NUMERIC,
    created_at     DATETIME NOT NULL,
    poll_id        NUMERIC,
    rank           INTEGER,
    PRIMARY KEY (poll_option_id, user_id)
);

CREATE TABLE polls
(
    original_id      NUMERIC  NOT NULL PRIMARY KEY,
    anonymous_voters INTEGER,
    chart_type       INTEGER,
    close_at         DATETIME,
    created_at       DATETIME NOT NULL,
    "groups"         TEXT,
    max              INTEGER,
    min              INTEGER,
    name             TEXT,
    post_id          NUMERIC,
    results          INTEGER,
    status           INTEGER,
    step             INTEGER,
    title            TEXT,
    type             INTEGER,
    visibility       INTEGER
);

CREATE TABLE post_custom_fields
(
    name    TEXT    NOT NULL,
    post_id NUMERIC NOT NULL,
    value   TEXT,
    PRIMARY KEY (post_id, name)
);

CREATE TABLE posts
(
    original_id      NUMERIC  NOT NULL PRIMARY KEY,
    created_at       DATETIME NOT NULL,
    deleted_at       DATETIME,
    deleted_by_id    NUMERIC,
    hidden           BOOLEAN,
    hidden_at        DATETIME,
    hidden_reason_id NUMERIC,
    image_upload_id  TEXT,
    last_editor_id   NUMERIC,
    last_version_at  DATETIME NOT NULL,
    like_count       INTEGER,
    locale           TEXT,
    locked_by_id     NUMERIC,
    original_raw     TEXT,
    post_number      INTEGER  NOT NULL,
    post_type        INTEGER,
    quote_count      INTEGER,
    raw              TEXT     NOT NULL,
    reads            INTEGER,
    reply_count      INTEGER,
    reply_to_post_id NUMERIC,
    reply_to_user_id NUMERIC,
    spam_count       INTEGER,
    topic_id         NUMERIC  NOT NULL,
    user_deleted     BOOLEAN,
    user_id          NUMERIC,
    wiki             BOOLEAN
);

CREATE INDEX posts_by_topic_post_number ON posts (topic_id, post_number);

CREATE TABLE tag_groups
(
    original_id   NUMERIC  NOT NULL PRIMARY KEY,
    created_at    DATETIME NOT NULL,
    name          TEXT     NOT NULL,
    one_per_topic BOOLEAN,
    parent_tag_id NUMERIC
);

CREATE TABLE tag_users
(
    tag_id             NUMERIC  NOT NULL,
    user_id            NUMERIC  NOT NULL,
    created_at         DATETIME NOT NULL,
    notification_level INTEGER  NOT NULL,
    original_id        NUMERIC  NOT NULL,
    PRIMARY KEY (tag_id, user_id)
);

CREATE TABLE tags
(
    original_id   NUMERIC  NOT NULL PRIMARY KEY,
    created_at    DATETIME NOT NULL,
    description   TEXT,
    name          TEXT     NOT NULL,
    tag_group_id  NUMERIC,
    target_tag_id NUMERIC
);

CREATE TABLE topic_tags
(
    tag_id      NUMERIC  NOT NULL,
    topic_id    NUMERIC  NOT NULL,
    created_at  DATETIME NOT NULL,
    original_id NUMERIC  NOT NULL,
    PRIMARY KEY (topic_id, tag_id)
);

CREATE TABLE topic_users
(
    topic_id                 NUMERIC  NOT NULL,
    user_id                  NUMERIC  NOT NULL,
    bookmarked               BOOLEAN,
    cleared_pinned_at        DATETIME,
    first_visited_at         DATETIME,
    last_emailed_post_number INTEGER,
    last_posted_at           DATETIME,
    last_read_post_number    INTEGER,
    last_visited_at          DATETIME,
    liked                    BOOLEAN,
    notification_level       INTEGER,
    notifications_changed_at DATETIME,
    notifications_reason_id  NUMERIC,
    posted                   BOOLEAN,
    total_msecs_viewed       INTEGER,
    PRIMARY KEY (user_id, topic_id)
);

CREATE TABLE topics
(
    original_id         NUMERIC  NOT NULL PRIMARY KEY,
    archetype           TEXT,
    archived            BOOLEAN,
    bannered_until      DATETIME,
    bumped_at           DATETIME NOT NULL,
    category_id         NUMERIC,
    closed              BOOLEAN,
    created_at          DATETIME NOT NULL,
    deleted_at          DATETIME,
    deleted_by_id       NUMERIC,
    excerpt             TEXT,
    featured_link       TEXT,
    featured_user1_id   NUMERIC,
    featured_user2_id   NUMERIC,
    featured_user3_id   NUMERIC,
    featured_user4_id   NUMERIC,
    has_summary         BOOLEAN,
    image_upload_id     TEXT,
    incoming_link_count INTEGER,
    locale              TEXT,
    pinned_at           DATETIME,
    pinned_globally     BOOLEAN,
    pinned_until        DATETIME,
    slug                TEXT,
    subtype             TEXT,
    title               TEXT     NOT NULL,
    user_id             NUMERIC,
    views               INTEGER,
    visible             BOOLEAN
);

CREATE TABLE user_associated_accounts
(
    provider_name TEXT      NOT NULL,
    user_id       NUMERIC,
    credentials   JSON_TEXT,
    extra         JSON_TEXT,
    info          JSON_TEXT,
    last_used     DATETIME  NOT NULL,
    provider_uid  TEXT      NOT NULL,
    PRIMARY KEY (user_id, provider_name)
);

CREATE TABLE user_badges
(
    badge_id      NUMERIC  NOT NULL,
    created_at    DATETIME NOT NULL,
    featured_rank INTEGER,
    granted_at    DATETIME NOT NULL,
    granted_by_id NUMERIC  NOT NULL,
    is_favorite   BOOLEAN,
    post_id       NUMERIC,
    user_id       NUMERIC  NOT NULL
);

CREATE TABLE user_chat_channel_memberships
(
    chat_channel_id                     NUMERIC  NOT NULL,
    user_id                             NUMERIC  NOT NULL,
    created_at                          DATETIME NOT NULL,
    desktop_notification_level          INTEGER,
    "following"                         BOOLEAN,
    join_mode                           INTEGER,
    last_read_message_id                NUMERIC,
    last_unread_mention_when_emailed_id NUMERIC,
    last_viewed_at                      DATETIME NOT NULL,
    mobile_notification_level           INTEGER,
    muted                               BOOLEAN,
    notification_level                  INTEGER,
    PRIMARY KEY (user_id, chat_channel_id)
);

CREATE TABLE user_chat_thread_memberships
(
    thread_id                           NUMERIC  NOT NULL,
    user_id                             NUMERIC  NOT NULL,
    created_at                          DATETIME NOT NULL,
    last_read_message_id                NUMERIC,
    last_unread_message_when_emailed_id NUMERIC,
    notification_level                  INTEGER,
    thread_title_prompt_seen            BOOLEAN,
    PRIMARY KEY (user_id, thread_id)
);

CREATE TABLE user_custom_fields
(
    field_id             NUMERIC NOT NULL,
    is_multiselect_field BOOLEAN NOT NULL,
    name                 TEXT    NOT NULL,
    user_id              NUMERIC NOT NULL,
    value                TEXT
);

CREATE UNIQUE INDEX user_field_values_multiselect ON user_custom_fields (user_id, field_id, value) WHERE is_multiselect_field = TRUE;

CREATE UNIQUE INDEX user_field_values_not_multiselect ON user_custom_fields (user_id, field_id) WHERE is_multiselect_field = FALSE;

CREATE TABLE user_emails
(
    email      TEXT     NOT NULL PRIMARY KEY,
    created_at DATETIME NOT NULL,
    "primary"  BOOLEAN,
    user_id    NUMERIC  NOT NULL
);

CREATE TABLE user_fields
(
    original_id       NUMERIC   NOT NULL PRIMARY KEY,
    created_at        DATETIME  NOT NULL,
    description       TEXT      NOT NULL,
    editable          BOOLEAN,
    external_name     TEXT,
    external_type     TEXT,
    field_type        TEXT,
    field_type_enum   INTEGER   NOT NULL,
    name              TEXT      NOT NULL,
    options           JSON_TEXT,
    position          INTEGER,
    required          BOOLEAN,
    requirement       INTEGER,
    searchable        BOOLEAN,
    show_on_profile   BOOLEAN,
    show_on_user_card BOOLEAN
);

CREATE TABLE user_options
(
    user_id                              NUMERIC  NOT NULL PRIMARY KEY,
    allow_private_messages               BOOLEAN,
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
    enable_experimental_sidebar          BOOLEAN,
    enable_quoting                       BOOLEAN,
    enable_smart_lists                   BOOLEAN,
    external_links_in_new_tab            BOOLEAN,
    hide_presence                        BOOLEAN,
    hide_profile                         BOOLEAN,
    hide_profile_and_presence            BOOLEAN,
    homepage_id                          NUMERIC,
    ignore_channel_wide_mention          BOOLEAN,
    include_tl0_in_digests               BOOLEAN,
    last_redirected_to_top_at            DATETIME,
    like_notification_frequency          INTEGER,
    mailing_list_mode                    BOOLEAN,
    mailing_list_mode_frequency          INTEGER,
    new_topic_duration_minutes           INTEGER,
    notification_level_when_replying     INTEGER,
    oldest_search_log_date               DATETIME,
    only_chat_push_notifications         BOOLEAN,
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

