require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'pg'

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

      next if all_records_exist? :users, users.map {|u| u["user_id"].to_i}

      create_users(users, total: total_count, offset: offset) do |user|
        {
          id:           user["user_id"],
          email:        user["email"] || (SecureRandom.hex << "@domain.com"),
          created_at:   Time.zone.at(@td.decode(user["joined"])),
          name:         user["name"]
        }
      end
    end
  end

  def parse_email(msg)
    receiver = Email::Receiver.new(msg, skip_sanity_check: true)
    mail = Mail.read_from_string(msg)
    mail.body

    selected = receiver.select_body(mail)
    selected.force_encoding(selected.encoding).encode("UTF-8")
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

      next if all_records_exist? :posts, topics.map {|t| t['node_id'].to_i}

      create_posts(topics, total: topic_count, offset: offset) do |t|
        raw = body_from(t)
        next unless raw

        { id: t['node_id'],
          title: t['subject'],
          user_id: user_id_from_imported_user_id(t["owner_id"]) || Discourse::SYSTEM_USER_ID,
          created_at: Time.zone.at(@td.decode(t["when_created"])),
          category: CATEGORY_ID,
          raw: raw,
          cook_method: Post.cook_methods[:email] }
      end
    end
  end

  def body_from(p)
    %w(m s).include?(p['msg_fmt']) ? parse_email(p['message']) : p['message']
  rescue Email::Receiver::EmptyEmailError
    puts "Skipped #{p['node_id']}"
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

      next if all_records_exist? :posts, posts.map {|p| p['node_id'].to_i}

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
        { id: id,
          topic_id: topic_id,
          user_id: user_id_from_imported_user_id(p['owner_id']) || Discourse::SYSTEM_USER_ID,
          created_at: Time.zone.at(@td.decode(p["when_created"])),
          raw: raw,
          cook_method: Post.cook_methods[:email] }
      end
    end
  end
end

ImportScripts::Nabble.new.perform
