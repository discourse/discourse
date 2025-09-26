# frozen_string_literal: true

require "mysql2"
require_relative "base"
require "htmlentities"
require "uri"
require "json"

# Before running this script, paste these lines into your shell,
# then use arrow keys to edit the values
=begin
export DB_HOST="localhost"
export DB_NAME="mylittleforum"
export DB_PW=""
export DB_USER="root"
export TABLE_PREFIX="forum_"
export IMPORT_AFTER="1970-01-01"
export IMAGE_BASE="http://www.example.com/forum"
export BASE="forum"

# Optional: set a parent category in Discourse. When set, all imported MLF
# categories will be created as subcategories under this one.
# export PARENT_CATEGORY="Existing Discourse Category Name"

# Optional: rewrite absolute legacy links (index.php?id=...) to Discourse permalinks
# using IMAGE_BASE as the legacy base.
# export REWRITE_LINKS="true"
#
# Optional: local path to the legacy uploads directory (flat namespace; files like 20250706095752686a48a0d33d0.pdf).
# If the original forum is behind auth or lacks disk space, this folder can be mounted via sshfs.
# Note: The path may only contain ASCII letters, digits, underscores (_), hyphens (-), dots (.) and slashes (/).
# Characters such as spaces, German umlauts (ä, ö, ü, ß) or any other special characters are not allowed,
# otherwise JPG and PNG files may cause an "InvalidAccess" error.
# The files mlf_missing_uploads.txt and mlf_upload_map.json are created in the script directory to keep track of uploads.
# If you update the Docker container and perform another import afterwards, make sure to back up these files beforehand.
# export UPLOADS_DIR="/path/to/mlf/uploads"
#
# Optional: repair pass to update already-imported posts that still contain legacy upload links
# (e.g., files became available only after the first run). When enabled, only posts imported by
# this script are scanned, and only links under IMAGE_BASE/…/images/uploaded are rewritten.
# export REPAIR_UPLOAD_LINKS="true"
#
# Optional: temporarily relax upload constraints during the uploads phase. When enabled, increases
# max_attachment_size_kb / max_image_size_kb to a generous value and temporarily allows all file
# extensions ('*') so the import won't fail on extension checks. All settings are restored after
# the uploads step.
# export LOOSEN_UPLOAD_CONSTRAINTS="true"
=end

