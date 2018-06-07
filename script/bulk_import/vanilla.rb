require_relative "base"
require "mysql2"
require "rake"

class BulkImport::Vanilla < BulkImport::Base

  VANILLA_DB = "dbname"
  TABLE_PREFIX = "GDN_"
  ATTACHMENTS_BASE_DIR = "/my/absolute/path/to/from_vanilla/uploads"
  BATCH_SIZE = 1000
  CONVERT_HTML = true

  SUSPENDED_TILL ||= Date.new(3000, 1, 1)

  def initialize
    super
    @htmlentities = HTMLEntities.new
    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      database: VANILLA_DB
    )

    @import_tags = false
    begin
      r = @client.query("select count(*) count from #{TABLE_PREFIX}Tag where countdiscussions > 0")
      @import_tags = true if r.first["count"].to_i > 0
    rescue => e
      puts "Tags won't be imported. None found. #{e.message}"
    end

    @category_mappings = {}
  end

  def start
    run # will call execute, and then "complete" the migration

    # Now that the migration is complete, do some more work:

    Discourse::Application.load_tasks
    Rake::Task["import:ensure_consistency"].invoke

    import_avatars # slow
    create_permalinks # TODO: do it bulk style
  end

  def execute
    if @import_tags
      SiteSetting.tagging_enabled = true
      SiteSetting.max_tags_per_topic = 10
      SiteSetting.max_tag_length = 100
    end

    # other good ones:

    # SiteSetting.port = 3000
    # SiteSetting.automatic_backups_enabled = false
    # SiteSetting.disable_emails = "non-staff"
    # etc.

    import_users
    import_user_emails
    import_user_profiles
    import_user_stats

    import_categories
    import_topics
    import_tags if @import_tags
    import_posts

    import_private_topics
    import_topic_allowed_users
    import_private_posts
  end

  def import_users
    puts '', "Importing users..."

    username = nil
    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}User;").first['count']

    users = mysql_stream <<-SQL
      SELECT UserID, Name, Title, Location, Email,
             DateInserted, DateLastActive, InsertIPAddress, Admin, Banned
        FROM #{TABLE_PREFIX}User
       WHERE UserID > #{@last_imported_user_id}
         AND Deleted = 0
    ORDER BY UserID ASC
    SQL

    create_users(users) do |row|
      next if row['Email'].blank?
      next if row['Name'].blank?

      if ip_address = row['InsertIPAddress']&.split(',').try(:[], 0)
        ip_address = nil unless (IPAddr.new(ip_address) rescue false)
      end

      u = {
        imported_id: row['UserID'],
        email: row['Email'],
        username: row['Name'],
        name: row['Name'],
        created_at: row['DateInserted'] == nil ? 0 : Time.zone.at(row['DateInserted']),
        registration_ip_address: ip_address,
        last_seen_at: row['DateLastActive'] == nil ? 0 : Time.zone.at(row['DateLastActive']),
        location: row['Location'],
        admin: row['Admin'] > 0
      }
      if row["Banned"] > 0
        u[:suspended_at] = Time.zone.at(row['DateInserted'])
        u[:suspended_till] = SUSPENDED_TILL
      end
      u
    end
  end

  def import_user_emails
    puts '', 'Importing user emails...'

    users = mysql_stream <<-SQL
      SELECT UserID, Name, Email, DateInserted
        FROM #{TABLE_PREFIX}User
       WHERE UserID > #{@last_imported_user_id}
         AND Deleted = 0
    ORDER BY UserID ASC
    SQL

    create_user_emails(users) do |row|
      next if row['Email'].blank?
      next if row['Name'].blank?

      {
        imported_id: row["UserID"],
        imported_user_id: row["UserID"],
        email: row["Email"],
        created_at: Time.zone.at(row["DateInserted"])
      }
    end
  end

  def import_user_profiles
    puts '', 'Importing user profiles...'

    user_profiles = mysql_stream <<-SQL
      SELECT UserID, Name, Email, Location, About
        FROM #{TABLE_PREFIX}User
       WHERE UserID > #{@last_imported_user_id}
         AND Deleted = 0
    ORDER BY UserID ASC
    SQL

    create_user_profiles(user_profiles) do |row|
      next if row['Email'].blank?
      next if row['Name'].blank?

      {
        user_id: user_id_from_imported_id(row["UserID"]),
        location: row["Location"],
        bio_raw: row["About"]
      }
    end
  end

  def import_user_stats
    puts '', "Importing user stats..."

    users = mysql_stream <<-SQL
      SELECT UserID, CountDiscussions, CountComments, DateInserted
        FROM #{TABLE_PREFIX}User
       WHERE UserID > #{@last_imported_user_id}
         AND Deleted = 0
    ORDER BY UserID ASC
    SQL

    now = Time.zone.now

    create_user_stats(users) do |row|
      next unless @users[row['UserID'].to_s] # shouldn't need this but it can be NULL :<

      {
        imported_id: row['UserID'],
        imported_user_id: row['UserID'],
        new_since: Time.zone.at(row['DateInserted'] || now),
        post_count: row['CountComments'] || 0,
        topic_count: row['CountDiscussions'] || 0
      }
    end
  end

  def import_avatars
    if ATTACHMENTS_BASE_DIR && File.exists?(ATTACHMENTS_BASE_DIR)
      puts "", "importing user avatars"

      start = Time.now
      count = 0

      User.find_each do |u|
        count += 1
        print "\r%7d - %6d/sec".freeze % [count, count.to_f / (Time.now - start)]

        next unless u.custom_fields["import_id"]

        r = mysql_query("SELECT photo FROM #{TABLE_PREFIX}User WHERE UserID = #{u.custom_fields['import_id']};").first
        next if r.nil?
        photo = r["photo"]
        next unless photo.present?

        # Possible encoded values:
        # 1. cf://uploads/userpics/820/Y0AFUQYYM6QN.jpg
        # 2. ~cf/userpics2/cf566487133f1f538e02da96f9a16b18.jpg
        # 3. ~cf/userpics/txkt8kw1wozn.jpg
        # 4. s3://uploads/xf/22/22690.jpg

        photo_real_filename = nil
        parts = photo.squeeze("/").split("/")
        if parts[0] =~ /^[a-z0-9]{2}:/
          photo_path = "#{ATTACHMENTS_BASE_DIR}/#{parts[2..-2].join('/')}".squeeze("/")
        elsif parts[0] == "~cf"
          photo_path = "#{ATTACHMENTS_BASE_DIR}/#{parts[1..-2].join('/')}".squeeze("/")
        else
          puts "UNKNOWN FORMAT: #{photo}"
          next
        end

        if !File.exists?(photo_path)
          puts "Path to avatar file not found! Skipping. #{photo_path}"
          next
        end

        photo_real_filename = find_photo_file(photo_path, parts.last)
        if photo_real_filename.nil?
          puts "Couldn't find file for #{photo}. Skipping."
          next
        end

        print "."

        upload = create_upload(u.id, photo_real_filename, File.basename(photo_real_filename))
        if upload.persisted?
          u.import_mode = false
          u.create_user_avatar
          u.import_mode = true
          u.user_avatar.update(custom_upload_id: upload.id)
          u.update(uploaded_avatar_id: upload.id)
        else
          puts "Error: Upload did not persist for #{u.username} #{photo_real_filename}!"
        end
      end
    end
  end

  def find_photo_file(path, base_filename)
    base_guess = base_filename.dup
    full_guess = File.join(path, base_guess) # often an exact match exists

    return full_guess if File.exists?(full_guess)

    # Otherwise, the file exists but with a prefix:
    # The p prefix seems to be the full file, so try to find that one first.
    ['p', 't', 'n'].each do |prefix|
      full_guess = File.join(path, "#{prefix}#{base_guess}")
      return full_guess if File.exists?(full_guess)
    end

    # Didn't find it.
    nil
  end

  def import_categories
    puts "", "Importing categories..."

    categories = mysql_query("
      SELECT CategoryID, ParentCategoryID, Name, Description, Sort
      FROM #{TABLE_PREFIX}Category
      WHERE CategoryID > 0
      ORDER BY Sort, CategoryID
    ").to_a

    # Throw the -1 level categories away since they contain no topics.
    # Use the next level as root categories.
    root_category_ids = Set.new(categories.select { |c| c["ParentCategoryID"] == -1 }.map { |c| c["CategoryID"] })

    top_level_categories = categories.select { |c| root_category_ids.include?(c["ParentCategoryID"]) }

    # Depth = 2
    create_categories(top_level_categories) do |category|
      next if category_id_from_imported_id(category['CategoryID'])
      {
        imported_id: category['CategoryID'],
        name: CGI.unescapeHTML(category['Name']),
        description: category['Description'] ? CGI.unescapeHTML(category['Description']) : nil,
        position: category['Sort']
      }
    end

    top_level_category_ids = Set.new(top_level_categories.map { |c| c["CategoryID"] })

    subcategories = categories.select { |c| top_level_category_ids.include?(c["ParentCategoryID"]) }

    # Depth = 3
    create_categories(subcategories) do |category|
      next if category_id_from_imported_id(category['CategoryID'])
      {
        imported_id: category['CategoryID'],
        parent_category_id: category_id_from_imported_id(category['ParentCategoryID']),
        name: CGI.unescapeHTML(category['Name']),
        description: category['Description'] ? CGI.unescapeHTML(category['Description']) : nil,
        position: category['Sort']
      }
    end

    subcategory_ids = Set.new(subcategories.map { |c| c['CategoryID'] })

    # Depth 4 and 5 need to be tags

    categories.each do |c|
      next if c['ParentCategoryID'] == -1
      next if top_level_category_ids.include?(c['CategoryID'])
      next if subcategory_ids.include?(c['CategoryID'])

      # Find a depth 3 category for topics in this category
      parent = c
      while !parent.nil? && !subcategory_ids.include?(parent['CategoryID'])
        parent = categories.find { |subcat| subcat['CategoryID'] == parent['ParentCategoryID'] }
      end

      if parent
        tag_name = DiscourseTagging.clean_tag(c['Name'])
        @category_mappings[c['CategoryID']] = {
          category_id: category_id_from_imported_id(parent['CategoryID']),
          tag: Tag.find_by_name(tag_name) || Tag.create(name: tag_name)
        }
      else
        puts '', "Couldn't find a category for #{c['CategoryID']} '#{c['Name']}'!"
      end
    end
  end

  def import_topics
    puts "", "Importing topics..."

    topics_sql = "SELECT DiscussionID, CategoryID, Name, Body, DateInserted, InsertUserID, Announce
      FROM #{TABLE_PREFIX}Discussion
      WHERE DiscussionID > #{@last_imported_topic_id}
      ORDER BY DiscussionID ASC"

    create_topics(mysql_stream(topics_sql)) do |row|
      {
        imported_id: row["DiscussionID"],
        title: normalize_text(row["Name"]),
        category_id: category_id_from_imported_id(row["CategoryID"]) ||
          @category_mappings[row["CategoryID"]].try(:[], :category_id),
        user_id: user_id_from_imported_id(row["InsertUserID"]),
        created_at: Time.zone.at(row['DateInserted']),
        pinned_at: row['Announce'] == 0 ? nil : Time.zone.at(row['DateInserted'])
      }
    end

    puts "", "importing first posts..."

    create_posts(mysql_stream(topics_sql)) do |row|
      {
        imported_id: "d-" + row['DiscussionID'].to_s,
        topic_id: topic_id_from_imported_id(row["DiscussionID"]),
        user_id: user_id_from_imported_id(row["InsertUserID"]),
        created_at: Time.zone.at(row['DateInserted']),
        raw: clean_up(row["Body"])
      }
    end

    puts '', 'converting deep categories to tags...'

    create_topic_tags(mysql_stream(topics_sql)) do |row|
      next unless mapping = @category_mappings[row['CategoryID']]

      {
        tag_id: mapping[:tag].id,
        topic_id: topic_id_from_imported_id(row["DiscussionID"])
      }
    end
  end

  def import_posts
    puts "", "Importing posts..."

    posts = mysql_stream(
      "SELECT CommentID, DiscussionID, Body, DateInserted, InsertUserID
         FROM #{TABLE_PREFIX}Comment
         WHERE CommentID > #{@last_imported_post_id}
         ORDER BY CommentID ASC")

    create_posts(posts) do |row|
      next unless topic_id = topic_id_from_imported_id(row['DiscussionID'])
      next if row['Body'].blank?

      {
        imported_id: row['CommentID'],
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row["InsertUserID"]),
        created_at: Time.zone.at(row['DateInserted']),
        raw: clean_up(row["Body"])
      }
    end
  end

  def import_tags
    puts "", "Importing tags..."

    tag_mapping = {}

    mysql_query("SELECT TagID, Name FROM #{TABLE_PREFIX}Tag").each do |row|
      tag_name = DiscourseTagging.clean_tag(row['Name'])
      tag = Tag.find_by_name(tag_name) || Tag.create(name: tag_name)
      tag_mapping[row['TagID']] = tag.id
    end

    tags = mysql_query(
      "SELECT TagID, DiscussionID
         FROM #{TABLE_PREFIX}TagDiscussion
        WHERE DiscussionID > #{@last_imported_topic_id}
    ORDER BY DateInserted")

    create_topic_tags(tags) do |row|
      next unless topic_id = topic_id_from_imported_id(row['DiscussionID'])

      {
        topic_id: topic_id,
        tag_id: tag_mapping[row['TagID']]
      }
    end
  end

  def import_private_topics
    puts "", "Importing private topics..."

    topics_sql = "SELECT c.ConversationID, c.Subject, m.MessageID, m.Body, c.DateInserted, c.InsertUserID
      FROM #{TABLE_PREFIX}Conversation c, #{TABLE_PREFIX}ConversationMessage m
      WHERE c.FirstMessageID = m.MessageID
        AND c.ConversationID > #{@last_imported_private_topic_id - PRIVATE_OFFSET}
      ORDER BY c.ConversationID ASC"

    create_topics(mysql_stream(topics_sql)) do |row|
      {
        archetype: Archetype.private_message,
        imported_id: row["ConversationID"] + PRIVATE_OFFSET,
        title: row["Subject"] ? normalize_text(row["Subject"]) : "Conversation #{row["ConversationID"]}",
        user_id: user_id_from_imported_id(row["InsertUserID"]),
        created_at: Time.zone.at(row['DateInserted'])
      }
    end
  end

  def import_topic_allowed_users
    puts "", "importing topic_allowed_users..."

    topic_allowed_users_sql = "
      SELECT ConversationID, UserID
        FROM #{TABLE_PREFIX}UserConversation
       WHERE Deleted = 0
         AND ConversationID > #{@last_imported_private_topic_id - PRIVATE_OFFSET}
    ORDER BY ConversationID ASC"

    added = 0

    create_topic_allowed_users(mysql_stream(topic_allowed_users_sql)) do |row|
      next unless topic_id = topic_id_from_imported_id(row['ConversationID'] + PRIVATE_OFFSET)
      next unless user_id = user_id_from_imported_id(row["UserID"])
      added += 1
      {
        topic_id: topic_id,
        user_id: user_id,
      }
    end

    puts '', "Added #{added} topic_allowed_users records."
  end

  def import_private_posts
    puts "", "importing private replies..."

    private_posts_sql = "
      SELECT ConversationID, MessageID, Body, InsertUserID, DateInserted
        FROM GDN_ConversationMessage
       WHERE ConversationID > #{@last_imported_private_topic_id - PRIVATE_OFFSET}
       ORDER BY ConversationID ASC, MessageID ASC"

    create_posts(mysql_stream(private_posts_sql)) do |row|
      next unless topic_id = topic_id_from_imported_id(row['ConversationID'] + PRIVATE_OFFSET)

      {
        imported_id: row['MessageID'] + PRIVATE_OFFSET,
        topic_id: topic_id,
        user_id: user_id_from_imported_id(row['InsertUserID']),
        created_at: Time.zone.at(row['DateInserted']),
        raw: clean_up(row['Body'])
      }
    end
  end

  # TODO: too slow
  def create_permalinks
    puts '', 'Creating permalinks...', ''

    puts '    User pages...'

    start = Time.now
    count = 0
    now = Time.zone.now

    sql = "COPY permalinks (url, created_at, updated_at, external_url) FROM STDIN"

    @raw_connection.copy_data(sql, @encoder) do
      User.includes(:_custom_fields).find_each do |u|
        count += 1
        ucf = u.custom_fields
        if ucf && ucf["import_id"]
          vanilla_username = ucf["import_username"] || u.username
          @raw_connection.put_copy_data(
            ["profile/#{vanilla_username}", now, now, "/users/#{u.username}"]
          )
        end

        print "\r%7d - %6d/sec".freeze % [count, count.to_f / (Time.now - start)] if count % 5000 == 0
      end
    end

    puts '', '', '    Topics and posts...'

    start = Time.now
    count = 0

    sql = "COPY permalinks (url, topic_id, post_id, created_at, updated_at) FROM STDIN"

    @raw_connection.copy_data(sql, @encoder) do
      Post.includes(:_custom_fields).find_each do |post|
        count += 1
        pcf = post.custom_fields
        if pcf && pcf["import_id"]
          topic = post.topic
          id = pcf["import_id"].split('-').last
          if post.post_number == 1
            slug = Slug.for(topic.title) # probably matches what vanilla would do...
            @raw_connection.put_copy_data(
              ["discussion/#{id}/#{slug}", topic.id, nil, now, now]
            )
          else
            @raw_connection.put_copy_data(
              ["discussion/comment/#{id}", nil, post.id, now, now]
            )
          end
        end

        print "\r%7d - %6d/sec".freeze % [count, count.to_f / (Time.now - start)] if count % 5000 == 0
      end
    end
  end

  def clean_up(raw)
    # post id is sometimes prefixed with "c-"
    raw.gsub!(/\[QUOTE="([^;]+);c-(\d+)"\]/i) { "[QUOTE=#{$1};#{$2}]" }

    raw
  end

  def staff_guardian
    @_staff_guardian ||= Guardian.new(Discourse.system_user)
  end

  def mysql_stream(sql)
    @client.query(sql, stream: true)
  end

  def mysql_query(sql)
    @client.query(sql)
  end

end

BulkImport::Vanilla.new.start
