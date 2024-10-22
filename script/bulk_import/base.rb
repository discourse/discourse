# frozen_string_literal: true

if ARGV.include?("bbcode-to-md")
  # Replace (most) bbcode with markdown before creating posts.
  # This will dramatically clean up the final posts in Discourse.
  #
  # In a temp dir:
  #
  # git clone https://github.com/nlalonde/ruby-bbcode-to-md.git
  # cd ruby-bbcode-to-md
  # gem build ruby-bbcode-to-md.gemspec
  # gem install ruby-bbcode-to-md-*.gem
  require "ruby-bbcode-to-md"
end

require "pg"
require "redcarpet"
require "htmlentities"

puts "Loading application..."
require_relative "../../config/environment"
require_relative "../import_scripts/base/uploader"

module BulkImport
end

class BulkImport::Base
  NOW = "now()"
  PRIVATE_OFFSET = 2**30

  CHARSET_MAP = {
    "armscii8" => nil,
    "ascii" => Encoding::US_ASCII,
    "big5" => Encoding::Big5,
    "binary" => Encoding::ASCII_8BIT,
    "cp1250" => Encoding::Windows_1250,
    "cp1251" => Encoding::Windows_1251,
    "cp1256" => Encoding::Windows_1256,
    "cp1257" => Encoding::Windows_1257,
    "cp850" => Encoding::CP850,
    "cp852" => Encoding::CP852,
    "cp866" => Encoding::IBM866,
    "cp932" => Encoding::Windows_31J,
    "dec8" => nil,
    "eucjpms" => Encoding::EucJP_ms,
    "euckr" => Encoding::EUC_KR,
    "gb2312" => Encoding::EUC_CN,
    "gbk" => Encoding::GBK,
    "geostd8" => nil,
    "greek" => Encoding::ISO_8859_7,
    "hebrew" => Encoding::ISO_8859_8,
    "hp8" => nil,
    "keybcs2" => nil,
    "koi8r" => Encoding::KOI8_R,
    "koi8u" => Encoding::KOI8_U,
    "latin1" => Encoding::ISO_8859_1,
    "latin2" => Encoding::ISO_8859_2,
    "latin5" => Encoding::ISO_8859_9,
    "latin7" => Encoding::ISO_8859_13,
    "macce" => Encoding::MacCentEuro,
    "macroman" => Encoding::MacRoman,
    "sjis" => Encoding::SHIFT_JIS,
    "swe7" => nil,
    "tis620" => Encoding::TIS_620,
    "ucs2" => Encoding::UTF_16BE,
    "ujis" => Encoding::EucJP_ms,
    "utf8" => Encoding::UTF_8,
  }

  def initialize
    charset = ENV["DB_CHARSET"] || "utf8"
    db = ActiveRecord::Base.connection_db_config.configuration_hash
    @encoder = PG::TextEncoder::CopyRow.new
    @raw_connection = PG.connect(dbname: db[:database], port: db[:port])
    @uploader = ImportScripts::Uploader.new
    @html_entities = HTMLEntities.new
    @encoding = CHARSET_MAP[charset]
    @bbcode_to_md = true if use_bbcode_to_md?

    @markdown =
      Redcarpet::Markdown.new(
        Redcarpet::Render::HTML.new(hard_wrap: true),
        no_intra_emphasis: true,
        fenced_code_blocks: true,
        autolink: true,
      )
  end

  def run
    start_time = Time.now

    puts "Starting..."
    Rails.logger.level = 3 # :error, so that we don't create log files that are many GB
    preload_i18n
    create_migration_mappings_table
    fix_highest_post_numbers
    load_imported_ids
    load_indexes
    execute
    fix_primary_keys
    execute_after
    puts "Done! (#{((Time.now - start_time) / 60).to_i} minutes)"
    puts "Now run the 'import:ensure_consistency' rake task."
  end

  def preload_i18n
    puts "Preloading I18n..."
    I18n.locale = ENV.fetch("LOCALE") { SiteSettings::DefaultsProvider::DEFAULT_LOCALE }.to_sym
    I18n.t("test")
    ActiveSupport::Inflector.transliterate("test")
  end

  MAPPING_TYPES =
    Enum.new(
      upload: 1,
      badge: 2,
      poll: 3,
      poll_option: 4,
      direct_message_channel: 5,
      chat_channel: 6,
      chat_thread: 7,
      chat_message: 8,
    )

  def create_migration_mappings_table
    puts "Creating migration mappings table..."
    @raw_connection.exec <<~SQL
      CREATE TABLE IF NOT EXISTS migration_mappings (
        original_id VARCHAR(255) NOT NULL,
        type INTEGER NOT NULL,
        discourse_id VARCHAR(255) NOT NULL,
        PRIMARY KEY (original_id, type)
      )
    SQL
  end

  def fix_highest_post_numbers
    puts "Fixing highest post numbers..."
    @raw_connection.exec <<-SQL
      WITH X AS (
          SELECT topic_id
               , COALESCE(MAX(post_number), 0) max_post_number
            FROM posts
           WHERE deleted_at IS NULL
        GROUP BY topic_id
      )
      UPDATE topics
         SET highest_post_number = X.max_post_number
        FROM X
       WHERE id = X.topic_id
         AND highest_post_number <> X.max_post_number
    SQL
  end

  def imported_ids(name)
    map = {}
    ids = []

    @raw_connection.send_query(
      "SELECT value, #{name}_id FROM #{name}_custom_fields WHERE name = 'import_id'",
    )
    @raw_connection.set_single_row_mode

    @raw_connection.get_result.stream_each do |row|
      id = row["value"].to_i
      ids << id
      map[id] = row["#{name}_id"].to_i
    end

    @raw_connection.get_result

    [map, ids]
  end

  def load_imported_ids
    puts "Loading imported group ids..."
    @groups, imported_group_ids = imported_ids("group")
    @last_imported_group_id = imported_group_ids.max || -1

    puts "Loading imported user ids..."
    @users, imported_user_ids = imported_ids("user")
    @last_imported_user_id = imported_user_ids.max || -1

    puts "Loading imported category ids..."
    @categories, imported_category_ids = imported_ids("category")
    @last_imported_category_id = imported_category_ids.max || -1

    puts "Loading imported topic ids..."
    @topics, imported_topic_ids = imported_ids("topic")
    @last_imported_topic_id = imported_topic_ids.select { |id| id < PRIVATE_OFFSET }.max || -1
    @last_imported_private_topic_id =
      imported_topic_ids.select { |id| id > PRIVATE_OFFSET }.max || (PRIVATE_OFFSET - 1)

    puts "Loading imported post ids..."
    @posts, imported_post_ids = imported_ids("post")
    @last_imported_post_id = imported_post_ids.select { |id| id < PRIVATE_OFFSET }.max || -1
    @last_imported_private_post_id =
      imported_post_ids.select { |id| id > PRIVATE_OFFSET }.max || (PRIVATE_OFFSET - 1)
  end

  def last_id(klass)
    # the first record created will have id of this value + 1
    [klass.unscoped.maximum(:id) || 0, 0].max
  end

  def load_values(name, column, size)
    map = Array.new(size)

    @raw_connection.send_query("SELECT id, #{column} FROM #{name}")
    @raw_connection.set_single_row_mode

    @raw_connection.get_result.stream_each { |row| map[row["id"].to_i] = row[column].to_i }

    @raw_connection.get_result

    map
  end

  def load_index(type)
    map = {}

    @raw_connection.send_query(
      "SELECT original_id, discourse_id FROM migration_mappings WHERE type = #{type}",
    )
    @raw_connection.set_single_row_mode

    @raw_connection.get_result.stream_each { |row| map[row["original_id"]] = row["discourse_id"] }

    @raw_connection.get_result

    map
  end

  def load_indexes
    puts "Loading groups indexes..."
    @last_group_id = last_id(Group)
    @group_names_lower = Group.unscoped.pluck(:name).map(&:downcase).to_set

    puts "Loading users indexes..."
    @last_user_id = last_id(User)
    @last_user_email_id = last_id(UserEmail)
    @last_sso_record_id = last_id(SingleSignOnRecord)
    @emails = UserEmail.pluck(:email, :user_id).to_h
    @external_ids = SingleSignOnRecord.pluck(:external_id, :user_id).to_h
    @usernames_lower = User.unscoped.pluck(:username_lower).to_set
    @anonymized_user_suffixes =
      DB.query_single(
        "SELECT SUBSTRING(username_lower, 5)::BIGINT FROM users WHERE username_lower ~* '^anon\\d+$'",
      ).to_set
    @mapped_usernames =
      UserCustomField
        .joins(:user)
        .where(name: "import_username")
        .pluck("user_custom_fields.value", "users.username")
        .to_h
    @last_user_avatar_id = last_id(UserAvatar)
    @last_upload_id = last_id(Upload)
    @user_ids_by_username_lower = User.unscoped.pluck(:id, :username_lower).to_h
    @usernames_by_id = User.unscoped.pluck(:id, :username).to_h
    @user_full_names_by_id = User.unscoped.where("name IS NOT NULL").pluck(:id, :name).to_h

    puts "Loading categories indexes..."
    @last_category_id = last_id(Category)
    @last_category_group_id = last_id(CategoryGroup)
    @highest_category_position = Category.unscoped.maximum(:position) || 0
    @category_names =
      Category
        .unscoped
        .pluck(:parent_category_id, :name)
        .map { |pci, name| "#{pci}-#{name.downcase}" }
        .to_set

    puts "Loading topics indexes..."
    @last_topic_id = last_id(Topic)
    @highest_post_number_by_topic_id = load_values("topics", "highest_post_number", @last_topic_id)

    puts "Loading posts indexes..."
    @last_post_id = last_id(Post)
    @post_number_by_post_id = load_values("posts", "post_number", @last_post_id)
    @topic_id_by_post_id = load_values("posts", "topic_id", @last_post_id)

    puts "Loading post actions indexes..."
    @last_post_action_id = last_id(PostAction)

    puts "Loading upload indexes..."
    @uploads_mapping = load_index(MAPPING_TYPES[:upload])
    @uploads_by_sha1 = Upload.pluck(:sha1, :id).to_h
    @upload_urls_by_id = Upload.pluck(:id, :url).to_h

    puts "Loading badge indexes..."
    @badge_mapping = load_index(MAPPING_TYPES[:badge])
    @last_badge_id = last_id(Badge)

    puts "Loading poll indexes..."
    @poll_mapping = load_index(MAPPING_TYPES[:poll])
    @poll_option_mapping = load_index(MAPPING_TYPES[:poll_option])
    @last_poll_id = last_id(Poll)
    @last_poll_option_id = last_id(PollOption)

    puts "Loading chat indexes..."
    @chat_direct_message_channel_mapping = load_index(MAPPING_TYPES[:direct_message_channel])
    @last_chat_direct_message_channel_id = last_id(Chat::DirectMessage)

    @chat_channel_mapping = load_index(MAPPING_TYPES[:chat_channel])
    @last_chat_channel_id = last_id(Chat::Channel)

    @chat_thread_mapping = load_index(MAPPING_TYPES[:chat_thread])
    @last_chat_thread_id = last_id(Chat::Thread)

    @chat_message_mapping = load_index(MAPPING_TYPES[:chat_message])
    @last_chat_message_id = last_id(Chat::Message)
  end

  def use_bbcode_to_md?
    ARGV.include?("bbcode-to-md")
  end

  def execute
    raise NotImplementedError
  end

  def execute_after
  end

  def fix_primary_keys
    puts "Updating primary key sequences..."
    if @last_group_id > 0
      @raw_connection.exec("SELECT setval('#{Group.sequence_name}', #{@last_group_id})")
    end
    if @last_user_id > 0
      @raw_connection.exec("SELECT setval('#{User.sequence_name}', #{@last_user_id})")
    end
    if @last_user_email_id > 0
      @raw_connection.exec("SELECT setval('#{UserEmail.sequence_name}', #{@last_user_email_id})")
    end
    if @last_sso_record_id > 0
      @raw_connection.exec(
        "SELECT setval('#{SingleSignOnRecord.sequence_name}', #{@last_sso_record_id})",
      )
    end
    if @last_category_id > 0
      @raw_connection.exec("SELECT setval('#{Category.sequence_name}', #{@last_category_id})")
    end
    if @last_category_group_id > 0
      @raw_connection.exec(
        "SELECT setval('#{CategoryGroup.sequence_name}', #{@last_category_group_id})",
      )
    end
    if @last_topic_id > 0
      @raw_connection.exec("SELECT setval('#{Topic.sequence_name}', #{@last_topic_id})")
    end
    if @last_post_id > 0
      @raw_connection.exec("SELECT setval('#{Post.sequence_name}', #{@last_post_id})")
    end
    if @last_post_action_id > 0
      @raw_connection.exec("SELECT setval('#{PostAction.sequence_name}', #{@last_post_action_id})")
    end
    if @last_user_avatar_id > 0
      @raw_connection.exec("SELECT setval('#{UserAvatar.sequence_name}', #{@last_user_avatar_id})")
    end
    if @last_upload_id > 0
      @raw_connection.exec("SELECT setval('#{Upload.sequence_name}', #{@last_upload_id})")
    end
    if @last_badge_id > 0
      @raw_connection.exec("SELECT setval('#{Badge.sequence_name}', #{@last_badge_id})")
    end
    if @last_poll_id > 0
      @raw_connection.exec("SELECT setval('#{Poll.sequence_name}', #{@last_poll_id})")
    end
    if @last_poll_option_id > 0
      @raw_connection.exec("SELECT setval('#{PollOption.sequence_name}', #{@last_poll_option_id})")
    end
    if @last_chat_direct_message_channel_id > 0
      @raw_connection.exec(
        "SELECT setval('#{Chat::DirectMessage.sequence_name}', #{@last_chat_direct_message_channel_id})",
      )
    end
    if @last_chat_channel_id > 0
      @raw_connection.exec(
        "SELECT setval('#{Chat::Channel.sequence_name}', #{@last_chat_channel_id})",
      )
    end
    if @last_chat_thread_id > 0
      @raw_connection.exec(
        "SELECT setval('#{Chat::Thread.sequence_name}', #{@last_chat_thread_id})",
      )
    end
    if @last_chat_message_id > 0
      @raw_connection.exec(
        "SELECT setval('#{Chat::Message.sequence_name}', #{@last_chat_message_id})",
      )
    end
  end

  def group_id_from_imported_id(id)
    @groups[id.to_i]
  end

  def user_id_from_imported_id(id)
    @users[id.to_i]
  end

  def user_id_from_original_username(username)
    normalized_username = User.normalize_username(@mapped_usernames[username] || username)
    @user_ids_by_username_lower[normalized_username]
  end

  def username_from_id(id)
    @usernames_by_id[id]
  end

  def user_full_name_from_id(id)
    @user_full_names_by_id[id]
  end

  def category_id_from_imported_id(id)
    @categories[id.to_i]
  end

  def topic_id_from_imported_id(id)
    @topics[id.to_i]
  end

  def post_id_from_imported_id(id)
    @posts[id.to_i]
  end

  def upload_id_from_original_id(id)
    @uploads_mapping[id.to_s]&.to_i
  end

  def upload_id_from_sha1(sha1)
    @uploads_by_sha1[sha1]
  end

  def upload_url_from_id(id)
    @upload_urls_by_id[id]
  end

  def post_number_from_imported_id(id)
    post_id = post_id_from_imported_id(id)
    post_id && @post_number_by_post_id[post_id]
  end

  def topic_id_from_imported_post_id(id)
    post_id = post_id_from_imported_id(id)
    post_id && @topic_id_by_post_id[post_id]
  end

  def badge_id_from_original_id(id)
    @badge_mapping[id.to_s]&.to_i
  end

  def poll_id_from_original_id(id)
    @poll_mapping[id.to_s]&.to_i
  end

  def poll_option_id_from_original_id(id)
    @poll_option_mapping[id.to_s]&.to_i
  end

  def chat_channel_id_from_original_id(id)
    @chat_channel_mapping[id.to_s]&.to_i
  end

  def chat_direct_message_channel_id_from_original_id(id)
    @chat_direct_message_channel_mapping[id.to_s]&.to_i
  end

  def chat_thread_id_from_original_id(id)
    @chat_thread_mapping[id.to_s]&.to_i
  end

  def chat_message_id_from_original_id(id)
    @chat_message_mapping[id.to_s]&.to_i
  end

  GROUP_COLUMNS = %i[
    id
    name
    full_name
    title
    bio_raw
    bio_cooked
    visibility_level
    members_visibility_level
    mentionable_level
    messageable_level
    created_at
    updated_at
  ]

  USER_COLUMNS = %i[
    id
    username
    username_lower
    name
    active
    trust_level
    admin
    moderator
    date_of_birth
    ip_address
    registration_ip_address
    primary_group_id
    suspended_at
    suspended_till
    last_seen_at
    last_emailed_at
    created_at
    updated_at
    flair_group_id
    title
  ]

  USER_EMAIL_COLUMNS = %i[id user_id email primary created_at updated_at]

  USER_STAT_COLUMNS = %i[
    user_id
    topics_entered
    time_read
    days_visited
    posts_read_count
    likes_given
    likes_received
    new_since
    read_faq
    first_post_created_at
    post_count
    topic_count
    bounce_score
    reset_bounce_score_after
    digest_attempted_at
  ]

  USER_HISTORY_COLUMNS = %i[action acting_user_id target_user_id details created_at updated_at]

  USER_AVATAR_COLUMNS = %i[id user_id custom_upload_id created_at updated_at]

  USER_PROFILE_COLUMNS = %i[user_id location website bio_raw bio_cooked views]

  USER_SSO_RECORD_COLUMNS = %i[
    id
    user_id
    external_id
    last_payload
    created_at
    updated_at
    external_username
    external_email
    external_name
    external_avatar_url
    external_profile_background_url
    external_card_background_url
  ]

  USER_ASSOCIATED_ACCOUNT_COLUMNS = %i[
    provider_name
    provider_uid
    user_id
    last_used
    info
    credentials
    extra
    created_at
    updated_at
  ]

  USER_OPTION_COLUMNS = %i[
    user_id
    mailing_list_mode
    mailing_list_mode_frequency
    email_level
    email_messages_level
    email_previous_replies
    email_in_reply_to
    email_digests
    digest_after_minutes
    include_tl0_in_digests
    automatically_unpin_topics
    enable_quoting
    external_links_in_new_tab
    dynamic_favicon
    new_topic_duration_minutes
    auto_track_topics_after_msecs
    notification_level_when_replying
    like_notification_frequency
    skip_new_user_tips
    hide_profile_and_presence
    sidebar_link_to_filtered_list
    sidebar_show_count_of_new_items
    timezone
  ]

  USER_FOLLOWER_COLUMNS = %i[user_id follower_id level created_at updated_at]

  GROUP_USER_COLUMNS = %i[group_id user_id created_at updated_at]

  USER_CUSTOM_FIELD_COLUMNS = %i[user_id name value created_at updated_at]

  POST_CUSTOM_FIELD_COLUMNS = %i[post_id name value created_at updated_at]

  TOPIC_CUSTOM_FIELD_COLUMNS = %i[topic_id name value created_at updated_at]

  USER_ACTION_COLUMNS = %i[
    action_type
    user_id
    target_topic_id
    target_post_id
    target_user_id
    acting_user_id
    created_at
    updated_at
  ]

  MUTED_USER_COLUMNS = %i[user_id muted_user_id created_at updated_at]

  CATEGORY_COLUMNS = %i[
    id
    name
    name_lower
    slug
    user_id
    description
    position
    parent_category_id
    read_restricted
    uploaded_logo_id
    created_at
    updated_at
  ]

  CATEGORY_CUSTOM_FIELD_COLUMNS = %i[category_id name value created_at updated_at]

  CATEGORY_GROUP_COLUMNS = %i[id category_id group_id permission_type created_at updated_at]

  CATEGORY_TAG_GROUP_COLUMNS = %i[category_id tag_group_id created_at updated_at]

  CATEGORY_USER_COLUMNS = %i[category_id user_id notification_level last_seen_at]

  TOPIC_COLUMNS = %i[
    id
    archetype
    title
    fancy_title
    slug
    user_id
    last_post_user_id
    category_id
    visible
    closed
    pinned_at
    pinned_until
    pinned_globally
    views
    subtype
    created_at
    bumped_at
    updated_at
  ]

  POST_COLUMNS = %i[
    id
    user_id
    last_editor_id
    topic_id
    post_number
    sort_order
    reply_to_post_number
    like_count
    raw
    cooked
    hidden
    word_count
    created_at
    last_version_at
    updated_at
  ]

  POST_ACTION_COLUMNS = %i[
    id
    post_id
    user_id
    post_action_type_id
    deleted_at
    created_at
    updated_at
    deleted_by_id
    related_post_id
    staff_took_action
    deferred_by_id
    targets_topic
    agreed_at
    agreed_by_id
    deferred_at
    disagreed_at
    disagreed_by_id
  ]

  TOPIC_ALLOWED_USER_COLUMNS = %i[topic_id user_id created_at updated_at]

  TOPIC_ALLOWED_GROUP_COLUMNS = %i[topic_id group_id created_at updated_at]

  TOPIC_TAG_COLUMNS = %i[topic_id tag_id created_at updated_at]

  TOPIC_USER_COLUMNS = %i[
    user_id
    topic_id
    last_read_post_number
    last_visited_at
    first_visited_at
    notification_level
    notifications_changed_at
    notifications_reason_id
    total_msecs_viewed
  ]

  TAG_USER_COLUMNS = %i[tag_id user_id notification_level created_at updated_at]

  UPLOAD_COLUMNS = %i[
    id
    user_id
    original_filename
    filesize
    width
    height
    url
    created_at
    updated_at
    sha1
    origin
    retain_hours
    extension
    thumbnail_width
    thumbnail_height
    etag
    secure
    access_control_post_id
    original_sha1
    animated
    verification_status
    security_last_changed_at
    security_last_changed_reason
    dominant_color
  ]

  UPLOAD_REFERENCE_COLUMNS = %i[upload_id target_type target_id created_at updated_at]

  OPTIMIZED_IMAGE_COLUMNS = %i[
    sha1
    extension
    width
    height
    upload_id
    url
    filesize
    etag
    version
    created_at
    updated_at
  ]

  POST_VOTING_VOTE_COLUMNS = %i[user_id votable_type votable_id direction created_at]

  BADGE_COLUMNS = %i[
    id
    name
    description
    badge_type_id
    badge_grouping_id
    long_description
    image_upload_id
    created_at
    updated_at
    multiple_grant
    query
    allow_title
    icon
    listable
    target_posts
    enabled
    auto_revoke
    trigger
    show_posts
  ]

  USER_BADGE_COLUMNS = %i[badge_id user_id granted_at granted_by_id seq post_id created_at]

  GAMIFICATION_SCORE_EVENT_COLUMNS = %i[user_id date points description created_at updated_at]

  POST_EVENT_COLUMNS = %i[
    id
    status
    original_starts_at
    original_ends_at
    deleted_at
    raw_invitees
    name
    url
    custom_fields
    reminders
    recurrence
    timezone
    minimal
  ]

  POST_EVENT_DATES_COLUMNS = %i[
    event_id
    starts_at
    ends_at
    reminder_counter
    event_will_start_sent_at
    event_started_sent_at
    finished_at
    created_at
    updated_at
  ]

  POLL_COLUMNS = %i[
    id
    post_id
    name
    close_at
    type
    status
    results
    visibility
    min
    max
    step
    anonymous_voters
    created_at
    updated_at
    chart_type
    groups
    title
  ]

  POLL_OPTION_COLUMNS = %i[id poll_id digest html anonymous_votes created_at updated_at]

  POLL_VOTE_COLUMNS = %i[poll_id poll_option_id user_id created_at updated_at]

  PLUGIN_STORE_ROW_COLUMNS = %i[plugin_name key type_name value]

  PERMALINK_COLUMNS = %i[
    url
    topic_id
    post_id
    category_id
    tag_id
    user_id
    external_url
    created_at
    updated_at
  ]

  CHAT_DIRECT_MESSAGE_CHANNEL_COLUMNS = %i[id group created_at updated_at]

  CHAT_CHANNEL_COLUMNS ||= %i[
    id
    name
    description
    slug
    status
    chatable_id
    chatable_type
    user_count
    messages_count
    type
    created_at
    updated_at
    allow_channel_wide_mentions
    auto_join_users
    threading_enabled
  ]

  USER_CHAT_CHANNEL_MEMBERSHIP_COLUMNS ||= %i[
    chat_channel_id
    user_id
    created_at
    updated_at
    following
    muted
    desktop_notification_level
    mobile_notification_level
    last_read_message_id
    join_mode
    last_viewed_at
  ]

  DIRECT_MESSAGE_USER_COLUMNS ||= %i[direct_message_channel_id user_id created_at updated_at]

  CHAT_THREAD_COLUMNS ||= %i[
    id
    channel_id
    original_message_id
    original_message_user_id
    status
    title
    created_at
    updated_at
    replies_count
  ]

  USER_CHAT_THREAD_MEMBERSHIP_COLUMNS ||= %i[
    user_id
    thread_id
    notification_level
    created_at
    updated_at
  ]

  CHAT_MESSAGE_COLUMNS ||= %i[
    id
    chat_channel_id
    user_id
    created_at
    updated_at
    deleted_at
    deleted_by_id
    in_reply_to_id
    message
    cooked
    cooked_version
    last_editor_id
    thread_id
  ]

  CHAT_MESSAGE_REACTION_COLUMNS ||= %i[chat_message_id user_id emoji created_at updated_at]

  CHAT_MENTION_COLUMNS ||= %i[chat_message_id target_id type created_at updated_at]

  def create_groups(rows, &block)
    create_records(rows, "group", GROUP_COLUMNS, &block)
  end

  def create_users(rows, &block)
    @imported_usernames = {}

    create_records(rows, "user", USER_COLUMNS, &block)

    create_custom_fields("user", "username", @imported_usernames.keys) do |username|
      { record_id: @imported_usernames[username], value: username }
    end
  end

  def create_user_emails(rows, &block)
    create_records(rows, "user_email", USER_EMAIL_COLUMNS, &block)
  end

  def create_user_stats(rows, &block)
    create_records(rows, "user_stat", USER_STAT_COLUMNS, &block)
  end

  def create_user_histories(rows, &block)
    create_records(rows, "user_history", USER_HISTORY_COLUMNS, &block)
  end

  def create_user_avatars(rows, &block)
    create_records(rows, "user_avatar", USER_AVATAR_COLUMNS, &block)
  end

  def create_user_profiles(rows, &block)
    create_records(rows, "user_profile", USER_PROFILE_COLUMNS, &block)
  end

  def create_user_options(rows, &block)
    create_records(rows, "user_option", USER_OPTION_COLUMNS, &block)
  end

  def create_user_followers(rows, &block)
    create_records(rows, "user_follower", USER_FOLLOWER_COLUMNS, &block)
  end

  def create_single_sign_on_records(rows, &block)
    create_records(rows, "single_sign_on_record", USER_SSO_RECORD_COLUMNS, &block)
  end

  def create_user_associated_accounts(rows, &block)
    create_records(rows, "user_associated_account", USER_ASSOCIATED_ACCOUNT_COLUMNS, &block)
  end

  def create_user_custom_fields(rows, &block)
    create_records(rows, "user_custom_field", USER_CUSTOM_FIELD_COLUMNS, &block)
  end

  def create_muted_users(rows, &block)
    create_records(rows, "muted_user", MUTED_USER_COLUMNS, &block)
  end

  def create_group_users(rows, &block)
    create_records(rows, "group_user", GROUP_USER_COLUMNS, &block)
  end

  def create_categories(rows, &block)
    create_records(rows, "category", CATEGORY_COLUMNS, &block)
  end

  def create_category_custom_fields(rows, &block)
    create_records(rows, "category_custom_field", CATEGORY_CUSTOM_FIELD_COLUMNS, &block)
  end

  def create_category_groups(rows, &block)
    create_records(rows, "category_group", CATEGORY_GROUP_COLUMNS, &block)
  end

  def create_category_tag_groups(rows, &block)
    create_records(rows, "category_tag_group", CATEGORY_TAG_GROUP_COLUMNS, &block)
  end

  def create_category_users(rows, &block)
    create_records(rows, "category_user", CATEGORY_USER_COLUMNS, &block)
  end

  def create_topics(rows, &block)
    create_records(rows, "topic", TOPIC_COLUMNS, &block)
  end

  def create_posts(rows, &block)
    create_records(rows, "post", POST_COLUMNS, &block)
  end

  def create_post_actions(rows, &block)
    create_records(rows, "post_action", POST_ACTION_COLUMNS, &block)
  end

  def create_topic_allowed_users(rows, &block)
    create_records(rows, "topic_allowed_user", TOPIC_ALLOWED_USER_COLUMNS, &block)
  end

  def create_topic_allowed_groups(rows, &block)
    create_records(rows, "topic_allowed_group", TOPIC_ALLOWED_GROUP_COLUMNS, &block)
  end

  def create_topic_tags(rows, &block)
    create_records(rows, "topic_tag", TOPIC_TAG_COLUMNS, &block)
  end

  def create_topic_users(rows, &block)
    create_records(rows, "topic_user", TOPIC_USER_COLUMNS, &block)
  end

  def create_tag_users(rows, &block)
    create_records(rows, "tag_user", TAG_USER_COLUMNS, &block)
  end

  def create_uploads(rows, &block)
    create_records_with_mapping(rows, "upload", UPLOAD_COLUMNS, &block)
  end

  def create_upload_references(rows, &block)
    create_records(rows, "upload_reference", UPLOAD_REFERENCE_COLUMNS, &block)
  end

  def create_optimized_images(rows, &block)
    create_records(rows, "optimized_image", OPTIMIZED_IMAGE_COLUMNS, &block)
  end

  def create_post_voting_votes(rows, &block)
    create_records(rows, "post_voting_vote", POST_VOTING_VOTE_COLUMNS, &block)
  end

  def create_post_custom_fields(rows, &block)
    create_records(rows, "post_custom_field", POST_CUSTOM_FIELD_COLUMNS, &block)
  end

  def create_topic_custom_fields(rows, &block)
    create_records(rows, "topic_custom_field", TOPIC_CUSTOM_FIELD_COLUMNS, &block)
  end

  def create_user_actions(rows, &block)
    create_records(rows, "user_action", USER_ACTION_COLUMNS, &block)
  end

  def create_badges(rows, &block)
    create_records_with_mapping(rows, "badge", BADGE_COLUMNS, &block)
  end

  def create_user_badges(rows, &block)
    create_records(rows, "user_badge", USER_BADGE_COLUMNS, &block)
  end

  def create_gamification_score_events(rows, &block)
    create_records(rows, "gamification_score_event", GAMIFICATION_SCORE_EVENT_COLUMNS, &block)
  end

  def create_post_events(rows, &block)
    create_records(rows, "discourse_post_event_events", POST_EVENT_COLUMNS, &block)
  end

  def create_post_event_dates(rows, &block)
    create_records(rows, "discourse_calendar_post_event_dates", POST_EVENT_DATES_COLUMNS, &block)
  end

  def create_polls(rows, &block)
    create_records_with_mapping(rows, "poll", POLL_COLUMNS, &block)
  end

  def create_poll_options(rows, &block)
    create_records_with_mapping(rows, "poll_option", POLL_OPTION_COLUMNS, &block)
  end

  def create_poll_votes(rows, &block)
    create_records(rows, "poll_vote", POLL_VOTE_COLUMNS, &block)
  end

  def create_plugin_store_rows(rows, &block)
    create_records(rows, "plugin_store_row", PLUGIN_STORE_ROW_COLUMNS, &block)
  end

  def create_permalinks(rows, &block)
    create_records(rows, "permalink", PERMALINK_COLUMNS, &block)
  end

  def create_chat_channels(rows, &block)
    create_records_with_mapping(rows, "chat_channel", CHAT_CHANNEL_COLUMNS, &block)
  end

  def create_chat_direct_message(rows, &block)
    create_records_with_mapping(
      rows,
      "direct_message_channel",
      CHAT_DIRECT_MESSAGE_CHANNEL_COLUMNS,
      &block
    )
  end

  def create_user_chat_channel_memberships(rows, &block)
    create_records(
      rows,
      "user_chat_channel_membership",
      USER_CHAT_CHANNEL_MEMBERSHIP_COLUMNS,
      &block
    )
  end

  def create_direct_message_users(rows, &block)
    create_records(rows, "direct_message_user", DIRECT_MESSAGE_USER_COLUMNS, &block)
  end

  def create_chat_threads(rows, &block)
    create_records_with_mapping(rows, "chat_thread", CHAT_THREAD_COLUMNS, &block)
  end

  def create_thread_users(rows, &block)
    create_records(rows, "user_chat_thread_membership", USER_CHAT_THREAD_MEMBERSHIP_COLUMNS, &block)
  end

  def create_chat_messages(rows, &block)
    create_records_with_mapping(rows, "chat_message", CHAT_MESSAGE_COLUMNS, &block)
  end

  def create_chat_message_reactions(rows, &block)
    create_records(rows, "chat_message_reaction", CHAT_MESSAGE_REACTION_COLUMNS, &block)
  end

  def create_chat_mentions(rows, &block)
    create_records(rows, "chat_mention", CHAT_MENTION_COLUMNS, &block)
  end

  def process_group(group)
    @groups[group[:imported_id].to_i] = group[:id] = @last_group_id += 1

    group[:name] = fix_name(group[:name])

    if group_or_user_exist?(group[:name])
      group_name = group[:name] + "_1"
      group_name.next! while group_or_user_exist?(group_name)
      group[:name] = group_name
    end

    group[:title] = group[:title].scrub.strip.presence if group[:title].present?
    group[:bio_raw] = group[:bio_raw].scrub.strip.presence if group[:bio_raw].present?
    group[:bio_cooked] = pre_cook(group[:bio_raw]) if group[:bio_raw].present?

    group[:visibility_level] ||= Group.visibility_levels[:public]
    group[:members_visibility_level] ||= Group.visibility_levels[:public]
    group[:mentionable_level] ||= Group::ALIAS_LEVELS[:nobody]
    group[:messageable_level] ||= Group::ALIAS_LEVELS[:nobody]

    group[:created_at] ||= NOW
    group[:updated_at] ||= group[:created_at]
    group
  end

  def group_or_user_exist?(name)
    name_lowercase = name.downcase
    return true if @usernames_lower.include?(name_lowercase)
    @group_names_lower.add?(name_lowercase).nil?
  end

  def process_user(user)
    if user[:email].present?
      user[:email] = user[:email].downcase

      if (existing_user_id = @emails[user[:email]])
        @users[user[:imported_id].to_i] = existing_user_id
        user[:skip] = true
        return user
      end
    end

    if user[:external_id].present?
      if (existing_user_id = @external_ids[user[:external_id]])
        @users[user[:imported_id].to_i] = existing_user_id
        user[:skip] = true
        return user
      end
    end

    @users[user[:imported_id].to_i] = user[:id] = @last_user_id += 1

    imported_username = user[:original_username].presence || user[:username].dup

    user[:username] = fix_name(user[:username]).presence || random_username

    if user[:username] != imported_username
      @imported_usernames[imported_username] = user[:id]
      @mapped_usernames[imported_username] = user[:username]
    end

    # unique username_lower
    if user_exist?(user[:username])
      username = user[:username] + "_1"
      username.next! while user_exist?(username)
      user[:username] = username
    end

    user[:username_lower] = user[:username].downcase
    user[:trust_level] ||= TrustLevel[1]
    user[:active] = true unless user.has_key?(:active)
    user[:admin] ||= false
    user[:moderator] ||= false
    user[:last_emailed_at] ||= NOW
    user[:created_at] ||= NOW
    user[:updated_at] ||= user[:created_at]
    user[:suspended_at] ||= user[:suspended_at]
    user[:suspended_till] ||= user[:suspended_till] ||
      (200.years.from_now if user[:suspended_at].present?)

    if (date_of_birth = user[:date_of_birth]).is_a?(Date) && date_of_birth.year != 1904
      user[:date_of_birth] = Date.new(1904, date_of_birth.month, date_of_birth.day)
    end

    @user_ids_by_username_lower[user[:username_lower]] = user[:id]
    @usernames_by_id[user[:id]] = user[:username]
    @user_full_names_by_id[user[:id]] = user[:name] if user[:name].present?

    user
  end

  def user_exist?(username)
    username_lowercase = username.downcase
    @usernames_lower.add?(username_lowercase).nil?
  end

  def process_user_email(user_email)
    user_email[:id] = @last_user_email_id += 1
    user_email[:primary] = true
    user_email[:created_at] ||= NOW
    user_email[:updated_at] ||= user_email[:created_at]

    user_email[:email] = user_email[:email]&.downcase || random_email
    # unique email
    user_email[:email] = random_email until EmailAddressValidator.valid_value?(
      user_email[:email],
    ) && !@emails.has_key?(user_email[:email])

    user_email
  end

  def process_user_stat(user_stat)
    user_stat[:user_id] = user_id_from_imported_id(user_email[:imported_user_id])
    user_stat[:topics_entered] ||= 0
    user_stat[:time_read] ||= 0
    user_stat[:days_visited] ||= 0
    user_stat[:posts_read_count] ||= 0
    user_stat[:likes_given] ||= 0
    user_stat[:likes_received] ||= 0
    user_stat[:new_since] ||= NOW
    user_stat[:post_count] ||= 0
    user_stat[:topic_count] ||= 0
    user_stat[:bounce_score] ||= 0
    user_stat[:digest_attempted_at] ||= NOW
    user_stat
  end

  def process_user_history(history)
    history[:created_at] ||= NOW
    history[:updated_at] ||= NOW
    history
  end

  def process_muted_user(muted_user)
    muted_user[:created_at] ||= NOW
    muted_user[:updated_at] ||= NOW
    muted_user
  end

  def process_user_profile(user_profile)
    user_profile[:bio_raw] = (user_profile[:bio_raw].presence || "").scrub.strip.presence
    user_profile[:bio_cooked] = pre_cook(user_profile[:bio_raw]) if user_profile[:bio_raw].present?
    user_profile[:views] ||= 0
    user_profile
  end

  USER_OPTION_DEFAULTS = {
    mailing_list_mode: SiteSetting.default_email_mailing_list_mode,
    mailing_list_mode_frequency: SiteSetting.default_email_mailing_list_mode_frequency,
    email_level: SiteSetting.default_email_level,
    email_messages_level: SiteSetting.default_email_messages_level,
    email_previous_replies: SiteSetting.default_email_previous_replies,
    email_in_reply_to: SiteSetting.default_email_in_reply_to,
    email_digests: SiteSetting.default_email_digest_frequency.to_i > 0,
    digest_after_minutes: SiteSetting.default_email_digest_frequency,
    include_tl0_in_digests: SiteSetting.default_include_tl0_in_digests,
    automatically_unpin_topics: SiteSetting.default_topics_automatic_unpin,
    enable_quoting: SiteSetting.default_other_enable_quoting,
    external_links_in_new_tab: SiteSetting.default_other_external_links_in_new_tab,
    dynamic_favicon: SiteSetting.default_other_dynamic_favicon,
    new_topic_duration_minutes: SiteSetting.default_other_new_topic_duration_minutes,
    auto_track_topics_after_msecs: SiteSetting.default_other_auto_track_topics_after_msecs,
    notification_level_when_replying: SiteSetting.default_other_notification_level_when_replying,
    like_notification_frequency: SiteSetting.default_other_like_notification_frequency,
    skip_new_user_tips: SiteSetting.default_other_skip_new_user_tips,
    hide_profile_and_presence: SiteSetting.default_hide_profile_and_presence,
    sidebar_link_to_filtered_list: SiteSetting.default_sidebar_link_to_filtered_list,
    sidebar_show_count_of_new_items: SiteSetting.default_sidebar_show_count_of_new_items,
  }

  def process_user_option(user_option)
    USER_OPTION_DEFAULTS.each { |key, value| user_option[key] = value if user_option[key].nil? }
    user_option
  end

  def process_user_follower(user_follower)
    user_follower[:created_at] ||= NOW
    user_follower[:updated_at] ||= NOW
    user_follower
  end

  def process_single_sign_on_record(sso_record)
    sso_record[:id] = @last_sso_record_id += 1
    sso_record[:last_payload] ||= ""
    sso_record[:created_at] = NOW
    sso_record[:updated_at] = NOW
    sso_record
  end

  def process_user_associated_account(account)
    account[:last_used] ||= NOW
    account[:info] ||= "{}"
    account[:credentials] ||= "{}"
    account[:extra] ||= "{}"
    account[:created_at] = NOW
    account[:updated_at] = NOW
    account
  end

  def process_group_user(group_user)
    group_user[:created_at] = NOW
    group_user[:updated_at] = NOW
    group_user
  end

  def process_category(category)
    if (existing_category_id = category[:existing_id]).present?
      if existing_category_id.is_a?(String)
        existing_category_id = Category.find_by(id: category[:existing_id])&.id
      end

      if existing_category_id
        @categories[category[:imported_id].to_i] = existing_category_id
        category[:skip] = true
        return category
      end
    end

    category[:id] ||= @last_category_id += 1
    @categories[category[:imported_id].to_i] ||= category[:id]

    next_number = 1
    original_name = name = category[:name][0...50].scrub.strip

    while @category_names.include?("#{category[:parent_category_id]}-#{name.downcase}")
      name = "#{original_name[0...50 - next_number.to_s.length]}#{next_number}"
      next_number += 1
    end

    @category_names << "#{category[:parent_category_id]}-#{name.downcase}"
    name_lower = name.downcase

    category[:name] = name
    category[:name_lower] = name_lower
    category[:slug] ||= Slug.ascii_generator(name_lower)
    category[:description] = (category[:description] || "").scrub.strip.presence
    category[:user_id] ||= Discourse::SYSTEM_USER_ID
    category[:read_restricted] = false if category[:read_restricted].nil?
    category[:created_at] ||= NOW
    category[:updated_at] ||= category[:created_at]

    if category[:position]
      @highest_category_position = category[:position] if category[:position] >
        @highest_category_position
    else
      category[:position] = @highest_category_position += 1
    end

    category
  end

  def process_category_custom_field(field)
    field[:created_at] ||= NOW
    field[:updated_at] ||= NOW
    field
  end

  def process_category_group(category_group)
    category_group[:id] = @last_category_group_id += 1
    category_group[:created_at] = NOW
    category_group[:updated_at] = NOW
    category_group
  end

  def process_category_tag_group(category_tag_group)
    category_tag_group[:created_at] = NOW
    category_tag_group[:updated_at] = NOW
    category_tag_group
  end

  def process_category_user(category_user)
    category_user
  end

  def process_topic(topic)
    @topics[topic[:imported_id].to_i] = topic[:id] = @last_topic_id += 1
    topic[:archetype] ||= Archetype.default
    topic[:title] = topic[:title][0...255].scrub.strip
    topic[:fancy_title] ||= pre_fancy(topic[:title])
    topic[:slug] ||= Slug.ascii_generator(topic[:title])
    topic[:user_id] ||= Discourse::SYSTEM_USER_ID
    topic[:last_post_user_id] ||= topic[:user_id]
    topic[:category_id] ||= -1 if topic[:archetype] != Archetype.private_message
    topic[:visible] = true unless topic.has_key?(:visible)
    topic[:closed] ||= false
    topic[:views] ||= 0
    topic[:created_at] ||= NOW
    topic[:bumped_at] ||= topic[:created_at]
    topic[:updated_at] ||= topic[:created_at]
    topic
  end

  def process_post(post)
    @posts[post[:imported_id].to_i] = post[:id] = @last_post_id += 1
    post[:user_id] ||= Discourse::SYSTEM_USER_ID
    post[:last_editor_id] = post[:user_id]
    @highest_post_number_by_topic_id[post[:topic_id]] ||= 0
    post[:post_number] = @highest_post_number_by_topic_id[post[:topic_id]] += 1
    post[:sort_order] = post[:post_number]
    @post_number_by_post_id[post[:id]] = post[:post_number]
    @topic_id_by_post_id[post[:id]] = post[:topic_id]
    post[:raw] = (post[:raw] || "").scrub.strip.presence || "<Empty imported post>"
    post[:raw] = process_raw post[:raw]
    if @bbcode_to_md
      post[:raw] = begin
        post[:raw].bbcode_to_md(false, {}, :disable, :quote)
      rescue StandardError
        post[:raw]
      end
    end
    post[:raw] = normalize_text(post[:raw])
    post[:like_count] ||= 0
    post[:score] ||= 0
    post[:cooked] = pre_cook post[:raw]
    post[:hidden] ||= false
    post[:word_count] = post[:raw].scan(/[[:word:]]+/).size
    post[:created_at] ||= NOW
    post[:last_version_at] = post[:created_at]
    post[:updated_at] ||= post[:created_at]

    if post[:raw].bytes.include?(0)
      STDERR.puts "Skipping post with original ID #{post[:imported_id]} because `raw` contains null bytes"
      post[:skip] = true
    end

    post[:reply_to_post_number] = nil if post[:reply_to_post_number] == 1

    if post[:cooked].bytes.include?(0)
      STDERR.puts "Skipping post with original ID #{post[:imported_id]} because `cooked` contains null bytes"
      post[:skip] = true
    end

    post
  end

  def process_post_action(post_action)
    post_action[:id] ||= @last_post_action_id += 1
    post_action[:staff_took_action] ||= false
    post_action[:targets_topic] ||= false
    post_action[:created_at] ||= NOW
    post_action[:updated_at] ||= post_action[:created_at]
    post_action
  end

  def process_topic_allowed_user(topic_allowed_user)
    topic_allowed_user[:created_at] = NOW
    topic_allowed_user[:updated_at] = NOW
    topic_allowed_user
  end

  def process_topic_allowed_group(topic_allowed_group)
    topic_allowed_group[:created_at] = NOW
    topic_allowed_group[:updated_at] = NOW
    topic_allowed_group
  end

  def process_topic_tag(topic_tag)
    topic_tag[:created_at] = NOW
    topic_tag[:updated_at] = NOW
    topic_tag
  end

  def process_topic_user(topic_user)
    topic_user
  end

  def process_tag_user(tag_user)
    tag_user[:created_at] = NOW
    tag_user[:updated_at] = NOW
    tag_user
  end

  def process_upload(upload)
    if (existing_upload_id = upload_id_from_sha1(upload[:sha1]))
      @imported_records[upload[:original_id]] = existing_upload_id
      @uploads_mapping[upload[:original_id]] = existing_upload_id
      return { skip: true }
    end

    upload[:id] = @last_upload_id += 1
    upload[:user_id] ||= Discourse::SYSTEM_USER_ID
    upload[:created_at] ||= NOW
    upload[:updated_at] ||= NOW

    @imported_records[upload[:original_id]] = upload[:id]
    @uploads_mapping[upload[:original_id]] = upload[:id]
    @uploads_by_sha1[upload[:sha1]] = upload[:id]
    @upload_urls_by_id[upload[:id]] = upload[:url]

    upload
  end

  def process_upload_reference(upload_reference)
    upload_reference[:created_at] ||= NOW
    upload_reference[:updated_at] ||= NOW
    upload_reference
  end

  def process_optimized_image(optimized_image)
    optimized_image[:user_id] ||= Discourse::SYSTEM_USER_ID
    optimized_image[:created_at] ||= NOW
    optimized_image[:updated_at] ||= NOW
    optimized_image
  end

  def process_post_voting_vote(vote)
    vote[:created_at] ||= NOW
    vote
  end

  def process_user_avatar(avatar)
    avatar[:id] = @last_user_avatar_id += 1
    avatar[:created_at] ||= NOW
    avatar[:updated_at] ||= NOW
    avatar
  end

  def process_raw(original_raw)
    raw = original_raw.dup
    # fix whitespaces
    raw.gsub!(/(\\r)?\\n/, "\n")
    raw.gsub!("\\t", "\t")

    # [HTML]...[/HTML]
    raw.gsub!(/\[HTML\]/i, "\n\n```html\n")
    raw.gsub!(%r{\[/HTML\]}i, "\n```\n\n")

    # [PHP]...[/PHP]
    raw.gsub!(/\[PHP\]/i, "\n\n```php\n")
    raw.gsub!(%r{\[/PHP\]}i, "\n```\n\n")

    # [HIGHLIGHT="..."]
    raw.gsub!(/\[HIGHLIGHT="?(\w+)"?\]/i) { "\n\n```#{$1.downcase}\n" }

    # [CODE]...[/CODE]
    # [HIGHLIGHT]...[/HIGHLIGHT]
    raw.gsub!(%r{\[/?CODE\]}i, "\n\n```\n\n")
    raw.gsub!(%r{\[/?HIGHLIGHT\]}i, "\n\n```\n\n")

    # [SAMP]...[/SAMP]
    raw.gsub!(%r{\[/?SAMP\]}i, "`")

    # replace all chevrons with HTML entities
    # /!\ must be done /!\
    #  - AFTER the "code" processing
    #  - BEFORE the "quote" processing
    raw.gsub!(/`([^`]+?)`/im) { "`" + $1.gsub("<", "\u2603") + "`" }
    raw.gsub!("<", "&lt;")
    raw.gsub!("\u2603", "<")

    raw.gsub!(/`([^`]+?)`/im) { "`" + $1.gsub(">", "\u2603") + "`" }
    raw.gsub!(">", "&gt;")
    raw.gsub!("\u2603", ">")

    raw.gsub!(%r{\[/?I\]}i, "*")
    raw.gsub!(%r{\[/?B\]}i, "**")
    raw.gsub!(%r{\[/?U\]}i, "")

    raw.gsub!(%r{\[/?RED\]}i, "")
    raw.gsub!(%r{\[/?BLUE\]}i, "")

    raw.gsub!(%r{\[AUTEUR\].+?\[/AUTEUR\]}im, "")
    raw.gsub!(%r{\[VOIRMSG\].+?\[/VOIRMSG\]}im, "")
    raw.gsub!(%r{\[PSEUDOID\].+?\[/PSEUDOID\]}im, "")

    # [IMG]...[/IMG]
    raw.gsub!(%r{(?:\s*\[IMG\]\s*)+(.+?)(?:\s*\[/IMG\]\s*)+}im) { "\n\n#{$1}\n\n" }

    # [IMG=url]
    raw.gsub!(/\[IMG=([^\]]*)\]/im) { "\n\n#{$1}\n\n" }

    # [URL=...]...[/URL]
    raw.gsub!(%r{\[URL="?(.+?)"?\](.+?)\[/URL\]}im) { "[#{$2.strip}](#{$1})" }

    # [URL]...[/URL]
    # [MP3]...[/MP3]
    # [EMAIL]...[/EMAIL]
    # [LEFT]...[/LEFT]
    raw.gsub!(%r{\[/?URL\]}i, "")
    raw.gsub!(%r{\[/?MP3\]}i, "")
    raw.gsub!(%r{\[/?EMAIL\]}i, "")
    raw.gsub!(%r{\[/?LEFT\]}i, "")

    # [FONT=blah] and [COLOR=blah]
    raw.gsub!(%r{\[FONT=.*?\](.*?)\[/FONT\]}im, "\\1")
    raw.gsub!(%r{\[COLOR=.*?\](.*?)\[/COLOR\]}im, "\\1")

    raw.gsub!(%r{\[SIZE=.*?\](.*?)\[/SIZE\]}im, "\\1")
    raw.gsub!(%r{\[H=.*?\](.*?)\[/H\]}im, "\\1")

    # [CENTER]...[/CENTER]
    raw.gsub!(%r{\[CENTER\](.*?)\[/CENTER\]}im, "\\1")

    # [INDENT]...[/INDENT]
    raw.gsub!(%r{\[INDENT\](.*?)\[/INDENT\]}im, "\\1")
    raw.gsub!(%r{\[TABLE\](.*?)\[/TABLE\]}im, "\\1")
    raw.gsub!(%r{\[TR\](.*?)\[/TR\]}im, "\\1")
    raw.gsub!(%r{\[TD\](.*?)\[/TD\]}im, "\\1")
    raw.gsub!(%r{\[TD="?.*?"?\](.*?)\[/TD\]}im, "\\1")

    # [STRIKE]
    raw.gsub!(/\[STRIKE\]/i, "<s>")
    raw.gsub!(%r{\[/STRIKE\]}i, "</s>")

    # [QUOTE]...[/QUOTE]
    raw.gsub!(/\[QUOTE="([^\]]+)"\]/i) { "[QUOTE=#{$1}]" }

    # Nested Quotes
    raw.gsub!(%r{(\[/?QUOTE.*?\])}mi) { |q| "\n#{q}\n" }

    # raw.gsub!(/\[QUOTE\](.+?)\[\/QUOTE\]/im) { |quote|
    #   quote.gsub!(/\[QUOTE\](.+?)\[\/QUOTE\]/im) { "\n#{$1}\n" }
    #   quote.gsub!(/\n(.+?)/) { "\n> #{$1}" }
    # }

    # [QUOTE=<username>;<postid>]
    raw.gsub!(/\[QUOTE=([^;\]]+);(\d+)\]/i) do
      imported_username, imported_postid = $1, $2

      username = @mapped_usernames[imported_username] || imported_username
      post_number = post_number_from_imported_id(imported_postid)
      topic_id = topic_id_from_imported_post_id(imported_postid)

      if post_number && topic_id
        "\n[quote=\"#{username}, post:#{post_number}, topic:#{topic_id}\"]\n"
      else
        "\n[quote=\"#{username}\"]\n"
      end
    end

    # [YOUTUBE]<id>[/YOUTUBE]
    raw.gsub!(%r{\[YOUTUBE\](.+?)\[/YOUTUBE\]}i) { "\nhttps://www.youtube.com/watch?v=#{$1}\n" }
    raw.gsub!(%r{\[DAILYMOTION\](.+?)\[/DAILYMOTION\]}i) do
      "\nhttps://www.dailymotion.com/video/#{$1}\n"
    end

    # [VIDEO=youtube;<id>]...[/VIDEO]
    raw.gsub!(%r{\[VIDEO=YOUTUBE;([^\]]+)\].*?\[/VIDEO\]}i) do
      "\nhttps://www.youtube.com/watch?v=#{$1}\n"
    end
    raw.gsub!(%r{\[VIDEO=DAILYMOTION;([^\]]+)\].*?\[/VIDEO\]}i) do
      "\nhttps://www.dailymotion.com/video/#{$1}\n"
    end

    # [SPOILER=Some hidden stuff]SPOILER HERE!![/SPOILER]
    raw.gsub!(%r{\[SPOILER="?(.+?)"?\](.+?)\[/SPOILER\]}im) do
      "\n#{$1}\n[spoiler]#{$2}[/spoiler]\n"
    end

    # convert list tags to ul and list=1 tags to ol
    # (basically, we're only missing list=a here...)
    # (https://meta.discourse.org/t/phpbb-3-importer-old/17397)
    raw.gsub!(%r{\[list\](.*?)\[/list\]}im, '[ul]\1[/ul]')
    raw.gsub!(%r{\[list=1\|?[^\]]*\](.*?)\[/list\]}im, '[ol]\1[/ol]')
    raw.gsub!(%r{\[list\](.*?)\[/list:u\]}im, '[ul]\1[/ul]')
    raw.gsub!(%r{\[list=1\|?[^\]]*\](.*?)\[/list:o\]}im, '[ol]\1[/ol]')
    # convert *-tags to li-tags so bbcode-to-md can do its magic on phpBB's lists:
    raw.gsub!(/\[\*\]\n/, "")
    raw.gsub!(%r{\[\*\](.*?)\[/\*:m\]}, '[li]\1[/li]')
    raw.gsub!(/\[\*\](.*?)\n/, '[li]\1[/li]')
    raw.gsub!(/\[\*=1\]/, "")

    raw
  end

  def process_user_custom_field(field)
    field[:created_at] ||= NOW
    field[:updated_at] ||= NOW
    field
  end

  def process_post_custom_field(field)
    field[:created_at] ||= NOW
    field[:updated_at] ||= NOW
    field
  end

  def process_topic_custom_field(field)
    field[:created_at] ||= NOW
    field[:updated_at] ||= NOW
    field
  end

  def process_user_action(user_action)
    user_action[:created_at] ||= NOW
    user_action[:updated_at] ||= NOW
    user_action
  end

  def process_badge(badge)
    badge[:id] = @last_badge_id += 1
    badge[:created_at] ||= NOW
    badge[:updated_at] ||= NOW
    badge[:multiple_grant] = false if badge[:multiple_grant].nil?

    @imported_records[badge[:original_id].to_s] = badge[:id]
    @badge_mapping[badge[:original_id].to_s] = badge[:id]

    badge
  end

  def process_user_badge(user_badge)
    user_badge[:granted_at] ||= NOW
    user_badge[:granted_by_id] ||= Discourse::SYSTEM_USER_ID
    user_badge[:created_at] ||= user_badge[:granted_at]
    user_badge
  end

  def process_gamification_score_event(score_event)
    score_event[:created_at] ||= NOW
    score_event[:updated_at] ||= NOW
    score_event
  end

  def process_discourse_post_event_events(post_event)
    post_event
  end

  def process_discourse_calendar_post_event_dates(post_event_date)
    post_event_date[:created_at] ||= NOW
    post_event_date[:updated_at] ||= NOW
    post_event_date
  end

  def process_poll(poll)
    poll[:id] = @last_poll_id += 1
    poll[:created_at] ||= NOW
    poll[:updated_at] ||= NOW

    @imported_records[poll[:original_id].to_s] = poll[:id]
    @poll_mapping[poll[:original_id].to_s] = poll[:id]

    poll
  end

  def process_poll_option(poll_option)
    poll_option[:id] = id = @last_poll_option_id += 1
    poll_option[:created_at] ||= NOW
    poll_option[:updated_at] ||= NOW
    poll_option[:anonymous_votes] ||= nil

    poll_option[:digest] = Digest::MD5.hexdigest([poll_option[:html]].to_json)

    poll_option[:original_ids]
      .map(&:to_s)
      .each do |original_id|
        @imported_records[original_id] = id
        @poll_option_mapping[original_id] = id
      end

    poll_option
  end

  def process_poll_vote(poll_vote)
    poll_vote[:created_at] ||= NOW
    poll_vote[:updated_at] ||= NOW
    poll_vote
  end

  def process_plugin_store_row(plugin_store_row)
    plugin_store_row
  end

  def process_permalink(permalink)
    permalink[:created_at] ||= NOW
    permalink[:updated_at] ||= NOW
    permalink
  end

  def process_direct_message_channel(chat_channel)
    chat_channel[:id] = @last_chat_direct_message_channel_id += 1
    chat_channel[:group] = false if chat_channel[:group].nil?
    chat_channel[:created_at] ||= NOW
    chat_channel[:updated_at] ||= NOW

    @imported_records[chat_channel[:original_id].to_s] = chat_channel[:id]
    @chat_direct_message_channel_mapping[chat_channel[:original_id].to_s] = chat_channel[:id]

    chat_channel
  end

  def process_chat_channel(chat_channel)
    chat_channel[:id] = @last_chat_channel_id += 1

    if chat_channel[:name].present?
      chat_channel[:name] = chat_channel[:name][0..SiteSetting.max_topic_title_length]
        .scrub
        .strip
        .presence
      chat_channel[:slug] ||= Slug.ascii_generator(chat_channel[:name])
    end

    chat_channel[:description] = chat_channel[:description][0..500].scrub.strip if chat_channel[
      :description
    ].present?
    chat_channel[:slug] = chat_channel[:slug][0..100] if chat_channel[:slug].present?
    chat_channel[:allow_channel_wide_mentions] ||= true if chat_channel[
      :allow_channel_wide_mentions
    ].nil?
    chat_channel[:auto_join_users] ||= false if chat_channel[:auto_join_users].nil?
    chat_channel[:threading_enabled] ||= false if chat_channel[:threading_enabled].nil?
    chat_channel[:user_count] ||= 0
    chat_channel[:messages_count] ||= 0
    chat_channel[:status] ||= 0
    chat_channel[:created_at] ||= NOW
    chat_channel[:updated_at] ||= NOW

    @imported_records[chat_channel[:original_id].to_s] = chat_channel[:id]
    @chat_channel_mapping[chat_channel[:original_id].to_s] = chat_channel[:id]

    chat_channel
  end

  def process_user_chat_channel_membership(membership)
    membership[:created_at] ||= NOW
    membership[:updated_at] ||= NOW
    membership[:following] = false if membership[:following].nil?
    membership[:muted] = false if membership[:muted].nil?
    membership[
      :desktop_notification_level
    ] ||= Chat::UserChatChannelMembership.desktop_notification_levels[:mention]
    membership[
      :mobile_notification_level
    ] ||= Chat::UserChatChannelMembership.mobile_notification_levels[:mention]
    membership[:join_mode] ||= Chat::UserChatChannelMembership.join_modes[:manual]

    membership
  end

  def process_direct_message_user(user)
    user[:created_at] ||= NOW
    user[:updated_at] ||= NOW

    user
  end

  def process_chat_thread(thread)
    thread[:id] = @last_chat_thread_id += 1
    thread[:created_at] ||= NOW
    thread[:updated_at] ||= NOW

    @imported_records[thread[:original_id].to_s] = thread[:id]
    @chat_thread_mapping[thread[:original_id].to_s] = thread[:id]

    thread
  end

  def process_user_chat_thread_membership(membership)
    membership[:created_at] ||= NOW
    membership[:updated_at] ||= NOW
    membership[:notification_level] ||= Chat::UserChatThreadMembership.notification_levels[
      :tracking
    ]
    membership[:thread_title_prompt_seen] = false if membership[:thread_title_prompt_seen].nil?

    membership
  end

  def process_chat_message(message)
    message[:id] = @last_chat_message_id += 1
    message[:user_id] ||= Discourse::SYSTEM_USER_ID
    message[:last_editor_id] ||= message[:user_id]
    message[:message] = (message[:message] || "").scrub.strip
    message[:message] = normalize_text(message[:message])
    message[:cooked] = ::Chat::Message.cook(message[:message], user_id: message[:last_editor_id])
    message[:cooked_version] = ::Chat::Message::BAKED_VERSION
    message[:created_at] ||= NOW
    message[:updated_at] ||= NOW

    @imported_records[message[:original_id].to_s] = message[:id]
    @chat_message_mapping[message[:original_id].to_s] = message[:id]

    if message[:message].bytes.include?(0)
      STDERR.puts "Skipping chat message with original ID #{message[:original_id]} because `message` contains null bytes"
      message[:skip] = true
    end

    if message[:cooked].bytes.include?(0)
      STDERR.puts "Skipping chat message with original ID #{message[:original_id]} because `cooked` contains null bytes"
      message[:skip] = true
    end

    message
  end

  def process_chat_message_reaction(reaction)
    reaction[:created_at] ||= NOW
    reaction[:updated_at] ||= NOW

    reaction
  end

  def process_chat_mention(mention)
    mention[:created_at] ||= NOW
    mention[:updated_at] ||= NOW

    mention
  end

  def create_records(all_rows, name, columns, &block)
    start = Time.now
    imported_ids = []
    process_method_name = "process_#{name}"

    rows_created = 0

    all_rows.each_slice(1_000) do |rows|
      sql = "COPY #{name.pluralize} (#{columns.map { |c| "\"#{c}\"" }.join(",")}) FROM STDIN"

      begin
        @raw_connection.copy_data(sql, @encoder) do
          rows.each do |row|
            begin
              if (mapped = yield(row))
                processed = send(process_method_name, mapped)
                imported_ids << mapped[:imported_id] unless mapped[:imported_id].nil?
                imported_ids |= mapped[:imported_ids] unless mapped[:imported_ids].nil?
                unless processed[:skip]
                  @raw_connection.put_copy_data columns.map { |c| processed[c] }
                end
              end
              rows_created += 1
              if rows_created % 100 == 0
                print "\r%7d - %6d/sec" % [rows_created, rows_created.to_f / (Time.now - start)]
              end
            rescue => e
              puts "\n"
              puts "ERROR: #{e.message}"
              puts e.backtrace.join("\n")
            end
          end
        end
      rescue => e
        puts "First Row: #{rows.first.inspect}"
        raise e
      end
    end

    if rows_created > 0
      print "\r%7d - %6d/sec\n" % [rows_created, rows_created.to_f / (Time.now - start)]
    end

    id_mapping_method_name = "#{name}_id_from_imported_id".freeze
    return true unless respond_to?(id_mapping_method_name)
    create_custom_fields(name, "id", imported_ids) do |imported_id|
      { record_id: send(id_mapping_method_name, imported_id), value: imported_id }
    end
    true
  rescue => e
    # FIXME: errors catched here stop the rest of the COPY
    puts e.message
    puts e.backtrace.join("\n")
    false
  end

  def create_records_with_mapping(all_rows, name, columns, &block)
    @imported_records = {}
    if create_records(all_rows, name, columns, &block)
      store_mappings(MAPPING_TYPES[name.to_sym], @imported_records)
    end
  end

  def create_custom_fields(table, name, rows)
    name = "import_#{name}"
    sql =
      "COPY #{table}_custom_fields (#{table}_id, name, value, created_at, updated_at) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      rows.each do |row|
        next unless cf = yield(row)
        @raw_connection.put_copy_data [cf[:record_id], name, cf[:value], NOW, NOW]
      end
    end
  end

  def store_mappings(type, rows)
    return if rows.empty?

    sql = "COPY migration_mappings (original_id, type, discourse_id) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      rows.each do |original_id, discourse_id|
        @raw_connection.put_copy_data [original_id, type, discourse_id]
      end
    end
  end

  def create_upload(user_id, path, source_filename)
    @uploader.create_upload(user_id, path, source_filename)
  end

  def html_for_upload(upload, display_filename)
    @uploader.html_for_upload(upload, display_filename)
  end

  def fix_name(name)
    name.scrub! if name && !name.valid_encoding?
    return if name.blank?
    # TODO Support Unicode if allowed in site settings and try to reuse logic from UserNameSuggester if possible
    name = ActiveSupport::Inflector.transliterate(name)
    name.gsub!(/[^\w.-]+/, "_")
    name.gsub!(/^\W+/, "")
    name.gsub!(/[^A-Za-z0-9]+$/, "")
    name.gsub!(/([-_.]{2,})/) { $1.first }
    name.strip!
    name.truncate(60)
    name
  end

  def random_username
    "Anonymous_#{SecureRandom.hex}"
  end

  def random_email
    "#{SecureRandom.hex}@email.invalid"
  end

  def pre_cook(raw)
    # TODO Check if this is still up-to-date
    # Convert YouTube URLs to lazyYT DOMs before being transformed into links
    cooked =
      raw.gsub(%r{\nhttps\://www.youtube.com/watch\?v=(\w+)\n}) do
        video_id = $1
        result = <<-HTML
        <div class="lazyYT" data-youtube-id="#{video_id}" data-width="480" data-height="270" data-parameters="feature=oembed&amp;wmode=opaque"></div>
        HTML
        result.strip
      end

    cooked = @markdown.render(cooked).scrub.strip

    cooked.gsub!(
      %r{\[QUOTE=(?:"|&quot;)?(.+?)(?:, post:(\d+), topic:(\d+))?(?:, username:(.+?))?(?:"|&quot;)?\](.+?)\[/QUOTE\]}im,
    ) do
      name_or_username, post_id, topic_id, username, quote = $1, $2, $3, $4, $5
      username ||= name_or_username

      quote = quote.scrub.strip
      quote.gsub!(/^(<br>\n?)+/, "")
      quote.gsub!(/(<br>\n?)+$/, "")

      if post_id.present? && topic_id.present?
        <<-HTML
          <aside class="quote" data-post="#{post_id}" data-topic="#{topic_id}">
            <div class="title">
              <div class="quote-controls"></div>
              #{name_or_username}:
            </div>
            <blockquote>#{quote}</blockquote>
          </aside>
        HTML
      else
        <<-HTML
          <aside class="quote no-group" data-username="#{username}">
            <div class="title">
              <div class="quote-controls"></div>
              #{name_or_username}:
            </div>
            <blockquote>#{quote}</blockquote>
          </aside>
        HTML
      end
    end

    # Attachments
    cooked.gsub!(%r{<a href="upload://(.*?)">(.*?)\|attachment</a>}) do
      upload_base62, filename = $1, $2
      %{<a class="attachment" href="#{Discourse.base_url}/uploads/short-url/#{upload_base62}">#{filename}</a>}
    end

    # Images
    cooked.gsub!(%r{<img src="(upload://.*?)"(?:\salt="(.*?)(?:\|(\d+)x(\d+))?")?.*?>}) do
      short_url, alt, width, height = $1, $2, $3, $4
      upload_sha1 = Upload.sha1_from_short_url(short_url)
      upload_base62 = Upload.base62_sha1(upload_sha1)
      upload_id = @uploads_by_sha1[upload_sha1]
      upload_url = upload_id ? @upload_urls_by_id[upload_id] : nil
      cdn_url = upload_url ? Discourse.store.cdn_url(upload_url) : ""

      attributes = +%{loading="lazy"}
      attributes << %{ alt="#{alt}"} if alt.present?
      attributes << %{ width="#{width}"} if width.present?
      attributes << %{ height="#{height}"} if height.present?
      if width.present? && height.present?
        attributes << %{ style="aspect-ratio: #{width} / #{height};"}
      end

      %{<img src="#{cdn_url}" data-base62-sha1="#{upload_base62} #{attributes}>}
    end

    cooked.gsub!(/@([-_.\w]+)/) do
      name = @mapped_usernames[$1] || $1
      normalized_name = User.normalize_username(name)

      if @usernames_lower.include?(normalized_name)
        %|<a class="mention" href="/u/#{normalized_name}">@#{name}</a>|
      elsif @group_names_lower.include?(normalized_name)
        %|<a class="mention-group" href="/groups/#{normalized_name}">@#{name}</a>|
      else
        "@#{name}"
      end
    end

    # TODO Check if scrub or strip is inserting \x00 which is causing Postgres COPY to fail
    cooked.scrub.strip
    cooked.gsub!(/\x00/, "")
    cooked
  end

  def user_avatar(user)
    url = user.avatar_template.gsub("{size}", "45")
    # TODO name/username preference check
    "<img alt=\"\" width=\"20\" height=\"20\" src=\"#{url}\" class=\"avatar\"> #{user.name.presence || user.username}"
  end

  def pre_fancy(title)
    Redcarpet::Render::SmartyPants.render(ERB::Util.html_escape(title)).scrub.strip
  end

  def normalize_text(text)
    return nil if text.blank?
    @html_entities.decode(normalize_charset(text.presence || "").scrub)
  end

  def normalize_charset(text)
    return text if @encoding == Encoding::UTF_8
    text && text.encode(@encoding).force_encoding(Encoding::UTF_8)
  end
end
