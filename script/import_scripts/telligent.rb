require_relative 'base'
require 'tiny_tds'

# Import script for Telligent communities
#
# Users are currently imported from a temp table. This will need some
# work the next time this import script is used, because that table
# won't exist. Also, it's really hard to find all attachments, but
# the script tries to do it anyway.

class ImportScripts::Telligent < ImportScripts::Base
  BATCH_SIZE ||= 1000
  LOCAL_AVATAR_REGEX ||= /\A~\/.*(?<directory>communityserver-components-(?:selectable)?avatars)\/(?<path>[^\/]+)\/(?<filename>.+)/i
  REMOTE_AVATAR_REGEX ||= /\Ahttps?:\/\//i
  EMBEDDED_ATTACHMENT_REGEX ||= /<a href="\/cfs-file(?:\.ashx)?\/__key\/(?<directory>[^\/]+)\/(?<path>[^\/]+)\/(?<filename1>.+)">(?<filename2>.*?)<\/a>/i

  CATEGORY_LINK_NORMALIZATION = '/.*?(f\/\d+)$/\1'
  TOPIC_LINK_NORMALIZATION = '/.*?(f\/\d+\/t\/\d+)$/\1'

  def initialize
    super()

    @client = TinyTds::Client.new(
      host: ENV["DB_HOST"],
      username: ENV["DB_USERNAME"],
      password: ENV["DB_PASSWORD"],
      database: ENV["DB_NAME"]
    )
  end

  def execute
    add_permalink_normalizations
    import_users
    import_categories
    import_topics
    import_posts
    mark_topics_as_solved
  end

  def import_users
    puts "", "Importing users..."

    user_conditions = <<~SQL
      (
        EXISTS(SELECT 1
               FROM te_Forum_Threads t
               WHERE t.UserId = u.UserID) OR
        EXISTS(SELECT 1
               FROM te_Forum_ThreadReplies r
               WHERE r.UserId = u.UserID)
      )
    SQL

    last_user_id = -1
    total_count = count(<<~SQL)
      SELECT COUNT(1) AS count
      FROM temp_User u
      WHERE #{user_conditions}
    SQL

    batches do |offset|
      rows = query(<<~SQL)
        SELECT TOP #{BATCH_SIZE} *
        FROM
          (
            SELECT
              u.UserID,
              u.Email,
              u.UserName,
              u.CommonName,
              u.CreateDate,
              p.PropertyName,
              p.PropertyValue
            FROM temp_User u
              LEFT OUTER JOIN temp_UserProperties p ON (u.UserID = p.UserID)
            WHERE u.UserID > #{last_user_id} AND #{user_conditions}
          ) x
          PIVOT (
            MAX(PropertyValue)
            FOR PropertyName
            IN (avatarUrl, bio, Location, webAddress, BannedUntil, UserBanReason)
          ) y
        ORDER BY UserID
      SQL

      break if rows.blank?
      last_user_id = rows[-1]["UserID"]
      next if all_records_exist?(:users, rows.map { |row| row["UserID"] })

      create_users(rows, total: total_count, offset: offset) do |row|
        {
          id: row["UserID"],
          email: row["Email"],
          username: row["UserName"],
          name: row["CommonName"],
          created_at: row["CreateDate"],
          bio_raw: html_to_markdown(row["bio"]),
          location: row["Location"],
          website: row["webAddress"],
          post_create_action: proc do |user|
            import_avatar(user, row["avatarUrl"])
            suspend_user(user, row["BannedUntil"], row["UserBanReason"])
          end
        }
      end
    end
  end

  # TODO move into base importer (create_user) and use consistent error handling
  def import_avatar(user, avatar_url)
    return if avatar_url.blank? || avatar_url.include?("anonymous")

    if match_data = avatar_url.match(LOCAL_AVATAR_REGEX)
      avatar_path = File.join(ENV["FILE_BASE_DIR"],
                              match_data[:directory].gsub("-", "."),
                              match_data[:path].split("-"),
                              match_data[:filename])

      if File.exists?(avatar_path)
        @uploader.create_avatar(user, avatar_path)
      else
        STDERR.puts "Could not find avatar: #{avatar_path}"
      end
    elsif avatar_url.match?(REMOTE_AVATAR_REGEX)
      UserAvatar.import_url_for_user(avatar_url, user) rescue nil
    end
  end

  def suspend_user(user, banned_until, ban_reason)
    return if banned_until.blank?

    if banned_until = DateTime.parse(banned_until) > DateTime.now
      user.suspended_till = banned_until
      user.suspended_at = DateTime.now
      user.save!

      StaffActionLogger.new(Discourse.system_user).log_user_suspend(user, ban_reason)
    end
  end

  def import_categories
    @new_parent_categories = {}
    @new_parent_categories[:archives] = create_category({ name: "Archives" }, nil)
    @new_parent_categories[:spotlight] = create_category({ name: "Spotlight" }, nil)
    @new_parent_categories[:optimizer] = create_category({ name: "SQL Optimizer" }, nil)

    puts "", "Importing parent categories..."
    parent_categories = query(<<~SQL)
      SELECT
        GroupID,
        Name, HtmlDescription,
        DateCreated, SortOrder
      FROM cs_Groups g
      WHERE (SELECT COUNT(1)
             FROM te_Forum_Forums f
             WHERE f.GroupId = g.GroupID) > 1
      ORDER BY SortOrder, Name
    SQL

    create_categories(parent_categories) do |row|
      {
        id: "G#{row['GroupID']}",
        name: clean_category_name(row["Name"]),
        description: html_to_markdown(row["HtmlDescription"]),
        position: row["SortOrder"]
      }
    end

    puts "", "Importing child categories..."
    child_categories = query(<<~SQL)
      SELECT
        ForumId, GroupId,
        Name, Description,
        DateCreated, SortOrder
      FROM te_Forum_Forums
      ORDER BY GroupId, SortOrder, Name
    SQL

    create_categories(child_categories) do |row|
      parent_category_id = parent_category_id_for(row)

      if category_id = replace_with_category_id(row, child_categories, parent_category_id)
        add_category(row['ForumId'], Category.find_by_id(category_id))
        url = "f/#{row['ForumId']}"
        Permalink.create(url: url, category_id: category_id) unless Permalink.exists?(url: url)
        nil
      else
        {
          id: row['ForumId'],
          parent_category_id: parent_category_id,
          name: clean_category_name(row["Name"]),
          description: html_to_markdown(row["Description"]),
          position: row["SortOrder"]
        }
      end
    end
  end

  def parent_category_id_for(row)
    name = row["Name"].downcase

    if name.include?("beta")
      @new_parent_categories[:archives].id
    elsif name.include?("spotlight")
      @new_parent_categories[:spotlight].id
    elsif name.include?("optimizer")
      @new_parent_categories[:optimizer].id
    elsif row.key?("GroupId")
      category_id_from_imported_category_id("G#{row['GroupId']}")
    else
      nil
    end
  end

  def replace_with_category_id(row, child_categories, parent_category_id)
    name = row["Name"].downcase

    if name.include?("data modeler") || name.include?("benchmark")
      category_id_from_imported_category_id("G#{row['GroupId']}")
    elsif only_child?(child_categories, parent_category_id)
      parent_category_id
    end
  end

  def only_child?(child_categories, parent_category_id)
    count = 0

    child_categories.each do |row|
      count += 1 if parent_category_id_for(row) == parent_category_id
    end

    count == 1
  end

  def clean_category_name(name)
    CGI.unescapeHTML(name)
      .sub(/(?:\- )?Forum/i, "")
      .strip
  end

  def import_topics
    puts "", "Importing topics..."

    last_topic_id = -1
    total_count = count("SELECT COUNT(1) AS count FROM te_Forum_Threads")

    batches do |offset|
      rows = query(<<~SQL)
        SELECT TOP #{BATCH_SIZE}
          t.ThreadId, t.ForumId, t.UserId,
          t.Subject, t.Body, t.DateCreated, t.IsLocked, t.StickyDate,
          a.ApplicationTypeId, a.ApplicationId, a.ApplicationContentTypeId, a.ContentId, a.FileName
        FROM te_Forum_Threads t
          LEFT JOIN te_Attachments a
            ON (a.ApplicationId = t.ForumId AND a.ApplicationTypeId = 0 AND a.ContentId = t.ThreadId AND
                a.ApplicationContentTypeId = 0)
        WHERE t.ThreadId > #{last_topic_id}
        ORDER BY t.ThreadId
      SQL

      break if rows.blank?
      last_topic_id = rows[-1]["ThreadId"]
      next if all_records_exist?(:post, rows.map { |row| import_topic_id(row["ThreadId"]) })

      create_posts(rows, total: total_count, offset: offset) do |row|
        user_id = user_id_from_imported_user_id(row["UserId"]) || Discourse::SYSTEM_USER_ID

        post = {
          id: import_topic_id(row["ThreadId"]),
          title: CGI.unescapeHTML(row["Subject"]),
          raw: raw_with_attachment(row, user_id),
          category: category_id_from_imported_category_id(row["ForumId"]),
          user_id: user_id,
          created_at: row["DateCreated"],
          closed: row["IsLocked"],
          post_create_action: proc do |action_post|
            topic = action_post.topic
            Jobs.enqueue_at(topic.pinned_until, :unpin_topic, topic_id: topic.id) if topic.pinned_until
            url = "f/#{row['ForumId']}/t/#{row['ThreadId']}"
            Permalink.create(url: url, topic_id: topic.id) unless Permalink.exists?(url: url)
          end
        }

        if row["StickyDate"] > Time.now
          post[:pinned_until] = row["StickyDate"]
          post[:pinned_at] = row["DateCreated"]
        end

        post
      end
    end
  end

  def import_topic_id(topic_id)
    "T#{topic_id}"
  end

  def import_posts
    puts "", "Importing posts..."

    last_post_id = -1
    total_count = count("SELECT COUNT(1) AS count FROM te_Forum_ThreadReplies")

    batches do |offset|
      rows = query(<<~SQL)
        SELECT TOP #{BATCH_SIZE}
          tr.ThreadReplyId, tr.ThreadId, tr.UserId, tr.ParentReplyId,
          tr.Body, tr.ThreadReplyDate,
          CONVERT(BIT,
                  CASE WHEN tr.AnswerVerifiedUtcDate IS NOT NULL AND NOT EXISTS(
                      SELECT 1
                      FROM te_Forum_ThreadReplies x
                      WHERE
                        x.ThreadId = tr.ThreadId AND x.ThreadReplyId < tr.ThreadReplyId AND x.AnswerVerifiedUtcDate IS NOT NULL
                  )
                    THEN 1
                  ELSE 0 END) AS IsFirstVerifiedAnswer,
          a.ApplicationTypeId, a.ApplicationId, a.ApplicationContentTypeId, a.ContentId, a.FileName
        FROM te_Forum_ThreadReplies tr
          JOIN te_Forum_Threads t ON (tr.ThreadId = t.ThreadId)
          LEFT JOIN te_Attachments a
            ON (a.ApplicationId = t.ForumId AND a.ApplicationTypeId = 0 AND a.ContentId = tr.ThreadReplyId AND
                a.ApplicationContentTypeId = 1)
        WHERE tr.ThreadReplyId > #{last_post_id}
        ORDER BY tr.ThreadReplyId
      SQL

      break if rows.blank?
      last_post_id = rows[-1]["ThreadReplyId"]
      next if all_records_exist?(:post, rows.map { |row| row["ThreadReplyId"] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        imported_parent_id = row["ParentReplyId"] > 0 ? row["ParentReplyId"] : import_topic_id(row["ThreadId"])
        parent_post = topic_lookup_from_imported_post_id(imported_parent_id)
        user_id = user_id_from_imported_user_id(row["UserId"]) || Discourse::SYSTEM_USER_ID

        if parent_post
          post = {
            id: row["ThreadReplyId"],
            raw: raw_with_attachment(row, user_id),
            user_id: user_id,
            topic_id: parent_post[:topic_id],
            created_at: row["ThreadReplyDate"],
            reply_to_post_number: parent_post[:post_number]
          }

          post[:custom_fields] = { is_accepted_answer: "true" } if row["IsFirstVerifiedAnswer"]
          post
        else
          puts "Failed to import post #{row['ThreadReplyId']}. Parent was not found."
        end
      end
    end
  end

  def raw_with_attachment(row, user_id)
    raw, embedded_paths, upload_ids = replace_embedded_attachments(row["Body"], user_id)
    raw = html_to_markdown(raw) || ""

    filename = row["FileName"]
    return raw if filename.blank?

    path = File.join(
      ENV["FILE_BASE_DIR"],
      "telligent.evolution.components.attachments",
      "%02d" % row["ApplicationTypeId"],
      "%02d" % row["ApplicationId"],
      "%02d" % row["ApplicationContentTypeId"],
      ("%010d" % row["ContentId"]).scan(/.{2}/),
      clean_filename(filename)
    )

    unless embedded_paths.include?(path)
      if File.exists?(path)
        upload = @uploader.create_upload(user_id, path, filename)

        if upload.present? && upload.persisted? && !upload_ids.include?(upload.id)
          raw << "\n" << @uploader.html_for_upload(upload, filename)
        end
      else
        STDERR.puts "Could not find file: #{path}"
      end
    end

    raw
  end

  def replace_embedded_attachments(raw, user_id)
    paths = []
    upload_ids = []

    raw = raw.gsub(EMBEDDED_ATTACHMENT_REGEX) do
      filename, path = attachment_path(Regexp.last_match)

      if File.exists?(path)
        upload = @uploader.create_upload(user_id, path, filename)

        if upload.present? && upload.persisted?
          paths << path
          upload_ids << upload.id
          @uploader.html_for_upload(upload, filename)
        end
      else
        STDERR.puts "Could not find file: #{path}"
      end
    end

    [raw, paths, upload_ids]
  end

  def clean_filename(filename)
    CGI.unescapeHTML(filename)
      .gsub(/[\x00\/\\:\*\?\"<>\|]/, '_')
      .gsub(/_(?:2B00|2E00|2D00|5B00|5D00|5F00)/, '')
  end

  def attachment_path(match_data)
    filename, path = join_attachment_path(match_data, filename_index: 2)
    filename, path = join_attachment_path(match_data, filename_index: 1) unless File.exists?(path)
    [filename, path]
  end

  # filenames are a total mess - try to guess the correct filename
  # works for 70% of all files
  def join_attachment_path(match_data, filename_index:)
    filename = clean_filename(match_data[:"filename#{filename_index}"])
    base_path = File.join(
      ENV["FILE_BASE_DIR"],
      match_data[:directory].gsub("-", "."),
      match_data[:path].split("-")
    )

    path = File.join(base_path, filename)
    return [filename, path] if File.exists?(path)

    original_filename = filename.dup

    filename = filename.gsub("-", " ")
    path = File.join(base_path, filename)
    return [filename, path] if File.exists?(path)

    filename = filename.gsub("_", "-")
    path = File.join(base_path, filename)
    return [filename, path] if File.exists?(path)

    [original_filename, File.join(base_path, original_filename)]
  end

  def mark_topics_as_solved
    puts "", "Marking topics as solved..."

    DB.exec <<~SQL
      INSERT INTO topic_custom_fields (name, value, topic_id, created_at, updated_at)
      SELECT 'accepted_answer_post_id', pcf.post_id, p.topic_id, p.created_at, p.created_at
        FROM post_custom_fields pcf
        JOIN posts p ON p.id = pcf.post_id
       WHERE pcf.name = 'is_accepted_answer' AND pcf.value = 'true'
    SQL
  end

  def html_to_markdown(html)
    HtmlToMarkdown.new(html).to_markdown if html.present?
  end

  def add_permalink_normalizations
    normalizations = SiteSetting.permalink_normalizations
    normalizations = normalizations.blank? ? [] : normalizations.split('|')

    add_normalization(normalizations, CATEGORY_LINK_NORMALIZATION)
    add_normalization(normalizations, TOPIC_LINK_NORMALIZATION)

    SiteSetting.permalink_normalizations = normalizations.join('|')
  end

  def add_normalization(normalizations, normalization)
    normalizations << normalization unless normalizations.include?(normalization)
  end

  def batches
    super(BATCH_SIZE)
  end

  def query(sql)
    @client.execute(sql).to_a
  end

  def count(sql)
    query(sql).first["count"]
  end
end

ImportScripts::Telligent.new.perform
