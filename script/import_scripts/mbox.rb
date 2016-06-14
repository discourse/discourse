require 'sqlite3'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Mbox < ImportScripts::Base
  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  BATCH_SIZE = 1000
  CATEGORY_ID = 6
  MBOX_DIR = File.expand_path("~/import/site")

  # Remove to not split individual files
  SPLIT_AT = /^From owner-/

  def execute
    create_email_indices
    create_user_indices
    massage_indices
    import_users
    create_forum_topics
    import_replies
  end

  def open_db
    SQLite3::Database.new("#{MBOX_DIR}/index.db")
  end

  def all_messages
    files = Dir["#{MBOX_DIR}/messages/*"]

    files.each_with_index do |f, idx|
      if SPLIT_AT.present?
        msg = ""
        File.foreach(f).with_index do |line, line_num|
          line = line.scrub
          if line =~ SPLIT_AT
            if !msg.empty?
              mail = Mail.read_from_string(msg)
              yield mail
              print_status(idx, files.size)
              msg = ""
            end
          end
          msg << line
        end
        if !msg.empty?
          mail = Mail.read_from_string(msg)
          yield mail
          print_status(idx, files.size)
          msg = ""
        end
      else
        raw = File.read(f)
        mail = Mail.read_from_string(raw)
        yield mail
        print_status(idx, files.size)
      end

    end
  end

  def massage_indices
    db = open_db
    db.execute "UPDATE emails SET reply_to = null WHERE reply_to = ''"

    rows = db.execute "SELECT msg_id, title, reply_to FROM emails ORDER BY email_date ASC"

    msg_ids = {}
    titles = {}
    rows.each do |row|
      msg_ids[row[0]] = true
      titles[row[1]] = row[0]
    end

    # First, any replies where the parent doesn't exist should have that field cleared
    not_found = []
    rows.each do |row|
      msg_id, _, reply_to = row

      if reply_to.present?
        not_found << msg_id if msg_ids[reply_to].blank?
      end
    end

    puts "#{not_found.size} records couldn't be associated with parents"
    if not_found.present?
      db.execute "UPDATE emails SET reply_to = NULL WHERE msg_id IN (#{not_found.map {|nf| "'#{nf}'"}.join(',')})"
    end

    dupe_titles = db.execute "SELECT title, COUNT(*) FROM emails GROUP BY title HAVING count(*) > 1"
    puts "#{dupe_titles.size} replies to wire up"
    dupe_titles.each do |t|
      title = t[0]
      first = titles[title]
      db.execute "UPDATE emails SET reply_to = ? WHERE title = ? and msg_id <> ?", [first, title, first]
    end

  ensure
    db.close
  end

  def create_email_indices
    db = open_db
    db.execute "DROP TABLE IF EXISTS emails"
    db.execute <<-SQL
      CREATE TABLE emails (
        msg_id VARCHAR(995) PRIMARY KEY,
        from_email VARCHAR(255) NOT NULL,
        from_name VARCHAR(255) NOT NULL,
        title VARCHAR(255) NOT NULL,
        reply_to VARCHAR(955) NULL,
        email_date DATETIME NOT NULL,
        message TEXT NOT NULL
      );
    SQL

    db.execute "CREATE INDEX by_title ON emails (title)"
    db.execute "CREATE INDEX by_email ON emails (from_email)"

    puts "", "creating indices"

    all_messages do |mail|
      msg_id = mail['Message-ID'].to_s

      # Many ways to get a name
      from = mail[:from]
      from_name = nil

      from_email = nil
      if mail.from.present?
        from_email = mail.from.first
      end

      display_names = from.try(:display_names)
      if display_names.present?
        from_name = display_names.first
      end

      if from_name.blank? && from.to_s =~ /\(([^\)]+)\)/
        from_name = Regexp.last_match[1]
      end
      from_name = from.to_s if from_name.blank?

      title = clean_title(mail['Subject'].to_s)
      reply_to = mail['In-Reply-To'].to_s
      email_date = mail['date'].to_s

      db.execute "INSERT OR IGNORE INTO emails (msg_id, from_email, from_name, title, reply_to, email_date, message)
                  VALUES (?, ?, ?, ?, ?, ?, ?)",
                 [msg_id, from_email, from_name, title, reply_to, email_date, mail.to_s]
    end
  ensure
    db.close
  end

  def create_user_indices
    db = open_db
    db.execute "DROP TABLE IF EXISTS users"
    db.execute <<-SQL
      CREATE TABLE users (
        email VARCHAR(995) PRIMARY KEY,
        name VARCHAR(255) NOT NULL
      );
    SQL

    db.execute "INSERT OR IGNORE INTO users (email, name) SELECT from_email, from_name FROM emails"
  ensure
    db.close
  end

  def clean_title(title)
    title ||= ""
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
    db = open_db

    all_users = db.execute("SELECT name, email FROM users")
    total_count = all_users.size

    batches(BATCH_SIZE) do |offset|
      users = all_users[offset..offset+BATCH_SIZE-1]
      break if users.nil?
      next if all_records_exist? :users, users.map {|u| u[1]}

      create_users(users, total: total_count, offset: offset) do |u|
        {
          id:           u[1],
          email:        u[1],
          name:         u[0]
        }
      end
    end
  ensure
    db.close
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

    db = open_db
    all_topics = db.execute("SELECT msg_id,
                                    from_email,
                                    from_name,
                                    title,
                                    email_date,
                                    message
                            FROM emails
                            WHERE reply_to IS NULL")

    topic_count = all_topics.size

    batches(BATCH_SIZE) do |offset|
      topics = all_topics[offset..offset+BATCH_SIZE-1]
      break if topics.nil?

      next if all_records_exist? :posts, topics.map {|t| t[0]}

      create_posts(topics, total: topic_count, offset: offset) do |t|
        raw_email = t[5]
        receiver = Email::Receiver.new(raw_email)
        mail = Mail.read_from_string(raw_email)
        mail.body

        selected = receiver.select_body
        next unless selected
        selected = selected.join('') if selected.kind_of?(Array)

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

        { id: t[0],
          title: clean_title(title),
          user_id: user_id_from_imported_user_id(mail.from.first) || Discourse::SYSTEM_USER_ID,
          created_at: mail.date,
          category: CATEGORY_ID,
          raw: clean_raw(raw),
          cook_method: Post.cook_methods[:email] }
      end
    end
  ensure
    db.close
  end

  def import_replies
    puts "", "creating topic replies"

    db = open_db
    replies = db.execute("SELECT msg_id,
                                 from_email,
                                 from_name,
                                 title,
                                 email_date,
                                 message,
                                 reply_to
                          FROM emails
                          WHERE reply_to IS NOT NULL")

    post_count = replies.size

    batches(BATCH_SIZE) do |offset|
      posts = replies[offset..offset+BATCH_SIZE-1]
      break if posts.nil?

      next if all_records_exist? :posts, posts.map {|p| p[0]}

      create_posts(posts, total: post_count, offset: offset) do |p|
        parent_id = p[6]
        id = p[0]

        topic = topic_lookup_from_imported_post_id(parent_id)
        topic_id = topic[:topic_id] if topic
        next unless topic_id

        raw_email = p[5]
        receiver = Email::Receiver.new(raw_email)
        mail = Mail.read_from_string(raw_email)
        mail.body

        selected = receiver.select_body
        selected = selected.join('') if selected.kind_of?(Array)
        next unless selected

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
  ensure
    db.close
  end
end

ImportScripts::Mbox.new.perform
