# frozen_string_literal: true

require "mysql2"
require_relative "base"

class ImportScripts::JForum < ImportScripts::Base
  BATCH_SIZE = 1000
  REMOTE_AVATAR_REGEX = %r{\Ahttps?://}i

  def initialize
    super

    @settings = YAML.safe_load(File.read(ARGV.first), symbolize_names: true)

    @database_client =
      Mysql2::Client.new(
        host: @settings[:database][:host],
        port: @settings[:database][:port],
        username: @settings[:database][:username],
        password: @settings[:database][:password],
        database: @settings[:database][:schema],
        reconnect: true,
      )
  end

  def execute
    import_users

    if @settings[:import_categories_as_tags]
      import_tags
    else
      import_categories
    end

    import_posts
    import_likes
    import_category_subscriptions
    import_topic_subscriptions
    mark_topics_as_solved
  end

  def import_users
    puts "", "creating users"
    total_count = count("SELECT COUNT(1) AS count FROM jforum_users")
    last_user_id = 0

    custom_fields_query = user_custom_fields_query

    batches do |offset|
      rows, last_user_id = query(<<~SQL, :user_id)
        SELECT user_id, username, user_lastvisit, user_regdate, user_email, user_from, user_active,
               user_avatar, COALESCE(user_realname, CONCAT(first_name, ' ', last_name)) AS name
               #{custom_fields_query}
        FROM jforum_users
        WHERE user_id > #{last_user_id}
        ORDER BY user_id
        LIMIT #{BATCH_SIZE}
      SQL
      break if rows.size < 1

      next if all_records_exist?(:users, rows.map { |row| row[:user_id] })

      create_users(rows, total: total_count, offset: offset) do |row|
        {
          id: row[:user_id],
          email: row[:user_email]&.strip,
          name: row[:name],
          created_at: row[:user_regdate],
          last_seen_at: row[:user_lastvisit],
          active: row[:user_active] == 1,
          location: row[:user_from],
          custom_fields: user_custom_fields(row),
          post_create_action: proc { |user| import_avatar(user, row[:user_avatar]) },
        }
      end
    end
  end

  def user_custom_fields_query
    return "" if @settings[:custom_fields].blank?

    columns = []
    @settings[:custom_fields].map do |field|
      columns << (field[:alias] ? "#{field[:column]} AS #{field[:alias]}" : field[:column])
    end
    ", #{columns.join(", ")}"
  end

  def user_fields
    @user_fields ||=
      begin
        Hash[UserField.all.map { |field| [field.name, field] }]
      end
  end

  def user_custom_fields(row)
    return nil if @settings[:custom_fields].blank?

    custom_fields = {}

    @settings[:custom_fields].map do |field|
      column = field[:alias] || field[:column]
      value = row[column.to_sym]
      user_field = user_fields[field[:name]]

      case user_field.field_type
      when "confirm"
        value = value == 1 ? true : nil
      when "dropdown"
        value = user_field.user_field_options.find { |option| option.value == value } ? value : nil
      end

      custom_fields["user_field_#{user_field.id}"] = value if value.present?
    end

    custom_fields
  end

  def import_avatar(user, avatar_source)
    return if avatar_source.blank?

    path = File.join(@settings[:avatar_directory], avatar_source)

    if File.file?(path)
      @uploader.create_avatar(user, path)
    elsif avatar_source.match?(REMOTE_AVATAR_REGEX)
      begin
        UserAvatar.import_url_for_user(avatar_source, user)
      rescue StandardError
        nil
      end
    end
  end

  def import_tags
    puts "", "creating tags"

    @tags_by_import_forum_id = {}

    SiteSetting.tagging_enabled = true
    SiteSetting.max_tag_length = 100
    SiteSetting.max_tags_per_topic = 10
    SiteSetting.force_lowercase_tags = false

    additional_tags = Array.wrap(@settings[:additional_tags])

    rows = query(<<~SQL)
      SELECT c.categories_id, c.title AS category_name, f.forum_id, f.forum_name
      FROM jforum_forums f
        JOIN jforum_categories c ON f.categories_id = c.categories_id
      WHERE EXISTS (
        SELECT 1
        FROM jforum_posts p
        WHERE p.forum_id = f.forum_id
      )
    SQL

    rows.each do |row|
      tag_names = [row[:category_name], row[:forum_name]]

      additional_tags.each do |additional_tag|
        if additional_tag[:old_category_name].match?(row[:category_name])
          tag_names += additional_tag[:tag_names]
        end
      end

      tag_names.map! { |t| t.parameterize(preserve_case: true) }

      tag_names.each_with_index do |tag_name, index|
        tag = create_tag(tag_name)
        next if tag.blank?

        case index
        when 0
          url = File.join(@settings[:permalink_prefix], "forums/list/#{row[:categories_id]}.page")
          Permalink.create(url: url, tag_id: tag.id) unless Permalink.find_by(url: url)
        when 1
          url = File.join(@settings[:permalink_prefix], "forums/show/#{row[:forum_id]}.page")
          Permalink.create(url: url, tag_id: tag.id) unless Permalink.find_by(url: url)
        end
      end

      @tags_by_import_forum_id[row[:forum_id]] = tag_names.uniq
    end

    category_mappings = Array.wrap(@settings[:category_mappings])

    if category_mappings.blank?
      rows.each do |row|
        category_mappings.each do |mapping|
          if mapping[:old_category_name].match?(row[:category_name])
            @lookup.add_category(row[:forum_id], Category.find(mapping[:category_id]))
          end
        end
      end
    end
  end

  def create_tag(tag_name)
    tag = Tag.find_by_name(tag_name)

    if tag
      # update if the case is different
      tag.update!(name: tag_name) if tag.name != tag_name
      nil
    else
      Tag.create!(name: tag_name)
    end
  end

  def import_categories
    puts "", "creating categories"

    rows = query(<<~SQL)
      SELECT categories_id, title, display_order
      FROM jforum_categories
      ORDER BY display_order
    SQL

    create_categories(rows) do |row|
      {
        id: "C#{row[:categories_id]}",
        name: row[:title],
        position: row[:display_order],
        post_create_action:
          proc do |category|
            url = File.join(@settings[:permalink_prefix], "forums/list/#{row[:categories_id]}.page")
            Permalink.create(url: url, category_id: category.id) unless Permalink.find_by(url: url)
          end,
      }
    end

    rows = query(<<~SQL)
      SELECT forum_id, categories_id, forum_name, forum_desc, forum_order
      FROM jforum_categories
      ORDER BY categories_id, forum_order
    SQL

    create_categories(rows) do |row|
      {
        id: row[:forum_id],
        name: row[:forum_name],
        description: row[:forum_desc],
        position: row[:forum_order],
        parent_category_id:
          @lookup.category_id_from_imported_category_id("C#{row[:categories_id]}"),
        post_create_action:
          proc do |category|
            url = File.join(@settings[:permalink_prefix], "forums/show/#{row[:forum_id]}.page")
            Permalink.create(url: url, category_id: category.id) unless Permalink.find_by(url: url)
          end,
      }
    end
  end

  def import_posts
    puts "", "creating topics and posts"
    total_count = count("SELECT COUNT(1) AS count FROM jforum_posts")
    last_post_id = 0

    batches do |offset|
      rows, last_post_id = query(<<~SQL, :post_id)
        SELECT p.post_id, p.topic_id, p.user_id, t.topic_title, pt.post_text, p.post_time, t.topic_status,
               t.topic_type, t.topic_views, p.poster_ip, p.forum_id, t.topic_acceptedanswer_post_id,
               EXISTS (SELECT 1 FROM jforum_attach a WHERE a.post_id = p.post_id) AS has_attachments,
               COALESCE(
                 (SELECT x.post_id FROM jforum_posts x WHERE x.post_id = t.topic_first_post_id),
                 (SELECT MIN(x.post_id) FROM jforum_posts x WHERE x.topic_id = t.topic_id)
               ) AS topic_first_post_id
        FROM jforum_posts p
            JOIN jforum_topics t ON p.topic_id = t.topic_id
            LEFT OUTER JOIN jforum_posts_text pt ON p.post_id = pt.post_id
        WHERE p.post_id > #{last_post_id}
        ORDER BY p.post_id
        LIMIT #{BATCH_SIZE}
      SQL
      break if rows.size < 1

      next if all_records_exist?(:posts, rows.map { |row| row[:post_id] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        user_id = @lookup.user_id_from_imported_user_id(row[:user_id]) || Discourse::SYSTEM_USER_ID
        is_first_post = row[:post_id] == row[:topic_first_post_id]
        post_text = fix_bbcodes(row[:post_text])

        if row[:has_attachments] > 0
          attachments = import_attachments(row[:post_id], user_id)
          post_text << "\n" << attachments.join("\n")
        end

        mapped = {
          id: row[:post_id],
          user_id: user_id,
          created_at: row[:post_time],
          raw: post_text,
          import_topic_id: row[:topic_id],
        }

        if row[:topic_acceptedanswer_post_id] == row[:post_id]
          mapped[:custom_fields] = { is_accepted_answer: "true" }
        end

        if is_first_post
          map_first_post(row, mapped)
        else
          map_other_post(row, mapped)
        end
      end
    end
  end

  def map_first_post(row, mapped)
    mapped[:title] = CGI.unescapeHTML(row[:topic_title]).strip[0...255]
    mapped[:views] = row[:topic_views]
    mapped[:post_create_action] = proc do |post|
      url = File.join(@settings[:permalink_prefix], "posts/list/#{row[:topic_id]}.page")
      Permalink.create(url: url, topic_id: post.topic.id) unless Permalink.find_by(url: url)

      TopicViewItem.add(post.topic_id, row[:poster_ip], post.user_id, post.created_at, true)
    end

    mapped[:tags] = @tags_by_import_forum_id[row[:forum_id]] if @settings[
      :import_categories_as_tags
    ]
    mapped[:category] = @lookup.category_id_from_imported_category_id(row[:forum_id])

    mapped
  end

  def map_other_post(row, mapped)
    parent = @lookup.topic_lookup_from_imported_post_id(row[:topic_first_post_id])

    if parent.blank?
      puts "Parent post #{row[:topic_first_post_id]} doesn't exist. Skipping #{row[:post_id]}: #{row[:topic_title][0..40]}"
      return nil
    end

    mapped[:topic_id] = parent[:topic_id]
    mapped[:post_create_action] = proc do |post|
      TopicViewItem.add(post.topic_id, row[:poster_ip], post.user_id, post.created_at, true)
    end

    mapped
  end

  def import_attachments(post_id, user_id)
    rows = query(<<~SQL)
      SELECT d.physical_filename, d.real_filename
      FROM jforum_attach a
        JOIN jforum_attach_desc d USING (attach_id)
      WHERE a.post_id = #{post_id}
      ORDER BY a.attach_id
    SQL
    return nil if rows.size < 1

    attachments = []

    rows.each do |row|
      path = File.join(@settings[:attachment_directory], row[:physical_filename])
      filename = CGI.unescapeHTML(row[:real_filename])
      upload = @uploader.create_upload(user_id, path, filename)

      if upload.nil? || !upload.persisted?
        puts "Failed to upload #{path}"
        puts upload.errors.inspect if upload
      else
        attachments << @uploader.html_for_upload(upload, filename)
      end
    end

    attachments
  end

  def mark_topics_as_solved
    puts "", "Marking topics as solved..."

    DB.exec <<~SQL
      INSERT INTO topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'accepted_answer_post_id', pcf.post_id, p.topic_id, p.created_at, p.created_at
        FROM post_custom_fields pcf
        JOIN posts p ON p.id = pcf.post_id
       WHERE pcf.name = 'is_accepted_answer' AND pcf.value = 'true'
         AND NOT EXISTS (
           SELECT 1
           FROM topic_custom_fields x
           WHERE x.topic_id = p.topic_id AND x.name = 'accepted_answer_post_id'
         )
    SQL
  end

  def import_likes
    puts "", "Importing likes..."
    total_count = count(<<~SQL)
      SELECT COUNT(1) AS count
      FROM jforum_karma k
      WHERE k.points >= 2
        AND EXISTS (SELECT 1 FROM jforum_posts p WHERE k.post_id = p.post_id)
        AND EXISTS (SELECT 1 FROM jforum_users u WHERE k.from_user_id = u.user_id)
    SQL
    current_index = 0
    last_post_id = 0
    last_user_id = 0

    batches do |_|
      rows, last_post_id, last_user_id = query(<<~SQL, :post_id, :from_user_id)
        SELECT k.post_id, k.from_user_id, k.rate_date
        FROM jforum_karma k
        WHERE k.points >= 2 AND ((k.post_id = #{last_post_id} AND k.from_user_id > #{last_user_id}) OR k.post_id > #{last_post_id})
          AND EXISTS (SELECT 1 FROM jforum_posts p WHERE k.post_id = p.post_id)
          AND EXISTS (SELECT 1 FROM jforum_users u WHERE k.from_user_id = u.user_id)
        ORDER BY k.post_id, k.from_user_id
        LIMIT #{BATCH_SIZE}
      SQL
      break if rows.size < 1

      rows.each do |row|
        created_by = User.find_by(id: @lookup.user_id_from_imported_user_id(row[:from_user_id]))
        post = Post.find_by(id: @lookup.post_id_from_imported_post_id(row[:post_id]))

        if created_by && post
          PostActionCreator.create(created_by, post, :like, created_at: row[:rate_date])
        end

        current_index += 1
        print_status(current_index, total_count, get_start_time("likes"))
      end
    end
  end

  def import_category_subscriptions
    puts "", "Importing category subscriptions..."
    total_count = count(<<~SQL)
      SELECT COUNT(1) AS count
      FROM (
               SELECT forum_id, user_id
               FROM jforum_forums_watch
               UNION
               SELECT forum_id, user_id
               FROM jforum_digest_forums
           ) x
      WHERE EXISTS (SELECT 1 FROM jforum_forums f WHERE x.forum_id = f.forum_id)
    SQL
    current_index = 0
    last_forum_id = 0
    last_user_id = 0

    batches do |_|
      rows, last_forum_id, last_user_id = query(<<~SQL, :forum_id, :user_id)
        SELECT x.forum_id, x.user_id
        FROM jforum_forums_watch x
        WHERE ((x.forum_id = #{last_forum_id} AND x.user_id > #{last_user_id}) OR x.forum_id > #{last_forum_id})
          AND EXISTS (SELECT 1 FROM jforum_forums f WHERE x.forum_id = f.forum_id)
        UNION
        SELECT forum_id, user_id
        FROM jforum_digest_forums x
        WHERE ((x.forum_id = #{last_forum_id} AND x.user_id > #{last_user_id}) OR x.forum_id > #{last_forum_id})
          AND EXISTS (SELECT 1 FROM jforum_forums f WHERE x.forum_id = f.forum_id)
        ORDER BY forum_id, user_id
        LIMIT #{BATCH_SIZE}
      SQL
      break if rows.size < 1

      tags = Tag.all.pluck(:name, :id).to_h

      rows.each do |row|
        user_id = @lookup.user_id_from_imported_user_id(row[:user_id])

        if @settings[:import_categories_as_tags]
          tag_names = @tags_by_import_forum_id[row[:forum_id]]
          tag_ids = tag_names ? tag_names.map { |name| tags[name] } : nil

          if user_id && tag_ids.present?
            tag_ids.each do |tag_id|
              TagUser.change(user_id, tag_id, TagUser.notification_levels[:watching])
            end
          end
        else
          user = User.find_by(id: user_id)
          category_id = @lookup.category_id_from_imported_category_id(row[:forum_id])

          if user && category_id
            CategoryUser.set_notification_level_for_category(
              user,
              NotificationLevels.all[:watching],
              category_id,
            )
          end
        end

        current_index += 1
        print_status(current_index, total_count, get_start_time("category_subscriptions"))
      end
    end
  end

  def import_topic_subscriptions
    puts "", "Importing topic subscriptions..."
    total_count = count(<<~SQL)
      SELECT COUNT(1) AS count
      FROM jforum_topics_watch x
      WHERE EXISTS (SELECT 1 FROM jforum_topics t WHERE x.topic_id = t.topic_id)
    SQL
    current_index = 0
    last_topic_id = 0
    last_user_id = 0

    batches do |_|
      rows, last_topic_id, last_user_id = query(<<~SQL, :topic_id, :user_id)
        SELECT x.topic_id, x.user_id,
          COALESCE(
            (SELECT x.post_id FROM jforum_posts x WHERE x.post_id = t.topic_first_post_id),
            (SELECT MIN(x.post_id) FROM jforum_posts x WHERE x.topic_id = t.topic_id)
          ) AS topic_first_post_id
        FROM jforum_topics_watch x
          JOIN jforum_topics t ON x.topic_id = t.topic_id
        WHERE ((x.topic_id = #{last_topic_id} AND x.user_id > #{last_user_id}) OR x.topic_id > #{last_topic_id})
        ORDER BY topic_id, user_id
        LIMIT #{BATCH_SIZE}
      SQL
      break if rows.size < 1

      rows.each do |row|
        user_id = @lookup.user_id_from_imported_user_id(row[:user_id])
        topic = @lookup.topic_lookup_from_imported_post_id(row[:topic_first_post_id])

        if user_id && topic
          TopicUser.change(
            user_id,
            topic[:topic_id],
            notification_level: NotificationLevels.all[:watching],
          )
        end

        current_index += 1
        print_status(current_index, total_count, get_start_time("topic_subscriptions"))
      end
    end
  end

  def fix_bbcodes(text)
    return text if text.blank?

    text = text.dup
    text.gsub!(/\r\n/, "\n")

    fix_bbcode_tag!(tag: "quote", text: text)
    fix_bbcode_tag!(tag: "code", text: text)
    fix_bbcode_tag!(tag: "list", text: text)
    fix_bbcode_tag!(tag: "center", text: text)
    fix_bbcode_tag!(tag: "right", text: text)
    fix_bbcode_tag!(tag: "left", text: text)

    fix_inline_bbcode!(tag: "i", text: text)
    fix_inline_bbcode!(tag: "b", text: text)
    fix_inline_bbcode!(tag: "s", text: text)
    fix_inline_bbcode!(tag: "u", text: text)
    fix_inline_bbcode!(tag: "size", text: text)
    fix_inline_bbcode!(tag: "font", text: text)
    fix_inline_bbcode!(tag: "color", text: text)

    text
  end

  def fix_bbcode_tag!(tag:, text:)
    text.gsub!(%r{\s+(\[#{tag}\].*?\[/#{tag}\])}im, '\1')

    text.gsub!(/(\[#{tag}.*?\])(?!$)/i) { "#{$1}\n" }
    text.gsub!(/((?<!^)\[#{tag}.*?\])/i) { "\n#{$1}" }

    text.gsub!(%r{(\[/#{tag}\])(?!$)}i) { "#{$1}\n" }
    text.gsub!(%r{((?<!^)\[/#{tag}\])}i) { "\n#{$1}" }
  end

  def fix_inline_bbcode!(tag:, text:)
    text.gsub!(%r{\[(#{tag}.*?)\](.*?)\[/#{tag}\]}im) do
      beginning_tag = $1
      content = $2.gsub(/(\n{2,})/) { "[/#{tag}]#{$1}[#{beginning_tag}]" }
      "[#{beginning_tag}]#{content}[/#{tag}]"
    end
  end

  def batches
    super(BATCH_SIZE)
  end

  def query(sql, *last_columns)
    rows = @database_client.query(sql, cache_rows: true, symbolize_keys: true)
    return rows if last_columns.length == 0

    result = [rows]
    last_row = rows.to_a.last

    last_columns.each { |column| result.push(last_row ? last_row[column] : nil) }
    result
  end

  # Executes a database query and returns the value of the 'count' column.
  def count(sql)
    query(sql).first[:count]
  end
end

ImportScripts::JForum.new.perform
