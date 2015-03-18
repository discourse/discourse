require "csv"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require "optparse"

class ImportScripts::VBulletinOld < ImportScripts::Base

  attr_reader :options

  def self.run
    options = Options.new

    begin
      options.parse!
    rescue OptionParser::MissingArgument, OptionParser::InvalidArgument => e
      $stderr.puts e.to_s.capitalize
      $stderr.puts options.usage
      exit 1
    end

    new(options).perform
  end

  def initialize(options)
    super()

    @options = options
  end

  def execute
    load_groups_mapping
    load_groups
    load_users

    load_categories_mappings
    load_categories
    load_categories_permissions

    load_topics
    load_posts

    import_groups
    import_users
    create_groups_membership

    import_categories
    # import_category_groups

    preprocess_posts

    import_topics
    import_posts

    postprocess_posts

    close_topics

    puts "", "Done"
  end

  private

    ############################################################################
    #                                   LOAD                                   #
    ############################################################################

    def default_csv_options
      @@default_csv_options ||= { headers: true, header_converters: :symbol }
    end

    def load_groups_mapping
      return if @options.group_mapping.blank?

      puts "", "Loading groups mappings from '#{@options.group_mapping}'..."

      data = File.read(@options.group_mapping)
      @groups_mappings = CSV.parse(data, default_csv_options).map { |row| row.to_hash }

      @mapped_groups = {}
      @new_group_ids = {}

      @groups_mappings.each do |gm|
        @mapped_groups[gm[:old_id]] = gm
        @new_group_ids[gm[:new_id]] ||= true
      end

      puts "Loaded #{@groups_mappings.count} groups mappings for #{@new_group_ids.count} groups!"
    end

    def load_groups
      puts "", "Loading groups from '#{@options.user_group}'..."

      data = File.read(@options.user_group)
      @all_groups = CSV.parse(data, default_csv_options).map { |row| row.to_hash }

      # reject unmapped groups
      @groups = @all_groups.reject { |group| !@new_group_ids.has_key?(group[:usergroupid]) }

      puts "Loaded #{@groups.count} out of #{@all_groups.count} groups!"
    end

    def load_users
      puts "", "Loading users from '#{@options.user}'..."

      data = File.read(@options.user)
      csv_options = default_csv_options.merge({ col_sep: "\t", quote_char: "\u200B" })
      @users = CSV.parse(data, csv_options).map { |row| row.to_hash }
      original_count = @users.count

      if @mapped_groups.try(:size) > 0
        # show some stats
        group_ids = Set.new(@users.map { |user| user[:usergroupid].to_i })
        group_ids.sort.each do |group_id|
          count = @users.select { |user| user[:usergroupid].to_i == group_id }.count
          group = @all_groups.select { |group| group[:usergroupid].to_i == group_id }.first.try(:[], :title)
          puts "\t- #{count} users in usergroup ##{group_id} (#{group})"
        end
        # reject users from unmapped groups
        @users.reject! { |user| !@mapped_groups.has_key?(user[:usergroupid]) }
        # change mapped groups
        @users.each { |user| user[:usergroupid] = @mapped_groups[user[:usergroupid]][:new_id] }
      end

      puts "Loaded #{@users.count} out of #{original_count} users!"
    end

    def load_categories_mappings
      return if @options.forum_mapping.blank?

      puts "", "Loading categories mappings from '#{@options.forum_mapping}'..."

      data = File.read(@options.forum_mapping)
      @categories_mappings = CSV.parse(data, default_csv_options).map { |row| row.to_hash }

      @mapped_categories = {}
      @new_category_ids = {}

      @categories_mappings.each do |cm|
        @mapped_categories[cm[:old_id]] = cm
        @new_category_ids[cm[:new_id]] ||= true
      end

      puts "Loaded #{@categories_mappings.count} categories mappings for #{@new_category_ids.count} categories!"
    end

    def load_categories
      puts "", "Loading categories from '#{@options.forum}'..."

      data = File.read(@options.forum)
      @categories = CSV.parse(data, default_csv_options).map { |row| row.to_hash }
      original_count = @categories.count

      if @new_category_ids.try(:size) > 0
        # reject unmapped categories
        @categories.reject! { |category| !@new_category_ids.has_key?(category[:forumid]) }
        # update mapped categories' title
        @categories.each { |category| category[:title] = @mapped_categories[category[:forumid]][:new_name] }
      end

      puts "Loaded #{@categories.count} out of #{original_count} categories!"
    end

    # extracted from the "bitfield_vbulletin.xml" file
    VB_FORUM_PERMISSIONS_CAN_VIEW = 1
    VB_FORUM_PERMISSIONS_CAN_VIEW_THREADS = 524288
    VB_FORUM_PERMISSIONS_CAN_REPLY_OWN = 32
    VB_FORUM_PERMISSIONS_CAN_REPLY_OTHERS = 64
    VB_FORUM_PERMISSIONS_CAN_POST_NEW = 16

    def translate_forum_permissions(permissions)
      can_see    = ((permissions & VB_FORUM_PERMISSIONS_CAN_VIEW) | (permissions & VB_FORUM_PERMISSIONS_CAN_VIEW_THREADS)) > 0
      can_reply  = ((permissions & VB_FORUM_PERMISSIONS_CAN_REPLY_OWN) | (permissions & VB_FORUM_PERMISSIONS_CAN_REPLY_OTHERS)) > 0
      can_create = (permissions & VB_FORUM_PERMISSIONS_CAN_POST_NEW) > 0
      return CategoryGroup.permission_types[:full]        if can_create
      return CategoryGroup.permission_types[:create_post] if can_reply
      return CategoryGroup.permission_types[:readonly]    if can_see
      nil
    end

    def load_categories_permissions
      puts "", "Loading categories permissions from '#{@options.forum_permission}'..."

      data = File.read(@options.forum_permission)
      @categories_permissions = CSV.parse(data, default_csv_options).map { |row| row.to_hash }
      original_count = @categories_permissions.count

      # reject unmapped groups
      if @mapped_groups.try(:size) > 0
        @categories_permissions.reject! { |cp| !@mapped_groups.has_key?(cp[:usergroupid]) }
      end

      # reject unmapped categories
      if @mapped_categories.try(:size) > 0
        @categories_permissions.reject! { |cp| !@mapped_categories.has_key?(cp[:forumid]) }
      end

      # translate permissions
      @categories_permissions.each do |cp|
        cp[:permission] = translate_forum_permissions(cp[:forumpermissions].to_i)
        cp[:usergroupid] = @mapped_groups[cp[:usergroupid]][:new_id]
        cp[:forumid] = @mapped_categories[cp[:forumid]][:new_id]
      end

      # clean permissions up
      @categories_permissions.reject! { |cp| cp[:permission].nil? }

      puts "Loaded #{@categories_permissions.count} out of #{original_count} categories permissions!"
    end

    def load_topics
      puts "", "Loading topics from '#{@options.thread}'..."

      data = File.read(@options.thread)
      csv_options = default_csv_options.merge({ col_sep: "\t", quote_char: "\u200B" })
      @topics = CSV.parse(data, csv_options).map { |row| row.to_hash }
      original_count = @topics.count

      if @mapped_categories.try(:size) > 0
        # reject topics from unmapped categories
        @topics.reject! { |topic| !@mapped_categories.has_key?(topic[:forumid]) }
        # change mapped categories
        @topics.each do |topic|
          topic[:old_forumid] = topic[:forumid]
          topic[:forumid] = @mapped_categories[topic[:forumid]][:new_id]
        end
      end

      puts "Loaded #{@topics.count} out of #{original_count} topics!"
    end

    def load_posts
      puts "", "Loading posts from '#{@options.post}'..."

      data = File.read(@options.post)
      csv_options = default_csv_options.merge({ col_sep: "\t", quote_char: "\u200B" })
      @posts = CSV.parse(data, csv_options).map { |row| row.to_hash }
      original_count = @posts.count

      # reject posts without topics
      topic_ids = Set.new(@topics.map { |t| t[:threadid] })
      @posts.reject! { |post| !topic_ids.include?(post[:threadid]) }

      puts "Loaded #{@posts.count} out of #{original_count} posts!"
    end

    ############################################################################
    #                                  IMPORT                                  #
    ############################################################################

    def import_groups
      puts "", "Importing groups..."

      # sort the groups
      @groups.sort_by! { |group| group[:usergroupid].to_i }

      create_groups(@groups) do |group|
        {
          id: group[:usergroupid],
          name: group[:title],
        }
      end

    end

    def import_users
      puts "", "Importing users..."

      # sort the users
      @users.sort_by! { |user| user[:userid].to_i }

      @old_username_to_new_usernames = {}

      create_users(@users) do |user|
        @old_username_to_new_usernames[user[:username]] = UserNameSuggester.fix_username(user[:username])

        {
          id: user[:userid],
          username: @old_username_to_new_usernames[user[:username]],
          email: user[:email],
          website: user[:homepage],
          title: user[:usertitle],
          primary_group_id: group_id_from_imported_group_id(user[:usergroupid]),
          merge: true,
        }
      end

    end

    def create_groups_membership
      puts "", "Creating groups membership..."

      Group.find_each do |group|
        begin
          next if group.automatic

          puts "\t#{group.name}"

          next if GroupUser.where(group_id: group.id).count > 0

          user_ids_in_group = User.where(primary_group_id: group.id).pluck(:id).to_a
          next if user_ids_in_group.size == 0

          values = user_ids_in_group.map { |user_id| "(#{group.id}, #{user_id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)" }.join(",")

          User.exec_sql <<-SQL
            BEGIN;
            INSERT INTO group_users (group_id, user_id, created_at, updated_at) VALUES #{values};
            COMMIT;
          SQL

          Group.reset_counters(group.id, :group_users)
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        end
      end
    end

    def import_categories
      puts "", "Importing categories..."

      # sort categories
      @categories.sort_by! { |category| category[:forumid].to_i }

      create_categories(@categories) do |category|
        {
          id: category[:forumid],
          name: category[:title].strip[0...50],
          position: category[:displayorder].to_i,
          description: category[:description],
        }
      end

    end

    def import_category_groups
      puts "", "Importing category groups..."

      # TODO
    end

    def preprocess_posts
      puts "", "Preprocessing posts..."

      current = 0
      max = @posts.size

      @posts.each do |post|
        post[:raw] = preprocess_post_raw(post[:pagetext])
        current += 1
        print_status(current, max)
      end
    end

    def preprocess_post_raw(raw)
      return "" if raw.blank?

      raw = raw.gsub(/(\\r)?\\n/, "\n")
               .gsub("\\t", "\t")

      # remove attachments
      raw = raw.gsub(/\[attach[^\]]*\]\d+\[\/attach\]/i, "")

      # [HTML]...[/HTML]
      raw = raw.gsub(/\[html\]/i, "\n```html\n")
               .gsub(/\[\/html\]/i, "\n```\n")

      # [PHP]...[/PHP]
      raw = raw.gsub(/\[php\]/i, "\n```php\n")
               .gsub(/\[\/php\]/i, "\n```\n")

      # [HIGHLIGHT="..."]
      raw = raw.gsub(/\[highlight="?(\w+)"?\]/i) { "\n```#{$1.downcase}\n" }

      # [CODE]...[/CODE]
      # [HIGHLIGHT]...[/HIGHLIGHT]
      raw = raw.gsub(/\[\/?code\]/i, "\n```\n")
               .gsub(/\[\/?highlight\]/i, "\n```\n")

      # [SAMP]...[/SAMP]
      raw = raw.gsub(/\[\/?samp\]/i, "`")

      # replace all chevrons with HTML entities
      # NOTE: must be done
      #  - AFTER all the "code" processing
      #  - BEFORE the "quote" processing
      raw = raw.gsub(/`([^`]+)`/im) { "`" + $1.gsub("<", "\u2603") + "`" }
               .gsub("<", "&lt;")
               .gsub("\u2603", "<")

      raw = raw.gsub(/`([^`]+)`/im) { "`" + $1.gsub(">", "\u2603") + "`" }
               .gsub(">", "&gt;")
               .gsub("\u2603", ">")

      # [URL=...]...[/URL]
      raw = raw.gsub(/\[url="?(.+?)"?\](.+)\[\/url\]/i) { "[#{$2}](#{$1})" }

      # [URL]...[/URL]
      # [MP3]...[/MP3]
      raw = raw.gsub(/\[\/?url\]/i, "")
               .gsub(/\[\/?mp3\]/i, "")

      # [MENTION]<username>[/MENTION]
      raw = raw.gsub(/\[mention\](.+?)\[\/mention\]/i) do
        old_username = $1
        if @old_username_to_new_usernames.has_key?(old_username)
          old_username = @old_username_to_new_usernames[old_username]
        end
        "@#{old_username}"
      end

      # [MENTION=<user_id>]<username>[/MENTION]
      raw = raw.gsub(/\[mention="?(\d+)"?\](.+?)\[\/mention\]/i) do
        user_id, old_username = $1, $2
        if user = @users.select { |u| u[:userid] == user_id }.first
          old_username = @old_username_to_new_usernames[user[:username]] || user[:username]
        end
        "@#{old_username}"
      end

      # [QUOTE]...[/QUOTE]
      raw = raw.gsub(/\[quote\](.+?)\[\/quote\]/im) { "\n> #{$1}\n" }

      # [QUOTE=<username>]...[/QUOTE]
      raw = raw.gsub(/\[quote=([^;\]]+)\](.+?)\[\/quote\]/im) do
        old_username, quote = $1, $2
        if @old_username_to_new_usernames.has_key?(old_username)
          old_username = @old_username_to_new_usernames[old_username]
        end
        "\n[quote=\"#{old_username}\"]\n#{quote}\n[/quote]\n"
      end

      # [YOUTUBE]<id>[/YOUTUBE]
      raw = raw.gsub(/\[youtube\](.+?)\[\/youtube\]/i) { "\n//youtu.be/#{$1}\n" }

      # [VIDEO=youtube;<id>]...[/VIDEO]
      raw = raw.gsub(/\[video=youtube;([^\]]+)\].*?\[\/video\]/i) { "\n//youtu.be/#{$1}\n" }

      raw
    end

    def import_topics
      puts "", "Importing topics..."

      # keep track of closed topics
      @closed_topic_ids = []

      # sort the topics
      @topics.sort_by! { |topic| topic[:threadid].to_i }

      create_posts(@topics) do |topic|
        id = "thread#" + topic[:threadid]

        # store the list of closed topics
        @closed_topic_ids << id if topic[:open] == "0"

        next if post_id_from_imported_post_id(id)
        next unless post = @posts.select { |p| p[:postid] == topic[:firstpostid] }.first

        t = {
          id: id,
          user_id: user_id_from_imported_user_id(topic[:postuserid]) || Discourse::SYSTEM_USER_ID,
          title: CGI.unescapeHTML(topic[:title]).strip[0...255],
          category: category_id_from_imported_category_id(topic[:forumid]),
          raw: post[:raw],
          created_at: Time.at(topic[:dateline].to_i),
          visible: topic[:visible].to_i == 1,
          views: topic[:views].to_i,
        }

        if topic[:sticky].to_i == 1
          t[:pinned_at] = t[:created_at]
        end

        # tag
        if (tag = @mapped_categories[topic[:old_forumid]][:tag] || "").present?
          t[:custom_fields] ||= {}
          t[:custom_fields]['tag'] = tag
        end

        t
      end
    end

    def import_posts
      puts "", "Importing posts..."

      # reject all first posts
      first_post_ids = Set.new(@topics.map { |t| t[:firstpostid] })
      posts_to_import = @posts.reject { |post| first_post_ids.include?(post[:postid]) }

      # sort the posts
      @posts.sort_by! { |post| post[:postid].to_i }

      create_posts(posts_to_import) do |post|
        next unless t = topic_lookup_from_imported_post_id("thread#" + post[:threadid])

        p = {
          id: post[:postid],
          user_id: user_id_from_imported_user_id(post[:userid]) || Discourse::SYSTEM_USER_ID,
          topic_id: t[:topic_id],
          raw: post[:raw],
          created_at: Time.at(post[:dateline].to_i),
          hidden: post[:visible].to_i == 0,
        }

        if (edit_reason = (post[:editreason] || "").gsub("NULL", "")).present?
          p[:edit_reason] = edit_reason
        end

        if parent = topic_lookup_from_imported_post_id(post[:parentid])
          p[:reply_to_post_number] = parent[:post_number]
        end

        p
      end
    end

    def postprocess_posts
      puts "", "Postprocessing posts..."

      current = 0
      max = @posts.size

      @posts.each do |post|
        begin
          new_raw = postprocess_post_raw(post[:raw])

          if new_raw != post[:raw]
            new_id = post_id_from_imported_post_id(post[:postid])
            p = Post.find_by(id: new_id)
            if p.nil?
              puts "Could not save the post-processed raw of the post ##{new_id} (previous id: ##{post[:postid]})"
              next
            end
            p.raw = new_raw
            p.save
          end
        rescue Exception => e
          puts "", "-" * 100
          puts e.message
          puts e.backtrace.join("\n")
          puts "-" * 100, ""
          next
        ensure
          current += 1
          print_status(current, max)
        end
      end
    end

    def postprocess_post_raw(raw)
      # [QUOTE=<username>;<post_id>]...[/QUOTE]
      raw = raw.gsub(/\[quote=([^;]+);(\d+)\](.+?)\[\/quote\]/im) do
        old_username, post_id, quote = $1, $2, $3

        if @old_username_to_new_usernames.has_key?(old_username)
          old_username = @old_username_to_new_usernames[old_username]
        end

        if topic_lookup = topic_lookup_from_imported_post_id(post_id)
          post_number = topic_lookup[:post_number]
          topic_id    = topic_lookup[:topic_id]
          "\n[quote=\"#{old_username},post:#{post_number},topic:#{topic_id}\"]\n#{quote}\n[/quote]\n"
        else
          "\n[quote=\"#{old_username}\"]\n#{quote}\n[/quote]\n"
        end
      end

      # [THREAD]<thread_id>[/THREAD]
      # ==> http://my.discourse.org/t/slug/<topic_id>
      raw = raw.gsub(/\[thread\](\d+)\[\/thread\]/i) do
        thread_id = $1
        if topic_lookup = topic_lookup_from_imported_post_id("thread#" + thread_id)
          topic_lookup[:url]
        else
          $&
        end
      end

      # [THREAD=<thread_id>]...[/THREAD]
      # ==> [...](http://my.discourse.org/t/slug/<topic_id>)
      raw = raw.gsub(/\[thread=(\d+)\](.+?)\[\/thread\]/i) do
        thread_id, link = $1, $2
        if topic_lookup = topic_lookup_from_imported_post_id("thread#" + thread_id)
          url = topic_lookup[:url]
          "[#{link}](#{url})"
        else
          $&
        end
      end

      # [POST]<post_id>[/POST]
      # ==> http://my.discourse.org/t/slug/<topic_id>/<post_number>
      raw = raw.gsub(/\[post\](\d+)\[\/post\]/i) do
        post_id = $1
        if topic_lookup = topic_lookup_from_imported_post_id(post_id)
          topic_lookup[:url]
        else
          $&
        end
      end

      # [POST=<post_id>]...[/POST]
      # ==> [...](http://my.discourse.org/t/<topic_slug>/<topic_id>/<post_number>)
      raw = raw.gsub(/\[post=(\d+)\](.+?)\[\/post\]/i) do
        post_id, link = $1, $2
        if topic_lookup = topic_lookup_from_imported_post_id(post_id)
          url = topic_lookup[:url]
          "[#{link}](#{url})"
        else
          $&
        end
      end

      raw
    end

    def close_topics
      puts "", "Closing topics..."

      sql = <<-SQL
        WITH closed_topic_ids AS (
          SELECT t.id AS topic_id
          FROM post_custom_fields pcf
          JOIN posts p ON p.id = pcf.post_id
          JOIN topics t ON t.id = p.topic_id
          WHERE pcf.name = 'import_id'
          AND pcf.value IN (?)
        )
        UPDATE topics
        SET closed = true
        WHERE id IN (SELECT topic_id FROM closed_topic_ids)
      SQL

      Topic.exec_sql(sql, @closed_topic_ids)
    end

    ############################################################################
    #                                 OPTIONS                                  #
    ############################################################################

    class Options

      attr_accessor :user_group, :user, :forum, :forum_permission, :thread, :post
      attr_accessor :group_mapping, :forum_mapping

      def parse!(args = ARGV)
        parser.parse!(args)

        [:user_group, :user, :forum, :forum_permission, :thread, :post].each do |option_name|
          option = self.send(option_name)
          raise OptionParser::MissingArgument.new(option_name) if option.nil?
          raise OptionParser::InvalidArgument.new("#{option} file does not exist") if !File.exists?(option)
        end
      end

      def usage
        parser.to_s
      end

      private

        def parser
          @parser ||= OptionParser.new(nil, 50) do |opts|
            opts.banner = "Usage:\truby #{File.basename($0)} [options]"
            opts.on("--user-group USER-GROUP.csv", "list of usergroups") { |s| self.user_group = s }
            opts.on("--user USER.csv", "list of users") { |s| self.user = s }
            opts.on("--forum FORUM.csv", "list of forums") { |s| self.forum = s }
            opts.on("--forum-permission FORUM-PERMISSION.csv", "list of forum permissions") { |s| self.forum_permission = s }
            opts.on("--thread THREAD.csv", "list of threads") { |s| self.thread = s }
            opts.on("--post POST.csv", "list of posts") { |s| self.post = s }
            opts.on("--group-mapping GROUP-MAPPING.csv", "list of group mappings") { |s| self.group_mapping = s }
            opts.on("--forum-mapping FORUM-MAPPING.csv", "list of forum mappings") { |s| self.forum_mapping = s }
          end
        end
    end

end

ImportScripts::VBulletinOld.run
