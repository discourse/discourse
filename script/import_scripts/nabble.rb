require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'pg'
require_relative 'base/uploader'

=begin
 if you want to create mock users for posts made by anonymous participants,
 run the following SQL prior to importing.

-- first attribute any anonymous posts to existing users (if any)

UPDATE node
SET owner_id = p.user_id, anonymous_name = NULL
FROM ( SELECT lower(name) AS name, user_id FROM user_ ) p
WHERE p.name = lower(node.anonymous_name)
  AND owner_id IS NULL;

-- then create mock users

INSERT INTO user_ (email, name, joined, registered)
  SELECT lower(anonymous_name) || '@dummy.com', MIN(anonymous_name), MIN(when_created), MIN(when_created)
  FROM node
  WHERE anonymous_name IS NOT NULL
  GROUP BY lower(anonymous_name);

-- then move these posts to the new users
-- (yes, this is the same query as the first one indeed)

UPDATE node
SET owner_id = p.user_id, anonymous_name = NULL
FROM ( SELECT lower(name) AS name, user_id FROM user_ ) p
WHERE p.name = lower(node.anonymous_name)
  AND owner_id IS NULL;

=end

class ImportScripts::Nabble < ImportScripts::Base
  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  BATCH_SIZE = 1000

  DB_NAME     = "nabble"
  CATEGORY_ID = 6

  def initialize
    super

    @tagmap = []
    @td = PG::TextDecoder::TimestampWithTimeZone.new
    @client = PG.connect(dbname: DB_NAME)
    @uploader = ImportScripts::Uploader.new
  end

  def execute
    import_users
    create_forum_topics
    import_replies
  end

  def import_users
    puts "", "importing users"

    total_count = @client.exec("SELECT COUNT(user_id) FROM user_")[0]["count"]

    batches(BATCH_SIZE) do |offset|
      users = @client.query(<<-SQL
          SELECT user_id, name, email, joined
            FROM user_
        ORDER BY joined
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL
      )

      break if users.ntuples() < 1

      next if all_records_exist? :users, users.map { |u| u["user_id"].to_i }

      create_users(users, total: total_count, offset: offset) do |row|
        {
          id:           row["user_id"],
          email:        row["email"] || (SecureRandom.hex << "@domain.com"),
          created_at:   Time.zone.at(@td.decode(row["joined"])),
          name:         row["name"],
          post_create_action: proc do |user|
            import_avatar(user, row["user_id"])
          end
        }
      end
    end
  end

  def import_avatar(user, org_id)
    filename = 'avatar' + org_id.to_s
    path = File.join('/tmp/nab', filename)
    res = @client.exec("SELECT content FROM file_avatar WHERE name='avatar100.png' AND user_id = #{org_id} LIMIT 1")
    return if res.ntuples() < 1

    binary = res[0]['content']
    File.open(path, 'wb') { |f|
      f.write(PG::Connection.unescape_bytea(binary))
    }

    upload = @uploader.create_upload(user.id, path, filename)

    if upload.persisted?
      user.import_mode = false
      user.create_user_avatar
      user.import_mode = true
      user.user_avatar.update(custom_upload_id: upload.id)
      user.update(uploaded_avatar_id: upload.id)
    else
      Rails.logger.error("Could not persist avatar for user #{user.username}")
    end

  end

  def parse_email(msg)
    receiver = Email::Receiver.new(msg)
    mail = Mail.read_from_string(msg)
    mail.body

    body, elided = receiver.select_body
    body.force_encoding(body.encoding).encode("UTF-8")
  end

  def create_forum_topics
    puts "", "creating forum topics"

    app_node_id = @client.exec("SELECT node_id FROM node WHERE is_app LIMIT 1")[0]['node_id']
    topic_count = @client.exec("SELECT COUNT(node_id) AS count FROM node WHERE parent_id = #{app_node_id}")[0]["count"]

    batches(BATCH_SIZE) do |offset|

      topics = @client.exec <<-SQL
        SELECT n.node_id, n.subject, n.owner_id, n.when_created, nm.message, n.msg_fmt
        FROM node AS n
        INNER JOIN node_msg AS nm ON nm.node_id = n.node_id
        WHERE n.parent_id = #{app_node_id}
        ORDER BY n.when_created
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL

      break if topics.ntuples() < 1

      next if all_records_exist? :posts, topics.map { |t| t['node_id'].to_i }

      create_posts(topics, total: topic_count, offset: offset) do |t|
        raw = body_from(t)
        next unless raw
        raw = process_content(raw)
        raw = process_attachments(raw, t['node_id'])

        { id: t['node_id'],
          title: t['subject'],
          user_id: user_id_from_imported_user_id(t["owner_id"]) || Discourse::SYSTEM_USER_ID,
          created_at: Time.zone.at(@td.decode(t["when_created"])),
          category: CATEGORY_ID,
          raw: raw,
          cook_method: Post.cook_methods[:regular] }
      end
    end
  end

  def body_from(p)
    %w(m s).include?(p['msg_fmt']) ? parse_email(p['message']) : p['message']
  rescue Email::Receiver::EmptyEmailError
    puts "Skipped #{p['node_id']}"
  end

  def process_content(txt)
    txt.gsub! /\<quote author="(.*?)"\>/, '[quote="\1"]'
    txt.gsub! /\<\/quote\>/, '[/quote]'
    txt.gsub!(/\<raw\>(.*?)\<\/raw\>/m) do |match|
      c = Regexp.last_match[1].indent(4);
       "\n#{c}\n"
    end

    # lines starting with # are comments, not headings, insert a space to prevent markdown
    txt.gsub! /\n#/m, ' #'

    # in the languagetool forum, quite a lot of XML was not marked as raw
    # so we treat <rule...>...</rule> and <category...>...</category> as raw

    # uncomment below if you want to use this

    #txt.gsub!(/<rule(.*?)>(.*?<\/rule>)/m) do |match|
    #   c = Regexp.last_match[2].indent(4);
    #   "\n    <rule#{Regexp.last_match[1]}>#{c}\n"
    #end
    #txt.gsub!(/<category(.*?)>(.*?<\/category>)/m) do |match|
    #   c = Regexp.last_match[2].indent(4);
    #   "\n    <rule#{Regexp.last_match[1]}>#{c}\n"
    #end
    txt
  end

  def process_attachments(txt, postid)
    txt.gsub!(/<nabble_img src="(.*?)" (.*?)>/m) do |match|
      basename = Regexp.last_match[1]
      get_attachment_upload(basename, postid) do |upload|
        @uploader.embedded_image_html(upload)
      end
    end

    txt.gsub!(/<nabble_a href="(.*?)">(.*?)<\/nabble_a>/m) do |match|
      basename = Regexp.last_match[1]
      get_attachment_upload(basename, postid) do |upload|
        @uploader.attachment_html(upload, basename)
      end
    end
    txt
  end

  def get_attachment_upload(basename, postid)
    contents = @client.exec("SELECT content FROM file_node WHERE name='#{basename}' AND node_id = #{postid}")
    if contents.any?
      binary = contents[0]['content']
      fn = File.join('/tmp/nab', basename)
      File.open(fn, 'wb') { |f|
        f.write(PG::Connection.unescape_bytea(binary))
      }
      yield @uploader.create_upload(0, fn, basename)
    end
  end

  def import_replies
    puts "", "creating topic replies"

    app_node_id = @client.exec("SELECT node_id FROM node WHERE is_app LIMIT 1")[0]['node_id']
    post_count = @client.exec("SELECT COUNT(node_id) AS count FROM node WHERE parent_id != #{app_node_id}")[0]["count"]

    topic_ids = {}

    batches(BATCH_SIZE) do |offset|
      posts = @client.exec <<-SQL
        SELECT n.node_id, n.parent_id, n.subject, n.owner_id, n.when_created, nm.message, n.msg_fmt
        FROM node AS n
        INNER JOIN node_msg AS nm ON nm.node_id = n.node_id
        WHERE n.parent_id != #{app_node_id}
        ORDER BY n.when_created
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL

      break if posts.ntuples() < 1

      next if all_records_exist? :posts, posts.map { |p| p['node_id'].to_i }

      create_posts(posts, total: post_count, offset: offset) do |p|
        parent_id = p['parent_id']
        id = p['node_id']

        topic_id = topic_ids[parent_id]
        unless topic_id
          topic = topic_lookup_from_imported_post_id(parent_id)
          topic_id = topic[:topic_id] if topic
        end
        next unless topic_id

        topic_ids[id] = topic_id

        raw = body_from(p)
        next unless raw
        raw = process_content(raw)
        raw = process_attachments(raw, id)
        { id: id,
          topic_id: topic_id,
          user_id: user_id_from_imported_user_id(p['owner_id']) || Discourse::SYSTEM_USER_ID,
          created_at: Time.zone.at(@td.decode(p["when_created"])),
          raw: raw,
          cook_method: Post.cook_methods[:regular] }
      end
    end
  end
end

class String
  def indent(count, char = ' ')
    gsub(/([^\n]*)(\n|$)/) do |match|
      last_iteration = ($1 == "" && $2 == "")
      line = ""
      line << (char * count) unless last_iteration
      line << $1
      line << $2
      line
    end
  end
end

ImportScripts::Nabble.new.perform
