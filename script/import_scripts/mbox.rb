require 'sqlite3'
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Paste these lines into your shell before running this:

=begin
export MBOX_SUBDIR="messages" # subdirectory with mbox files
export LIST_NAME=LIST_NAME
export DEFAULT_TRUST_LEVEL=1
export DATA_DIR=~/data/import
export SPLIT_AT="^From " # or "^From (.*)"
=end

# If you change the functionality of this script, please consider updating this HOWTO:
# https://meta.discourse.org/t/howto-import-mbox-mailing-list-files/51233

class ImportScripts::Mbox < ImportScripts::Base
  include ActiveModel::Validations

  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  MBOX_SUBDIR = ENV['MBOX_SUBDIR'] || "messages" # subdirectory with mbox files
  LIST_NAME = ENV['LIST_NAME'] || "" # Will remove [LIST_NAME] from Subjects
  DEFAULT_TRUST_LEVEL = ENV['DEFAULT_TRUST_LEVEL'] || 1
  DATA_DIR = ENV['DATA_DIR'] || "~/data/import"
  MBOX_DIR = File.expand_path(DATA_DIR) # where index.db will be created
  BATCH_SIZE = 1000

  # Site settings
  SiteSetting.disable_emails = "non-staff"

  # Comment out if each file contains a single message
  # Use formail to split yourself: http://linuxcommand.org/man_pages/formail1.html
  # SPLIT_AT = /^From (.*) at/ # for Google Groups?
  SPLIT_AT = /#{ENV['SPLIT_AT']}/ || /^From / # for standard MBOX files

  # Will create a category if it doesn't exist
  # create subdirectories in MBOX_SUBDIR with categories
  CATEGORY_MAPPINGS = {
    "default" => "uncategorized",
    # ex: "jobs-folder" => "jobs"
  }

  unless File.directory?(MBOX_DIR)
    puts "Cannot find import directory #{MBOX_DIR}. Giving up."
    exit
  end

  validates_format_of :email, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, on: :create

  def execute
    import_categories
    create_email_indices
    create_user_indices
    massage_indices
    import_users
    create_forum_topics
    import_replies
    # replace_email_addresses # uncomment to replace all email address with @username
  end

  def import_categories
    mappings = CATEGORY_MAPPINGS.values - ['uncategorized']

    create_categories(mappings) do |c|
      { id: c, name: c }
    end
  end

  def open_db
    SQLite3::Database.new("#{MBOX_DIR}/index.db")
  end

  def each_line(f)
    infile = File.open(f, 'r')
    if f.ends_with?('.gz')
      gz = Zlib::GzipReader.new(infile)
      gz.each_line do |line|
        yield line
      end
    else
      infile.each_line do |line|
        yield line
      end
    end
  ensure
    infile.close
  end

  def all_messages
    files = Dir["#{MBOX_DIR}/#{MBOX_SUBDIR}/*"]

    CATEGORY_MAPPINGS.keys.each do |k|
      files << Dir["#{MBOX_DIR}/#{k}/*"]
    end

    files.flatten!

    files.sort!

    files.each_with_index do |f, idx|
      print_warning "\nProcessing: #{f}"
      start_time = Time.now

      if SPLIT_AT.present?
        msg = ""
        message_count = 0

        each_line(f) do |line|
          line = line.scrub
          if line =~ SPLIT_AT
            p message_count += 1
            if !msg.empty?
              mail = Mail.read_from_string(msg)
              yield mail, f
              print_status(idx, files.size, start_time)
              msg = ""
            end
          end
          msg << line
        end

        if !msg.empty?
          mail = Mail.read_from_string(msg)
          yield mail, f
          print_status(idx, files.size, start_time)
          msg = ""
        end
      else
        raw = File.read(f)
        mail = Mail.read_from_string(raw)
        yield mail, f
        print_status(idx, files.size, start_time)
      end

    end
  end

  def massage_indices
    db = open_db
    db.execute "UPDATE emails SET reply_to = null WHERE reply_to = ''"

    rows = db.execute "SELECT msg_id, title, reply_to FROM emails ORDER BY datetime(email_date) ASC"

    msg_ids = {}
    titles = {}
    rows.each do |row|
      msg_ids[row[0]] = true
      if titles[row[1]].nil?
        titles[row[1]] = row[0]
      end
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
      db.execute "UPDATE emails SET reply_to = NULL WHERE msg_id IN (#{not_found.map { |nf| "'#{nf}'" }.join(',')})"
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

  def extract_name(mail)
    from_name = nil
    from = mail[:from]

    from_email = nil
    if mail.from.present?
      from_email = mail.from.dup
      if from_email.kind_of?(Array)
        if from_email[0].nil?
          print_warning "Cannot find email address (ignoring)!\n#{mail}"
        else
          from_email = from_email.first.dup
          from_email.gsub!(/ at /, '@')
          from_email.gsub!(/ [at] /, '@')
          # strip real names in ()s. Todo: read into name
          from_email.gsub!(/ \(.*$/, '')
          from_email.gsub!(/ /, '')
        end
      end
    end

    display_names = from.try(:display_names)
    if display_names.present?
      from_name = display_names.first
    end

    if from_name.blank? && from.to_s =~ /\(([^\)]+)\)/
      from_name = Regexp.last_match[1]
    end
    from_name = from.to_s if from_name.blank?

    [from_email, from_name]
  end

  def print_warning(message)
    $stderr.puts "#{message}"
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
        message TEXT NOT NULL,
        category VARCHAR(255) NOT NULL
      );
    SQL

    db.execute "CREATE INDEX by_title ON emails (title)"
    db.execute "CREATE INDEX by_email ON emails (from_email)"

    puts "", "creating indices"

    all_messages do |mail, filename|

      directory = filename.sub("#{MBOX_DIR}/", '').split("/")[0]

      category = CATEGORY_MAPPINGS[directory] || CATEGORY_MAPPINGS['default'] || 'uncategorized'

      msg_id = mail['Message-ID'].to_s

      # Many ways to get a name
      from_email, from_name = extract_name(mail)

      title = clean_title(mail['Subject'].to_s)
      reply_to = mail['In-Reply-To'].to_s
      email_date = mail['date'].to_s
      email_date = DateTime.parse(email_date).to_s unless email_date.blank?

      if from_email.kind_of?(String)
        unless from_email.match(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
          print_warning "Ignoring bad email address #{from_email} in #{msg_id}"
        else
          db.execute "INSERT OR IGNORE INTO emails (msg_id,
                                                from_email,
                                                from_name,
                                                title,
                                                reply_to,
                                                email_date,
                                                message,
                                                category)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                     [msg_id, from_email, from_name, title, reply_to, email_date, mail.to_s, category]
        end
      end
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
    title = title.gsub(/\[#{Regexp.escape(LIST_NAME)}\]/, '').strip

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
    if original_length > title.length
      clean_title(title)
    else
      title
    end
  end

  def clean_raw(input)
    raw = input.dup
    raw.scrub!
    raw.gsub!(/-- \nYou received this message because you are subscribed to the Google Groups "[^"]*" group.\nTo unsubscribe from this group and stop receiving emails from it, send an email to [^+@]+\+unsubscribe@googlegroups.com\.\nFor more options, visit https:\/\/groups\.google\.com\/groups\/opt_out\./, '')

    raw
  end

  def import_users
    puts "", "importing users"
    db = open_db

    all_users = db.execute("SELECT name, email FROM users")
    total_count = all_users.size

    batches(BATCH_SIZE) do |offset|
      users = all_users[offset..offset + BATCH_SIZE - 1]
      break if users.nil?
      next if all_records_exist? :users, users.map { |u| u[1] }

      create_users(users, total: total_count, offset: offset) do |u|
        {
          id:           u[1],
          email:        u[1],
          name:         u[0],
          trust_level:  DEFAULT_TRUST_LEVEL,
        }
      end
    end
  ensure
    db.close
  end

  def replace_email_addresses
    puts "", "replacing email addresses with @usernames"
    post = Post.new

    total_count = User.real.count
    progress_count = 0
    start_time = Time.now

    # from: https://meta.discourse.org/t/replace-a-string-in-all-posts/48729/17
    # and https://github.com/discourse/discourse/blob/master/lib/tasks/posts.rake#L114-L136
    User.find_each do |u|
      i = 0
      find = u.email.dup
      replace = "@#{u.username}"
      if !replace.include? "@"
        puts "Skipping #{replace}"
      end

      found = Post.where("raw ILIKE ?", "%#{find}%")
      next if found.nil?
      next if found.count < 1

      found.each do |p|
        new_raw = p.raw.dup
        new_raw = new_raw.gsub!(/#{Regexp.escape(find)}/i, replace) || new_raw
        if new_raw != p.raw
          p.revise(Discourse.system_user, { raw: new_raw }, bypass_bump: true)
          print_warning "\nReplaced #{find} with #{replace} in topic #{p.topic_id}"
        end
      end
      progress_count += 1
      puts ""
      print_status(progress_count, total_count, start_time)
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

    db = open_db
    all_topics = db.execute("SELECT msg_id,
                                    from_email,
                                    from_name,
                                    title,
                                    email_date,
                                    message,
                                    category
                            FROM emails
                            WHERE reply_to IS NULL
                            ORDER BY DATE(email_date)")

    topic_count = all_topics.size

    batches(BATCH_SIZE) do |offset|
      topics = all_topics[offset..offset + BATCH_SIZE - 1]
      break if topics.nil?

      next if all_records_exist? :posts, topics.map { |t| t[0] }

      create_posts(topics, total: topic_count, offset: offset) do |t|
        raw_email = t[5]
        receiver = Email::Receiver.new(raw_email)
        mail = Mail.read_from_string(raw_email)
        mail.body

        from_email, _ = extract_name(mail)
        selected = receiver.select_body
        next unless selected
        selected = selected.join('') if selected.kind_of?(Array)

        title = mail.subject

        username = User.find_by_email(from_email).username

        # import the attachments
        raw = ""
        mail.attachments.each do |attachment|
          tmp = Tempfile.new("discourse-email-attachment")
          begin
            # read attachment
            File.open(tmp.path, "w+b") { |f| f.write attachment.body.decoded }
            # create the upload for the user
            upload = UploadCreator.new(tmp, attachment.filename).create_for(user_id_from_imported_user_id(from_email) || Discourse::SYSTEM_USER_ID)
            if upload && upload.errors.empty?
              raw << "\n\n#{receiver.attachment_markdown(upload)}\n\n"
            end
          ensure
            tmp.try(:close!) rescue nil
          end
        end

        user_id = user_id_from_imported_user_id(from_email) || Discourse::SYSTEM_USER_ID

        raw = selected.force_encoding(selected.encoding).encode("UTF-8")
        raw = clean_raw(raw)
        raw = raw.dup.to_s
        raw.gsub!(/#{from_email}/, "@#{username}")
        cleaned_email = from_email.dup.sub(/@/, ' at ')
        raw.gsub!(/#{cleaned_email}/, "@#{username}")
        { id: t[0],
          title: clean_title(title),
          user_id: user_id,
          created_at: mail.date,
          category: t[6],
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
                          WHERE reply_to IS NOT NULL
                          ORDER BY DATE(email_date)
                          ")

    post_count = replies.size

    puts "Replies: #{post_count}"

    batches(BATCH_SIZE) do |offset|
      posts = replies[offset..offset + BATCH_SIZE - 1]
      break if posts.nil?
      break if posts.count < 1

      next if all_records_exist? :posts, posts.map { |p| p[0] }

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

        from_email, _ = extract_name(mail)

        selected = receiver.select_body
        selected = selected.join('') if selected.kind_of?(Array)
        next unless selected

        raw = selected.force_encoding(selected.encoding).encode("UTF-8")
        username = User.find_by_email(from_email).username

        user_id = user_id_from_imported_user_id(from_email) || Discourse::SYSTEM_USER_ID
        raw = clean_raw(raw).to_s
        raw.gsub!(/#{from_email}/, "@#{username}")
        cleaned_email = from_email.dup.sub(/@/, ' at ')
        raw.gsub!(/#{cleaned_email}/, "@#{username}")
        # import the attachments
        mail.attachments.each do |attachment|
          tmp = Tempfile.new("discourse-email-attachment")
          begin
            # read attachment
            File.open(tmp.path, "w+b") { |f| f.write attachment.body.decoded }
            # create the upload for the user
            upload = UploadCreator.new(tmp, attachment.filename).create_for(user_id_from_imported_user_id(from_email) || Discourse::SYSTEM_USER_ID)
            if upload && upload.errors.empty?
              raw << "\n\n#{receiver.attachment_markdown(upload)}\n\n"
            end
          ensure
            tmp.try(:close!) rescue nil
          end
        end

        { id: id,
          topic_id: topic_id,
          user_id: user_id_from_imported_user_id(from_email) || Discourse::SYSTEM_USER_ID,
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
