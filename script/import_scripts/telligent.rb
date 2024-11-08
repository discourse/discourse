# frozen_string_literal: true

require_relative "base"
require "tiny_tds"

# Import script for Telligent communities
#
# It's really hard to find all attachments, but the script tries to do it anyway.
#
# You can supply a JSON file if you need to map and ignore categories during the import
# by providing the path to the file in the `CATEGORY_MAPPING` environment variable.
# You can also add tags to remapped categories and remap multiple old forums into one
# category. Here's an example of such a `mapping.json` file:
#
# {
#   "ignored_forum_ids": [41, 360, 378],
#
#   "mapping": [
#     {
#       "category": ["New Category 1"],
#       "forums": [
#         { "id": 348, "tag": "some_tag" },
#         { "id": 347, "tag": "another_tag" }
#       ]
#     },
#     {
#       "category": ["New Category 2"],
#       "forums": [
#         { "id": 9 }
#       ]
#     },
#     {
#       "category": ["Nested", "Category"],
#       "forums": [
#         { "id": 322 }
#       ]
#     }
#   ]
# }

class ImportScripts::Telligent < ImportScripts::Base
  BATCH_SIZE = 1000
  LOCAL_AVATAR_REGEX =
    %r{\A~/.*(?<directory>communityserver-components-(?:selectable)?avatars)/(?<path>[^/]+)/(?<filename>.+)}i
  REMOTE_AVATAR_REGEX = %r{\Ahttps?://}i
  ATTACHMENT_REGEXES = [
    %r{<a[^>]*\shref="[^"]*?/cfs-file(?:systemfile)?(?:\.ashx)?/__key/(?<directory>[^/]+)/(?<path>[^/]+)/(?<filename>.+?)".*?>.*?</a>}i,
    %r{<img[^>]*\ssrc="[^"]*?/cfs-file(?:systemfile)?(?:\.ashx)?/__key/(?<directory>[^/]+)/(?<path>[^/]+)/(?<filename>.+?)".*?>}i,
    %r{\[View:[^\]]*?/cfs-file(?:systemfile)?(?:\.ashx)?/__key/(?<directory>[^/]+)/(?<path>[^/]+)/(?<filename>.+?)(?:\:[:\d\s]*?)?\]}i,
    %r{\[(?<tag>img|url)\][^\[]*?cfs-file(?:systemfile)?(?:\.ashx)?/__key/(?<directory>[^/]+)/(?<path>[^/]+)/(?<filename>.+?)\[/\k<tag>\]}i,
    %r{\[(?<tag>img|url)=[^\[]*?cfs-file(?:systemfile)?(?:\.ashx)?/__key/(?<directory>[^/]+)/(?<path>[^/]+)/(?<filename>.+?)\][^\[]*?\[/\k<tag>\]}i,
  ].freeze
  PROPERTY_NAMES_REGEX = /(?<name>\w+):S:(?<start>\d+):(?<length>\d+):/
  INTERNAL_LINK_REGEX =
    %r{\shref=".*?/f/\d+(?:(/t/(?<topic_id>\d+))|(?:/p/\d+/(?<post_id>\d+))|(?:/p/(?<post_id>\d+)/reply))\.aspx[^"]*?"}i

  CATEGORY_LINK_NORMALIZATION = '/.*?(f\/\d+)$/\1'
  TOPIC_LINK_NORMALIZATION = '/.*?(f\/\d+\/t\/\d+)$/\1'

  UNICODE_REPLACEMENTS = {
    "5F00" => "_",
    "2800" => "(",
    "2900" => ")",
    "2D00" => "-",
    "2C00" => ",",
    "2700" => "'",
    "5B00" => "[",
    "5D00" => "]",
    "3D00" => "=",
    "2600" => "&",
    "2100" => "!",
    "2300" => "#",
    "7E00" => "~",
    "2500" => "%",
    "2E00" => ".",
    "4000" => "@",
    "2B00" => "+",
    "2400" => "$",
    "1920" => "’",
    "E900" => "é",
    "E000" => "à",
    "F300" => "ó",
    "1C20" => "“",
    "1D20" => "”",
    "B000" => "°",
    "0003" => ["0300".to_i(16)].pack("U"),
    "0103" => ["0301".to_i(16)].pack("U"),
  }.freeze

  def initialize
    super()

    @client =
      TinyTds::Client.new(
        host: ENV["DB_HOST"],
        username: ENV["DB_USERNAME"],
        password: ENV["DB_PASSWORD"],
        database: ENV["DB_NAME"],
        timeout: 60, # the user query is very slow
      )

    @filestore_root_directory = ENV["FILE_BASE_DIR"]
    @files = {}

    SiteSetting.tagging_enabled = true
  end

  def execute
    add_permalink_normalizations
    index_filestore

    import_categories
    import_users
    import_topics
    import_posts
    import_messages
    mark_topics_as_solved
  end

  def index_filestore
    puts "", "Indexing filestore..."
    index_directory(@filestore_root_directory)
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
               WHERE r.UserId = u.UserID) OR
        EXISTS(SELECT 1
               FROM cs_Messaging_ConversationParticipants p
                 JOIN cs_Messaging_ConversationMessages cm ON p.ConversationId = cm.ConversationId
                 JOIN cs_Messaging_Messages m ON m.MessageId = cm.MessageId
               WHERE p.ParticipantId = u.UserID)
      )
    SQL

    last_user_id = -1
    total_count = count(<<~SQL)
      SELECT COUNT(1) AS count
      FROM cs_Users u
      WHERE #{user_conditions}
    SQL
    import_count = 0

    loop do
      rows = query(<<~SQL)
        SELECT TOP #{BATCH_SIZE}
            u.UserID, u.Email, u.UserName, u.CreateDate,
            ap.PropertyNames AP_PropertyNames, ap.PropertyValuesString AS AP_PropertyValues,
            up.PropertyNames UP_PropertyNames, up.PropertyValues AS UP_PropertyValues
        FROM cs_Users u
            LEFT OUTER JOIN aspnet_Profile ap ON ap.UserId = u.MembershipID
            LEFT OUTER JOIN cs_UserProfile up ON up.UserID = u.UserID
        WHERE u.UserID > #{last_user_id} AND #{user_conditions}
        ORDER BY UserID
      SQL

      break if rows.blank?
      last_user_id = rows[-1]["UserID"]

      if all_records_exist?(:users, rows.map { |row| row["UserID"] })
        import_count += rows.size
        next
      end

      create_users(rows, total: total_count, offset: import_count) do |row|
        ap_properties = parse_properties(row["AP_PropertyNames"], row["AP_PropertyValues"])
        up_properties = parse_properties(row["UP_PropertyNames"], row["UP_PropertyValues"])

        {
          id: row["UserID"],
          email: row["Email"],
          username: row["UserName"],
          name: ap_properties["commonName"],
          created_at: row["CreateDate"],
          bio_raw: html_to_markdown(ap_properties["bio"]),
          location: ap_properties["location"],
          website: ap_properties["webAddress"],
          post_create_action:
            proc do |user|
              import_avatar(user, up_properties["avatarUrl"])
              suspend_user(user, up_properties["BannedUntil"], up_properties["UserBanReason"])
            end,
        }
      end

      import_count += rows.size
    end
  end

  # TODO move into base importer (create_user) and use consistent error handling
  def import_avatar(user, avatar_url)
    if @filestore_root_directory.blank? || avatar_url.blank? || avatar_url.include?("anonymous")
      return
    end

    if match_data = avatar_url.match(LOCAL_AVATAR_REGEX)
      avatar_path =
        File.join(
          @filestore_root_directory,
          match_data[:directory].gsub("-", "."),
          match_data[:path].split("-"),
          match_data[:filename],
        )

      if File.file?(avatar_path)
        @uploader.create_avatar(user, avatar_path)
      else
        STDERR.puts "Could not find avatar: #{avatar_path}"
      end
    elsif avatar_url.match?(REMOTE_AVATAR_REGEX)
      begin
        UserAvatar.import_url_for_user(avatar_url, user)
      rescue StandardError
        nil
      end
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
    if ENV["CATEGORY_MAPPING"]
      import_mapped_forums_as_categories
    else
      import_groups_and_forums_as_categories
    end
  end

  def import_mapped_forums_as_categories
    puts "", "Importing categories..."

    json = JSON.parse(File.read(ENV["CATEGORY_MAPPING"]))

    categories = []
    @forum_ids_to_tags = {}
    @ignored_forum_ids = json["ignored_forum_ids"]

    json["mapping"].each do |m|
      parent_id = nil
      last_index = m["category"].size - 1
      forum_ids = []

      m["forums"].each do |f|
        forum_ids << f["id"]
        @forum_ids_to_tags[f["id"]] = f["tag"] if f["tag"].present?
      end

      m["category"].each_with_index do |name, index|
        id = Digest::MD5.hexdigest(name)
        categories << {
          id: id,
          name: name,
          parent_id: parent_id,
          forum_ids: index == last_index ? forum_ids : nil,
        }
        parent_id = id
      end
    end

    create_categories(categories) do |c|
      if category_id = category_id_from_imported_category_id(c[:id])
        map_forum_ids(category_id, c[:forum_ids])
        nil
      else
        {
          id: c[:id],
          name: c[:name],
          parent_category_id: category_id_from_imported_category_id(c[:parent_id]),
          post_create_action: proc { |category| map_forum_ids(category.id, c[:forum_ids]) },
        }
      end
    end
  end

  def map_forum_ids(category_id, forum_ids)
    return if forum_ids.blank?

    forum_ids.each do |id|
      url = "f/#{id}"
      Permalink.create(url: url, category_id: category_id) unless Permalink.exists?(url: url)
      add_category(id, Category.find_by_id(category_id))
    end
  end

  def import_groups_and_forums_as_categories
    puts "", "Importing parent categories..."
    parent_categories = query(<<~SQL)
      SELECT GroupID, Name, HtmlDescription, DateCreated, SortOrder
      FROM cs_Groups g
      WHERE (SELECT COUNT(1)
             FROM te_Forum_Forums f
             WHERE f.GroupId = g.GroupID) > 1
      ORDER BY SortOrder, Name
    SQL

    create_categories(parent_categories) do |row|
      {
        id: "G#{row["GroupID"]}",
        name: clean_category_name(row["Name"]),
        description: html_to_markdown(row["HtmlDescription"]),
        position: row["SortOrder"],
      }
    end

    puts "", "Importing child categories..."
    child_categories = query(<<~SQL)
      SELECT ForumId, GroupId, Name, Description, DateCreated, SortOrder
      FROM te_Forum_Forums
      ORDER BY GroupId, SortOrder, Name
    SQL

    create_categories(child_categories) do |row|
      parent_category_id = parent_category_id_for(row)

      if category_id = replace_with_category_id(child_categories, parent_category_id)
        add_category(row["ForumId"], Category.find_by_id(category_id))
        url = "f/#{row["ForumId"]}"
        Permalink.create(url: url, category_id: category_id) unless Permalink.exists?(url: url)
        nil
      else
        {
          id: row["ForumId"],
          parent_category_id: parent_category_id,
          name: clean_category_name(row["Name"]),
          description: html_to_markdown(row["Description"]),
          position: row["SortOrder"],
          post_create_action:
            proc do |category|
              url = "f/#{row["ForumId"]}"
              unless Permalink.exists?(url: url)
                Permalink.create(url: url, category_id: category.id)
              end
            end,
        }
      end
    end
  end

  def parent_category_id_for(row)
    category_id_from_imported_category_id("G#{row["GroupId"]}") if row.key?("GroupId")
  end

  def replace_with_category_id(child_categories, parent_category_id)
    parent_category_id if only_child?(child_categories, parent_category_id)
  end

  def only_child?(child_categories, parent_category_id)
    count = 0

    child_categories.each { |row| count += 1 if parent_category_id_for(row) == parent_category_id }

    count == 1
  end

  def clean_category_name(name)
    CGI.unescapeHTML(name).strip
  end

  def import_topics
    puts "", "Importing topics..."

    last_topic_id = -1
    total_count =
      count("SELECT COUNT(1) AS count FROM te_Forum_Threads t WHERE #{ignored_forum_sql_condition}")

    batches do |offset|
      rows = query(<<~SQL)
        SELECT TOP #{BATCH_SIZE}
          t.ThreadId, t.ForumId, t.UserId, t.TotalViews, t.ContentID AS TopicContentId,
          t.Subject, t.Body, t.DateCreated, t.IsLocked, t.StickyDate,
          a.ApplicationTypeId, a.ApplicationId, a.ApplicationContentTypeId, a.ContentId, a.FileName, a.IsRemote
        FROM te_Forum_Threads t
          LEFT JOIN te_Attachments a
            ON (a.ApplicationId = t.ForumId AND a.ApplicationTypeId = 0 AND a.ContentId = t.ThreadId AND
                a.ApplicationContentTypeId = 0)
        WHERE t.ThreadId > #{last_topic_id} AND #{ignored_forum_sql_condition}
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
          raw: raw_with_attachment(row, user_id, :topic),
          category: category_id_from_imported_category_id(row["ForumId"]),
          user_id: user_id,
          created_at: row["DateCreated"],
          closed: row["IsLocked"],
          views: row["TotalViews"],
          post_create_action:
            proc do |action_post|
              topic = action_post.topic
              if topic.pinned_until
                Jobs.enqueue_at(topic.pinned_until, :unpin_topic, topic_id: topic.id)
              end
              url = "f/#{row["ForumId"]}/t/#{row["ThreadId"]}"
              Permalink.create(url: url, topic_id: topic.id) unless Permalink.exists?(url: url)
              import_topic_views(topic, row["TopicContentId"])
            end,
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

  def import_topic_views(topic, content_id)
    last_user_id = -1

    batches do |_|
      rows = query(<<~SQL)
        SELECT TOP #{BATCH_SIZE}
          UserId, MAX(CreatedUtcDate) AS ViewDate
        FROM te_Content_Views
        WHERE ContentId = '#{content_id}' AND UserId > #{last_user_id}
        GROUP BY UserId
        ORDER BY UserId
      SQL

      break if rows.blank?
      last_user_id = rows[-1]["UserId"]

      rows.each do |row|
        user_id = user_id_from_imported_user_id(row["UserId"])
        TopicViewItem.add(topic.id, "127.0.0.1", user_id, row["ViewDate"], true) if user_id
      end
    end
  end

  def ignored_forum_sql_condition
    @ignored_forum_sql_condition ||=
      @ignored_forum_ids.present? ? "t.ForumId NOT IN (#{@ignored_forum_ids.join(",")})" : "1 = 1"
  end

  def import_posts
    puts "", "Importing posts..."

    last_post_id = -1
    total_count = count(<<~SQL)
      SELECT COUNT(1) AS count
      FROM te_Forum_ThreadReplies tr
        JOIN te_Forum_Threads t ON (tr.ThreadId = t.ThreadId)
      WHERE #{ignored_forum_sql_condition}
    SQL

    batches do |offset|
      rows = query(<<~SQL)
        SELECT TOP #{BATCH_SIZE}
          tr.ThreadReplyId, tr.ThreadId, tr.UserId, pr.ThreadReplyId AS ParentReplyId,
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
          a.ApplicationTypeId, a.ApplicationId, a.ApplicationContentTypeId, a.ContentId, a.FileName, a.IsRemote
        FROM te_Forum_ThreadReplies tr
          JOIN te_Forum_Threads t ON (tr.ThreadId = t.ThreadId)
          LEFT JOIN te_Forum_ThreadReplies pr ON (tr.ParentReplyId = pr.ThreadReplyId AND tr.ParentReplyId < tr.ThreadReplyId AND tr.ThreadId = pr.ThreadId)
          LEFT JOIN te_Attachments a
            ON (a.ApplicationId = t.ForumId AND a.ApplicationTypeId = 0 AND a.ContentId = tr.ThreadReplyId AND
                a.ApplicationContentTypeId = 1)
        WHERE tr.ThreadReplyId > #{last_post_id} AND #{ignored_forum_sql_condition}
        ORDER BY tr.ThreadReplyId
      SQL

      break if rows.blank?
      last_post_id = rows[-1]["ThreadReplyId"]
      next if all_records_exist?(:post, rows.map { |row| row["ThreadReplyId"] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        imported_parent_id =
          row["ParentReplyId"]&.nonzero? ? row["ParentReplyId"] : import_topic_id(row["ThreadId"])
        parent_post = topic_lookup_from_imported_post_id(imported_parent_id)
        user_id = user_id_from_imported_user_id(row["UserId"]) || Discourse::SYSTEM_USER_ID

        if parent_post
          post = {
            id: row["ThreadReplyId"],
            raw: raw_with_attachment(row, user_id, :post),
            user_id: user_id,
            topic_id: parent_post[:topic_id],
            created_at: row["ThreadReplyDate"],
            reply_to_post_number: parent_post[:post_number],
          }

          post[:custom_fields] = { is_accepted_answer: "true" } if row["IsFirstVerifiedAnswer"]
          post
        else
          puts "Failed to import post #{row["ThreadReplyId"]}. Parent was not found."
        end
      end
    end
  end

  def import_messages
    puts "", "Importing messages..."

    current_conversation_id = ""
    current_topic_import_id = ""

    last_conversation_id = ""

    total_count = count(<<~SQL)
      SELECT COUNT(1) AS count
      FROM cs_Messaging_Messages m
        JOIN cs_Messaging_ConversationMessages cm ON m.MessageId = cm.MessageId
    SQL

    batches do |offset|
      if last_conversation_id.blank?
        conditions = ""
      else
        conditions = <<~SQL
          WHERE cm.ConversationId > '#{last_conversation_id}'
        SQL
      end

      rows = query(<<~SQL)
        SELECT TOP #{BATCH_SIZE}
          cm.ConversationId, m.MessageId, m.AuthorId, m.Subject, m.Body, m.DateCreated,
          STUFF((SELECT ';' + CONVERT(VARCHAR, p.ParticipantId)
                 FROM cs_Messaging_ConversationParticipants p
                 WHERE p.ConversationId = cm.ConversationId
                 ORDER BY p.ParticipantId
                 FOR XML PATH('')), 1, 1, '') AS ParticipantIds
        FROM cs_Messaging_Messages m
          JOIN cs_Messaging_ConversationMessages cm ON m.MessageId = cm.MessageId
        #{conditions}
        ORDER BY cm.ConversationId, m.DateCreated, m.MessageId
      SQL

      break if rows.blank?

      last_row = rows[-1]
      last_conversation_id = last_row["ConversationId"]
      next if all_records_exist?(:post, rows.map { |row| row["MessageId"] })

      create_posts(rows, total: total_count, offset: offset) do |row|
        user_id = user_id_from_imported_user_id(row["AuthorId"]) || Discourse::SYSTEM_USER_ID

        post = {
          id: row["MessageId"],
          raw: raw_with_attachment(row, user_id, :message),
          user_id: user_id,
          created_at: row["DateCreated"],
        }

        if current_conversation_id == row["ConversationId"]
          parent_post = topic_lookup_from_imported_post_id(current_topic_import_id)

          if parent_post
            post[:topic_id] = parent_post[:topic_id]
          else
            puts "Failed to import message #{row["MessageId"]}. Parent was not found."
            post = nil
          end
        else
          post[:title] = CGI.unescapeHTML(row["Subject"])
          post[:archetype] = Archetype.private_message
          post[:target_usernames] = get_recipient_usernames(row)

          if post[:target_usernames].empty?
            puts "Private message without recipients. Skipping #{row["MessageId"]}"
            post = nil
          end

          current_topic_import_id = row["MessageId"]
        end

        current_conversation_id = row["ConversationId"]
        post
      end
    end

    # Mark all imported messages as read
    DB.exec(<<~SQL)
      UPDATE topic_users tu
      SET last_read_post_number = t.highest_post_number
      FROM topics t
        JOIN topic_custom_fields tcf ON t.id = tcf.topic_id
      WHERE tu.topic_id = t.id
        AND tu.user_id > 0
        AND t.archetype = 'private_message'
        AND tcf.name = 'import_id'
    SQL
  end

  def get_recipient_user_ids(participant_ids)
    return [] if participant_ids.blank?

    user_ids = participant_ids.split(";")
    user_ids.uniq!
    user_ids.map!(&:strip)
  end

  def get_recipient_usernames(row)
    import_user_ids = get_recipient_user_ids(row["ParticipantIds"])

    import_user_ids
      .map! { |import_user_id| find_user_by_import_id(import_user_id).try(:username) }
      .compact
  end

  def index_directory(root_directory)
    Dir.foreach(root_directory) do |directory_name|
      next if directory_name == "." || directory_name == ".."

      path = File.join(root_directory, directory_name)
      if File.directory?(path)
        index_directory(path)
      else
        path.delete_prefix!(@filestore_root_directory)
        path.delete_prefix!("/")
        @files[path.downcase] = path
      end
    end
  end

  def raw_with_attachment(row, user_id, type)
    raw, embedded_paths, upload_ids = replace_embedded_attachments(row, user_id, type)
    raw = html_to_markdown(raw) || ""

    filename = row["FileName"]
    return raw if @filestore_root_directory.blank? || filename.blank?

    return "#{raw}\n#{filename}" if row["IsRemote"]

    path =
      File.join(
        "telligent.evolution.components.attachments",
        "%02d" % row["ApplicationTypeId"],
        "%02d" % row["ApplicationId"],
        "%02d" % row["ApplicationContentTypeId"],
        ("%010d" % row["ContentId"]).scan(/.{2}/),
      )
    path = fix_attachment_path(path, filename)

    if path && !embedded_paths.include?(path)
      if File.file?(path)
        upload = @uploader.create_upload(user_id, path, filename)

        if upload.present? && upload.persisted? && !upload_ids.include?(upload.id)
          raw = "#{raw}\n#{@uploader.html_for_upload(upload, filename)}"
        end
      else
        print_file_not_found_error(type, path, row)
      end
    end

    raw
  end

  def print_file_not_found_error(type, path, row)
    case type
    when :topic
      id = row["ThreadId"]
    when :post
      id = row["ThreadReplyId"]
    when :message
      id = row["MessageId"]
    end

    STDERR.puts "Could not find file for #{type} #{id}: #{path}"
  end

  def replace_embedded_attachments(row, user_id, type)
    raw = row["Body"]
    paths = []
    upload_ids = []

    return raw, paths, upload_ids if @filestore_root_directory.blank?

    ATTACHMENT_REGEXES.each do |regex|
      raw =
        raw.gsub(regex) do
          match_data = Regexp.last_match

          path = File.join(match_data[:directory], match_data[:path])
          fixed_path = fix_attachment_path(path, match_data[:filename])

          if fixed_path && File.file?(fixed_path)
            filename = File.basename(fixed_path)
            upload = @uploader.create_upload(user_id, fixed_path, filename)

            if upload.present? && upload.persisted?
              paths << fixed_path
              upload_ids << upload.id
              @uploader.html_for_upload(upload, filename)
            end
          else
            path = File.join(path, match_data[:filename])
            print_file_not_found_error(type, path, row)
            match_data[0]
          end
        end
    end

    [raw, paths, upload_ids]
  end

  def fix_attachment_path(base_path, filename)
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    base_path.downcase!
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    filename = CGI.unescapeHTML(filename)
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    filename.gsub!("-", " ")
    filename.strip!
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    directories = base_path.split(File::SEPARATOR)
    first_directory = directories.shift
    first_directory.gsub!("-", ".")
    base_path = File.join(first_directory, directories)
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    directories.map! { |d| File.join(d.split(/[\.\-]/).map(&:strip)) }
    base_path = File.join(first_directory, directories)
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    directories = base_path.split(File::SEPARATOR)
    directories.map! { |d| d.gsub("+", " ").strip }
    base_path = File.join(directories)
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    replace_codes!(filename)
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    replace_codes!(base_path)
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    filename.gsub!(/(?:\:\d+)+$/, "")
    path = find_correct_path(base_path, filename)
    return path if attachment_exists?(path)

    path = File.join(base_path, filename)
    path_regex = Regexp.new("^#{Regexp.escape(path)}-\\d+x\\d+\\.\\w+$", Regexp::IGNORECASE)
    path = find_correct_path_with_regex(path_regex)
    return path if attachment_exists?(path)

    nil
  end

  def find_correct_path(base_path, filename)
    path = File.join(base_path, filename)
    path = @files[path.downcase]
    path ? File.join(@filestore_root_directory, path) : nil
  end

  def find_correct_path_with_regex(regex)
    keys = @files.keys.filter { |key| regex =~ key }
    keys.size == 1 ? File.join(@filestore_root_directory, @files[keys.first]) : nil
  end

  def attachment_exists?(path)
    path.present? && File.file?(path)
  end

  def replace_codes!(text)
    text.gsub!(/_(\h{4}+)_/i) do
      codes = Regexp.last_match[1].upcase.scan(/.{4}/)
      mapped_codes = codes.map { |c| UNICODE_REPLACEMENTS[c] }
      mapped_codes.any? { |c| c.nil? } ? Regexp.last_match[0] : mapped_codes.join("")
    end
  end

  def html_to_markdown(html)
    return html if html.blank?

    html = fix_internal_links(html)

    md = HtmlToMarkdown.new(html).to_markdown
    md.gsub!(/\[quote.*?\]/, "\n" + '\0' + "\n")
    md.gsub!(%r{(?<!^)\[/quote\]}, "\n[/quote]\n")
    md.gsub!(%r{\[/quote\](?!$)}, "\n[/quote]\n")
    md.gsub!(/\[View:(http.*?)[:\d\s]*?(?:\]|\z)/i, '\1')
    md.strip!
    md
  end

  def fix_internal_links(html)
    html.gsub(INTERNAL_LINK_REGEX) do
      match_data = Regexp.last_match

      if match_data[:topic_id].present?
        imported_id = import_topic_id(match_data[:topic_id])
      else
        imported_id = match_data[:post_id]
      end

      post = topic_lookup_from_imported_post_id(imported_id) if imported_id
      post ? %Q| href="#{Discourse.base_url}#{post[:url]}"| : match_data[0]
    end
  end

  def parse_properties(names, values)
    properties = {}
    return properties if names.blank? || values.blank?

    names
      .scan(PROPERTY_NAMES_REGEX)
      .each do |property|
        name = property[0]
        start_index = property[1].to_i
        end_index = start_index + property[2].to_i - 1

        properties[name] = values[start_index..end_index]
      end

    properties
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

  def add_permalink_normalizations
    normalizations = SiteSetting.permalink_normalizations
    normalizations = normalizations.blank? ? [] : normalizations.split("|")

    add_normalization(normalizations, CATEGORY_LINK_NORMALIZATION)
    add_normalization(normalizations, TOPIC_LINK_NORMALIZATION)

    SiteSetting.permalink_normalizations = normalizations.join("|")
  end

  def add_normalization(normalizations, normalization)
    normalizations << normalization if normalizations.exclude?(normalization)
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
