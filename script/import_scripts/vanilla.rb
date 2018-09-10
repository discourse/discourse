require "csv"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

class ImportScripts::Vanilla < ImportScripts::Base

  def initialize
    super

    @vanilla_file = ARGV[0]
    raise ArgumentError.new('Vanilla file argument missing. Provide full path to vanilla csv file.') if @vanilla_file.blank?

    @use_lastest_activity_as_user_bio = true if ARGV.include?('use-latest-activity-as-user-bio')
  end

  def execute
    check_file_exist
    parse_file

    import_users
    import_categories

    import_topics
    import_posts

    import_private_topics
    import_private_posts
  end

  private

  def check_file_exist
    raise ArgumentError.new("File does not exist: #{@vanilla_file}") unless File.exist?(@vanilla_file)
  end

  def parse_file
    puts "parsing file..."
    file = read_file

    # TODO: parse header & validate version number
    header = file.readline

    until file.eof?
      line = file.readline
      next if line.blank?
      next if line.start_with?("//")

      if m = /^Table: (\w+)/.match(line)
        # extract table name
        table = m[1].underscore.pluralize
        # read the data until an empty line
        data = []
        # first line is the table definition, turn that into a proper csv header
        data << file.readline.split(",").map { |c| c.split(":")[0].underscore }.join(",")
        until (line = file.readline).blank?
          data << line.strip
        end
        # PERF: don't parse useless tables
        useless_tables = ["user_meta"]
        useless_tables << "activities" unless @use_lastest_activity_as_user_bio
        next if useless_tables.include?(table)
        # parse the data
        puts "parsing #{table}..."
        parsed_data = CSV.parse(data.join("\n"), headers: true, header_converters: :symbol).map { |row| row.to_hash }
        instance_variable_set("@#{table}".to_sym, parsed_data)
      end
    end
  end

  def read_file
    puts "reading file..."
    string = File.read(@vanilla_file).gsub("\\N", "")
      .gsub(/\\$\n/m, "\\n")
      .gsub("\\,", ",")
      .gsub(/(?<!\\)\\"/, '""')
      .gsub(/\\\\\\"/, '\\""')
    StringIO.new(string)
  end

  def import_users
    puts "", "importing users..."

    admin_role_id = @roles.select { |r| r[:name] == "Administrator" }.first[:role_id]
    moderator_role_id = @roles.select { |r| r[:name] == "Moderator" }.first[:role_id]

    activities = (@activities || []).reject { |a| a[:activity_user_id] != a[:regarding_user_id] }

    create_users(@users) do |user|
      next if user[:name] == "[Deleted User]"

      if @use_lastest_activity_as_user_bio
        last_activity = activities.select { |a| user[:user_id] == a[:activity_user_id] }.last
        bio_raw = last_activity.try(:[], :story) || ""
      else
        bio_raw = user[:discovery_text]
      end

      u = {
        id: user[:user_id],
        email: user[:email],
        username: user[:name],
        created_at: parse_date(user[:date_inserted]),
        bio_raw: clean_up(bio_raw),
        avatar_url: user[:photo],
        moderator: @user_roles.select { |ur| ur[:user_id] == user[:user_id] }.map { |ur| ur[:role_id] }.include?(moderator_role_id),
        admin: @user_roles.select { |ur| ur[:user_id] == user[:user_id] }.map { |ur| ur[:role_id] }.include?(admin_role_id),
      }

      u
    end
  end

  def import_categories
    puts "", "importing categories..."

    # save some information about the root category
    @root_category = @categories.select { |c| c[:category_id] == "-1" }.first
    @root_category_created_at = parse_date(@root_category[:date_inserted])

    # removes root category
    @categories.reject! { |c| c[:category_id] == "-1" }

    # adds root's child categories
    first_level_categories = @categories.select { |c| c[:parent_category_id] == "-1" }
    if first_level_categories.count > 0
      puts "", "importing first-level categories..."
      create_categories(first_level_categories) { |category| import_category(category) }

      # adds other categories
      second_level_categories = @categories.select { |c| c[:parent_category_id] != "-1" }
      if second_level_categories.count > 0
        puts "", "importing second-level categories..."
        create_categories(second_level_categories) { |category| import_category(category) }
      end
    end
  end

  def import_category(category)
    c = {
      id: category[:category_id],
      name: category[:name],
      user_id: user_id_from_imported_user_id(category[:insert_user_id]) || Discourse::SYSTEM_USER_ID,
      position: category[:sort].to_i,
      created_at: parse_category_date(category[:date_inserted]),
      description: clean_up(category[:description]),
    }
    if category[:parent_category_id] != "-1"
      c[:parent_category_id] = category_id_from_imported_category_id(category[:parent_category_id])
    end
    c
  end

  def parse_category_date(date)
    date == "0000-00-00 00:00:00" ? @root_category_created_at : parse_date(date)
  end

  def import_topics
    puts "", "importing topics..."

    create_posts(@discussions) do |discussion|
      {
        id: "discussion#" + discussion[:discussion_id],
        user_id: user_id_from_imported_user_id(discussion[:insert_user_id]) || Discourse::SYSTEM_USER_ID,
        title: discussion[:name],
        category: category_id_from_imported_category_id(discussion[:category_id]),
        raw: clean_up(discussion[:body]),
        created_at: parse_date(discussion[:date_inserted]),
      }
    end
  end

  def import_posts
    puts "", "importing posts..."

    create_posts(@comments) do |comment|
      next unless t = topic_lookup_from_imported_post_id("discussion#" + comment[:discussion_id])

      {
        id: "comment#" + comment[:comment_id],
        user_id: user_id_from_imported_user_id(comment[:insert_user_id]) || Discourse::SYSTEM_USER_ID,
        topic_id: t[:topic_id],
        raw: clean_up(comment[:body]),
        created_at: parse_date(comment[:date_inserted]),
      }
    end
  end

  def import_private_topics
    puts "", "importing private topics..."

    create_posts(@conversations) do |conversation|
      next if conversation[:first_message_id].blank?

      # list all other user ids in the conversation
      user_ids_in_conversation = @user_conversations.select { |uc| uc[:conversation_id] == conversation[:conversation_id] && uc[:user_id] != conversation[:insert_user_id] }
        .map { |uc| uc[:user_id] }
      # retrieve their emails
      user_emails_in_conversation = @users.select { |u| user_ids_in_conversation.include?(u[:user_id]) }
        .map { |u| u[:email] }
      # retrieve their usernames from the database
      target_usernames = User.where("email IN (?)", user_emails_in_conversation).pluck(:username).to_a

      next if target_usernames.blank?

      user = find_user_by_import_id(conversation[:insert_user_id]) || Discourse.system_user
      first_message = @conversation_messages.select { |cm| cm[:message_id] == conversation[:first_message_id] }.first

      {
        archetype: Archetype.private_message,
        id: "conversation#" + conversation[:conversation_id],
        user_id: user.id,
        title: "Private message from #{user.username}",
        target_usernames: target_usernames,
        raw: clean_up(first_message[:body]),
        created_at: parse_date(conversation[:date_inserted]),
      }
    end
  end

  def import_private_posts
    puts "", "importing private posts..."

    first_message_ids = Set.new(@conversations.map { |c| c[:first_message_id] }.to_a)
    @conversation_messages.reject! { |cm| first_message_ids.include?(cm[:message_id]) }

    create_posts(@conversation_messages) do |message|
      next unless t = topic_lookup_from_imported_post_id("conversation#" + message[:conversation_id])

      {
        archetype: Archetype.private_message,
        id: "message#" + message[:message_id],
        user_id: user_id_from_imported_user_id(message[:insert_user_id]) || Discourse::SYSTEM_USER_ID,
        topic_id: t[:topic_id],
        raw: clean_up(message[:body]),
        created_at: parse_date(message[:date_inserted]),
      }
    end
  end

  def parse_date(date)
    DateTime.strptime(date, "%Y-%m-%d %H:%M:%S")
  end

  def clean_up(raw)
    return "" if raw.blank?
    raw.gsub("\\n", "\n")
      .gsub(/<\/?pre\s*>/i, "\n```\n")
      .gsub(/<\/?code\s*>/i, "`")
      .gsub("&lt;", "<")
      .gsub("&gt;", ">")
  end

end

ImportScripts::Vanilla.new.perform
