require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Mbox < ImportScripts::Base
  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  BATCH_SIZE = 1000
  CATEGORY_ID = 6
  MBOX_DIR = "/tmp/mbox-input"
  USER_INDEX_PATH = "#{MBOX_DIR}/user-index.json"
  TOPIC_INDEX_PATH = "#{MBOX_DIR}/topic-index.json"
  REPLY_INDEX_PATH = "#{MBOX_DIR}/replies-index.json"

  def execute
    create_indices
    import_users
    create_forum_topics
    import_replies
  end

  def all_messages

    files = Dir["#{MBOX_DIR}/*/*"]

    files.each_with_index do |f, idx|
      raw = File.read(f)
      mail = Mail.read_from_string(raw)
      yield mail, f
      print_status(idx, files.size)
    end
  end

  def create_indices
    return if File.exist?(USER_INDEX_PATH) && File.exist?(TOPIC_INDEX_PATH) && File.exist?(REPLY_INDEX_PATH)
    puts "", "creating indices"
    users = {}

    topics = []

    topic_lookup = {}
    replies = []

    all_messages do |mail, filename|
      users[mail.from.first] = mail[:from].display_names.first

      msg_id = mail['Message-ID'].to_s
      reply_to = mail['In-Reply-To'].to_s

      if reply_to.present?
        topic = topic_lookup[reply_to] || reply_to
        topic_lookup[msg_id] = topic
        replies << {id: msg_id, topic: topic, file: filename}
      else
        topics << {id: msg_id, file: filename}
      end
    end

    File.write(USER_INDEX_PATH, {users: users}.to_json)
    File.write(TOPIC_INDEX_PATH, {topics: topics}.to_json)
    File.write(REPLY_INDEX_PATH, {replies: replies}.to_json)
  end

  def import_users
    puts "", "importing users"

    all_users = ::JSON.parse(File.read(USER_INDEX_PATH))['users']
    user_keys = all_users.keys
    total_count = user_keys.size

    batches(BATCH_SIZE) do |offset|
      users = user_keys[offset..offset+BATCH_SIZE-1]
      break if users.nil?
      next if all_records_exist? :users, users

      create_users(users, total: total_count, offset: offset) do |email|
        {
          id:           email,
          email:        email,
          name:         all_users[email]
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

    all_topics = ::JSON.parse(File.read(TOPIC_INDEX_PATH))['topics']
    topic_count = all_topics.size

    batches(BATCH_SIZE) do |offset|
      topics = all_topics[offset..offset+BATCH_SIZE-1]
      break if topics.nil?

      next if all_records_exist? :posts, topics.map {|t| t['id'].to_i}

      create_posts(topics, total: topic_count, offset: offset) do |t|
        raw_email = File.read(t['file'])
        receiver = Email::Receiver.new(raw_email, skip_sanity_check: true)
        mail = Mail.read_from_string(raw_email)
        mail.body

        selected = receiver.select_body(mail)
        next unless selected

        raw = selected.force_encoding(selected.encoding).encode("UTF-8")

        title = mail.subject.gsub(/\[[^\]]+\]+/, '').strip

        { id: t['id'],
          title: title,
          user_id: user_id_from_imported_user_id(mail.from.first) || Discourse::SYSTEM_USER_ID,
          created_at: mail.date,
          category: CATEGORY_ID,
          raw: raw,
          cook_method: Post.cook_methods[:email] }
      end
    end
  end

  def import_replies
    puts "", "creating topic replies"

    all_topics = ::JSON.parse(File.read(TOPIC_INDEX_PATH))['topics']
    topic_count = all_topics.size

    replies = ::JSON.parse(File.read(REPLY_INDEX_PATH))['replies']
    post_count = replies.size

    batches(BATCH_SIZE) do |offset|
      posts = replies[offset..offset+BATCH_SIZE-1]
      break if posts.nil?

      next if all_records_exist? :posts, posts.map {|p| p['id'].to_i}

      create_posts(posts, total: post_count, offset: offset) do |p|
        parent_id = p['topic']
        id = p['id']

        topic = topic_lookup_from_imported_post_id(parent_id)
        topic_id = topic[:topic_id] if topic
        next unless topic_id

        raw_email = File.read(p['file'])
        receiver = Email::Receiver.new(raw_email, skip_sanity_check: true)
        mail = Mail.read_from_string(raw_email)
        mail.body

        selected = receiver.select_body(mail)
        raw = selected.force_encoding(selected.encoding).encode("UTF-8")

        { id: id,
          topic_id: topic_id,
          user_id: user_id_from_imported_user_id(mail.from.first) || Discourse::SYSTEM_USER_ID,
          created_at: mail.date,
          raw: raw,
          cook_method: Post.cook_methods[:email] }
      end
    end
  end
end

ImportScripts::Mbox.new.perform
