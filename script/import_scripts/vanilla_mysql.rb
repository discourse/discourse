# frozen_string_literal: true

require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'htmlentities'
require_relative 'vanilla_body_parser'

class ImportScripts::VanillaSQL < ImportScripts::Base

  VANILLA_DB = "vanilla_mysql"
  TABLE_PREFIX = "GDN_"
  ATTACHMENTS_BASE_DIR = nil # "/absolute/path/to/attachments" set the absolute path if you have attachments
  BATCH_SIZE = 1000
  CONVERT_HTML = true

  def initialize
    super
    @htmlentities = HTMLEntities.new
    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      password: "pa$$word",
      database: VANILLA_DB
    )

    VanillaBodyParser.configure(
      lookup: @lookup,
      uploader: @uploader,
      host: 'vanilla.yourforum.com', # your Vanilla forum domain
      uploads_path: 'uploads' # relative path to your vanilla uploads folder
    )

    @import_tags = false
    begin
      r = @client.query("select count(*) count from #{TABLE_PREFIX}Tag where countdiscussions > 0")
      @import_tags = true if r.first["count"].to_i > 0
    rescue => e
      puts "Tags won't be imported. #{e.message}"
    end
  end

  def execute
    if @import_tags
      SiteSetting.tagging_enabled = true
      SiteSetting.max_tags_per_topic = 10
    end

    import_users
    import_avatars
    import_categories
    import_topics
    import_posts
    import_messages

    update_tl0

    create_permalinks
  end

  def import_users
    puts '', "creating users"

    @user_is_deleted = false
    @last_deleted_username = nil
    username = nil
    @last_user_id = -1
    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}User;").first['count']

    batches(BATCH_SIZE) do |offset|
      results = mysql_query(
        "SELECT UserID, Name, Title, Location, About, Email, Admin, Banned, CountComments,
                DateInserted, DateLastActive, InsertIPAddress
         FROM #{TABLE_PREFIX}User
         WHERE UserID > #{@last_user_id}
         ORDER BY UserID ASC
         LIMIT #{BATCH_SIZE};")

      break if results.size < 1
      @last_user_id = results.to_a.last['UserID']
      next if all_records_exist? :users, results.map { |u| u['UserID'].to_i }

      create_users(results, total: total_count, offset: offset) do |user|
        email = user['Email'].squish

        next if email.blank?
        next if user['Name'].blank?
        next if @lookup.user_id_from_imported_user_id(user['UserID'])
        if user['Name'] == '[Deleted User]'
          # EVERY deleted user record in Vanilla has the same username: [Deleted User]
          # Save our UserNameSuggester some pain:
          @user_is_deleted = true
          username = @last_deleted_username || user['Name']
        else
          @user_is_deleted = false
          username = user['Name']
        end

        banned = user['Banned'] != 0
        commented = (user['CountComments'] || 0) > 0

        { id: user['UserID'],
          email: email,
          username: username,
          name: user['Name'],
          created_at: user['DateInserted'] == nil ? 0 : Time.zone.at(user['DateInserted']),
          bio_raw: user['About'],
          registration_ip_address: user['InsertIPAddress'],
          last_seen_at: user['DateLastActive'] == nil ? 0 : Time.zone.at(user['DateLastActive']),
          location: user['Location'],
          admin: user['Admin'] == 1,
          trust_level: !banned && commented ? 2 : 0,
          post_create_action: proc do |newuser|
            if @user_is_deleted
              @last_deleted_username = newuser.username
            end
            if banned
              newuser.suspended_at = Time.now
              # banning on Vanilla doesn't have an end, so a thousand years seems equivalent
              newuser.suspended_till = 1000.years.from_now
              if newuser.save
                StaffActionLogger.new(Discourse.system_user).log_user_suspend(newuser, 'Imported from Vanilla Forum')
              else
                puts "Failed to suspend user #{newuser.username}. #{newuser.errors.full_messages.join(', ')}"
              end
            end
          end }
      end
    end
  end

  def import_avatars
    if ATTACHMENTS_BASE_DIR && File.exists?(ATTACHMENTS_BASE_DIR)
      puts "", "importing user avatars"

      User.find_each do |u|
        next unless u.custom_fields["import_id"]

        r = mysql_query("SELECT photo FROM #{TABLE_PREFIX}User WHERE UserID = #{u.custom_fields['import_id']};").first
        next if r.nil?
        photo = r["photo"]
        next unless photo.present?

        # Possible encoded values:
        # 1. cf://uploads/userpics/820/Y0AFUQYYM6QN.jpg
        # 2. ~cf/userpics2/cf566487133f1f538e02da96f9a16b18.jpg
        # 3. ~cf/userpics/txkt8kw1wozn.jpg

        photo_real_filename = nil
        parts = photo.squeeze("/").split("/")
        if parts[0] == "cf:"
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
    puts "", "importing categories..."

    categories = mysql_query("
                              SELECT CategoryID, Name, Description
                              FROM #{TABLE_PREFIX}Category
                              ORDER BY CategoryID ASC
                            ").to_a

    create_categories(categories) do |category|
      {
        id: category['CategoryID'],
        name: CGI.unescapeHTML(category['Name']),
        description: CGI.unescapeHTML(category['Description'])
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    tag_names_sql = "select t.name as tag_name from GDN_Tag t, GDN_TagDiscussion td where t.tagid = td.tagid and td.discussionid = {discussionid} and t.name != '';"

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}Discussion;").first['count']

    @last_topic_id = -1

    batches(BATCH_SIZE) do |offset|
      discussions = mysql_query(
        "SELECT DiscussionID, CategoryID, Name, Body, Format, CountViews, Closed, Announce,
                DateInserted, InsertUserID, DateLastComment
         FROM #{TABLE_PREFIX}Discussion
         WHERE DiscussionID > #{@last_topic_id}
         ORDER BY DiscussionID ASC
         LIMIT #{BATCH_SIZE};")

      break if discussions.size < 1
      @last_topic_id = discussions.to_a.last['DiscussionID']
      next if all_records_exist? :posts, discussions.map { |t| "discussion#" + t['DiscussionID'].to_s }

      create_posts(discussions, total: total_count, offset: offset) do |discussion|
        user_id = user_id_from_imported_user_id(discussion['InsertUserID']) || Discourse::SYSTEM_USER_ID
        {
          id: "discussion#" + discussion['DiscussionID'].to_s,
          user_id: user_id,
          title: discussion['Name'],
          category: category_id_from_imported_category_id(discussion['CategoryID']),
          raw: VanillaBodyParser.new(discussion, user_id).parse,
          views: discussion['CountViews'] || 0,
          closed: discussion['Closed'] == 1,
          pinned_at: discussion['Announce'] == 0 ? nil : Time.zone.at(discussion['DateLastComment'] || discussion['DateInserted']),
          pinned_globally: discussion['Announce'] == 1,
          created_at: Time.zone.at(discussion['DateInserted']),
          post_create_action: proc do |post|
            if @import_tags
              tag_names = @client.query(tag_names_sql.gsub('{discussionid}', discussion['DiscussionID'].to_s)).map { |row| row['tag_name'] }
              DiscourseTagging.tag_topic_by_names(post.topic, staff_guardian, tag_names)
            end
          end
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}Comment;").first['count']
    @last_post_id = -1
    batches(BATCH_SIZE) do |offset|
      comments = mysql_query(
        "SELECT CommentID, DiscussionID, Body, Format,
                DateInserted, InsertUserID
         FROM #{TABLE_PREFIX}Comment
         WHERE CommentID > #{@last_post_id}
         ORDER BY CommentID ASC
         LIMIT #{BATCH_SIZE};")

      break if comments.size < 1
      @last_post_id = comments.to_a.last['CommentID']
      next if all_records_exist? :posts, comments.map { |comment| "comment#" + comment['CommentID'].to_s }

      create_posts(comments, total: total_count, offset: offset) do |comment|
        next unless t = topic_lookup_from_imported_post_id("discussion#" + comment['DiscussionID'].to_s)
        next if comment['Body'].blank?
        user_id = user_id_from_imported_user_id(comment['InsertUserID']) || Discourse::SYSTEM_USER_ID
        {
          id: "comment#" + comment['CommentID'].to_s,
          user_id: user_id,
          topic_id: t[:topic_id],
          raw: VanillaBodyParser.new(comment, user_id).parse,
          created_at: Time.zone.at(comment['DateInserted'])
        }
      end
    end
  end

  def import_messages
    puts "", "importing messages..."

    total_count = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}ConversationMessage;").first['count']

    @last_message_id = -1

    batches(BATCH_SIZE) do |offset|
      messages = mysql_query(
        "SELECT m.MessageID, m.Body, m.Format,
                m.InsertUserID, m.DateInserted,
                m.ConversationID, c.Contributors
         FROM #{TABLE_PREFIX}ConversationMessage m
         INNER JOIN #{TABLE_PREFIX}Conversation c on c.ConversationID = m.ConversationID
         WHERE m.MessageID > #{@last_message_id}
         ORDER BY m.MessageID ASC
         LIMIT #{BATCH_SIZE};")

      break if messages.size < 1
      @last_message_id = messages.to_a.last['MessageID']
      next if all_records_exist? :posts, messages.map { |t| "message#" + t['MessageID'].to_s }

      create_posts(messages, total: total_count, offset: offset) do |message|
        user_id = user_id_from_imported_user_id(message['InsertUserID']) || Discourse::SYSTEM_USER_ID
        body = VanillaBodyParser.new(message, user_id).parse

        common = {
          user_id: user_id,
          raw: body,
          created_at: Time.zone.at(message['DateInserted']),
          custom_fields: {
            conversation_id: message['ConversationID'],
            participants: message['Contributors'],
            message_id: message['MessageID']
          }
        }

        conversation_id = "conversation#" + message['ConversationID'].to_s
        message_id = "message#" + message['MessageID'].to_s

        imported_conversation = topic_lookup_from_imported_post_id(conversation_id)

        if imported_conversation.present?
          common.merge(id: message_id, topic_id: imported_conversation[:topic_id])
        else
          user_ids = (message['Contributors'] || '').scan(/\"(\d+)\"/).flatten.map(&:to_i)
          usernames = user_ids.map { |id| @lookup.find_user_by_import_id(id).try(:username) }.compact
          usernames = [@lookup.find_user_by_import_id(message['InsertUserID']).try(:username)].compact if usernames.empty?
          title = body.truncate(40)

          {
            id: conversation_id,
            title: title,
            archetype: Archetype.private_message,
            target_usernames: usernames.uniq,
          }.merge(common)
        end
      end
    end
  end

  def staff_guardian
    @_staff_guardian ||= Guardian.new(Discourse.system_user)
  end

  def mysql_query(sql)
    @client.query(sql)
    # @client.query(sql, cache_rows: false) #segfault: cache_rows: false causes segmentation fault
  end

  def create_permalinks
    puts '', 'Creating redirects...', ''

    User.find_each do |u|
      ucf = u.custom_fields
      if ucf && ucf["import_id"] && ucf["import_username"]
        encoded_username = CGI.escape(ucf['import_username']).gsub('+', '%20')
        Permalink.create(url: "profile/#{ucf['import_id']}/#{encoded_username}", external_url: "/users/#{u.username}") rescue nil
        print '.'
      end
    end

    Post.find_each do |post|
      pcf = post.custom_fields
      if pcf && pcf["import_id"]
        topic = post.topic
        id = pcf["import_id"].split('#').last
        if post.post_number == 1
          slug = Slug.for(topic.title) # probably matches what vanilla would do...
          Permalink.create(url: "discussion/#{id}/#{slug}", topic_id: topic.id) rescue nil
        else
          Permalink.create(url: "discussion/comment/#{id}", post_id: post.id) rescue nil
        end
        print '.'
      end
    end
  end

end

ImportScripts::VanillaSQL.new.perform
