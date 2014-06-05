require File.expand_path(File.dirname(__FILE__) + "/base.rb")

require "mysql2"
require "csv"

# TODO
#
# It would be better to have a mysql dump of the joomla users too.
# But I got a csv file and had an awful time trying to use the LOAD DATA command to put it into a table.
# So, this script reads Joomla users from a csv file for now.

class ImportScripts::Kunena < ImportScripts::Base

  KUNENA_DB    = "kunena"
  JOOMLA_USERS = "j-users.csv"

  def initialize
    super

    @joomla_users_file = ARGV[0]
    raise ArgumentError.new('Joomla users file argument missing. Provide full path to joomla users csv file.') if !@joomla_users_file.present?

    @users = {}

    @client = Mysql2::Client.new(
      host: "localhost",
      username: "root",
      #password: "password",
      database: KUNENA_DB
    )
  end

  def execute
    check_files_exist

    parse_users

    create_users(@users) do |id, user|
      { id: id,
        email: user[:email],
        username: user[:username],
        created_at: user[:created_at],
        bio_raw: user[:bio],
        moderator: user[:moderator] ? true : false,
        suspended_at: user[:suspended] ? Time.zone.now : nil,
        suspended_till: user[:suspended] ? 100.years.from_now : nil }
    end

    create_categories(@client.query("SELECT id, parent, name, description, ordering FROM jos_kunena_categories ORDER BY parent, id;")) do |c|
      h = {id: c['id'], name: c['name'], description: c['description'], position: c['ordering'].to_i}
      if c['parent'].to_i > 0
        parent = category_from_imported_category_id(c['parent'])
        h[:parent_category_id] = parent.id if parent
      end
      h
    end

    import_posts

    begin
      create_admin(email: 'neil.lalonde@discourse.org', username: UserNameSuggester.suggest('neil'))
    rescue => e
      puts '', "Failed to create admin user"
      puts e.message
    end
  end

  def check_files_exist
    raise ArgumentError.new("File does not exist: #{@joomla_users_file}") unless File.exist?(@joomla_users_file)
  end

  def read_csv(f)
    data = File.read(f)
    data.gsub!(/\" \n/,"\"\n")
    data.gsub!(/\\\"/,";;")
    data.gsub!(/\\/,"\n")
    data
  end

  def parse_users
    # Need to merge data from joomla with kunena

    puts "parsing joomla user data from #{@joomla_users_file}"
    CSV.foreach(@joomla_users_file) do |u|
      next unless u[0].to_i > 0 and u[1].present? and u[2].present?
      username = u[1].gsub(' ', '_').gsub(/[^A-Za-z0-9_]/, '')[0,User.username_length.end]
      if username.length < User.username_length.first
        username = username * User.username_length.first
      end
      @users[u[0].to_i] = {id: u[0].to_i, username: username, email: u[2], created_at: Time.zone.parse(u[3])}
    end

    puts "parsing kunena user data from mysql"
    results = @client.query("SELECT userid, signature, moderator, banned FROM jos_kunena_users;", cache_rows: false)
    results.each do |u|
      next unless u['userid'].to_i > 0
      user = @users[u['userid'].to_i]
      if user
        user[:bio] = u['signature']
        user[:moderator] = (u['moderator'].to_i == 1)
        user[:suspended] = u['banned'].present?
      end
    end
  end

  def import_posts
    puts '', "creating topics and posts"

    total_count = @client.query("SELECT COUNT(*) count FROM jos_kunena_messages m;").first['count']

    batch_size = 1000

    batches(batch_size) do |offset|
      results = @client.query("
        SELECT m.id id,
               m.thread thread,
               m.parent parent,
               m.catid catid,
               m.userid userid,
               m.subject subject,
               m.time time,
               t.message message
        FROM jos_kunena_messages m,
             jos_kunena_messages_text t
        WHERE m.id = t.mesid
        ORDER BY m.id
        LIMIT #{batch_size}
        OFFSET #{offset};
      ", cache_rows: false)

      break if results.size < 1

      create_posts(results, total: total_count, offset: offset) do |m|
        skip = false
        mapped = {}

        mapped[:id] = m['id']
        mapped[:user_id] = user_id_from_imported_user_id(m['userid']) || find_user_by_import_id(m['userid']).try(:id) || -1
        mapped[:raw] = m["message"]
        mapped[:created_at] = Time.zone.at(m['time'])
        mapped[:custom_fields] = {import_id: m['id']}

        if m['id'] == m['thread']
          mapped[:category] = category_from_imported_category_id(m['catid']).try(:name)
          mapped[:title] = m['subject']
        else
          parent = topic_lookup_from_imported_post_id(m['parent'])
          if parent
            mapped[:topic_id] = parent[:topic_id]
            mapped[:reply_to_post_number] = parent[:post_number] if parent[:post_number] > 1
          else
            puts "Parent post #{m['parent']} doesn't exist. Skipping #{m["id"]}: #{m["subject"][0..40]}"
            skip = true
          end
        end

        skip ? nil : mapped
      end
    end
  end
end

ImportScripts::Kunena.new.perform
