/*
 This file is auto-generated from the Discourse core database schema. Instead of editing it directly,
 please update the `schema.yml` configuration file and re-run the `generate_schema` script to update it.
*/

CREATE TABLE badges (
  id INTEGER NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  badge_type_id INTEGER NOT NULL,
  created_at DATETIME NOT NULL,
  multiple_grant BOOLEAN NOT NULL,
  query TEXT,
  long_description TEXT,
  image_upload_id INTEGER,
  bage_group TEXT
);

CREATE TABLE categories (
  id INTEGER NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  slug TEXT NOT NULL,
  description TEXT,
  text_color TEXT NOT NULL,
  read_restricted BOOLEAN NOT NULL,
  position INTEGER,
  parent_category_id INTEGER,
  about_topic_title TEXT,
  old_relative_url TEXT,
  existing_id INTEGER,
  permissions JSON_TEXT,
  logo_upload_id TEXT,
  tag_group_ids JSON_TEXT
);

CREATE TABLE category_custom_fields (
  category_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  value TEXT,
  PRIMARY KEY (category_id, name)
);

CREATE TABLE config (
  name TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE group_members (
  group_id INTEGER,
  user_id INTEGER,
  owner BOOLEAN,
  PRIMARY KEY (group_id, user_id)
);

CREATE TABLE groups (
  id INTEGER NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  full_name TEXT,
  visibility_level INTEGER NOT NULL,
  messageable_level INTEGER,
  mentionable_level INTEGER,
  members_visibility_level INTEGER NOT NULL,
  description TEXT
);

CREATE TABLE likes (
  post_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  created_at DATETIME NOT NULL,
  PRIMARY KEY (user_id, post_id)
);

CREATE TABLE log_entries (
  created_at DATETIME NOT NULL,
  type TEXT NOT NULL,
  message TEXT NOT NULL,
  exception TEXT,
  details TEXT
);

CREATE TABLE muted_users (
  user_id INTEGER NOT NULL,
  muted_user_id INTEGER NOT NULL,
  PRIMARY KEY (user_id, muted_user_id)
);

CREATE TABLE permalink_normalizations (
  normalization TEXT NOT NULL PRIMARY KEY
);

CREATE TABLE poll_options (
  id INTEGER NOT NULL PRIMARY KEY,
  poll_id INTEGER NOT NULL,
  created_at DATETIME,
  text TEXT NOT NULL,
  position INTEGER
);

CREATE TABLE poll_votes (
  poll_option_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  created_at DATETIME,
  PRIMARY KEY (poll_option_id, user_id)
);

CREATE TABLE polls (
  id INTEGER NOT NULL PRIMARY KEY,
  post_id INTEGER,
  name TEXT NOT NULL,
  close_at DATETIME,
  type INTEGER NOT NULL,
  status INTEGER NOT NULL,
  results INTEGER NOT NULL,
  visibility INTEGER NOT NULL,
  min INTEGER,
  max INTEGER,
  step INTEGER,
  anonymous_voters INTEGER,
  created_at DATETIME NOT NULL,
  chart_type INTEGER NOT NULL,
  groups TEXT,
  title TEXT
);

CREATE TABLE post_custom_fields (
  post_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  value TEXT,
  PRIMARY KEY (post_id, name)
);

CREATE TABLE posts (
  id INTEGER NOT NULL PRIMARY KEY,
  user_id INTEGER,
  topic_id INTEGER NOT NULL,
  post_number INTEGER NOT NULL,
  raw TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  like_count INTEGER NOT NULL,
  reply_to_post_id TEXT,
  original_raw TEXT,
  upload_ids JSON_TEXT,
  old_relative_url TEXT,
  accepted_answer BOOLEAN,
  small_action TEXT,
  whisper BOOLEAN,
  placeholders JSON_TEXT
);

CREATE INDEX posts_by_topic_post_number ON posts (topic_id, post_number);

CREATE TABLE schema_migrations (
  path TEXT NOT NULL PRIMARY KEY,
  created_at DATETIME
);

CREATE TABLE site_settings (
  name TEXT NOT NULL,
  value TEXT,
  action TEXT
);

CREATE TABLE tag_groups (
  id INTEGER NOT NULL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE tag_users (
  tag_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  notification_level INTEGER NOT NULL,
  PRIMARY KEY (tag_id, user_id)
);

CREATE TABLE tags (
  id INTEGER NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  tag_group_id INTEGER
);

CREATE TABLE topic_tags (
  topic_id INTEGER NOT NULL,
  tag_id INTEGER NOT NULL,
  PRIMARY KEY (topic_id, tag_id)
);

CREATE TABLE topic_users (
  user_id INTEGER NOT NULL,
  topic_id INTEGER NOT NULL,
  last_read_post_number INTEGER,
  last_visited_at DATETIME,
  first_visited_at DATETIME,
  notification_level INTEGER NOT NULL,
  notifications_changed_at DATETIME,
  notifications_reason_id INTEGER,
  total_msecs_viewed INTEGER NOT NULL,
  PRIMARY KEY (user_id, topic_id)
);

CREATE TABLE topics (
  id INTEGER NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  created_at DATETIME NOT NULL,
  views INTEGER NOT NULL,
  user_id INTEGER,
  category_id INTEGER,
  visible BOOLEAN NOT NULL,
  closed BOOLEAN NOT NULL,
  archived BOOLEAN NOT NULL,
  pinned_at DATETIME,
  subtype TEXT,
  pinned_globally BOOLEAN NOT NULL,
  pinned_until DATETIME,
  old_relative_url TEXT,
  private_message TEXT
);

CREATE TABLE uploads (
  id INTEGER NOT NULL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  filename TEXT NOT NULL,
  relative_path TEXT,
  type TEXT,
  data BLOB
);

CREATE TABLE user_badges (
  badge_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  granted_at DATETIME NOT NULL
);

CREATE TABLE user_field_values (
  user_id INTEGER NOT NULL,
  field_id INTEGER NOT NULL,
  is_multiselect_field BOOLEAN NOT NULL,
  value TEXT
);

CREATE UNIQUE INDEX user_field_values_multiselect ON user_field_values (user_id, field_id, value) WHERE is_multiselect_field = TRUE;
CREATE UNIQUE INDEX user_field_values_not_multiselect ON user_field_values (user_id, field_id) WHERE is_multiselect_field = FALSE;

CREATE TABLE user_fields (
  id INTEGER NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  field_type TEXT NOT NULL,
  editable BOOLEAN NOT NULL,
  description TEXT NOT NULL,
  required BOOLEAN NOT NULL,
  show_on_profile BOOLEAN NOT NULL,
  position INTEGER,
  show_on_user_card BOOLEAN NOT NULL,
  searchable BOOLEAN NOT NULL,
  options JSON_TEXT
);

CREATE TABLE users (
  id INTEGER NOT NULL PRIMARY KEY,
  username TEXT NOT NULL,
  created_at DATETIME,
  name TEXT,
  last_seen_at DATETIME,
  admin BOOLEAN NOT NULL,
  trust_level INTEGER,
  approved BOOLEAN NOT NULL,
  approved_at DATETIME,
  date_of_birth DATE,
  moderator BOOLEAN,
  registration_ip_address TEXT,
  staged BOOLEAN,
  email TEXT,
  avatar_path TEXT,
  avatar_url TEXT,
  avatar_upload_id TEXT,
  bio TEXT,
  password TEXT,
  suspension TEXT,
  location TEXT,
  website TEXT,
  old_relative_url TEXT,
  sso_record TEXT,
  anonymized BOOLEAN,
  original_username TEXT,
  timezone TEXT,
  email_level INTEGER,
  email_messages_level INTEGER,
  email_digests BOOLEAN
);


/*
Core table columns implicitly excluded from the generated schema above via the `include` configuration option
in `schema.yml`. This serves as an inventory of these columns, allowing new core additions to be tracked and,
if necessary, synchronized with the intermediate database schema.

Table: groups
--------------
 created_at datetime false
 automatic boolean false
 user_count integer false
 automatic_membership_email_domains text true
 primary_group boolean false
 title string true
 grant_trust_level integer true
 incoming_email string true
 has_messages boolean false
 flair_bg_color string true
 flair_color string true
 bio_raw text true
 bio_cooked text true
 allow_membership_requests boolean false
 default_notification_level integer false
 public_exit boolean false
 public_admission boolean false
 membership_request_template text true
 smtp_server string true
 smtp_port integer true
 smtp_ssl boolean true
 imap_server string true
 imap_port integer true
 imap_ssl boolean true
 imap_mailbox_name string false
 imap_uid_validity integer false
 imap_last_uid integer false
 email_username string true
 email_password string true
 publish_read_state boolean false
 imap_last_error text true
 imap_old_emails integer true
 imap_new_emails integer true
 flair_icon string true
 flair_upload_id integer true
 allow_unknown_sender_topic_replies boolean false
 smtp_enabled boolean true
 smtp_updated_at datetime true
 smtp_updated_by_id integer true
 imap_enabled boolean true
 imap_updated_at datetime true
 imap_updated_by_id integer true
 email_from_alias string true

Table: site_settings
---------------------
 id integer false
 data_type integer false
 created_at datetime false

Table: tag_groups
------------------
 created_at datetime false
 parent_tag_id integer true
 one_per_topic boolean true

Table: tags
------------
 created_at datetime false
 pm_topic_count integer false
 target_tag_id integer true
 description string true
 public_topic_count integer false
 staff_topic_count integer false

Table: user_badges
-------------------
 id integer false
 granted_by_id integer false
 post_id integer true
 notification_id integer true
 seq integer false
 featured_rank integer true
 created_at datetime false
 is_favorite boolean true
*/