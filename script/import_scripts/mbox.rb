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
    topic_titles = {}
    replies = []

    all_messages do |mail, filename|
      users[mail.from.first] = mail[:from].display_names.first

      msg_id = mail['Message-ID'].to_s
      reply_to = mail['In-Reply-To'].to_s
      title = clean_title(mail['Subject'].to_s)
      date = Time.parse(mail['date'].to_s).to_i

      if reply_to.present?
        topic = topic_lookup[reply_to] || reply_to
        topic_lookup[msg_id] = topic
        replies << {id: msg_id, topic: topic, file: filename, title: title, date: date}
      else
        topics << {id: msg_id, file: filename, title: title, date: date}
        topic_titles[title] ||= msg_id
      end
    end

    replies.sort! {|a, b| a[:date] <=> b[:date]}
    topics.sort! {|a, b| a[:date] <=> b[:date]}

    # Replies without parents should be hoisted to topics
    to_hoist = []
    replies.each do |r|
      to_hoist << r if !topic_lookup[r[:topic]]
    end

    to_hoist.each do |h|
      replies.delete(h)
      topics << {id: h[:id], file: h[:file], title: h[:title], date: h[:date]}
      topic_titles[h[:title]] ||= h[:id]
    end

    # Topics with duplicate replies should be replies
    to_group = []
    topics.each do |t|
      first = topic_titles[t[:title]]
      to_group << t if first && first != t[:id]
    end

    to_group.each do |t|
      topics.delete(t)
      replies << {id: t[:id], topic: topic_titles[t[:title]], file: t[:file], title: t[:title], date: t[:date]}
    end

    replies.sort! {|a, b| a[:date] <=> b[:date]}
    topics.sort! {|a, b| a[:date] <=> b[:date]}


    File.write(USER_INDEX_PATH, {users: users}.to_json)
    File.write(TOPIC_INDEX_PATH, {topics: topics}.to_json)
    File.write(REPLY_INDEX_PATH, {replies: replies}.to_json)
  end

  def clean_title(title)
    #Strip mailing list name from subject
    title = title.gsub(/\[[^\]]+\]+/, '').strip

    original_length = title.length

    #Strip Reply prefix from title (Standard and localized)
    title = title.gsub(/^Re: */i, '')
    title = title.gsub(/^R: */i, '') #Italian
    title = title.gsub(/^RIF: */i, '') #Italian

    #Strip Forward prefix from title (Standard and localized)
    title = title.gsub(/^Fwd: */i, '')
    title = title.gsub(/^I: */i, '') #Italian

    title.strip

    #In case of mixed localized prefixes there could be many of them if the mail client didn't strip the localized ones
    if original_length >  title.length
      clean_title(title)
    else
      title
    end
  end

  def clean_raw(raw)
    raw.gsub(/-- \nYou received this message because you are subscribed to the Google Groups "[^"]*" group.\nTo unsubscribe from this group and stop receiving emails from it, send an email to [^+@]+\+unsubscribe@googlegroups.com\.\nFor more options, visit https:\/\/groups\.google\.com\/groups\/opt_out\./, '')
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
    receiver = Email::Receiver.new(msg)
    mail = Mail.read_from_string(msg)
    mail.body

    selected = receiver.select_body
    selected.force_encoding(selected.encoding).encode("UTF-8")
  end

  def create_forum_topics
    puts "", "creating forum topics"

    all_topics = ::JSON.parse(File.read(TOPIC_INDEX_PATH))['topics']
    topic_count = all_topics.size

    batches(BATCH_SIZE) do |offset|
      topics = all_topics[offset..offset+BATCH_SIZE-1]
      break if topics.nil?

      next if all_records_exist? :posts, topics.map {|t| t['id']}

      create_posts(topics, total: topic_count, offset: offset) do |t|
        raw_email = File.read(t['file'])
        receiver = Email::Receiver.new(raw_email)
        mail = Mail.read_from_string(raw_email)
        mail.body

        selected = receiver.select_body
        next unless selected

        raw = selected.force_encoding(selected.encoding).encode("UTF-8")

        title = mail.subject

        # import the attachments
        mail.attachments.each do |attachment|
          tmp = Tempfile.new("discourse-email-attachment")
          begin
            # read attachment
            File.open(tmp.path, "w+b") { |f| f.write attachment.body.decoded }
            # create the upload for the user
            upload = Upload.create_for(user_id_from_imported_user_id(mail.from.first) || Discourse::SYSTEM_USER_ID, tmp, attachment.filename, tmp.size )
            if upload && upload.errors.empty?
              raw << "\n\n#{receiver.attachment_markdown(upload)}\n\n"
            end
          ensure
            tmp.try(:close!) rescue nil
          end
        end

        { id: t['id'],
          title: clean_title(title),
          user_id: user_id_from_imported_user_id(mail.from.first) || Discourse::SYSTEM_USER_ID,
          created_at: mail.date,
          category: CATEGORY_ID,
          raw: clean_raw(raw),
          cook_method: Post.cook_methods[:email] }
      end
    end
  end

  def import_replies
    puts "", "creating topic replies"

    replies = ::JSON.parse(File.read(REPLY_INDEX_PATH))['replies']
    post_count = replies.size

    batches(BATCH_SIZE) do |offset|
      posts = replies[offset..offset+BATCH_SIZE-1]
      break if posts.nil?

      next if all_records_exist? :posts, posts.map {|p| p['id']}

      create_posts(posts, total: post_count, offset: offset) do |p|
        parent_id = p['topic']
        id = p['id']

        topic = topic_lookup_from_imported_post_id(parent_id)
        topic_id = topic[:topic_id] if topic
        next unless topic_id

        raw_email = File.read(p['file'])
        receiver = Email::Receiver.new(raw_email)
        mail = Mail.read_from_string(raw_email)
        mail.body

        selected = receiver.select_body
        raw = selected.force_encoding(selected.encoding).encode("UTF-8")

        # import the attachments
        mail.attachments.each do |attachment|
          tmp = Tempfile.new("discourse-email-attachment")
          begin
            # read attachment
            File.open(tmp.path, "w+b") { |f| f.write attachment.body.decoded }
            # create the upload for the user
            upload = Upload.create_for(user_id_from_imported_user_id(mail.from.first) || Discourse::SYSTEM_USER_ID, tmp, attachment.filename, tmp.size )
            if upload && upload.errors.empty?
              raw << "\n\n#{receiver.attachment_markdown(upload)}\n\n"
            end
          ensure
            tmp.try(:close!) rescue nil
          end
        end

        { id: id,
          topic_id: topic_id,
          user_id: user_id_from_imported_user_id(mail.from.first) || Discourse::SYSTEM_USER_ID,
          created_at: mail.date,
          raw: clean_raw(raw),
          cook_method: Post.cook_methods[:email] }
      end
    end
  end
end

ImportScripts::Mbox.new.perform