class ImportScripts::MylittleforumSQL < ImportScripts::Base
  DB_HOST = ENV["DB_HOST"] || "localhost"
  DB_NAME = ENV["DB_NAME"] || "mylittleforum"
  DB_PW = ENV["DB_PW"] || ""
  DB_USER = ENV["DB_USER"] || "root"
  TABLE_PREFIX = ENV["TABLE_PREFIX"] || "forum_"
  IMPORT_AFTER = ENV["IMPORT_AFTER"] || "1970-01-01"
  IMAGE_BASE = ENV["IMAGE_BASE"] || ""
  BASE = ENV["BASE"] || "forum/"
  PARENT_CATEGORY = ENV["PARENT_CATEGORY"]
  REWRITE_LINKS = (ENV["REWRITE_LINKS"] || "").strip.upcase == "TRUE"
  UPLOADS_DIR = ENV["UPLOADS_DIR"]
  REPAIR_UPLOAD_LINKS = (ENV["REPAIR_UPLOAD_LINKS"] || "").strip.upcase == "TRUE"
  LOOSEN_UPLOAD_CONSTRAINTS = (ENV["LOOSEN_UPLOAD_CONSTRAINTS"] || "").strip.upcase == "TRUE"

  BATCH_SIZE = 1000
  CONVERT_HTML = true
  QUIET = nil || ENV["VERBOSE"] == "TRUE"
  FORCE_HOSTNAME = nil || ENV["FORCE_HOSTNAME"]

  QUIET = true

  # Site settings
  SiteSetting.disable_emails = "non-staff"
  SiteSetting.force_hostname = FORCE_HOSTNAME if FORCE_HOSTNAME

  def resolve_parent_category_id
    # Find existing Discourse category by name or slug; return id or nil
    return nil if PARENT_CATEGORY.nil? || PARENT_CATEGORY.strip.empty?

    name = PARENT_CATEGORY.strip
    parent =
      Category.where("lower(name) = ?", name.downcase).first ||
        Category.where("lower(slug) = ?", name.parameterize.downcase).first

    unless parent
      print_warning(
        "Note: PARENT_CATEGORY='#{PARENT_CATEGORY}' not found. " \
          "Import will create top-level categories.",
      )
      return nil
    end

    parent.id
  end

  def initialize
    print_warning("Importing data after #{IMPORT_AFTER}") if IMPORT_AFTER > "1970-01-01"

    super
    @htmlentities = HTMLEntities.new
    begin
      @client =
        Mysql2::Client.new(host: DB_HOST, username: DB_USER, password: DB_PW, database: DB_NAME)
    rescue Exception => e
      puts "=" * 50
      puts e.message
      puts <<~TEXT
        Cannot log in to database.

        Hostname: #{DB_HOST}
        Username: #{DB_USER}
        Password: #{DB_PW}
        database: #{DB_NAME}

        You should set these variables:

        export DB_HOST="localhost"
        export DB_NAME="mylittleforum"
        export DB_PW=""
        export DB_USER="root"
        export TABLE_PREFIX="forum_"
        export IMPORT_AFTER="1970-01-01"
        export IMAGE_BASE="http://www.example.com/forum"
        export BASE="forum"

        Exiting.
      TEXT
      exit
    end

    @parent_category_id = resolve_parent_category_id
    build_legacy_link_rewriter

    # uploads
    @script_dir = File.expand_path(File.dirname(__FILE__))
    @upload_map_path = File.join(@script_dir, "mlf_upload_map.json")
    @missing_uploads_path = File.join(@script_dir, "mlf_missing_uploads.txt")
    @upload_map = load_upload_map(@upload_map_path)
    build_legacy_upload_rewriter
  end

  def execute
    import_users
    import_categories

    # Uploads first, so posts can link to already-imported Discourse uploads.
    import_uploads

    import_topics
    import_posts

    repair_legacy_upload_links if REPAIR_UPLOAD_LINKS

    update_tl0

    create_permalinks

    # persist the upload map at the very end
    save_upload_map(@upload_map_path, @upload_map)
  end

  def import_users
    puts "", "creating users"

    total_count =
      mysql_query(
        "SELECT count(*) count FROM #{TABLE_PREFIX}userdata WHERE last_login > '#{IMPORT_AFTER}';",
      ).first[
        "count"
      ]

    batches(BATCH_SIZE) do |offset|
      # MLF 1.x used 'user_place', MLF 2.x uses 'user_location'
      location_col =
        if mysql_query("SHOW COLUMNS FROM #{TABLE_PREFIX}userdata LIKE 'user_place'").any?
          "user_place"
        else
          "user_location"
        end

      results =
        mysql_query(
          "
             SELECT user_id as UserID, user_name as username,
                user_real_name as Name,
                user_email as Email,
                user_hp as website,
                #{location_col} as Location,
                profile as bio_raw,
                last_login as DateLastActive,
                user_ip as InsertIPAddress,
                user_pw as password,
                logins as days_visited, # user_stats
                registered as DateInserted,
                user_pw as password,
                user_type
             FROM #{TABLE_PREFIX}userdata
		 WHERE last_login > '#{IMPORT_AFTER}'
                 order by UserID ASC
                 LIMIT #{BATCH_SIZE}
                 OFFSET #{offset};",
        )

      break if results.size < 1

      next if all_records_exist? :users, results.map { |u| u["UserID"].to_i }

      create_users(results, total: total_count, offset: offset) do |user|
        # respect already "prepared" users created earlier (e.g. via mbox import)
        next if user["Email"].blank?
        if existing = User.find_by_email(user["Email"])
          @lookup.add_user(user["UserID"].to_s, existing)
          next
        end
        next if @lookup.user_id_from_imported_user_id(user["UserID"])

        # username = fix_username(user['username'])

        {
          id: user["UserID"],
          email: user["Email"],
          username: user["username"],
          name: user["Name"],
          staged: true,
          created_at: user["DateInserted"] == nil ? 0 : Time.zone.at(user["DateInserted"]),
          bio_raw: user["bio_raw"],
          registration_ip_address: user["InsertIPAddress"],
          website: user["user_hp"],
          password: user["password"],
          last_seen_at: user["DateLastActive"] == nil ? 0 : Time.zone.at(user["DateLastActive"]),
          location: user["Location"],
          admin: user["user_type"] == "admin",
          moderator: user["user_type"] == "mod",
        }
      end
    end
  end

  def fix_username(username)
    olduser = username.dup
    username.gsub!(/Dr\. /, "Dr") # no &
    username.gsub!(%r{[ +!/,*()?]}, "_") # can't have these
    username.gsub!(/&/, "_and_") # no &
    username.gsub!(/@/, "_at_") # no @
    username.gsub!(/#/, "_hash_") # no &
    username.gsub!(/\'/, "") # seriously?
    username.gsub!(/[._]+/, "_") # can't have 2 special in a row
    username.gsub!(/_+/, "_") # could result in dupes, but wtf?
    username.gsub!(/_$/, "") # could result in dupes, but wtf?
    print_warning("#{olduser} --> #{username}") if olduser != username
    username
  end

  def import_categories
    puts "", "importing categories..."

    categories =
      mysql_query(
        "
                              SELECT id as CategoryID,
                              category as Name,
                              description as Description
                              FROM #{TABLE_PREFIX}categories
                              ORDER BY CategoryID ASC
                            ",
      ).to_a

    parent_id = @parent_category_id

    create_categories(categories) do |category|
      {
        id: category["CategoryID"],
        name: CGI.unescapeHTML(category["Name"]),
        description: CGI.unescapeHTML(category["Description"]),
        # When parent_id is nil, Discourse creates a top-level category (default behavior).
        parent_category_id: parent_id,
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    total_count =
      mysql_query(
        "SELECT count(*) count FROM #{TABLE_PREFIX}entries
                               WHERE time > '#{IMPORT_AFTER}'
                               AND pid = 0;",
      ).first[
        "count"
      ]

    # Optional youtube_link column (not present in standard MLF 2.x)
    youtube_available =
      mysql_query("SHOW COLUMNS FROM #{TABLE_PREFIX}entries LIKE 'youtube_link'").any?
    youtube_select = youtube_available ? ", youtube_link as youtube" : ""

    batches(BATCH_SIZE) do |offset|
      discussions =
        mysql_query(
          "SELECT id as DiscussionID,
                category as CategoryID,
                subject as Name,
                text as Body,
                time as DateInserted#{youtube_select},
                user_id as InsertUserID
         FROM #{TABLE_PREFIX}entries
         WHERE pid = 0
	 AND time > '#{IMPORT_AFTER}'
         ORDER BY time ASC
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};",
        )

      break if discussions.size < 1
      if all_records_exist? :posts, discussions.map { |t| "discussion#" + t["DiscussionID"].to_s }
        next
      end

      create_posts(discussions, total: total_count, offset: offset) do |discussion|
        raw = clean_up(discussion["Body"])

        youtube = nil
        if discussion["youtube"].present?
          youtube = clean_youtube(discussion["youtube"])
          raw += "\n#{youtube}\n"
          print_warning(raw)
        end

        raw = rewrite_legacy_links(raw)
        raw = rewrite_legacy_uploads(raw)

        {
          id: "discussion#" + discussion["DiscussionID"].to_s,
          user_id:
            user_id_from_imported_user_id(discussion["InsertUserID"]) || Discourse::SYSTEM_USER_ID,
          title: discussion["Name"].gsub('\\"', '"'),
          category: category_id_from_imported_category_id(discussion["CategoryID"]),
          raw: raw,
          created_at: Time.zone.at(discussion["DateInserted"]),
        }
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    total_count =
      mysql_query(
        "SELECT count(*) count
       FROM #{TABLE_PREFIX}entries
       WHERE pid > 0
       AND time > '#{IMPORT_AFTER}';",
      ).first[
        "count"
      ]

    # Optional youtube_link column (not present in standard MLF 2.x)
    youtube_available =
      mysql_query("SHOW COLUMNS FROM #{TABLE_PREFIX}entries LIKE 'youtube_link'").any?
    youtube_select = youtube_available ? ", youtube_link as youtube" : ""

    batches(BATCH_SIZE) do |offset|
      comments =
        mysql_query(
          "SELECT id as CommentID,
                tid as DiscussionID,
                text as Body,
                time as DateInserted#{youtube_select},
                user_id as InsertUserID
         FROM #{TABLE_PREFIX}entries
         WHERE pid > 0
	 AND time > '#{IMPORT_AFTER}'
         ORDER BY time ASC
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset};",
        )

      break if comments.size < 1
      if all_records_exist? :posts,
                            comments.map { |comment| "comment#" + comment["CommentID"].to_s }
        next
      end

      create_posts(comments, total: total_count, offset: offset) do |comment|
        unless t = topic_lookup_from_imported_post_id("discussion#" + comment["DiscussionID"].to_s)
          next
        end
        next if comment["Body"].blank?
        raw = clean_up(comment["Body"])
        youtube = nil
        if comment["youtube"].present?
          youtube = clean_youtube(comment["youtube"])
          raw += "\n#{youtube}\n"
        end

        raw = rewrite_legacy_links(raw)
        raw = rewrite_legacy_uploads(raw)

        {
          id: "comment#" + comment["CommentID"].to_s,
          user_id:
            user_id_from_imported_user_id(comment["InsertUserID"]) || Discourse::SYSTEM_USER_ID,
          topic_id: t[:topic_id],
          raw: clean_up(raw),
          created_at: Time.zone.at(comment["DateInserted"]),
        }
      end
    end
  end

  def clean_youtube(youtube_raw)
    youtube_cooked = clean_up(youtube_raw.dup.to_s)
    # get just src from <iframe> and put on a line by itself
    re = %r{<iframe.+?src="(\S+?)".+?</iframe>}mix
    youtube_cooked.gsub!(re) { "\n#{$1}\n" }
    re = %r{<object.+?src="(\S+?)".+?</object>}mix
    youtube_cooked.gsub!(re) { "\n#{$1}\n" }
    youtube_cooked.gsub!(%r{^//}, "https://") # make sure it has a protocol
    unless /http/.match(youtube_cooked) # handle case of only youtube object number
      if youtube_cooked.length < 8 || /[<>=]/.match(youtube_cooked)
        # probably not a youtube id
        youtube_cooked = ""
      else
        youtube_cooked = "https://www.youtube.com/watch?v=" + youtube_cooked
      end
    end
    print_warning("#{"-" * 40}\nBefore: #{youtube_raw}\nAfter: #{youtube_cooked}") unless QUIET

    youtube_cooked
  end

  def clean_up(raw)
    return "" if raw.blank?

    # decode HTML entities
    raw = @htmlentities.decode(raw)

    # don't \ quotes
    raw = raw.gsub('\\"', '"')
    raw = raw.gsub("\\'", "'")

    raw = raw.gsub(/\[b\]/i, "<strong>")
    raw = raw.gsub(%r{\[/b\]}i, "</strong>")

    raw = raw.gsub(/\[i\]/i, "<em>")
    raw = raw.gsub(%r{\[/i\]}i, "</em>")

    raw = raw.gsub(/\[u\]/i, "<em>")
    raw = raw.gsub(%r{\[/u\]}i, "</em>")

    raw = raw.gsub(%r{\[url\](\S+)\[/url\]}im) { "#{$1}" }
    raw = raw.gsub(%r{\[link\](\S+)\[/link\]}im) { "#{$1}" }

    # URL & LINK with text
    raw = raw.gsub(%r{\[url=(\S+?)\](.*?)\[/url\]}im) { "<a href=\"#{$1}\">#{$2}</a>" }
    raw = raw.gsub(%r{\[link=(\S+?)\](.*?)\[/link\]}im) { "<a href=\"#{$1}\">#{$2}</a>" }

    # remote images
    raw = raw.gsub(%r{\[img\](https?:.+?)\[/img\]}im) { "<img src=\"#{$1}\">" }
    raw = raw.gsub(%r{\[img=(https?.+?)\](.+?)\[/img\]}im) { "<img src=\"#{$1}\" alt=\"#{$2}\">" }
    # local images
    raw = raw.gsub(%r{\[img\](.+?)\[/img\]}i) { "<img src=\"#{IMAGE_BASE}/#{$1}\">" }
    raw =
      raw.gsub(%r{\[img=(.+?)\](https?.+?)\[/img\]}im) do
        "<img src=\"#{IMAGE_BASE}/#{$1}\" alt=\"#{$2}\">"
      end

    # Convert image bbcode
    raw.gsub!(%r{\[img=(\d+),(\d+)\]([^\]]*)\[/img\]}im, '<img width="\1" height="\2" src="\3">')

    # [div]s are really [quote]s
    raw.gsub!(/\[div\]/mix, "[quote]")
    raw.gsub!(%r{\[/div\]}mix, "[/quote]")

    # BBCode list to Markdown (unordered)
    raw.gsub!(/\[list\]/i, "")
    raw.gsub!(%r{\[/list\]}i, "")
    raw.gsub!(/\[\*\]\s*/i, "* ")

    # [postedby] -> link to @user
    raw.gsub(%r{\[postedby\](.+?)\[b\](.+?)\[/b\]\[/postedby\]}i) { "#{$1}@#{$2}" }

    # CODE (not tested)
    raw = raw.gsub(%r{\[code\](\S+)\[/code\]}im) { "```\n#{$1}\n```" }
    raw = raw.gsub(%r{\[pre\](\S+)\[/pre\]}im) { "```\n#{$1}\n```" }

    raw = raw.gsub(%r{(https://youtu\S+)}i) { "\n#{$1}\n" } #youtube links on line by themselves

    # no center
    raw = raw.gsub(%r{\[/?center\]}i, "")

    # no size
    raw = raw.gsub(%r{\[/?size.*?\]}i, "")

    ### FROM VANILLA:

    # fix whitespaces
    raw = raw.gsub(/(\\r)?\\n/, "\n").gsub("\\t", "\t")

    # enforce block boundaries so BBCode [quote] is parsed reliably
    raw.gsub!(/[ \t]*\n?[ \t]*\[quote\][ \t]*/i) { "\n\n[quote]\n" }
    raw.gsub!(%r{[ \t]*\[/quote\][ \t]*\n?}i) { "\n[/quote]\n\n" }

    # end a Markdown blockquote unless the next line intentionally continues it
    # (next line starts with '>' or a list marker like '- ', '* ', '1. ')
    # prevent Markdown lazy-continuation from pulling the next paragraph into the quote
    raw = ensure_quote_breaks(raw)

    unless CONVERT_HTML
      # replace all chevrons with HTML entities
      # NOTE: must be done
      #  - AFTER all the "code" processing
      #  - BEFORE the "quote" processing
      raw =
        raw
          .gsub(/`([^`]+)`/im) { "`" + $1.gsub("<", "\u2603") + "`" }
          .gsub("<", "&lt;")
          .gsub("\u2603", "<")

      raw =
        raw
          .gsub(/`([^`]+)`/im) { "`" + $1.gsub(">", "\u2603") + "`" }
          .gsub(">", "&gt;")
          .gsub("\u2603", ">")
    end

    # Remove the color tag
    raw.gsub!(/\[color=[#a-z0-9]+\]/i, "")
    raw.gsub!(%r{\[/color\]}i, "")
    ### END VANILLA:

    raw
  end

  def staff_guardian
    @_staff_guardian ||= Guardian.new(Discourse.system_user)
  end

  def mysql_query(sql)
    @client.query(sql)
    # @client.query(sql, cache_rows: false) #segfault: cache_rows: false causes segmentation fault
  end

  def create_permalinks
    puts "", "Creating redirects...", ""

    puts "", "Users...", ""
    User.find_each do |u|
      ucf = u.custom_fields
      if ucf && ucf["import_id"] && ucf["import_username"]
        begin
          Permalink.create(
            url: "#{BASE}/user-id-#{ucf["import_id"]}.html",
            external_url: "/u/#{u.username}",
          )
        rescue StandardError
          nil
        end
        print "."
      end
    end

    puts "", "Posts...", ""
    Post.find_each do |post|
      pcf = post.custom_fields
      if pcf && pcf["import_id"]
        topic = post.topic
        id = pcf["import_id"].split("#").last
        if post.post_number == 1
          begin
            Permalink.create(url: "#{BASE}/forum_entry-id-#{id}.html", topic_id: topic.id)
          rescue StandardError
            nil
          end
          unless QUIET
            print_warning("forum_entry-id-#{id}.html --> http://localhost:3000/t/#{topic.id}")
          end
        else
          begin
            Permalink.create(url: "#{BASE}/forum_entry-id-#{id}.html", post_id: post.id)
          rescue StandardError
            nil
          end
          unless QUIET
            print_warning(
              "forum_entry-id-#{id}.html --> http://localhost:3000/t/#{topic.id}/#{post.id}",
            )
          end
        end
        print "."
      end
    end

    puts "", "Categories...", ""
    Category.find_each do |cat|
      ccf = cat.custom_fields
      next unless id = ccf["import_id"]
      print_warning("forum-category-#{id}.html --> /t/#{cat.id}") unless QUIET
      begin
        Permalink.create(url: "#{BASE}/forum-category-#{id}.html", category_id: cat.id)
      rescue StandardError
        nil
      end
      print "."
    end
  end

  def print_warning(message)
    $stderr.puts "#{message}"
  end

  # ensure a blank line after a quoted block unless the next line intentionally continues it
  def ensure_quote_breaks(text)
    return text if text.blank?

    out = []
    in_quote = false
    lines = text.split("\n", -1) # keep trailing empties

    lines.each do |line|
      if line =~ /\A\s*>/
        in_quote = true
        out << line
        next
      end

      if in_quote
        # leaving a quote: if the current non-quote line is NOT a continuation marker, insert a blank line before it
        unless line =~ /\A\s*(?:>|[-*]\s|\d+\.\s)/
          out << "" unless out.last == ""
        end
      end

      in_quote = false
      out << line
    end

    out.join("\n")
  end

  private

  def build_legacy_link_rewriter
    @rewrite_links_enabled = false
    return unless REWRITE_LINKS
    return if IMAGE_BASE.to_s.strip.empty?

    begin
      u = URI.parse(IMAGE_BASE.strip)
      host = u.host
      path = u.path || ""
      return unless host

      # normalize host (allow matching with/without www)
      host = host.sub(/\Awww\./i, "")
      # normalize path (no trailing slash)
      path = path.sub(%r{/\z}, "")

      host_esc = Regexp.escape(host)
      path_esc = Regexp.escape(path)

      # match absolute legacy links: http(s)://(www.)?host/path/index.php?id=123...
      @legacy_link_regex =
        %r{https?://(?:www\.)?#{host_esc}#{path_esc}/index\.php\?id=(\d+)(?:[&#][^"\s<]*)?}i

      @rewrite_links_enabled = true
    rescue => e
      print_warning(
        "Note: REWRITE_LINKS enabled but IMAGE_BASE invalid (#{e.message}). Skipping link rewrite.",
      )
      @rewrite_links_enabled = false
    end
  end

  def rewrite_legacy_links(raw)
    return raw unless @rewrite_links_enabled
    return raw if raw.blank?

    prefix = "/#{BASE.to_s.strip.sub(%r{\A/}, "").sub(%r{/\z}, "")}"
    prefix = "" if prefix == "/"

    # 1) rewrite only href="LEGACY..."
    raw =
      raw.gsub(/(\bhref\s*=\s*["'])#{@legacy_link_regex}/i) do
        %(#{$1}#{prefix}/forum_entry-id-#{$2}.html)
      end

    # 2) rewrite naked legacy URLs to clickable anchors (avoid attr contexts)
    raw =
      raw.gsub(/(?<![="'=])#{@legacy_link_regex}/i) do
        path = "#{prefix}/forum_entry-id-#{$1}.html"
        %(<a href="#{path}">#{path}</a>)
      end

    raw
  end

  #
  # uploads support
  #

  def build_legacy_upload_rewriter
    @rewrite_uploads_enabled = false
    return if IMAGE_BASE.to_s.strip.empty?

    begin
      u = URI.parse(IMAGE_BASE.strip)
      host = u.host
      path = u.path || ""
      return unless host

      host = host.sub(/\Awww\./i, "")
      path = path.sub(%r{/\z}, "")

      host_esc = Regexp.escape(host)
      path_esc = Regexp.escape(path)

      # match absolute legacy uploads: http(s)://(www.)?host/path/images/uploaded/<filename>
      @legacy_upload_regex =
        %r{https?://(?:www\.)?#{host_esc}#{path_esc}/images/uploaded/([^\s"'<>\?#]+)}i

      @rewrite_uploads_enabled = true
    rescue => e
      print_warning(
        "Note: IMAGE_BASE invalid for upload rewrite (#{e.message}). Skipping upload link rewrite.",
      )
      @rewrite_uploads_enabled = false
    end
  end

  def relative_upload_url(url)
    return url if url.blank?
    url.sub(%r{\Ahttps?://[^/]+}, "")
  end

  def load_upload_map(path)
    if File.exist?(path)
      JSON.parse(File.read(path))
    else
      {}
    end
  rescue => e
    print_warning("Could not read upload map at #{path}: #{e.message}")
    {}
  end

  def save_upload_map(path, map)
    File.open(path, "w") { |f| f.write(JSON.pretty_generate(map)) }
  rescue => e
    print_warning("Could not write upload map at #{path}: #{e.message}")
  end

  def append_missing_upload(filename)
    begin
      File.open(@missing_uploads_path, "a") { |f| f.puts(filename) }
    rescue => e
      print_warning(
        "Could not append to missing uploads list #{@missing_uploads_path}: #{e.message}",
      )
    end
  end

  def find_uploads_table_name
    # try common variants
    candidates = ["#{TABLE_PREFIX}uploads", "mlf_uploads", "#{TABLE_PREFIX}mlf_uploads"]
    names = @client.query("SHOW TABLES").map { |r| r.values.first.to_s }
    candidates.find { |t| names.include?(t) }
  end

  def import_uploads
    return if UPLOADS_DIR.to_s.strip.empty?

    table = find_uploads_table_name
    unless table
      print_warning(
        "No uploads table found (tried '#{TABLE_PREFIX}uploads', 'mlf_uploads'). Skipping uploads import.",
      )
      return
    end

    puts "", "importing uploads from #{table}..."

    loosened = false
    original_limits = nil

    if LOOSEN_UPLOAD_CONSTRAINTS
      loosened = true
      original_limits = {
        max_attachment_size_kb: SiteSetting.max_attachment_size_kb,
        max_image_size_kb: SiteSetting.max_image_size_kb,
        authorized_extensions: SiteSetting.authorized_extensions,
        authorized_extensions_for_staff: SiteSetting.authorized_extensions_for_staff,
      }
      # keep it conservative & reversible
      SiteSetting.max_attachment_size_kb = [SiteSetting.max_attachment_size_kb, 102_400].max
      SiteSetting.max_image_size_kb = [SiteSetting.max_image_size_kb, 102_400].max

      # temporarily allow all extensions ('*') so extension checks don't block the import
      begin
        SiteSetting.authorized_extensions = "*" unless SiteSetting
          .authorized_extensions
          .to_s
          .strip == "*"
      rescue => e
        print_warning("Could not widen authorized_extensions: #{e.message}")
      end
      begin
        SiteSetting.authorized_extensions_for_staff = "*" unless SiteSetting
          .authorized_extensions_for_staff
          .to_s
          .strip == "*"
      rescue => e
        print_warning("Could not widen authorized_extensions_for_staff: #{e.message}")
      end
    end

    # only import uploads newer than IMPORT_AFTER (consistent with topics/posts)
    total =
      mysql_query(
        "SELECT count(*) AS c
       FROM #{table}
       WHERE tstamp > '#{IMPORT_AFTER}'",
      ).first[
        "c"
      ]
    offset = 0

    missing = 0
    created = 0
    skipped = 0

    while offset < total
      rows =
        mysql_query(
          "SELECT id, uploader, filename, tstamp
         FROM #{table}
         WHERE tstamp > '#{IMPORT_AFTER}'
         ORDER BY id ASC
         LIMIT #{BATCH_SIZE}
         OFFSET #{offset}",
        ).to_a
      break if rows.empty?

      rows.each do |row|
        fn = row["filename"].to_s
        next if fn.blank?

        if @upload_map.key?(fn)
          skipped += 1
          next
        end

        base_fn = fn
        path = File.join(UPLOADS_DIR, fn)
        actual_fn = fn

        # handle filenames without extension in DB: try to find "<filename>.*" on disk
        unless File.exist?(path)
          if File.extname(base_fn).to_s.empty?
            candidates = Dir.glob(File.join(UPLOADS_DIR, "#{base_fn}.*"))
            if candidates.any?
              path = candidates.first
              actual_fn = File.basename(path)
              # don't double-import if we already mapped the on-disk name somehow
              if @upload_map.key?(actual_fn)
                @upload_map[base_fn] = @upload_map[actual_fn]
                skipped += 1
                next
              end
              print_warning("Resolved extensionless '#{base_fn}' to '#{actual_fn}'")
            end
          end
        end

        unless File.exist?(path)
          missing += 1
          append_missing_upload(fn)
          next
        end

        uploader_id = user_id_from_imported_user_id(row["uploader"]) || Discourse::SYSTEM_USER_ID

        begin
          File.open(path, "rb") do |file|
            # create an Upload in Discourse; Discourse deduplicates identical files internally
            # note: the uploader context is determined by the argument to `create_for`
            upload =
              UploadCreator.new(file, File.basename(path), type: "attachment").create_for(
                uploader_id,
              )

            if upload && upload.url
              url = relative_upload_url(upload.url)
              # map both keys: the DB name (possibly without extension) and the actual filename
              @upload_map[base_fn] = url
              @upload_map[actual_fn] = url unless actual_fn == base_fn
              created += 1
            else
              missing += 1
              append_missing_upload(fn)
              begin
                print_warning(
                  "Upload returned no URL for #{actual_fn} (ext='#{File.extname(actual_fn).delete(".")}', size=#{File.size(path)} bytes)",
                )
              rescue StandardError
                nil
              end
            end
          end
        rescue => e
          bt = (e.backtrace && e.backtrace.first) ? " @ #{e.backtrace.first}" : ""
          print_warning("Upload failed for #{actual_fn}: #{e.class}: #{e.message}#{bt}")
          missing += 1
          append_missing_upload(base_fn)
        end
      end

      offset += rows.length
      save_upload_map(@upload_map_path, @upload_map) # persist incrementally
    end

    if loosened && original_limits
      SiteSetting.max_attachment_size_kb = original_limits[:max_attachment_size_kb]
      SiteSetting.max_image_size_kb = original_limits[:max_image_size_kb]
      begin
        SiteSetting.authorized_extensions = original_limits[:authorized_extensions]
      rescue => e
        print_warning("Could not restore authorized_extensions: #{e.message}")
      end
      begin
        SiteSetting.authorized_extensions_for_staff =
          original_limits[:authorized_extensions_for_staff]
      rescue => e
        print_warning("Could not restore authorized_extensions_for_staff: #{e.message}")
      end
    end

    puts "uploads: created=#{created}, skipped=#{skipped}, missing=#{missing}"
  end

  def rewrite_legacy_uploads(raw)
    return raw if raw.blank?
    return raw unless @rewrite_uploads_enabled
    return raw if @upload_map.nil? || @upload_map.empty?

    # 0) [img]LEGACY[/img] -> [img]NEW[/img]
    raw =
      raw.gsub(%r{\[img\]\s*(#{@legacy_upload_regex})\s*\[/img\]}i) do
        legacy = $1 # full legacy URL
        filename = $2 # captured filename from @legacy_upload_regex
        new_url = @upload_map[filename]
        new_url ? "[img]#{new_url}[/img]" : $&
      end

    # 0b) <img ... src="LEGACY" ...> -> src="NEW"
    raw =
      raw.gsub(/(<img[^>]*\bsrc\s*=\s*["'])(#{@legacy_upload_regex})(["'][^>]*>)/i) do
        pre = $1
        filename = $3 # 1=pre, 2=full legacy URL, 3=filename, 4=post
        post = $4
        new_url = @upload_map[filename]
        new_url ? "#{pre}#{new_url}#{post}" : $&
      end

    # 1) rewrite only href="LEGACY_UPLOAD..." (1=href prefix, 2=full legacy URL, 3=filename)
    raw =
      raw.gsub(/(\bhref\s*=\s*["'])#{@legacy_upload_regex}/i) do
        # @legacy_upload_regex exposes the filename as its single capture group
        filename = $2
        new_url = @upload_map[filename]
        new_url ? "#{$1}#{new_url}" : $&
      end

    # 2) rewrite naked legacy upload URLs in plain text (groups: 1=prefix, 2=filename)
    raw =
      raw.gsub(/(^|[\s\(\[\{>"'])#{@legacy_upload_regex}(?=$|[\s\)\]\}',\.\!\?:;])/i) do
        prefix = $1
        filename = $2
        new_url = @upload_map[filename]
        new_url ? %(#{prefix}<a href="#{new_url}">#{new_url}</a>) : $&
      end
    raw
  end

  def repair_legacy_upload_links
    puts "", "repairing legacy upload links in imported posts...", ""

    return unless @rewrite_uploads_enabled

    ids = PostCustomField.where(name: "import_id").pluck(:post_id)
    return if ids.empty?

    Post
      .where(id: ids)
      .find_in_batches(batch_size: BATCH_SIZE) do |posts|
        posts.each do |post|
          begin
            old_raw = post.raw.to_s
            next if old_raw.blank?
            #next unless old_raw =~ @legacy_upload_regex
            next if old_raw.exclude?("/images/uploaded/")
            begin
              total_legacy = old_raw.scan(@legacy_upload_regex).length
              mapped_legacy =
                old_raw
                  .scan(@legacy_upload_regex)
                  .count { |m| @upload_map[m.is_a?(Array) ? m.last : m] }
              if total_legacy > 0
                print_warning(
                  "Repair post #{post.id}: legacy=#{total_legacy}, mapped=#{mapped_legacy}",
                )
              end
            rescue StandardError
            end

            new_raw = rewrite_legacy_uploads(old_raw)
            next if new_raw == old_raw

            post.raw = new_raw
            post.save!
            post.rebake!
            print "."
          rescue => e
            print_warning("Repair failed for post #{post.id}: #{e.message}")
          end
        end
      end

    puts "", "repair pass finished", ""
  end
end

ImportScripts::MylittleforumSQL.new.perform
