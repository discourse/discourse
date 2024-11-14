# coding: utf-8
# frozen_string_literal: true

require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")

require "htmlentities"
require "tsort"
require "optparse"
require "etc"
require "open3"

class ImportScripts::Smf2 < ImportScripts::Base
  BATCH_SIZE = 5000

  def self.run
    options = Options.new
    begin
      options.parse!
    rescue Options::SettingsError => err
      $stderr.puts "Cannot load SMF settings: #{err.message}"
      exit 1
    rescue Options::Error => err
      $stderr.puts err.to_s.capitalize
      $stderr.puts options.usage
      exit 1
    end
    new(options).perform
  end

  attr_reader :options

  def initialize(options)
    if options.timezone.nil?
      $stderr.puts "No source timezone given and autodetection from PHP failed."
      $stderr.puts "Use -t option to specify correct source timezone:"
      $stderr.puts options.usage
      exit 1
    end

    super()
    @options = options

    begin
      Time.zone = options.timezone
    rescue ArgumentError
      $stderr.puts "Timezone name '#{options.timezone}' is invalid."
      exit 1
    end

    if options.database.blank?
      $stderr.puts "No database name given."
      $stderr.puts options.usage
      exit 1
    end
    if options.password == :ask
      require "highline"
      $stderr.print "Enter password for MySQL database `#{options.database}`: "
      options.password = HighLine.new.ask("") { |q| q.echo = false }
    end

    @default_db_connection = create_db_connection
  end

  def execute
    import_groups
    import_users
    import_categories
    import_posts
    import_personal_posts
    postprocess_posts
    make_prettyurl_permalinks("/forum")
  end

  def import_groups
    puts "", "creating groups"

    total = query(<<-SQL, as: :single)
      SELECT COUNT(*) FROM {prefix}membergroups
      WHERE min_posts = -1 AND group_type IN (1, 2)
    SQL

    create_groups(query(<<-SQL), total: total) { |group| group }
      SELECT id_group AS id, group_name AS name
      FROM {prefix}membergroups
      WHERE min_posts = -1 AND group_type IN (1, 2)
    SQL
  end

  GUEST_GROUP = -1
  MEMBER_GROUP = 0
  ADMIN_GROUP = 1
  MODERATORS_GROUP = 2

  def import_users
    puts "", "creating users"
    total = query("SELECT COUNT(*) FROM {prefix}members", as: :single)

    create_users(query(<<-SQL), total: total) do |member|
      SELECT a.id_member, a.member_name, a.date_registered, a.real_name, a.email_address,
             CONCAT(LCASE(a.member_name),':', a.passwd) AS password,
             a.is_activated, a.last_login, a.birthdate, a.member_ip, a.id_group, a.additional_groups,
             b.id_attach, b.file_hash, b.filename
      FROM {prefix}members AS a
      LEFT JOIN {prefix}attachments AS b ON a.id_member = b.id_member
    SQL
      group_ids = [member[:id_group], *member[:additional_groups].split(",").map(&:to_i)]
      create_time =
        begin
          Time.zone.at(member[:date_registered])
        rescue StandardError
          Time.now
        end
      last_seen_time =
        begin
          Time.zone.at(member[:last_login])
        rescue StandardError
          nil
        end
      ip_addr =
        begin
          IPAddr.new(member[:member_ip])
        rescue StandardError
          nil
        end
      {
        id: member[:id_member],
        username: member[:member_name],
        password: member[:password],
        created_at: create_time,
        name: member[:real_name],
        email: member[:email_address],
        active: member[:is_activated] == 1,
        approved: member[:is_activated] == 1,
        last_seen_at: last_seen_time,
        date_of_birth: member[:birthdate],
        ip_address: ip_addr,
        admin: group_ids.include?(ADMIN_GROUP),
        moderator: group_ids.include?(MODERATORS_GROUP),
        post_create_action:
          proc do |user|
            user.update(created_at: create_time) if create_time < user.created_at
            user.save
            GroupUser.transaction do
              group_ids.each do |gid|
                (group_id = group_id_from_imported_group_id(gid)) &&
                  GroupUser.find_or_create_by(user: user, group_id: group_id)
              end
            end
            if options.smfroot && member[:id_attach].present? && user.uploaded_avatar_id.blank?
              (
                path =
                  find_smf_attachment_path(
                    member[:id_attach],
                    member[:file_hash],
                    member[:filename],
                  )
              ) &&
                begin
                  upload = create_upload(user.id, path, member[:filename])
                  user.update(uploaded_avatar_id: upload.id) if upload.persisted?
                rescue SystemCallError => err
                  puts "Could not import avatar: #{err.message}"
                end
            end
          end,
      }
    end
  end

  def import_categories
    create_categories(query(<<-SQL)) do |board|
      SELECT id_board, id_parent, name, description, member_groups
      FROM {prefix}boards
      ORDER BY id_parent ASC, id_board ASC
    SQL
      parent_id = category_id_from_imported_category_id(board[:id_parent]) if board[:id_parent] > 0
      groups = (board[:member_groups] || "").split(/,/).map(&:to_i)
      restricted = !groups.include?(GUEST_GROUP) && !groups.include?(MEMBER_GROUP)
      board[:name] += board[:id_board].to_s if Category.find_by_name(board[:name])
      {
        id: board[:id_board],
        name: board[:name],
        description: board[:description],
        parent_category_id: parent_id,
        post_create_action:
          restricted &&
            proc do |category|
              category.update(read_restricted: true)
              groups.each do |imported_group_id|
                (group_id = group_id_from_imported_group_id(imported_group_id)) &&
                  CategoryGroup.find_or_create_by(category: category, group_id: group_id) do |cg|
                    cg.permission_type = CategoryGroup.permission_types[:full]
                  end
              end
            end,
      }
    end
  end

  def import_posts
    puts "", "creating posts"
    spinner = %w[/ - \\ |].cycle
    total = query("SELECT COUNT(*) FROM {prefix}messages", as: :single)
    PostCreator.class_eval do
      def guardian
        @guardian ||=
          if opts[:import_mode]
            @@system_guardian ||= Guardian.new(Discourse.system_user)
          else
            Guardian.new(@user)
          end
      end
    end

    db2 = create_db_connection

    create_posts(query(<<-SQL), total: total) do |message|
      SELECT m.id_msg, m.id_topic, m.id_member, m.poster_time, m.body,
             m.subject, t.id_board, t.id_first_msg, COUNT(a.id_attach) AS attachment_count
      FROM {prefix}messages AS m
      LEFT JOIN {prefix}topics AS t ON t.id_topic = m.id_topic
      LEFT JOIN {prefix}attachments AS a ON a.id_msg = m.id_msg AND a.attachment_type = 0
      GROUP BY m.id_msg
      ORDER BY m.id_topic ASC, m.id_msg ASC
    SQL
      skip = false
      ignore_quotes = false

      post = {
        id: message[:id_msg],
        user_id: user_id_from_imported_user_id(message[:id_member]) || -1,
        created_at: Time.zone.at(message[:poster_time]),
        post_create_action:
          ignore_quotes &&
            proc do |p|
              p.custom_fields["import_rebake"] = "t"
              p.save
            end,
      }

      if message[:id_msg] == message[:id_first_msg]
        post[:category] = category_id_from_imported_category_id(message[:id_board])
        post[:title] = decode_entities(message[:subject])
      else
        parent = topic_lookup_from_imported_post_id(message[:id_first_msg])
        if parent
          post[:topic_id] = parent[:topic_id]
        else
          puts "Parent post #{message[:id_first_msg]} doesn't exist. Skipping #{message[:id_msg]}: #{message[:subject][0..40]}"
          skip = true
        end
      end
      next nil if skip

      attachments =
        message[:attachment_count] == 0 ? [] : query(<<-SQL, connection: db2, as: :array)
        SELECT id_attach, file_hash, filename FROM {prefix}attachments
        WHERE attachment_type = 0 AND id_msg = #{message[:id_msg]}
        ORDER BY id_attach ASC
      SQL
      attachments.map! do |a|
        begin
          import_attachment(post, a)
        rescue StandardError
          (
            puts $!
            nil
          )
        end
      end
      begin
        post[:raw] = convert_message_body(message[:body], attachments, ignore_quotes: ignore_quotes)
      rescue => e
        puts "Failed to import message with ID #{post[:id]}"
        puts e.message
        puts e.backtrace.join("\n")
        post[:raw] = "-- MESSAGE SKIPPED --"
      end
      next post
    end
  end

  def import_personal_posts
    puts "Loading pm mapping..."

    @pm_mapping = {}

    Topic
      .joins(:topic_allowed_users)
      .where(archetype: Archetype.private_message)
      .where("title NOT ILIKE 'Re:%'")
      .group(:id)
      .order(:id)
      .pluck(
        "string_agg(topic_allowed_users.user_id::text, ',' ORDER BY topic_allowed_users.user_id), title, topics.id",
      )
      .each do |users, title, topic_id|
        @pm_mapping[users] ||= {}
        @pm_mapping[users][title] ||= []
        @pm_mapping[users][title] << topic_id
      end

    puts "", "Importing personal posts..."

    last_post_id = -1
    total =
      query(
        "SELECT COUNT(*) count FROM smf_personal_messages WHERE deleted_by_sender = 0",
        as: :single,
      )

    batches(BATCH_SIZE) do |offset|
      posts = query(<<~SQL, as: :array)
        SELECT id_pm
             , id_member_from
             , msgtime
             , subject
             , body
             , (SELECT GROUP_CONCAT(id_member) FROM smf_pm_recipients r WHERE r.id_pm = pm.id_pm) recipients
          FROM smf_personal_messages pm
         WHERE deleted_by_sender = 0
           AND id_pm > #{last_post_id}
         ORDER BY id_pm
         LIMIT #{BATCH_SIZE}
      SQL

      break if posts.empty?

      last_post_id = posts[-1][:id_pm]
      post_ids = posts.map { |p| "pm-#{p[:id_pm]}" }

      next if all_records_exist?(:post, post_ids)

      create_posts(posts, total: total, offset: offset) do |p|
        next unless user_id = user_id_from_imported_user_id(p[:id_member_from])
        next if p[:recipients].blank?
        recipients =
          p[:recipients].split(",").map { |id| user_id_from_imported_user_id(id) }.compact.uniq
        next if recipients.empty?

        id = "pm-#{p[:id_pm]}"
        next if post_id_from_imported_post_id(id)

        post = { id: id, created_at: Time.at(p[:msgtime]), user_id: user_id }
        begin
          post[:raw] = convert_message_body(p[:body])
        rescue => e
          puts "Failed to import personal message with ID #{post[:id]}"
          puts e.message
          puts e.backtrace.join("\n")
          post[:raw] = "-- MESSAGE SKIPPED --"
        end

        users = (recipients + [user_id]).sort.uniq.join(",")
        title = decode_entities(p[:subject])

        if topic_id = find_pm_topic_id(users, title)
          post[:topic_id] = topic_id
        else
          post[:archetype] = Archetype.private_message
          post[:title] = title
          post[:target_usernames] = User.where(id: recipients).pluck(:username)
          post[:post_create_action] = proc do |action_post|
            @pm_mapping[users] ||= {}
            @pm_mapping[users][title] ||= []
            @pm_mapping[users][title] << action_post.topic_id
          end
        end

        post
      end
    end
  end

  def find_pm_topic_id(users, title)
    # Please note that this approach to topic matching is lifted straight from smf1.rb.
    # With SMFv2 we could update this to use id_pm_head, which contains
    # the id of the message this is a reply to, or the message's own id_pm
    # if it's the first in the messages thread.
    #
    return unless title.start_with?("Re:")

    return unless @pm_mapping[users]

    title = title.gsub(/^(Re:)+/i, "")
    return unless @pm_mapping[users][title]

    @pm_mapping[users][title][-1]
  end

  def import_attachment(post, attachment)
    path =
      find_smf_attachment_path(
        attachment[:id_attach],
        attachment[:file_hash],
        attachment[:filename],
      )
    raise "Attachment for post #{post[:id]} failed: #{attachment[:filename]}" if path.blank?
    upload = create_upload(post[:user_id], path, attachment[:filename])
    unless upload.persisted?
      raise "Attachment for post #{post[:id]} failed: #{upload.errors.full_messages.join(", ")}"
    end
    upload
  rescue SystemCallError => err
    raise "Attachment for post #{post[:id]} failed: #{err.message}"
  end

  def postprocess_posts
    puts "", "rebaking posts"

    tags = PostCustomField.where(name: "import_rebake", value: "t")
    tags_total = tags.count
    tags_done = 0

    tags.each do |tag|
      post = tag.post
      Post.transaction do
        post.raw = convert_bbcode(post.raw)
        post.rebake!
        post.save
        tag.destroy!
      end
      print_status(tags_done += 1, tags_total)
    end
  end

  private

  def create_db_connection
    Mysql2::Client.new(
      host: options.host,
      username: options.username,
      password: options.password,
      database: options.database,
    )
  end

  def query(sql, **opts, &block)
    db = opts[:connection] || @default_db_connection
    return __query(db, sql).to_a if opts[:as] == :array
    return __query(db, sql, as: :array).first[0] if opts[:as] == :single
    return __query(db, sql, stream: true).each(&block) if block_given?
    __query(db, sql, stream: true)
  end

  def __query(db, sql, **opts)
    db.query(
      sql.gsub("{prefix}", options.prefix),
      { symbolize_keys: true, cache_rows: false }.merge(opts),
    )
  end

  TRTR_TABLE =
    begin
      from = "ŠŽšžŸÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖØÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöøùúûüýÿ"
      to = "SZszYAAAAAACEEEEIIIINOOOOOOUUUUYaaaaaaceeeeiiiinoooooouuuuyy"
      from.chars.zip(to.chars)
    end

  def find_smf_attachment_path(attachment_id, file_hash, filename)
    cleaned_name = filename.dup
    TRTR_TABLE.each { |from, to| cleaned_name.gsub!(from, to) }
    cleaned_name.gsub!(/\s/, "_")
    cleaned_name.gsub!(/[^\w_\.\-]/, "")
    legacy_name =
      "#{attachment_id}_#{cleaned_name.gsub(".", "_")}#{Digest::MD5.hexdigest(cleaned_name)}"

    [filename, "#{attachment_id}_#{file_hash}", legacy_name].map do |name|
        File.join(options.smfroot, "attachments", name)
      end
      .detect { |file| File.exist?(file) }
  end

  def decode_entities(*args)
    (@html_entities ||= HTMLEntities.new).decode(*args)
  end

  def convert_message_body(body, attachments = [], **opts)
    body = decode_entities(body.gsub(%r{<br\s*/>}, "\n"))
    body.gsub!(ColorPattern, '\k<inner>')
    body.gsub!(ListPattern) do |s|
      params = parse_tag_params($~[:params])
      tag = params["type"] == "decimal" ? "ol" : "ul"
      "\n[#{tag}]#{$~[:inner].strip}[/#{tag}]\n"
    end
    body.gsub!(XListPattern) do |s|
      r = +"\n[ul]"
      s.lines.each { |l| r += "[li]#{l.strip.sub(/^\[x\]\s*/, "")}[/li]" }
      "#{r}[/ul]\n"
    end

    if attachments.present?
      use_count = Hash.new(0)
      AttachmentPatterns.each do |p|
        pattern, emitter = *p
        body.gsub!(pattern) do |s|
          next s if (num = $~[:num].to_i - 1) < 0
          next s if (upload = attachments[num]).blank?
          use_count[num] += 1
          instance_exec(upload, &emitter)
        end
      end
      if use_count.keys.length < attachments.select(&:present?).length
        body = "#{body}\n\n---"
        attachments.each_with_index do |upload, num|
          "#{body}\n\n#{get_upload_markdown(upload)}" if upload.present? && use_count[num] == (0)
        end
      end
    end

    opts[:ignore_quotes] ? body : convert_bbcode(body)
  end

  def get_upload_markdown(upload)
    html_for_upload(upload, upload.original_filename)
  end

  def convert_quotes(body)
    body
      .to_s
      .gsub(QuotePattern) do |s|
        inner = $~[:inner].strip
        params = parse_tag_params($~[:params])
        if params["author"].present?
          quote = +"\n[quote=\"#{params["author"]}"
          if QuoteParamsPattern =~ params["link"]
            tl = topic_lookup_from_imported_post_id($~[:msg].to_i)
            quote = "#{quote} post:#{tl[:post_number]}, topic:#{tl[:topic_id]}" if tl
          end
          quote = "#{quote}\"]\n#{convert_quotes(inner)}\n[/quote]"
        else
          "<blockquote>#{convert_quotes(inner)}</blockquote>"
        end
      end
  end

  IGNORED_BBCODE = %w[
    black
    blue
    center
    color
    email
    flash
    font
    glow
    green
    iurl
    left
    list
    move
    red
    right
    shadown
    size
    table
    time
    white
  ]

  def convert_bbcode(raw)
    return "" if raw.blank?

    raw = convert_quotes(raw)

    # [acronym]
    raw.gsub!(%r{\[acronym=([^\]]+)\](.*?)\[/acronym\]}im) { %{<abbr title="#{$1}">#{$2}</abbr>} }

    # [br]
    raw.gsub!(/\[br\]/i, "\n")
    raw.gsub!(%r{<br\s*/?>}i, "\n")
    # [hr]
    raw.gsub!(/\[hr\]/i, "<hr/>")

    # [sub]
    raw.gsub!(%r{\[sub\](.*?)\[/sub\]}im) { "<sub>#{$1}</sub>" }
    # [sup]
    raw.gsub!(%r{\[sup\](.*?)\[/sup\]}im) { "<sup>#{$1}</sup>" }

    # [html]
    raw.gsub!(/\[html\]/i, "\n```html\n")
    raw.gsub!(%r{\[/html\]}i, "\n```\n")

    # [php]
    raw.gsub!(/\[php\]/i, "\n```php\n")
    raw.gsub!(%r{\[/php\]}i, "\n```\n")

    # [code]
    raw.gsub!(%r{\[/?code\]}i, "\n```\n")

    # [pre]
    raw.gsub!(%r{\[/?pre\]}i, "\n```\n")

    # [tt]
    raw.gsub!(%r{\[/?tt\]}i, "`")

    # [ftp]
    raw.gsub!(/\[ftp/i, "[url")
    raw.gsub!(%r{\[/ftp\]}i, "[/url]")

    # [me]
    raw.gsub!(%r{\[me=([^\]]*)\](.*?)\[/me\]}im) { "_\\* #{$1} #{$2}_" }

    # [ul]
    raw.gsub!(/\[ul\]/i, "")
    raw.gsub!(%r{\[/ul\]}i, "")

    # [li]
    raw.gsub!(%r{\[li\](.*?)\[/li\]}im) { "- #{$1}" }

    # puts [img] on their own line
    raw.gsub!(%r{\[img[^\]]*\](.*?)\[/img\]}im) { "\n#{$1}\n" }

    # puts [youtube] on their own line
    raw.gsub!(%r{\[youtube\](.*?)\[/youtube\]}im) { "\n#{$1}\n" }

    IGNORED_BBCODE.each { |code| raw.gsub!(%r{\[#{code}[^\]]*\](.*?)\[/#{code}\]}im, '\1') }

    # ensure [/quote] are on their own line
    raw.gsub!(%r{\s*\[/quote\]\s*}im, "\n[/quote]\n")

    # remove tapatalk mess
    raw.gsub!(%r{Sent from .+? using \[url=.*?\].+?\[/url\]}i, "")
    raw.gsub!(/Sent from .+? using .+?\z/i, "")

    # clean URLs
    raw.gsub!(%r{\[url=(.+?)\]\1\[/url\]}i, '\1')

    raw
  end

  def extract_quoted_message_ids(body)
    Set.new.tap do |quoted|
      body.scan(/\[quote\s+([^\]]+)\s*\]/) do |params|
        params = parse_tag_params(params)
        if params.has_key?("link")
          match = QuoteParamsPattern.match(params["link"])
          quoted = "#{quoted}#{match[:msg].to_i}" if match
        end
      end
    end
  end

  # param1=value1=still1 value1 param2=value2 ...
  # => {'param1' => 'value1=still1 value1', 'param2' => 'value2 ...'}
  def parse_tag_params(params)
    params
      .to_s
      .strip
      .scan(/(?<param>\w+)=(?<value>(?:(?>\S+)|\s+(?!\w+=))*)/)
      .inject({}) do |h, e|
        h[e[0]] = e[1]
        h
      end
  end

  class << self
    private

    # [tag param=value param2=value2]
    #   text
    #   [tag nested=true]text[/tag]
    # [/tag]
    # => match[:params] == 'param=value param2=value2'
    #    match[:inner] == "\n  text\n  [tag nested=true]text[/tag]\n"
    def build_nested_tag_regex(ltag, rtag = nil)
      rtag ||= "/" + ltag
      /
        \[#{ltag}(?-x:[ =](?<params>[^\]]*))?\]            # consume open tag, followed by...
          (?<inner>(?:
            (?> [^\[]+ )                                   # non-tags, or...
            |
            \[(?! #{ltag}(?-x:[ =][^\]]*)?\] | #{rtag}\])  # different tags, or ...
            |
            (?<re>                                         # recursively matched tags of the same kind
              \[#{ltag}(?-x:[ =][^\]]*)?\]
                (?:
                  (?> [^\[]+ )
                  |
                  \[(?! #{ltag}(?-x:[ =][^\]]*)?\] | #{rtag}\])
                  |
                  \g<re>                                   # recursion here
                )*
              \[#{rtag}\]
            )
          )*)
        \[#{rtag}\]
      /x
    end
  end

  QuoteParamsPattern = /^topic=(?<topic>\d+).msg(?<msg>\d+)#msg\k<msg>$/
  XListPattern = /(?<xblock>(?>^\[x\]\s*(?<line>.*)$\n?)+)/
  QuotePattern = build_nested_tag_regex("quote")
  ColorPattern = build_nested_tag_regex("color")
  ListPattern = build_nested_tag_regex("list")
  AttachmentPatterns = [
    [/^\[attach(?:|img|url|mini)=(?<num>\d+)\]$/, ->(u) { "\n" + get_upload_markdown(u) + "\n" }],
    [/\[attach(?:|img|url|mini)=(?<num>\d+)\]/, ->(u) { get_upload_markdown(u) }],
  ]

  # Provides command line options and parses the SMF settings file.
  class Options
    class Error < StandardError
    end

    class SettingsError < Error
    end

    def parse!(args = ARGV)
      raise Error, "not enough arguments" if ARGV.empty?
      begin
        parser.parse!(args)
      rescue OptionParser::ParseError => err
        raise Error, err.message
      end
      raise Error, "too many arguments" if args.length > 1
      self.smfroot = args.first
      read_smf_settings if self.smfroot

      self.host ||= "localhost"
      self.username ||= Etc.getlogin
      self.prefix ||= "smf_"
      self.timezone ||= get_php_timezone
    end

    def usage
      parser.to_s
    end

    attr_accessor :host
    attr_accessor :username
    attr_accessor :password
    attr_accessor :database
    attr_accessor :prefix
    attr_accessor :smfroot
    attr_accessor :timezone

    private

    def get_php_timezone
      phpinfo, status = Open3.capture2("php", "-i")
      phpinfo.lines.each do |line|
        key, *vals = line.split(" => ").map(&:strip)
        break vals[0] if key == "Default timezone"
      end
    rescue Errno::ENOENT
      $stderr.puts "Error: PHP CLI executable not found"
    end

    def read_smf_settings
      settings = File.join(self.smfroot, "Settings.php")
      File
        .readlines(settings)
        .each do |line|
          next unless m = %r{\$([a-z_]+)\s*=\s*['"](.+?)['"]\s*;\s*((#|//).*)?$}.match(line)
          case m[1]
          when "db_server"
            self.host ||= m[2]
          when "db_user"
            self.username ||= m[2]
          when "db_passwd"
            self.password ||= m[2]
          when "db_name"
            self.database ||= m[2]
          when "db_prefix"
            self.prefix ||= m[2]
          end
        end
    rescue => err
      raise SettingsError, err.message unless self.database
    end

    def parser
      @parser ||=
        OptionParser.new(nil, 12) do |o|
          o.banner = "Usage:\t#{File.basename($0)} <SMFROOT> [options]\n"
          o.banner = "${o.banner}\t#{File.basename($0)} -d <DATABASE> [options]"
          o.on("-h HOST", :REQUIRED, "MySQL server hostname [\"#{self.host}\"]") do |s|
            self.host = s
          end
          o.on("-u USER", :REQUIRED, "MySQL username [\"#{self.username}\"]") do |s|
            self.username = s
          end
          o.on(
            "-p [PASS]",
            :OPTIONAL,
            "MySQL password. Without argument, reads password from STDIN.",
          ) { |s| self.password = s || :ask }
          o.on("-d DBNAME", :REQUIRED, "Name of SMF database") { |s| self.database = s }
          o.on("-f PREFIX", :REQUIRED, "Table names prefix [\"#{self.prefix}\"]") do |s|
            self.prefix = s
          end
          o.on("-t TIMEZONE", :REQUIRED, "Timezone used by SMF2 [auto-detected from PHP]") do |s|
            self.timezone = s
          end
        end
    end
  end #Options

  # Framework around TSort, used to build a dependency graph over messages
  # to find and solve cyclic quotations.
  class MessageDependencyGraph
    include TSort

    def initialize
      @nodes = {}
    end

    def [](key)
      @nodes[key]
    end

    def add_message(id, prev = nil, quoted = [])
      @nodes[id] = Node.new(self, id, prev, quoted)
    end

    def tsort_each_node(&block)
      @nodes.each_value(&block)
    end

    def tsort_each_child(node, &block)
      node.dependencies.each(&block)
    end

    def cycles
      strongly_connected_components.select { |c| c.length > 1 }.to_a
    end

    class Node
      attr_reader :id

      def initialize(graph, id, prev = nil, quoted = [])
        @graph = graph
        @id = id
        @prev = prev
        @quoted = quoted
      end

      def prev
        @graph[@prev]
      end

      def quoted
        @quoted.map { |id| @graph[id] }.reject(&:nil?)
      end

      def ignore_quotes?
        !!@ignore_quotes
      end

      def ignore_quotes=(value)
        @ignore_quotes = !!value
        @dependencies = nil
      end

      def dependencies
        @dependencies ||=
          Set
            .new
            .tap do |deps|
              deps.merge(quoted) unless ignore_quotes?
              deps << prev if prev.present?
            end
            .to_a
      end

      def hash
        @id.hash
      end

      def eql?(other)
        @id.eql?(other)
      end

      def inspect
        "#<#{self.class.name}: id=#{id.inspect}, prev=#{safe_id(@prev)}, quoted=[#{@quoted.map(&method(:safe_id)).join(", ")}]>"
      end

      private

      def safe_id(id)
        @graph[id].present? ? @graph[id].id.inspect : "(#{id})"
      end
    end #Node
  end #MessageDependencyGraph

  def make_prettyurl_permalinks(prefix)
    puts "creating permalinks for prettyurl plugin"
    begin
      serialized = query(<<-SQL, as: :single)
        SELECT value FROM {prefix}settings
        WHERE variable='pretty_board_urls';
      SQL
      board_slugs = Array.new
      ser = /\{(.*)\}/.match(serialized)[1]
      ser.scan(/i:(\d+);s:\d+:\"(.*?)\";/).each { |nv| board_slugs[nv[0].to_i] = nv[1] }
      topic_urls = query(<<-SQL, as: :array)
        SELECT t.id_first_msg, t.id_board,u.pretty_url
        FROM smf_topics t
        LEFT JOIN smf_pretty_topic_urls u ON u.id_topic = t.id_topic ;
      SQL
      topic_urls.each do |url|
        t = topic_lookup_from_imported_post_id(url[:id_first_msg])
        Permalink.create(
          url: "#{prefix}/#{board_slugs[url[:id_board]]}/#{url[:pretty_url]}",
          topic_id: t[:topic_id],
        )
      end
    rescue StandardError
    end
  end
end

ImportScripts::Smf2.run
