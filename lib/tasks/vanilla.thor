require "csv"

class Vanilla < Thor

  desc "import", "Imports posts from a Vanilla export"
  method_option :file, aliases: '-f', required: true, desc: "The vanilla file to import"

  def import

    unless File.exist?(options[:file])
      puts "File '#{options[:file]}' not found"
      exit 1
    end

    load_rails

    file = read_file(options[:file])
    parse_file(file)

    disable_rate_limiter

    create_users
    create_user_memberships

    create_categories
    create_topics
    create_posts
    update_topic_statuses

    create_private_topics
    create_private_posts
  ensure
    enable_rate_limiter
  end

  no_commands do

    def load_rails
      puts "loading rails..."
      require "./config/environment"
    end

    def disable_rate_limiter
      puts "disabling rate limiter..."
      RateLimiter.disable
    end

    def read_file(file)
      puts "reading file..."
      string = File.read(file).gsub("\\N", "").gsub(/\\$\n/m, "\\n").gsub("\\,", ",").gsub(/(?<!\\)\\"/, '""').gsub(/\\\\\\"/, '\\""')
      StringIO.new(string)
    end

    def parse_file(file)
      # TODO: parse header & validate version number
      header = file.readline

      until file.eof?
        line = file.readline

        next if line.blank?
        next if line.start_with?("//")

        if m = /^Table: (\w+)/.match(line)
          # extract table name
          table = m[1]
          # read the data until an empty line
          data = []
          # first line is the table definition, turn that into a proper csv header
          data << file.readline.split(",").map { |c| c.split(":")[0].underscore }.join(",")
          until (line = file.readline).blank?
            data << line.strip
          end
          # parse the data
          puts "parsing #{table.underscore.pluralize}..."
          parsed_data = CSV.parse(data.join("\n"), headers: true, header_converters: :symbol).map { |row| row.to_hash }
          instance_variable_set("@#{table.underscore.pluralize}".to_sym, parsed_data)
        end
      end
    end

    def create_users
      puts "creating users..."
      users_created = 0

      @users.each do |user|
        begin
          next if user[:name] == "[Deleted User]"

          user[:new_id] = User.create!(
            name: user[:name],
            email: user[:email],
            username: UserNameSuggester.suggest(user[:name]),
            created_at: DateTime.strptime(user[:date_inserted], "%Y-%m-%d %H:%M:%S"),
            trust_level: TrustLevel.levels[:basic],
            bio_raw: (user[:discovery_text] || "").gsub("\\n", "\n")
          ).id

          users_created += 1
        rescue ActiveRecord::RecordInvalid
          # email has already been taken...
        end
      end

      puts "created #{users_created} users!"
    end

    def create_user_memberships
      puts "creating user memberships..."
      add_administrators
      add_moderators
    end

    def add_administrators
      puts "granting admin rights..."

      admin_role_id = @roles.select { |r| r[:name] == "Administrator" }.first[:role_id]
      admin_emails = @user_roles.select { |ur| ur[:role_id] == admin_role_id }.map { |ur| @users.select { |u| u[:user_id] == ur[:user_id] }.first[:email] }
      admin_emails.each { |admin_email| User.where(email: admin_email).first.grant_admin! }

      puts "#{admin_emails.size} admins!"
    end

    def add_moderators
      puts "granting moderation rights..."

      moderator_role_id = @roles.select { |r| r[:name] == "Moderator" }.first[:role_id]
      moderator_emails = @user_roles.select { |ur| ur[:role_id] == moderator_role_id }.map { |ur| @users.select { |u| u[:user_id] == ur[:user_id] }.first[:email] }
      moderator_emails.each { |admin_email| User.where(email: admin_email).first.grant_moderation! }

      puts "#{moderator_emails.size} moderators!"
    end

    def create_categories
      puts "creating categories..."
      categories_created = 0

      @categories.each do |category|
        next if category[:category_id].to_i == -1
        # TODO: should not allow more than 2 levels
        next if category[:parent_category_id].to_i != -1

        category[:new_id] = Category.create!(
          name: category[:name],
          color: "AB9364",
          text_color: "FFF",
          position: category[:sort].to_i,
          user: get_user_by_previous_id(category[:insert_user_id]) || Discourse.system_user,
          created_at: DateTime.strptime(category[:date_inserted], "%Y-%m-%d %H:%M:%S"),
          description: category[:description]
        ).id

        categories_created += 1
      end

      puts "created #{categories_created} categories!"
    end

    def create_topics
      puts "creating topics..."
      topics_created = 0

      @discussions.each do |discussion|
        user = get_user_by_previous_id(discussion[:insert_user_id]) || Discourse.system_user
        discussion[:created_at] = DateTime.strptime(discussion[:date_inserted], "%Y-%m-%d %H:%M:%S")

        options = {
          title: discussion[:name],
          raw: discussion[:body].gsub("\\n", "\n"),
          created_at: discussion[:created_at],
          skip_validations: true
        }
        options[:category] = get_category_by_previous_id(discussion[:category_id]).try(:name) if discussion[:category_id]

        post = PostCreator.new(user, options).create

        discussion[:new_id] = post.topic.id
        topics_created += 1
      end

      puts "created #{topics_created} topics!"
    end

    def create_posts
      puts "creating posts..."
      posts_created = 0

      @comments.each do |comment|
        discussion = @discussions.select { |d| d[:discussion_id] == comment[:discussion_id] }.first
        unless discussion && discussion[:new_id]
          puts "could not find discussion ##{comment[:discussion_id]}"
          next
        end

        topic_id = discussion[:new_id]
        user = get_user_by_previous_id(comment[:insert_user_id]) || Discourse.system_user

        options = {
          topic_id: topic_id,
          raw: comment[:body].gsub("\\n", "\n"),
          created_at: DateTime.strptime(comment[:date_inserted], "%Y-%m-%d %H:%M:%S"),
          skip_validations: true
        }

        post = PostCreator.new(user, options).create

        comment[:new_id] = post.id
        posts_created += 1
      end

      puts "created #{posts_created} posts!"
    end

    def update_topic_statuses
      puts "updating topic statuses..."

      @discussions.each do |discussion|
        next unless topic_id = discussion[:new_id]

        # HACK to make sure bumped_at is properly set

        sql = <<-SQL
          UPDATE topics
          SET    views = :views,
                 closed = :closed,
                 pinned_at = :pinned_at,
                 bumped_at = (SELECT created_at FROM posts WHERE topic_id = :topic_id ORDER BY created_at DESC LIMIT 1)
          WHERE id = :topic_id
        SQL

        Topic.exec_sql(sql,
          views: discussion[:count_views].to_i,
          closed: discussion[:closed] == "1",
          pinned_at: discussion[:announce] == "1" ? discussion[:created_at] : nil,
          topic_id: topic_id
        )
      end
    end

    def create_private_topics
      puts "creating private topics..."
      private_topics_created = 0

      @conversations.each do |conversation|
        # select the first conversation message
        message = @conversation_messages.select { |cm| cm[:message_id] == conversation[:first_message_id] }.first
        # list all other user ids in the conversation
        user_ids_in_conversation = @user_conversations.select { |uc| uc[:conversation_id] == conversation[:conversation_id] && uc[:user_id] != conversation[:insert_user_id] }.map { |uc| uc[:user_id] }
        # retrieve their emails
        user_emails_in_conversation = @users.select { |u| user_ids_in_conversation.include?(u[:user_id]) }.map { |u| u[:email] }
        # retrieve their usernames from the database
        target_usernames = User.where("email in (?)", user_emails_in_conversation).pluck(:username).to_a

        next if target_usernames.empty?

        user = get_user_by_previous_id(conversation[:insert_user_id]) || Discourse.system_user

        options = {
          archetype: Archetype::private_message,
          title: "Private message from #{user.username}",
          raw: message[:body].gsub("\\n", "\n"),
          target_usernames: target_usernames.join(","),
          created_at: DateTime.strptime(conversation[:date_inserted], "%Y-%m-%d %H:%M:%S"),
          skip_validations: true
        }

        post = PostCreator.new(user, options).create

        conversation[:new_id] = post.topic.id
        private_topics_created += 1
      end

      puts "created #{private_topics_created} private topics!"
    end

    def create_private_posts
      puts "creating private posts..."
      private_posts_created = 0

      @conversation_messages.each do |message|
        conversation = @conversations.select { |c| c[:conversation_id] == message[:conversation_id] }.first
        next if conversation[:first_message_id] == message[:message_id]

        next unless topic_id = conversation[:new_id]

        user = get_user_by_previous_id(message[:insert_user_id]) || Discourse.system_user

        options = {
          topic_id: topic_id,
          raw: message[:body].gsub("\\n", "\n"),
          created_at: DateTime.strptime(message[:date_inserted], "%Y-%m-%d %H:%M:%S"),
          skip_validations: true
        }

        post = PostCreator.new(user, options).create
        next unless post && post.errors.empty?

        message[:new_id] = post.id
        private_posts_created += 1
      end

      puts "created #{private_posts_created} private posts!"
    end

    def get_user_by_previous_id(previous_id)
      user = @users.select { |u| u[:user_id] == previous_id }.first
      User.find(user[:new_id]) if user && user[:new_id]
    end

    def get_category_by_previous_id(previous_id)
      category = @categories.select { |c| c[:category_id] == previous_id }.first
      Category.find(category[:new_id]) if category && category[:new_id]
    end

    def enable_rate_limiter
      puts "enabling rate limiter..."
      RateLimiter.enable
    end

  end

end
