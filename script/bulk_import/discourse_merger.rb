require_relative "base"

class BulkImport::DiscourseMerger < BulkImport::Base

  NOW ||= "now()".freeze
  CUSTOM_FIELDS = ['category', 'group', 'post', 'topic', 'user']

  # DB_NAME: name of database being merged into the current local db
  # DB_HOST: hostname of database being merged
  # UPLOADS_PATH: absolute path of the directory containing "original"
  #               and "optimized" dirs. e.g. /home/discourse/other-site/public/uploads/default
  # SOURCE_BASE_URL: base url of the site being merged. e.g. https://meta.discourse.org
  # SOURCE_CDN: (optional) base url of the CDN of the site being merged.
  #             e.g. https://discourse-cdn-sjc1.com/business4

  def initialize
    local_db = ActiveRecord::Base.connection_config
    @raw_connection = PG.connect(dbname: local_db[:database], host: 'localhost', port: local_db[:port])

    @source_db_config = {
      dbname: ENV["DB_NAME"] || 'dd_demo',
      host: ENV["DB_HOST"] || 'localhost'
    }

    raise "SOURCE_BASE_URL missing!" unless ENV['SOURCE_BASE_URL']

    @source_base_url = ENV["SOURCE_BASE_URL"]
    @uploads_path = ENV['UPLOADS_PATH']
    @uploader = ImportScripts::Uploader.new

    if ENV['SOURCE_CDN']
      @source_cdn = ENV['SOURCE_CDN']
    end

    local_version = @raw_connection.exec("select max(version) from schema_migrations")
    local_version = local_version.first['max']
    source_version = source_raw_connection.exec("select max(version) from schema_migrations")
    source_version = source_version.first['max']

    if local_version != source_version
      raise "DB schema mismatch. Databases must be at the same migration version. Local is #{local_version}, other is #{source_version}"
    end

    @encoder = PG::TextEncoder::CopyRow.new

    @merged_user_ids = []
    @tags = {}
    @tag_groups = {}
    @uploads = {}
    @post_actions = {}
    @notifications = {}
    @badge_groupings = {}
    @badges = {}

    @auto_group_ids = Group::AUTO_GROUPS.values

    # add your authorized extensions here:
    SiteSetting.authorized_extensions = ['jpg', 'jpeg', 'png', 'gif'].join('|')

    @sequences = {}
  end

  def start
    run
  ensure
    @raw_connection&.close
    source_raw_connection&.close
  end

  def execute
    copy_users
    copy_user_stuff
    copy_groups
    copy_categories
    copy_topics
    copy_posts
    copy_tags
    copy_uploads if @uploads_path
    copy_everything_else
    copy_badges
    fix_category_descriptions
  end

  def source_raw_connection
    @source_raw_connection ||= PG.connect(@source_db_config)
  end

  def copy_users
    puts '', "merging users..."

    imported_ids = []

    usernames_lower = User.unscoped.pluck(:username_lower).to_set

    columns = User.columns.map(&:name)
    sql = "COPY users (#{columns.map { |c| "\"#{c}\"" }.join(",")}) FROM STDIN"

    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection.exec("SELECT #{columns.map { |c| "u.\"#{c}\"" }.join(",")}, e.email FROM users u INNER JOIN user_emails e ON (u.id = e.user_id AND e.primary = TRUE) WHERE u.id > 0").each do |row|
        old_user_id = row['id']&.to_i
        if existing = UserEmail.where(email: row.delete('email')).first&.user
          # Merge these users
          @users[old_user_id.to_s] = existing.id
          @merged_user_ids << old_user_id
          next
        else
          # New user
          unless usernames_lower.add?(row['username_lower'])
            username = row['username'] + "_1"
            username.next! until usernames_lower.add?(username.downcase)
            row['username'] = username
            row['username_lower'] = row['username'].downcase
          end

          row['id'] = (@last_user_id += 1)
          @users[old_user_id.to_s] = row['id']
          @raw_connection.put_copy_data row.values
        end
        imported_ids << old_user_id
      end
    end

    @sequences[User.sequence_name] = @last_user_id + 1 if @last_user_id

    create_custom_fields('user', 'id', imported_ids) do |old_user_id|
      { value: old_user_id, record_id: user_id_from_imported_id(old_user_id) }
    end
  end

  def copy_user_stuff
    [
      UserEmail, EmailToken, UserStat, UserOption, UserProfile, EmailChangeRequest,
      UserVisit, UserSearchData, GivenDailyLike, UserSecondFactor, UserOpenId
    ].each do |c|
      copy_model(c, skip_if_merged: true, is_a_user_model: true, skip_processing: true)
    end

    [FacebookUserInfo, GithubUserInfo, GoogleUserInfo, InstagramUserInfo, Oauth2UserInfo,
      SingleSignOnRecord, TwitterUserInfo
    ].each do |c|
      copy_model(c, skip_if_merged: true, is_a_user_model: true)
    end
  end

  def copy_groups
    copy_model(Group,
      mapping: @groups,
      skip_processing: true,
      select_sql: "SELECT #{Group.columns.map { |c| "\"#{c.name}\"" }.join(', ')} FROM groups WHERE automatic = false"
    )

    copy_model(GroupUser, skip_if_merged: true)
    copy_model(GroupArchivedMessage)
    copy_model(GroupMention, skip_processing: true)

    [CategoryGroup, GroupHistory].each do |k|
      col_list = k.columns.map { |c| "\"#{c.name}\"" }.join(', ')
      copy_model(k,
        select_sql: "SELECT #{col_list} FROM #{k.table_name} WHERE group_id NOT IN (#{@auto_group_ids.join(', ')})"
      )
    end
  end

  def copy_categories
    puts "merging categories..."

    columns = Category.columns.map(&:name)
    imported_ids = []
    last_id = Category.unscoped.maximum(:id)

    sql = "COPY categories (#{columns.map { |c| "\"#{c}\"" }.join(', ')}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection.exec("SELECT #{columns.map { |c| "\"#{c}\"" }.join(', ')} FROM categories").each do |row|

        if existing = Category.where(name: row['name']).first
          @categories[row['id']] = existing.id
          next
        end

        old_user_id = row['user_id'].to_i
        if old_user_id >= 1
          row['user_id'] = user_id_from_imported_id(old_user_id) || -1
        end

        if row['parent_category_id']
          row['parent_category_id'] = category_id_from_imported_id(row['parent_category_id'])
        end

        old_id = row['id']
        row['id'] = (last_id += 1)
        imported_ids << old_id
        @categories[old_id.to_s] = row['id']

        @raw_connection.put_copy_data(row.values)
      end
    end

    @sequences[Category.sequence_name] = last_id + 1

    create_custom_fields('category', 'id', imported_ids) do |imported_id|
      {
        record_id: category_id_from_imported_id(imported_id),
        value: imported_id,
      }
    end
  end

  def fix_category_descriptions
    puts 'updating category description topic ids...'

    @categories.each do |old_id, new_id|
      category = Category.find(new_id)
      if description_topic_id = topic_id_from_imported_id(category.topic_id)
        category.topic_id = description_topic_id
        category.save!
      end
    end
  end

  def copy_topics
    copy_model(Topic, mapping: @topics)
    [TopicAllowedGroup, TopicAllowedUser, TopicEmbed, TopicSearchData,
      TopicTimer, TopicUser, TopicViewItem
    ].each do |k|
      copy_model(k, skip_processing: true)
    end
  end

  def copy_posts
    copy_model(Post, skip_processing: true, mapping: @posts)
    copy_model(PostAction, mapping: @post_actions)
    [PostReply, TopicLink, UserAction, QuotedPost].each do |k|
      copy_model(k)
    end
    [PostStat, IncomingEmail, PostDetail, PostRevision].each do |k|
      copy_model(k, skip_processing: true)
    end
  end

  def copy_tags
    puts "merging tags..."

    columns = Tag.columns.map(&:name)
    imported_ids = []
    last_id = Tag.unscoped.maximum(:id)

    sql = "COPY tags (#{columns.map { |c| "\"#{c}\"" }.join(', ')}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection.exec("SELECT #{columns.map { |c| "\"#{c}\"" }.join(', ')} FROM tags").each do |row|

        if existing = Tag.where(name: row['name']).first
          @tags[row['id']] = existing.id
          next
        end

        old_id = row['id']
        row['id'] = (last_id += 1)
        @tags[old_id.to_s] = row['id']

        @raw_connection.put_copy_data(row.values)
      end
    end

    @sequences[Tag.sequence_name] = last_id + 1

    [TagUser, TopicTag, CategoryTag, CategoryTagStat].each do |k|
      copy_model(k, skip_processing: true)
    end
    copy_model(TagGroup, mapping: @tag_groups)
    [TagGroupMembership, CategoryTagGroup].each do |k|
      copy_model(k, skip_processing: true)
    end

    col_list = TagGroupPermission.columns.map { |c| "\"#{c.name}\"" }.join(', ')
    copy_model(TagGroupPermission,
      skip_processing: true,
      select_sql: "SELECT #{col_list} FROM tag_group_permissions WHERE group_id NOT IN (#{@auto_group_ids.join(', ')})"
    )
  end

  def copy_uploads
    puts ''
    print "copying uploads..."

    source_raw_connection.exec("SELECT * FROM uploads").each do |row|
      user_id = row['user_id'].to_i
      user_id = user_id_from_imported_id(user_id) if user_id > 0
      absolute_filename = File.join(@uploads_path, row['url'].gsub(/^\/uploads\/[^\/]+\//, ''))
      print '.'

      next unless File.exists?(absolute_filename)

      upload = create_upload(user_id, absolute_filename, File.basename(absolute_filename))
      if upload&.persisted?
        @uploads[row['id']] = upload.id
        if @source_cdn
          DbHelper.remap(UrlHelper.absolute(row['url'], @source_cdn), upload.url)
        end
        DbHelper.remap(UrlHelper.absolute(row['url'], @source_base_url), upload.url)
        DbHelper.remap(row['url'], upload.url)
      else
        puts "Error: Upload did not persist for #{absolute_filename}! #{upload&.errors&.full_messages}"
      end
    end
    puts ''

    copy_model(PostUpload)
    copy_model(UserAvatar)
  end

  def copy_everything_else
    [PostTiming, UserArchivedMessage, UnsubscribeKey].each do |k|
      copy_model(k, skip_processing: true)
    end

    [UserHistory, UserWarning].each do |k|
      copy_model(k)
    end

    copy_model(Notification, mapping: @notifications)
  end

  def copy_badges
    copy_model(BadgeGrouping, mapping: @badge_groupings, skip_processing: true)

    puts "merging badges..."
    columns = Badge.columns.map(&:name)
    imported_ids = []
    last_id = Badge.unscoped.maximum(:id)

    sql = "COPY badges (#{columns.map { |c| "\"#{c}\"" }.join(', ')}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection.exec("SELECT #{columns.map { |c| "\"#{c}\"" }.join(', ')} FROM badges").each do |row|

        if existing = Badge.where(name: row['name']).first
          @badges[row['id']] = existing.id
          next
        end

        old_id = row['id']
        row['id'] = (last_id += 1)
        @badges[old_id.to_s] = row['id']

        row['badge_grouping_id'] = @badge_groupings[row['badge_grouping_id']] if row['badge_grouping_id']

        @raw_connection.put_copy_data(row.values)
      end
    end

    @sequences[Badge.sequence_name] = last_id + 1

    copy_model(UserBadge, is_a_user_model: true, skip_if_merged: true)
  end

  def copy_model(klass, skip_if_merged: false, is_a_user_model: false, skip_processing: false, mapping: nil, select_sql: nil)

    puts "copying #{klass.table_name}..."

    columns = klass.columns.map(&:name)
    has_custom_fields = CUSTOM_FIELDS.include?(klass.name.downcase)
    imported_ids = []
    last_id = columns.include?('id') ? (klass.unscoped.maximum(:id) || 1) : nil

    sql = "COPY #{klass.table_name} (#{columns.map { |c| "\"#{c}\"" }.join(', ')}) FROM STDIN"
    @raw_connection.copy_data(sql, @encoder) do
      source_raw_connection.exec(select_sql || "SELECT #{columns.map { |c| "\"#{c}\"" }.join(', ')} FROM #{klass.table_name}").each do |row|
        if row['user_id']
          old_user_id = row['user_id'].to_i

          next if skip_if_merged && @merged_user_ids.include?(old_user_id)

          if is_a_user_model
            next if old_user_id < 1
            next if user_id_from_imported_id(old_user_id).nil?
          end

          if old_user_id >= 1
            row['user_id'] = user_id_from_imported_id(old_user_id)
            if is_a_user_model && row['user_id'].nil?
              raise "user_id nil for user id '#{old_user_id}'"
            end
            next if row['user_id'].nil? # associated record for a deleted user
          end
        end

        row['group_id'] = group_id_from_imported_id(row['group_id']) if row['group_id']
        row['category_id'] = category_id_from_imported_id(row['category_id']) if row['category_id']
        if row['topic_id'] && klass != Category
          row['topic_id'] = topic_id_from_imported_id(row['topic_id'])
          next if row['topic_id'].nil?
        end
        if row['post_id']
          row['post_id'] = post_id_from_imported_id(row['post_id'])
          next if row['post_id'].nil?
        end
        row['tag_id'] = tag_id_from_imported_id(row['tag_id']) if row['tag_id']
        row['tag_group_id'] = tag_group_id_from_imported_id(row['tag_group_id']) if row['tag_group_id']
        row['upload_id'] = upload_id_from_imported_id(row['upload_id']) if row['upload_id']
        row['deleted_by_id'] = user_id_from_imported_id(row['deleted_by_id']) if row['deleted_by_id']
        row['badge_id'] = badge_id_from_imported_id(row['badge_id']) if row['badge_id']

        old_id = row['id']
        if old_id && last_id
          row['id'] = (last_id += 1)
          imported_ids << old_id if has_custom_fields
          mapping[old_id.to_s] = row['id'] if mapping
        end

        if skip_processing
          @raw_connection.put_copy_data(row.values)
        else
          process_method_name = "process_#{klass.name.underscore}"

          processed = respond_to?(process_method_name) ? send(process_method_name, HashWithIndifferentAccess.new(row)) : row

          if processed
            @raw_connection.put_copy_data columns.map { |c| processed[c] }
          end
        end
      end
    end

    @sequences[klass.sequence_name] = last_id + 1 if last_id

    if has_custom_fields
      id_mapping_method_name = "#{klass.name.downcase}_id_from_imported_id".freeze
      return unless respond_to?(id_mapping_method_name)
      create_custom_fields(klass.name.downcase, "id", imported_ids) do |imported_id|
        {
          record_id: send(id_mapping_method_name, imported_id),
          value: imported_id,
        }
      end
    end
  end

  def process_topic(topic)
    return nil if topic['category_id'].nil?
    topic
  end

  def process_post(post)
    post[:last_editor_id] = user_id_from_imported_id(post[:user_id])
    @topic_id_by_post_id[post[:id]] = post[:topic_id]
    post
  end

  def process_post_reply(post_reply)
    post_reply['reply_id'] = post_id_from_imported_id(post_reply['reply_id']) if post_reply['reply_id']
    post_reply
  end

  def process_quoted_post(quoted_post)
    quoted_post['quoted_post_id'] = post_id_from_imported_id(quoted_post['quoted_post_id']) if quoted_post['quoted_post_id']
    return nil if quoted_post['quoted_post_id'].nil?
    quoted_post
  end

  def process_topic_link(topic_link)
    topic_link['link_topic_id'] = topic_id_from_imported_id(topic_link['link_topic_id']) if topic_link['link_topic_id']
    topic_link['link_post_id'] = post_id_from_imported_id(topic_link['link_post_id']) if topic_link['link_post_id']
    return nil if topic_link['link_topic_id'].nil? || topic_link['link_post_id'].nil?
    topic_link
  end

  def process_post_action(post_action)
    return nil unless post_action['post_id'].present?
    post_action['related_post_id'] = post_id_from_imported_id(post_action['related_post_id'])
    post_action['deferred_by_id'] = user_id_from_imported_id(post_action['deferred_by_id'])
    post_action['agreed_by_id'] = user_id_from_imported_id(post_action['agreed_by_id'])
    post_action['disagreed_by_id'] = user_id_from_imported_id(post_action['disagreed_by_id'])
    post_action
  end

  def process_user_action(user_action)
    user_action['target_topic_id'] = topic_id_from_imported_id(user_action['target_topic_id']) if user_action['target_topic_id']
    user_action['target_post_id'] = post_id_from_imported_id(user_action['target_post_id']) if user_action['target_post_id']
    user_action['target_user_id'] = user_id_from_imported_id(user_action['target_user_id']) if user_action['target_user_id']
    user_action['acting_user_id'] = user_id_from_imported_id(user_action['acting_user_id']) if user_action['acting_user_id']
    user_action['queued_post_id'] = post_id_from_imported_id(user_action['queued_post_id']) if user_action['queued_post_id']
    user_action
  end

  def process_tag_group(tag_group)
    tag_group['parent_tag_id'] = tag_id_from_imported_id(tag_group['parent_tag_id']) if tag_group['parent_tag_id']
    tag_group
  end

  def process_category_group(category_group)
    return nil if category_group['category_id'].nil? || category_group['group_id'].nil?
    category_group
  end

  def process_group_user(group_user)
    if @auto_group_ids.include?(group_user['group_id'].to_i) &&
        @merged_user_ids.include?(group_user['user_id'].to_i)
      return nil
    end
    return nil if group_user['user_id'].to_i < 1
    group_user
  end

  def process_group_history(group_history)
    group_history['acting_user_id'] = user_id_from_imported_id(group_history['acting_user_id']) if group_history['acting_user_id']
    group_history['target_user_id'] = user_id_from_imported_id(group_history['target_user_id']) if group_history['target_user_id']
    group_history
  end

  def process_group_archived_message(gam)
    return nil unless gam['topic_id'].present? && gam['group_id'].present?
    gam
  end

  def process_topic_link(topic_link)
    topic_link['link_topic_id'] = topic_id_from_imported_id(topic_link['link_topic_id']) if topic_link['link_topic_id']
    topic_link['link_post_id'] = post_id_from_imported_id(topic_link['link_post_id']) if topic_link['link_post_id']
    topic_link
  end

  def process_user_avatar(user_avatar)
    user_avatar['custom_upload_id'] = upload_id_from_imported_id(user_avatar['custom_upload_id']) if user_avatar['custom_upload_id']
    user_avatar['gravatar_upload_id'] = upload_id_from_imported_id(user_avatar['gravatar_upload_id']) if user_avatar['gravatar_upload_id']
    return nil unless user_avatar['custom_upload_id'].present? && user_avatar['gravatar_upload_id'].present?
    user_avatar
  end

  def process_user_history(user_history)
    user_history['acting_user_id'] = user_id_from_imported_id(user_history['acting_user_id']) if user_history['acting_user_id']
    user_history['target_user_id'] = user_id_from_imported_id(user_history['target_user_id']) if user_history['target_user_id']
    user_history
  end

  def process_user_warning(user_warning)
    user_warning['created_by_id'] = user_id_from_imported_id(user_warning['created_by_id']) if user_warning['created_by_id']
    user_warning
  end

  def process_post_upload(post_upload)
    return nil unless post_upload['upload_id'].present?

    # can't figure out why there are duplicates of these during merge.
    # here's a hack to prevent it:
    @imported_post_uploads ||= {}
    return nil if @imported_post_uploads[post_upload['post_id']] == post_upload['upload_id']
    @imported_post_uploads[post_upload['post_id']] = post_upload['upload_id']

    post_upload
  end

  def process_notification(notification)
    notification['post_action_id'] = post_action_id_from_imported_id(notification['post_action_id']) if notification['post_action_id']
    notification
  end

  def process_facebook_user_info(r)
    return nil if FacebookUserInfo.where(facebook_user_id: r['facebook_user_id']).exists?
    r
  end

  def process_github_user_info(r)
    return nil if GithubUserInfo.where(github_user_id: r['github_user_id']).exists?
    r
  end

  def process_google_user_info(r)
    return nil if GoogleUserInfo.where(google_user_id: r['google_user_id']).exists?
    r
  end

  def process_instagram_user_info(r)
    return nil if InstagramUserInfo.where(instagram_user_id: r['instagram_user_id']).exists?
    r
  end

  def process_oauth2_user_info(r)
    return nil if Oauth2UserInfo.where(uid: r['uid'], provider: r['provider']).exists?
    r
  end

  def process_single_sign_on_record(r)
    return nil if SingleSignOnRecord.where(external_id: r['external_id']).exists?
    r
  end

  def process_twitter_user_info(r)
    return nil if TwitterUserInfo.where(twitter_user_id: r['twitter_user_id']).exists?
    r
  end

  def process_user_badge(user_badge)
    user_badge['granted_by_id'] = user_id_from_imported_id(user_badge['granted_by_id']) if user_badge['granted_by_id']
    user_badge['notification_id'] = notification_id_from_imported_id(user_badge['notification_id']) if user_badge['notification_id']
    user_badge
  end

  def user_id_from_imported_id(id)
    return id if id.to_i < 1
    super(id)
  end

  def group_id_from_imported_id(id)
    return id if @auto_group_ids.include?(id&.to_i)
    super(id)
  end

  def tag_id_from_imported_id(id)
    @tags[id.to_s]
  end

  def tag_group_id_from_imported_id(id)
    @tag_groups[id.to_s]
  end

  def upload_id_from_imported_id(id)
    @uploads[id.to_s]
  end

  def post_action_id_from_imported_id(id)
    @post_actions[id.to_s]
  end

  def badge_id_from_imported_id(id)
    @badges[id.to_s]
  end

  def notification_id_from_imported_id(id)
    @notifications[id.to_s]
  end

  def fix_primary_keys
    @sequences.each do |sequence_name, val|
      sql = "SELECT setval('#{sequence_name}', #{val})"
      puts sql
      @raw_connection.exec(sql)
    end
  end

end

BulkImport::DiscourseMerger.new.start
