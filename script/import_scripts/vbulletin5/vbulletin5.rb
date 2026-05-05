# frozen_string_literal: true

require "json"
require "mysql2"
require "net/http"
require "uri"
require_relative "../base"
require "htmlentities"

class ImportScripts::VBulletin < ImportScripts::Base
  BATCH_SIZE = 5000
  ROOT_NODE = 2
  TIMEZONE = "America/New_York"

  # override these using environment vars

  URL_PREFIX = ENV["URL_PREFIX"] || "forum/"
  DB_PREFIX = ENV["DB_PREFIX"] || ""
  DB_HOST = ENV["DB_HOST"] || "localhost"
  DB_NAME = ENV["DB_NAME"] || "sci"
  DB_PASS = ENV["DB_PASS"] || "password123"
  DB_USER = ENV["DB_USER"] || "root"
  ATTACH_DIR = ENV["ATTACH_DIR"] || "/shared/uploads/attachments"
  AVATAR_DIR = ENV["AVATAR_DIR"] || "/shared/uploads/avatars"

  # Maps BBCode inline formatting tags to their HTML equivalents.
  BBCODE_INLINE = { "b" => "strong", "strong" => "strong",
                    "i" => "em",     "em"     => "em",
                    "u" => "u",      "s" => "s", "strike" => "s" }.freeze

  # Maps vBulletin smilie shortcodes (smilietext column) to Unicode emoji.
  # Shortcodes that appear in post rawtext as :name: or as bare text like :) :D etc.
  # Edit this table to adjust mappings.
  SMILIE_TEXT_EMOJI = {
    # Standard ASCII smilies
    ":)"        => "😊",  ":D"        => "😁",  ":("        => "🙁",
    ":o"        => "😳",  ":p"        => "😛",  ";)"        => "😉",
    ":cool:"    => "😎",  ":mad:"     => "😡",  ":eek:"     => "😱",
    ":confused:"=> "😕",  ":rolleyes:"=> "🙄",
    # Emotions
    ":cry:"     => "😢",  ":lol:"     => "😂",  ":lolz:"    => "😂",
    ":hahaha:"  => "😂",  ":rofl:"    => "🤣",  ":rotfl:"   => "🤣",
    ":zzz:"     => "😴",  ":yawn:"    => "😴",  ":thinking:"=> "🤔",
    ":drunk:"   => "🥴",  ":crazy:"   => "🤪",  ":bored:"   => "😑",
    ":gloomy:"  => "😞",  ":evil:"    => "😈",  ":devil:"   => "😈",
    ":angel:"   => "😇",  ":innocent:"=> "😇",  ":zombie:"  => "🧟",
    ":agog:"    => "🤩",  ":lovingeye"=> "😍",  ":love2:"   => "💕",
    ":cooldude:"=> "😎",  ":devdude:" => "🤓",  ":homeranm:"=> "🤪",
    ":tinfoil:" => "🤪",  ":wtf:"     => "😳",  ":sconf:"   => "😕",
    ":mdramatic"=> "🎭",  ":busted2:" => "😬",  ":dontknow:"=> "🤷",
    ":decision:"=> "🤔",  ":jawdrp:"  => "😲",  ":hissyfit:"=> "😤",
    ":stressbut"=> "😤",  ":tease:"   => "😜",  ":stirpot:" => "😏",
    ":flamed:"  => "🔥",  ":ogre:"    => "👹",  ":medusa:"  => "😱",
    ":eek1:"    => "😱",  ":eek2:"    => "😱",
    # Sick/gross
    ":sick:"    => "🤢",  ":fever:"   => "🤒",  ":puke:"    => "🤮",
    ":puke1:"   => "🤮",  ":puke2:"   => "🤮",  ":puke3:"   => "🤮",
    ":shitfan:" => "💩",  ":bs:"      => "💩",  ":booboo:"  => "🤕",
    # Gestures/actions
    ":thumbsup:"=> "👍",  ":thumb:"   => "👍",  ":tup3:"    => "👍",
    ":pray:"    => "🙏",  ":amen:"    => "🙏",  ":hug:"     => "🤗",
    ":grphug:"  => "🤗",  ":wave:"    => "👋",  ":waving:"  => "👋",
    ":high5:"   => "🙌",  ":salute:"  => "🫡",  ":wazzup:"  => "🤙",
    ":playnice:"=> "🤝",  ":metoo:"   => "🙋",  ":notworthy"=> "🙇",
    ":applaud:" => "👏",  ":nono:"    => "🙅",  ":no:"      => "🚫",
    ":tape:"    => "🤐",  ":whisper:" => "🤫",  ":whistle:" => "😗",
    ":sorry:"   => "😔",  ":sorry!:"  => "😔",  ":doh:"     => "🤦",
    ":banghead:"=> "🤦",  ":footmth:" => "🤦",
    # People/characters
    ":ninja:"   => "🥷",  ":santa:"   => "🎅",  ":baby:"    => "👶",
    ":nana:"    => "👵",  ":alien:"   => "👽",
    ":geek:"    => "🤓",  ":drillsgt:"=> "🪖",  ":director:"=> "🎬",
    # Animals/objects
    ":cat:"     => "🐱",  ":dog:"     => "🐶",  ":fish2:"   => "🐟",
    ":broomstk:"=> "🧹",  ":frypan:"  => "🍳",  ":hammer:"  => "🔨",
    ":mega:"    => "📣",  ":chat:"    => "💬",  ":spam:"    => "🚫",
    ":help:"    => "🆘",  ":2guns:"   => "💥",  ":popcorn:" => "🍿",
    ":beer:"    => "🍺",  ":beer2:"   => "🍺",  ":yumyum:"  => "😋",
    # Activities/events
    ":party:"   => "🎉",  ":partyguy:"=> "🥳",  ":bday:"    => "🎂",
    ":friday:"  => "🎉",  ":first:"   => "🥇",  ":eureka:"  => "💡",
    ":bounce:"  => "😄",  ":welcome:" => "🤗",  ":back2top:"=> "🎯",
    ":fishing:" => "🎣",  ":surfing:"  => "🏄",  ":running:" => "🏃",
    ":wtrski:"  => "🤽",  ":wtlftr:"  => "🏋️",
    # Misc
    ":argue:"   => "🗣️",  ":judge:"   => "⚖️",
    ":laughabv:"=> "😂",  ":crybaby:" => "😭",
  }.freeze

  def initialize
    super

    @old_username_to_new_usernames = {}

    # Populated by import_attachments: filedataid (Integer) => upload HTML string.
    # Used by postprocess_post_raw to replace [attach] tags inline.
    @filedataid_to_upload_html = {}

    setup_mysql
  end

  # Lightweight init for use when loading vbulletin5.rb as a library (IMPORT_LIBRARY_ONLY=1).
  # Sets up MySQL connection, typeids, and helpers without calling super (which loads all
  # existing Discourse data into memory - unnecessary for single-post reprocessing).
  def library_only_init
    @old_username_to_new_usernames = {}
    @filedataid_to_upload_html = {}
    @uploader = ImportScripts::Uploader.new
    setup_mysql
    # Override lookup methods that require @lookup (not available without super)
    # to use direct DB queries instead.
    def self.topic_lookup_from_imported_post_id(import_id)
      post_id = PostCustomField.find_by(name: "import_id", value: import_id.to_s)&.post_id
      return nil unless post_id
      post = Post.find_by(id: post_id)
      return nil unless post
      { post_number: post.post_number, topic_id: post.topic_id,
        url: "#{Discourse.base_url}/p/#{post_id}" }
    rescue StandardError
      nil
    end
    def self.user_id_from_imported_user_id(import_id)
      UserCustomField.find_by(name: "import_id", value: import_id.to_s)&.user_id
    rescue StandardError
      nil
    end
    self
  end

  def setup_mysql
    @tz = TZInfo::Timezone.get(TIMEZONE)

    @htmlentities = HTMLEntities.new

    @client =
      Mysql2::Client.new(host: DB_HOST, username: DB_USER, database: DB_NAME, password: DB_PASS)

    @forum_typeid =
      mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Forum'").first[
        "contenttypeid"
      ]
    @channel_typeid =
      mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Channel'").first[
        "contenttypeid"
      ]
    @text_typeid =
      mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Text'").first[
        "contenttypeid"
      ]
    @gallery_typeid =
      mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Gallery'").first[
        "contenttypeid"
      ]
    @link_typeid =
      mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Link'").first[
        "contenttypeid"
      ]
    @video_typeid =
      mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Video'").first[
        "contenttypeid"
      ]
    @poll_typeid =
      mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='Poll'").first[
        "contenttypeid"
      ]
  end

  def execute
    import_groups
    import_users
    import_categories
    import_topics
    import_posts
    import_comments
    import_attachments
    import_gallery_photos
    import_poll_votes
    import_tags
    close_topics
    post_process_posts
    create_permalinks
    create_redirect_permalinks
  end

  def import_groups
    puts "", "importing groups..."

    last_id = resume_group_id
    puts "  Resuming groups from usergroupid > #{last_id}" if last_id > 0

    groups = mysql_query <<-SQL
        SELECT usergroupid, title
          FROM #{DB_PREFIX}usergroup
         WHERE usergroupid > #{last_id}
      ORDER BY usergroupid
    SQL

    create_groups(groups) do |group|
      { id: group["usergroupid"], name: decode_html_entities(group["title"]).strip }
    end
  end

  def import_users
    puts "", "importing users"

    last_id = resume_user_id
    puts "  Resuming users from userid > #{last_id}" if last_id > 0

    user_count = mysql_query("SELECT COUNT(userid) count FROM #{DB_PREFIX}user WHERE userid > #{last_id}").first["count"]

    # Track emails seen within this run to catch within-batch and cross-batch duplicates.
    # Emails already in the DB from a prior run are caught by the UserEmail.exists? check below.
    @seen_emails = Set.new

    batches(BATCH_SIZE) do |offset|
      users = mysql_query <<-SQL
          SELECT u.userid, u.username, u.homepage, u.usertitle, u.usergroupid, u.joindate, u.email,
            CASE WHEN u.scheme='blowfish:10' THEN token
                 WHEN u.scheme='legacy' THEN REPLACE(token, ' ', ':')
                 WHEN u.scheme='argon2id:::' THEN token
            END AS password,
            IF(ug.title = 'Administrators', 1, 0) AS admin
            FROM #{DB_PREFIX}user u
            LEFT JOIN #{DB_PREFIX}usergroup ug ON ug.usergroupid = u.usergroupid
           WHERE u.userid > #{last_id}
        ORDER BY userid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if users.size < 1

      create_users(users, total: user_count, offset: offset) do |user|
        username = decode_html_entities(user["username"]).strip

        # Deduplicate email: use a deterministic fake address if this email was
        # already seen in this run, or already exists in Discourse from a prior run.
        # The fake address is derived from the vBulletin userid so it is stable
        # across re-runs - the base importer will find the same address in
        # UserEmail and recognise the user as already imported rather than
        # creating a duplicate.
        raw_email = user["email"].presence
        email =
          if raw_email.nil?
            "vb-user-#{user["userid"]}@fake.invalid"
          elsif @seen_emails.include?(raw_email.downcase)
            # Seen earlier in this same run - genuine within-run duplicate
            puts "  WARNING: duplicate email #{raw_email} for user #{user["userid"]} " \
                 "(#{username}), substituting deterministic fake address"
            "vb-user-#{user["userid"]}@fake.invalid"
          else
            existing = UserEmail.where("lower(email) = ?", raw_email.downcase).first
            if existing.nil?
              # Not in Discourse at all - first import of this email
              @seen_emails << raw_email.downcase
              raw_email
            else
              # Email exists in Discourse - check if it belongs to THIS vBulletin user
              already_imported_as_this_user =
                UserCustomField
                  .where(user_id: existing.user_id, name: "import_id", value: user["userid"].to_s)
                  .exists?
              if already_imported_as_this_user
                # Re-run: this is our own previously imported user - pass real email through
                # so the base importer can find and skip them via import_id lookup
                @seen_emails << raw_email.downcase
                raw_email
              else
                # Genuinely belongs to a different user - substitute fake address
                puts "  WARNING: duplicate email #{raw_email} for user #{user["userid"]} " \
                     "(#{username}), substituting deterministic fake address"
                "vb-user-#{user["userid"]}@fake.invalid"
              end
            end
          end

        {
          id: user["userid"],
          name: username,
          username: username,
          email: email,
          admin: user["admin"] == 1,
          password: user["password"],
          website: user["homepage"].strip,
          title: decode_html_entities(user["usertitle"]).strip,
          primary_group_id: group_id_from_imported_group_id(user["usergroupid"]),
          created_at: parse_timestamp(user["joindate"]),
          post_create_action:
            proc do |u|
              @old_username_to_new_usernames[user["username"]] = u.username
              import_profile_picture(user, u)
              # import_profile_background(user, u)
              # Mark email as confirmed so users can log in without clicking an activation link
              EmailToken.where(user_id: u.id, confirmed: false).update_all(confirmed: true)
            end,
        }
      end
    end
  end

  # Find an avatar file on disk. VBulletin seems to name the avatar files for userid 1234
  # as 'avatar1234_n.EXT'. That is, the first avatar the user ever uploads is avatar1234_0.ext
  # and so on. I had a bunch of problems with avatar files. The latest numbered one was sometimes
  # a JPG image but the filename was .gif. Or sometimes the latest numbered one was corrupt,
  # but a prior one was valid. This algorithm tries to find a file of the right name. Failing that,
  # it looks for the highest numbered avatar file and tries that. Sometimes my database named a
  # file that didn't really exist. So this will return nil if no file of any name exists.
  #
  # Returns the full path if found, nil otherwise.
  def find_avatar_file(filename)
    path = File.join(AVATAR_DIR, filename)
    return path if File.exist?(path)

    basename = File.basename(filename, ".*")
    return nil unless basename =~ /\Aavatar(\d+)_\d+\z/

    userid = $1
    supported = %w[gif png jpg jpeg].to_set

    candidates = Dir[File.join(AVATAR_DIR, "avatar#{userid}_*")]
      .select { |f| supported.include?(File.extname(f).delete(".").downcase) }
      .sort_by { |f| File.basename(f, ".*")[/\d+\z/].to_i }
      .reverse

    candidates.first
  end

  def import_profile_picture(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename, LENGTH(filedata) AS dbsize
          FROM #{DB_PREFIX}customavatar
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    picture = query.first
    return if picture.nil?

    file = nil
    upload = nil

    fs_path = find_avatar_file(picture["filename"])

    if fs_path
      # Filesystem is the authoritative source - use it directly
      upload = create_upload(imported_user.id, fs_path, picture["filename"])
    elsif picture["dbsize"].to_i > 0
      # Fall back to DB blob for older records never migrated to disk
      file = Tempfile.new(["avatar#{old_user["userid"]}", File.extname(picture["filename"])])
      file.binmode
      file.write(picture["filedata"].b)
      file.rewind
      upload = UploadCreator.new(file, picture["filename"]).create_for(imported_user.id)
    else
      return nil
    end

    return if !upload.persisted?

    imported_user.create_user_avatar unless imported_user.user_avatar
    imported_user.user_avatar.update(custom_upload_id: upload.id)
    imported_user.update(uploaded_avatar_id: upload.id)
  ensure
    file&.close
    file&.unlink rescue nil
  end

  def import_profile_background(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM #{DB_PREFIX}customprofilepic
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    background = query.first

    return if background.nil?

    file = Tempfile.new("profile-background")
    file.write(background["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
    file.rewind

    upload = UploadCreator.new(file, background["filename"]).create_for(imported_user.id)

    return if !upload.persisted?

    imported_user.user_profile.upload_profile_background(upload)
  ensure
    begin
      file.close
    rescue StandardError
      nil
    end
    begin
      file.unlink
    rescue StandardError
      nil
    end
  end

  def import_categories
    puts "", "importing top level categories..."

    categories =
      mysql_query(
        "SELECT nodeid AS forumid, title, description, displayorder, parentid
	      FROM #{DB_PREFIX}node
          WHERE parentid=#{ROOT_NODE}
        UNION
          SELECT nodeid, title, description, displayorder, parentid
          FROM #{DB_PREFIX}node
          WHERE contenttypeid = #{@channel_typeid}
            AND parentid IN (SELECT nodeid FROM #{DB_PREFIX}node WHERE parentid=#{ROOT_NODE})",
      ).to_a

    top_level_categories = categories.select { |c| c["parentid"] == ROOT_NODE }

    create_categories(top_level_categories) do |category|
      {
        id: category["forumid"],
        name: decode_html_entities(category["title"]).strip,
        position: category["displayorder"],
        description: decode_html_entities(category["description"]).strip,
      }
    end

    puts "", "importing child categories..."

    children_categories = categories.select { |c| c["parentid"] != ROOT_NODE }
    top_level_category_ids = Set.new(top_level_categories.map { |c| c["forumid"] })

    # cut down the tree to only 2 levels of categories
    children_categories.each do |cc|
      while !top_level_category_ids.include?(cc["parentid"])
        cc["parentid"] = categories.detect { |c| c["forumid"] == cc["parentid"] }["parentid"]
      end
    end

    create_categories(children_categories) do |category|
      {
        id: category["forumid"],
        name: decode_html_entities(category["title"]).strip,
        position: category["displayorder"],
        description: decode_html_entities(category["description"]).strip,
        parent_category_id: category_id_from_imported_category_id(category["parentid"]),
      }
    end
  end

  def import_topics
    puts "", "importing topics..."

    # keep track of closed topics
    @closed_topic_ids = []

    last_id = resume_topic_id
    puts "  Resuming topics from nodeid > #{last_id}" if last_id > 0

    topic_count =
      mysql_query(
        "SELECT COUNT(nodeid) cnt
        FROM #{DB_PREFIX}node
        WHERE (unpublishdate = 0 OR unpublishdate IS NULL)
        AND (approved = 1 AND showapproved = 1)
        AND nodeid > #{last_id}
        AND parentid IN (
          SELECT nodeid FROM #{DB_PREFIX}node WHERE contenttypeid=#{@channel_typeid}
        )
        AND contenttypeid IN (#{@text_typeid}, #{@gallery_typeid}, #{@link_typeid}, #{@video_typeid}, #{@poll_typeid});",
      ).first["cnt"]

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
        SELECT t.nodeid AS threadid, t.contenttypeid, t.title, t.parentid AS forumid,
            t.open, t.userid AS postuserid, t.publishdate AS dateline,
            nv.count views, 1 AS visible, t.sticky,
            CONVERT(CAST(txt.rawtext AS BINARY) USING utf8) AS raw,
            lnk.url AS link_url, lnk.url_title AS link_url_title, lnk.meta AS link_meta
        FROM #{DB_PREFIX}node t
        LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = t.nodeid
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = t.nodeid
        LEFT JOIN #{DB_PREFIX}link lnk ON lnk.nodeid = t.nodeid
        WHERE t.parentid IN (
          SELECT nodeid FROM #{DB_PREFIX}node WHERE contenttypeid = #{@channel_typeid}
        )
          AND t.contenttypeid IN (#{@text_typeid}, #{@gallery_typeid}, #{@link_typeid}, #{@video_typeid}, #{@poll_typeid})
          AND (t.unpublishdate = 0 OR t.unpublishdate IS NULL)
          AND t.approved = 1 AND t.showapproved = 1
          AND t.nodeid > #{last_id}
        ORDER BY t.nodeid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if topics.size < 1

      create_posts(topics, total: topic_count, offset: offset) do |topic|
        raw =
          if topic["contenttypeid"] == @link_typeid
            build_link_post_body(topic["link_url"], topic["link_url_title"], topic["link_meta"])
          else
            begin
              preprocess_post_raw(topic["raw"])
            rescue StandardError
              nil
            end
          end
        raw = gallery_placeholder(topic["threadid"]) if raw.blank? && topic["contenttypeid"] == @gallery_typeid
        if topic["contenttypeid"] == @poll_typeid
          poll_syntax = build_poll_syntax(topic["threadid"])
          raw = (raw.presence || "") + "\n\n" + poll_syntax if poll_syntax
        end
        next if raw.blank?
        topic_id = "thread-#{topic["threadid"]}"
        @closed_topic_ids << topic_id if topic["open"] == "0"
        t = {
          id: topic_id,
          user_id: user_id_from_imported_user_id(topic["postuserid"]) || Discourse::SYSTEM_USER_ID,
          title: decode_html_entities(topic["title"]).strip[0...255],
          category: category_id_from_imported_category_id(topic["forumid"]),
          raw: raw,
          created_at: parse_timestamp(topic["dateline"]),
          visible: topic["visible"].to_i == 1,
          views: topic["views"],
        }
        t[:pinned_at] = t[:created_at] if topic["sticky"].to_i == 1
        t
      end
    end
  end

  def import_posts
    puts "", "importing posts..."

    # make sure `firstpostid` is indexed
    begin
      mysql_query("CREATE INDEX firstpostid_index ON thread (firstpostid)")
    rescue StandardError
    end

    last_id = resume_post_id
    puts "  Resuming posts from nodeid > #{last_id}" if last_id > 0

    post_count =
      mysql_query(
        "SELECT COUNT(nodeid) cnt FROM #{DB_PREFIX}node
        WHERE nodeid > #{last_id}
        AND parentid NOT IN (
          SELECT nodeid FROM #{DB_PREFIX}node WHERE contenttypeid=#{@channel_typeid}
        )
        AND contenttypeid IN (#{@text_typeid}, #{@gallery_typeid}, #{@link_typeid}, #{@video_typeid}, #{@poll_typeid});",
      ).first["cnt"]

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query <<-SQL
        SELECT p.nodeid AS postid, p.contenttypeid, p.userid AS userid, p.parentid AS threadid,
            CONVERT(CAST(txt.rawtext AS BINARY) USING utf8) AS raw, p.publishdate AS dateline,
            1 AS visible, p.parentid AS parentid,
            lnk.url AS link_url, lnk.url_title AS link_url_title, lnk.meta AS link_meta
        FROM #{DB_PREFIX}node p
        LEFT JOIN #{DB_PREFIX}nodeview nv ON nv.nodeid = p.nodeid
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = p.nodeid
        LEFT JOIN #{DB_PREFIX}link lnk ON lnk.nodeid = p.nodeid
        WHERE p.parentid NOT IN (
          SELECT nodeid FROM #{DB_PREFIX}node WHERE contenttypeid = #{@channel_typeid}
        )
          AND p.contenttypeid IN (#{@text_typeid}, #{@gallery_typeid}, #{@link_typeid}, #{@video_typeid}, #{@poll_typeid})
          AND p.nodeid > #{last_id}
        ORDER BY postid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if posts.size < 1

      create_posts(posts, total: post_count, offset: offset) do |post|
        raw =
          if post["contenttypeid"] == @link_typeid
            build_link_post_body(post["link_url"], post["link_url_title"], post["link_meta"])
          else
            preprocess_post_raw(post["raw"])
          end
        raw = gallery_placeholder(post["postid"]) if raw.blank? && post["contenttypeid"] == @gallery_typeid
        if post["contenttypeid"] == @poll_typeid
          poll_syntax = build_poll_syntax(post["postid"])
          raw = (raw.presence || "") + "\n\n" + poll_syntax if poll_syntax
        end
        next if raw.blank?
        next unless topic = topic_lookup_from_imported_post_id("thread-#{post["threadid"]}")
        p = {
          id: post["postid"],
          user_id: user_id_from_imported_user_id(post["userid"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: raw,
          created_at: parse_timestamp(post["dateline"]),
          hidden: post["visible"].to_i != 1,
        }
        if parent = topic_lookup_from_imported_post_id(post["parentid"])
          p[:reply_to_post_number] = parent[:post_number]
        end
        p
      end
    end
  end

  ATTACH_CHECKPOINT_FILE = "/tmp/vb_import_attach_checkpoint"

  def resume_attachment_filedataid
    return 0 unless File.exist?(ATTACH_CHECKPOINT_FILE)
    File.read(ATTACH_CHECKPOINT_FILE).strip.to_i
  end

  def save_attachment_checkpoint(filedataid)
    File.write(ATTACH_CHECKPOINT_FILE, filedataid.to_s)
  end

  COMMENT_CHECKPOINT_FILE = "/tmp/vb_import_comment_checkpoint"

  def resume_comment_id
    return 0 if ENV["FULL_RESCAN"] == "1"
    return 0 unless File.exist?(COMMENT_CHECKPOINT_FILE)
    File.read(COMMENT_CHECKPOINT_FILE).strip.to_i
  end

  # Build the attribution blockquote prepended to imported comment raw text.
  # Uses a relative URL (strips Discourse.base_url prefix) so the link works
  # regardless of which hostname the site is accessed from.
  def comment_attribution(parent_post, parent_authorname)
    url = parent_post[:url].to_s.delete_prefix(Discourse.base_url)
    author = parent_authorname.to_s.strip
    if author.empty?
      "> *In reply to [this post](#{url})*\n\n"
    else
      "> *In reply to [#{author}'s post](#{url})*\n\n"
    end
  end

  # Build a post-params hash for a single comment row, or return nil to skip.
  # Used by both import_comments (batch) and import_comments_for_thread (targeted).
  def build_comment_post_params(comment)
    raw =
      begin
        preprocess_post_raw(comment["raw"].to_s)
      rescue StandardError
        nil
      end
    return nil if raw.blank?

    topic = topic_lookup_from_imported_post_id("thread-#{comment["thread_nodeid"]}")
    unless topic
      puts "  WARNING: comment #{comment["commentid"]} - " \
           "parent topic thread-#{comment["thread_nodeid"]} not found, skipping"
      return nil
    end

    parent_post = topic_lookup_from_imported_post_id(comment["parent_post_nodeid"].to_s)
    raw = comment_attribution(parent_post, comment["parent_authorname"]) + raw if parent_post

    p = {
      id:         comment["commentid"],
      user_id:    user_id_from_imported_user_id(comment["userid"]) || Discourse::SYSTEM_USER_ID,
      topic_id:   topic[:topic_id],
      raw:        raw,
      created_at: parse_timestamp(comment["dateline"]),
    }
    p[:reply_to_post_number] = parent_post[:post_number] if parent_post
    p
  end

  # Import vBulletin comments. These are Text nodes where parentid points to another Text node and
  # parentid != starter. They are translated into Discourse replies with:
  #   - topic_id resolved from "thread-{starter}"
  #   - reply_to_post_number set to the parent post's post_number
  #   - an attribution blockquote prepended to the raw text (plain text author name,
  def import_comments
    puts "", "importing comments..."

    last_id = resume_comment_id
    puts "  Resuming comments from nodeid > #{last_id}" if last_id > 0

    comment_count =
      mysql_query(<<~SQL).first["cnt"]
        SELECT COUNT(c.nodeid) cnt
        FROM #{DB_PREFIX}node c
        JOIN #{DB_PREFIX}node parent ON parent.nodeid = c.parentid
        JOIN #{DB_PREFIX}contenttype parent_ct
          ON parent_ct.contenttypeid = parent.contenttypeid
        WHERE c.contenttypeid = #{@text_typeid}
          AND parent_ct.class = 'Text'
          AND c.parentid != c.starter
          AND c.approved = 1
          AND (c.unpublishdate = 0 OR c.unpublishdate IS NULL)
          AND c.nodeid > #{last_id}
      SQL

    puts "  #{comment_count} comment(s) to import"

    batches(BATCH_SIZE) do |offset|
      comments =
        mysql_query(<<~SQL).to_a
          SELECT c.nodeid AS commentid, c.userid, c.publishdate AS dateline,
                 c.parentid AS parent_post_nodeid, c.starter AS thread_nodeid,
                 parent.authorname AS parent_authorname,
                 CONVERT(CAST(txt.rawtext AS BINARY) USING utf8) AS raw
          FROM #{DB_PREFIX}node c
          JOIN #{DB_PREFIX}node parent ON parent.nodeid = c.parentid
          JOIN #{DB_PREFIX}contenttype parent_ct
            ON parent_ct.contenttypeid = parent.contenttypeid
          LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = c.nodeid
          WHERE c.contenttypeid = #{@text_typeid}
            AND parent_ct.class = 'Text'
            AND c.parentid != c.starter
            AND c.approved = 1
            AND (c.unpublishdate = 0 OR c.unpublishdate IS NULL)
            AND c.nodeid > #{last_id}
          ORDER BY c.nodeid
          LIMIT #{BATCH_SIZE} OFFSET #{offset}
        SQL

      break if comments.size < 1

      create_posts(comments, total: comment_count, offset: offset) do |comment|
        build_comment_post_params(comment)
      end

      # Checkpoint after each batch so re-runs can fast-forward.
      last_comment_id = comments.last["commentid"]
      File.write(COMMENT_CHECKPOINT_FILE, last_comment_id.to_s)
    end

    File.delete(COMMENT_CHECKPOINT_FILE) if File.exist?(COMMENT_CHECKPOINT_FILE)
    puts "  Comments complete"
  end

  # Import all comments for a single thread - used by redo_vb5_post.rb for targeted
  # testing and remediation. Uses PostCreator directly (no @lookup) so it works in
  # library_only_init mode. Deduplication via PostCustomField.
  def import_comments_for_thread(thread_nodeid)
    puts "  importing comments for thread #{thread_nodeid}..."

    comments =
      mysql_query(<<~SQL).to_a
        SELECT c.nodeid AS commentid, c.userid, c.publishdate AS dateline,
               c.parentid AS parent_post_nodeid, c.starter AS thread_nodeid,
               parent.authorname AS parent_authorname,
               CONVERT(CAST(txt.rawtext AS BINARY) USING utf8) AS raw
        FROM #{DB_PREFIX}node c
        JOIN #{DB_PREFIX}node parent ON parent.nodeid = c.parentid
        JOIN #{DB_PREFIX}contenttype parent_ct
          ON parent_ct.contenttypeid = parent.contenttypeid
        LEFT JOIN #{DB_PREFIX}text txt ON txt.nodeid = c.nodeid
        WHERE c.contenttypeid = #{@text_typeid}
          AND parent_ct.class = 'Text'
          AND c.parentid != c.starter
          AND c.starter = #{thread_nodeid}
          AND c.approved = 1
          AND (c.unpublishdate = 0 OR c.unpublishdate IS NULL)
        ORDER BY c.nodeid
      SQL

    if comments.empty?
      puts "  no comments found for thread #{thread_nodeid}"
      return 0
    end

    puts "  #{comments.size} comment(s) found"
    imported = 0
    skipped  = 0
    dupes    = 0

    comments.each do |comment|
      import_id = comment["commentid"].to_s

      if PostCustomField.where(name: "import_id", value: import_id).exists?
        dupes += 1
        next
      end

      params = build_comment_post_params(comment)
      if params.nil?
        skipped += 1
        next
      end

      params.delete(:id)  # import_id handled via custom_fields below
      params.merge!(
        skip_validations: true,
        import_mode:      true,
        custom_fields:    { "import_id" => import_id },
      )

      user = User.find(params.delete(:user_id))
      post = PostCreator.new(user, params).create

      if post.is_a?(Post) && post.persisted?
        puts "  imported comment #{import_id} → #{Discourse.base_url}/p/#{post.id}"
        imported += 1
      else
        puts "  ERROR: failed to create comment #{import_id}"
        skipped += 1
      end
    end

    puts "  comments: #{imported} imported, #{dupes} already existed, #{skipped} skipped/errors"
    imported
  end

  def import_attachments
    puts "", "importing attachments..."

    last_filedataid = resume_attachment_filedataid
    puts "  Resuming attachments from filedataid > #{last_filedataid}" if last_filedataid > 0

    ext =
      mysql_query("SELECT GROUP_CONCAT(DISTINCT(extension)) exts FROM #{DB_PREFIX}filedata").first[
        "exts"
      ].split(",")
    SiteSetting.authorized_extensions =
      (SiteSetting.authorized_extensions.split("|") + ext).uniq.join("|")

    uploads = mysql_query <<-SQL
    SELECT n.parentid nodeid, a.nodeid AS attach_nodeid, a.filename, fd.userid, fd.filesize, fd.dateline, LENGTH(fd.filedata) AS dbsize, filedata, fd.filedataid
      FROM #{DB_PREFIX}attach a
      LEFT JOIN #{DB_PREFIX}filedata fd ON fd.filedataid = a.filedataid
      LEFT JOIN #{DB_PREFIX}node n on n.nodeid = a.nodeid
     WHERE fd.filedataid > #{last_filedataid}
     ORDER BY fd.filedataid
    SQL

    current_count = 0
    total_count = uploads.count
    puts "  #{total_count} attachment(s) remaining"

    uploads.each do |upload|
      post_id =
        PostCustomField.where(name: "import_id").where(value: upload["nodeid"]).first&.post_id
      post_id =
        PostCustomField
          .where(name: "import_id")
          .where(value: "thread-#{upload["nodeid"]}")
          .first
          &.post_id unless post_id
      if post_id.nil?
        puts "Post for #{upload["nodeid"]} not found"
        save_attachment_checkpoint(upload["filedataid"])
        next
      end
      post = Post.find(post_id)

      real_filename = upload["filename"].to_s
      real_filename.prepend SecureRandom.hex if real_filename[0] == "."

      # Deduplicate only on the .attach filename - never fall back to real_filename
      # since generic names like "image.png" are not unique across imports.
      attach_filename = "#{upload["filedataid"]}.attach"
      existing_upload = Upload.find_by(original_filename: attach_filename)
      if existing_upload
        html = html_for_upload(existing_upload, real_filename)
        @filedataid_to_upload_html[upload["filedataid"].to_i]    = html
        @filedataid_to_upload_html[upload["attach_nodeid"].to_i] = html
        unless post.raw.include?(html)
          candidate = post.raw + "\n\n#{html}\n\n"
          if candidate.length <= SiteSetting.max_post_length
            post.raw = candidate
            post.save!
            UploadReference.ensure_exist!(upload_ids: [existing_upload.id], target: post)
          end
        end
        save_attachment_checkpoint(upload["filedataid"])
        current_count += 1
        print_status(current_count, total_count)
        next
      end

      filename =
        File.join(
          ATTACH_DIR,
          upload["userid"].to_s.split("").join("/"),
          "#{upload["filedataid"]}.attach",
        )

      unless File.exist?(filename)
        # attachments can be on filesystem or in database
        # try to retrieve from database if the file did not exist on filesystem
        if upload["dbsize"].to_i == 0
          placeholder = missing_attachment_placeholder(upload)
          puts "  [#{upload["filedataid"]}] not on disk and no DB data - adding placeholder"
          unless post.raw.include?(placeholder)
            candidate = post.raw + "\n\n#{placeholder}\n\n"
            if candidate.length <= SiteSetting.max_post_length
              post.raw = candidate
              post.save!
            end
          end
          save_attachment_checkpoint(upload["filedataid"])
          next
        end

        tmpfile = "attach_" + upload["filedataid"].to_s
        filename = File.join("/tmp/", tmpfile)
        File.open(filename, "wb") do |f|
          #f.write(PG::Connection.unescape_bytea(row['filedata']))
          f.write(upload["filedata"])
        end
      end

      upl_obj = create_upload(post.user.id, filename, real_filename)
      if upl_obj&.persisted?
        html = html_for_upload(upl_obj, real_filename)
        # Store by both filedataid and attach_nodeid so postprocess_post_raw
        # can resolve [ATTACH=JSON] tags which use data-attachmentid (nodeid).
        @filedataid_to_upload_html[upload["filedataid"].to_i]   = html
        @filedataid_to_upload_html[upload["attach_nodeid"].to_i] = html
        if !post.raw.include?(html)
          candidate = post.raw + "\n\n#{html}\n\n"
          if candidate.length > SiteSetting.max_post_length
            puts "  WARNING: skipping attachment #{upload["filedataid"]} (#{real_filename}) - " \
                 "appending would exceed max_post_length " \
                 "(#{candidate.length} > #{SiteSetting.max_post_length}) for post #{post.id}"
          else
            post.raw = candidate
            post.save!
            UploadReference.ensure_exist!(upload_ids: [upl_obj.id], target: post)
          end
        end
      else
        puts "  WARNING: failed to create upload for attachment #{upload["filedataid"]} (#{real_filename}), skipping"
      end
      save_attachment_checkpoint(upload["filedataid"])
      current_count += 1
      print_status(current_count, total_count)
    end

    # Clean up checkpoint file on successful completion
    File.delete(ATTACH_CHECKPOINT_FILE) if File.exist?(ATTACH_CHECKPOINT_FILE)
    puts "  Attachments complete, checkpoint cleared"
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

    DB.exec(sql, @closed_topic_ids)
  end

  def post_process_posts
    puts "", "Postprocessing posts..."

    # Pre-populate @filedataid_to_upload_html from already-imported uploads so
    # that [attach] tags resolve correctly on re-runs where import_attachments
    # was skipped. The original filename stored on the Upload record is
    # "<filedataid>.attach" for filesystem-sourced attachments, or the real
    # filename for DB-blob attachments. We match on the .attach pattern first.
    if @filedataid_to_upload_html.empty?
      puts "  rebuilding filedataid→upload_html map from existing uploads..."
      Upload.where("original_filename ~ '^[0-9]+\\.attach$'").find_each do |upl|
        fid = upl.original_filename.to_i
        @filedataid_to_upload_html[fid] ||= html_for_upload(upl, upl.original_filename)
      end
      puts "  #{@filedataid_to_upload_html.size} upload(s) mapped"
    end

    current = 0
    max = Post.count

    Post.find_each do |post|
      begin
        new_raw = postprocess_post_raw(post.raw)
        if new_raw != post.raw
          post.raw = new_raw
          post.save
        end
      rescue PrettyText::JavaScriptError, MiniRacer::RuntimeError, StandardError => e
        vb_id = PostCustomField.where(post_id: post.id, name: "import_id").pick(:value)
        puts "  WARNING: error postprocessing post #{post.id}, skipping: #{e.message.lines.first&.strip}"
        puts "    Discourse: #{Discourse.base_url}/p/#{post.id}"
        puts "    vBulletin node ID: #{vb_id || "unknown"}"
      ensure
        print_status(current += 1, max)
      end
    end
  end

  def preprocess_post_raw(raw)
    return "" if raw.blank?

    # Strip zero-width and other invisible Unicode characters that sneak in via
    # copy-paste in vBulletin editors. These corrupt URLs and look like trailing
    # junk when percent-encoded (e.g. %E2%80%8B for U+200B zero-width space).
    raw = raw.gsub(/[\u200B\u200C\u200D\uFEFF\u00AD]/, "")

    # decode HTML entities
    raw = decode_html_entities(raw)

    # Fast path: if there are no BBCode tags and no chevrons, nothing to do.
    return raw unless raw.include?("[") || raw.include?("<") || raw.include?(">")

    # fix whitespaces
    raw = raw.gsub(/(\\r)?\\n/, "\n").gsub("\\t", "\t").gsub(/^[ \t]+/, "")

    # Convert vBulletin smilie shortcodes to Unicode emoji.
    # Must run before BBCode processing since shortcodes use : delimiters.
    raw = raw.gsub(/(?<![:\w])(:[^:\s]+:|;\)|:\)|:D|:\(|:o|:p)(?![:\w])/) do |match|
      SMILIE_TEXT_EMOJI[match] || match
    end

    # [HTML]...[/HTML]
    raw = raw.gsub(/\[html\]/i, "\n```html\n").gsub(%r{\[/html\]}i, "\n```\n")

    # [PHP]...[/PHP]
    raw = raw.gsub(/\[php\]/i, "\n```php\n").gsub(%r{\[/php\]}i, "\n```\n")

    # [HIGHLIGHT="..."]
    raw = raw.gsub(/\[highlight="?(\w+)"?\]/i) { "\n```#{$1.downcase}\n" }

    # [CODE]...[/CODE] and [HIGHLIGHT]...[/HIGHLIGHT] - combined into one pass
    raw = raw.gsub(%r{\[/?(code|highlight)\]}i, "\n```\n")

    # [SAMP]...[/SAMP]
    raw = raw.gsub(%r{\[/?samp\]}i, "`")

    # replace all chevrons with HTML entities
    # NOTE: must be done
    #  - AFTER all the "code" processing
    #  - BEFORE the "quote" processing
    # Protect < and > inside backtick spans in a single pass using two sentinels,
    # then replace bare chevrons, then restore the sentinels.
    if raw.include?("<") || raw.include?(">")
      raw = raw.gsub(/`([^`]+)`/im) { "`" + $1.gsub("<", "\u2603").gsub(">", "\u2604") + "`" }
      raw = raw.gsub("<", "&lt;").gsub(">", "&gt;")
      raw = raw.gsub("\u2603", "<").gsub("\u2604", ">")
    end

    # [TABLE]/[TR]/[TD]/[TH] - convert to HTML after chevron escaping.
    # Strip all BBCode attributes (width, class, bgcolor, etc.)
    raw.gsub!(%r{\[(/?)(TABLE|TR|TH|TD)(?:=[^\]]*)?\]}i) do
      "<#{$1}#{$2.downcase}>"
    end

    # Inline formatting - convert to HTML so it works inside table cells
    # and anywhere else the discourse-bbcode plugin won't reach.
    raw.gsub!(%r{\[(/?)(b|strong|i|em|u|s|strike)\]}i) do
      "<#{$1}#{BBCODE_INLINE[$2.downcase]}>"
    end

    # [URL=...]...[/URL]
    # Strip vBulletin internal filedata URL wrappers around [ATTACH] tags before
    # the general URL handler runs, otherwise the [ATTACH] tag gets buried in HTML.
    raw.gsub!(%r{\[url=filedata/fetch\?[^\]]+\](.*?)\[/url\]}im, '\1')

    raw.gsub!(%r{\[url="?(.+?)"?\](.+?)\[/url\]}i) { "<a href=\"#{$1}\">#{$2}</a>" }

    # [URL]...[/URL] and [MP3]...[/MP3]
    raw = raw.gsub(%r{\[/?(url|mp3)\]}i, "")

    # [MENTION]<username>[/MENTION]
    raw =
      raw.gsub(%r{\[mention\](.+?)\[/mention\]}i) do
        old_username = $1
        if @old_username_to_new_usernames.has_key?(old_username)
          old_username = @old_username_to_new_usernames[old_username]
        end
        "@#{old_username}"
      end

    # [USER=<user_id>]<username>[/USER]
    raw =
      raw.gsub(%r{\[user="?(\d+)"?\](.+?)\[/user\]}i) do
        user_id, old_username = $1, $2
        if @old_username_to_new_usernames.has_key?(old_username)
          new_username = @old_username_to_new_usernames[old_username]
        else
          new_username = old_username
        end
        "@#{new_username}"
      end

    # Strip [SIZE], [FONT], [COLOR], [CENTER] opening and closing tags.
    # We strip only the tags themselves, leaving the content intact.
    # [B], [I], [S], [STRIKE], [U] are left for the discourse-bbcode plugin.
    raw.gsub!(%r{\[/?(size|font|indent|color|center|left|right)[^\]]*\]}i, "")
    # fix LIST - [LIST] = unordered, [LIST=1] or [LIST=a] = ordered
    raw.gsub!(%r{\[LIST(=\w+)?\](.*?)\[/LIST\]}im) do
      ordered = $1 && $1 != ""
      items = $2.gsub(/\[\*\]/i, "\x00").split("\x00").map(&:strip).reject(&:empty?)
      if ordered
        items.each_with_index.map { |item, i| "#{i + 1}. #{item}" }.join("\n")
      else
        items.map { |item| "* #{item}" }.join("\n")
      end
    end
    # Strip any stray [*] outside a list
    raw.gsub!(/\[\*\]/im, "")

    # [QUOTE]...[/QUOTE]
    raw = raw.gsub(%r{\[quote\](.+?)\[/quote\]}im) { "\n> #{$1}\n" }

    # [QUOTE=<username>]...[/QUOTE]
    # [QUOTE=<username>;<postid>]...[/QUOTE]   (vB5 format)
    # [QUOTE=<username>;n<postid>]...[/QUOTE]  (vB3/4 format)
    # Preserve the post ID (if any) as a placeholder so postprocess can resolve it.
    raw =
      raw.gsub(%r{\[quote=([^;\]]+)(?:;n?(\d+))?\](.+?)\[/quote\]}im) do
        old_username, post_id, quote = $1, $2, $3

        if @old_username_to_new_usernames.has_key?(old_username)
          old_username = @old_username_to_new_usernames[old_username]
        end

        if post_id
          "\n[quote=\"#{old_username},post:#{post_id}\"]\n#{quote}\n[/quote]\n"
        else
          "\n[quote=\"#{old_username}\"]\n#{quote}\n[/quote]\n"
        end
      end

    # [YOUTUBE]<id>[/YOUTUBE]
    raw = raw.gsub(%r{\[youtube\](.+?)\[/youtube\]}i) { "\n//youtu.be/#{$1}\n" }

    # [VIDEO=youtube;<id>]...[/VIDEO]
    raw = raw.gsub(%r{\[video=youtube;([^\]]+)\].*?\[/video\]}i) { "\n//youtu.be/#{$1}\n" }

    # [IMG]url[/IMG]
    raw.gsub!(%r{\[img\](.*?)\[/img\]}im) { "![](#{$1.strip})" }

    # Convert local smilie images to emoji, strip unknown local smilies.
    # Runs after [img] conversion so we match Markdown image syntax.
    raw.gsub!(%r{!\[\]\(([^)]+)\)}) do |match|
      path = $1
      result = smilie_to_emoji(path)
      case result
      when :not_smilie then match   # leave non-smilie images alone
      when nil         then ""      # known smilie path, unknown stem - strip
      else             result       # emoji replacement
      end
    end

    # [IMG2=JSON]{"src":"...","data-align":"none",...}[/IMG2]
    raw.gsub!(%r{\[img2=[^\]]*\](.*?)\[/img2\]}im) do
      begin
        src = JSON.parse($1)["src"].to_s.strip
        src.empty? ? "" : "![](#{src})"
      rescue JSON::ParserError
        ""
      end
    end

    # [EMAIL]addr[/EMAIL] and [EMAIL=addr]label[/EMAIL]
    raw.gsub!(%r{\[email=([^\]]+)\](.*?)\[/email\]}im) { "[#{$2}](mailto:#{$1})" }
    raw.gsub!(%r{\[email\](.*?)\[/email\]}im) { "<#{$1.strip}>" }

    # [SUP]...[/SUP]
    raw.gsub!(%r{\[sup\](.*?)\[/sup\]}im) { "<sup>#{$1}</sup>" }

    # [NOPARSE]...[/NOPARSE] - strip the tags, keep the content as-is
    raw.gsub!(%r{\[noparse\](.*?)\[/noparse\]}im, '\1')

    raw
  end

  def postprocess_post_raw(raw)
    # [quote="username,post:<vb_post_id>"] placeholders left by preprocess -
    # resolve the vBulletin post ID to a Discourse post number + topic ID.
    # Handles both vB5 (;postid) and vB3/4 (;npostid) forms, which preprocess
    # has already normalised to [quote="username,post:NNNN"].
    raw =
      raw.gsub(%r{\[quote="([^"]+),post:(\d+)"\](.+?)\[/quote\]}im) do
        username, post_id, quote = $1, $2, $3

        if topic_lookup = topic_lookup_from_imported_post_id(post_id)
          post_number = topic_lookup[:post_number]
          topic_id = topic_lookup[:topic_id]
          "\n[quote=\"#{username},post:#{post_number},topic:#{topic_id}\"]\n#{quote}\n[/quote]\n"
        else
          "\n[quote=\"#{username}\"]\n#{quote}\n[/quote]\n"
        end
      end

    # [ATTACH=JSON]...[/ATTACH]  (vBulletin 5 format)
    # The JSON is in the tag attribute, not the body. The relevant field is
    # "data-attachmentid" which maps to the vBulletin filedataid.
    # [ATTACH=config]<filedataid>[/ATTACH]  (vBulletin 3/4 format)
    # Replace inline with the Discourse upload HTML if the upload was imported;
    # strip the tag silently if not found (attachment was missing or skipped).

    # [ATTACH]<filedataid>[/ATTACH]  (vBulletin 3 plain format - no attribute)
    # If the upload markdown is already present elsewhere in the post (e.g. from
    # a prior import_attachments run), strip the tag to avoid duplication.
    # Otherwise replace with the upload markdown, or strip silently if not found.
    raw =
      raw.gsub(%r{\[attach\](\d+)\[/attach\]}i) do
        filedataid = $1.to_i
        html = @filedataid_to_upload_html[filedataid]
        if html.nil?
          ""
        elsif raw.include?(html)
          ""
        else
          html
        end
      end

    raw =
      raw.gsub(%r{\[attach=([^\]]+)\](.*?)\[/attach\]}im) do
        attr = $1.strip
        body = $2.strip
        filedataid =
          if attr.casecmp("json") == 0 && body.start_with?("{")
            # vB5 format: [ATTACH=JSON]{...json...}[/ATTACH]
            begin
              data = JSON.parse(body.gsub(/[\t\n\r]/, " "))
              (data["data-attachmentid"] || data["id"]).to_i.nonzero?
            rescue JSON::ParserError
              nil
            end
          elsif attr.start_with?("{")
            # vB5 format: [ATTACH={"data-attachmentid":...}]...[/ATTACH]
            begin
              data = JSON.parse(attr.gsub(/[\t\n\r]/, " "))
              (data["data-attachmentid"] || data["id"]).to_i.nonzero?
            rescue JSON::ParserError
              nil
            end
          else
            attr.to_i.nonzero?
          end
        filedataid && @filedataid_to_upload_html[filedataid] || ""
      end

    # [THREAD]<id>[/THREAD] and [POST]<id>[/POST]
    # ==> URL
    raw =
      raw.gsub(%r{\[(thread|post)\](\d+)\[/\1\]}i) do
        tag, id = $1.downcase, $2
        import_id = tag == "thread" ? "thread-#{id}" : id
        if topic_lookup = topic_lookup_from_imported_post_id(import_id)
          topic_lookup[:url]
        else
          ""
        end
      end

    # [THREAD=<id>]...[/THREAD] and [POST=<id>]...[/POST]
    # ==> [...](URL)
    raw =
      raw.gsub(%r{\[(thread|post)=(\d+)\](.+?)\[/\1\]}i) do
        tag, id, link = $1.downcase, $2, $3
        import_id = tag == "thread" ? "thread-#{id}" : id
        if topic_lookup = topic_lookup_from_imported_post_id(import_id)
          "[#{link}](#{topic_lookup[:url]})"
        else
          link
        end
      end

    raw
  end

  def create_permalinks
    puts "", "creating permalinks..."

    current_count = 0
    total_count =
      mysql_query(
        "SELECT COUNT(nodeid) cnt
        FROM #{DB_PREFIX}node
        WHERE (unpublishdate = 0 OR unpublishdate IS NULL)
        AND (approved = 1 AND showapproved = 1)
        AND parentid IN (
        SELECT nodeid FROM #{DB_PREFIX}node WHERE contenttypeid=#{@channel_typeid} ) AND contenttypeid=#{@text_typeid};",
      ).first[
        "cnt"
      ]

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query <<-SQL
        SELECT p.urlident p1, f.urlident p2, t.nodeid, t.urlident p3
        FROM #{DB_PREFIX}node f
        LEFT JOIN #{DB_PREFIX}node t ON t.parentid = f.nodeid
        LEFT JOIN #{DB_PREFIX}node p ON p.nodeid = f.parentid
        WHERE f.contenttypeid = #{@channel_typeid}
          AND t.contenttypeid = #{@text_typeid}
          AND t.approved = 1 AND t.showapproved = 1
          AND (t.unpublishdate = 0 OR t.unpublishdate IS NULL)
        ORDER BY t.nodeid
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL

      break if topics.size < 1

      topics.each do |topic|
        current_count += 1
        print_status current_count, total_count
        disc_topic = topic_lookup_from_imported_post_id("thread-#{topic["nodeid"]}")

        begin
          Permalink.create(
            url: "#{URL_PREFIX}#{topic["p1"]}/#{topic["p2"]}/#{topic["nodeid"]}-#{topic["p3"]}",
            topic_id: disc_topic[:topic_id],
          )
        rescue StandardError
          nil
        end
      end
    end

    # cats
    cats = mysql_query <<-SQL
      SELECT nodeid, urlident
      FROM #{DB_PREFIX}node
      WHERE contenttypeid=#{@channel_typeid}
      AND parentid=#{ROOT_NODE};
    SQL
    cats.each do |c|
      category_id =
        CategoryCustomField.where(name: "import_id").where(value: c["nodeid"]).first.category_id
      begin
        Permalink.create(url: "#{URL_PREFIX}#{c["urlident"]}", category_id: category_id)
      rescue StandardError
        nil
      end
    end

    # subcats
    subcats = mysql_query <<-SQL
      SELECT n1.nodeid,n2.urlident p1,n1.urlident p2
      FROM #{DB_PREFIX}node n1
      LEFT JOIN #{DB_PREFIX}node n2 ON n2.nodeid=n1.parentid
      WHERE n2.parentid = #{ROOT_NODE}
      AND n1.contenttypeid=#{@channel_typeid};
    SQL
    subcats.each do |sc|
      category_id =
        CategoryCustomField.where(name: "import_id").where(value: sc["nodeid"]).first.category_id
      begin
        Permalink.create(url: "#{URL_PREFIX}#{sc["p1"]}/#{sc["p2"]}", category_id: category_id)
      rescue StandardError
        nil
      end
    end
  end

  def create_redirect_permalinks
    puts "", "creating redirect permalinks..."

    redirects = mysql_query <<-SQL
      SELECT r.nodeid, r.tonodeid,
             n.urlident,
             p.urlident  AS parent_urlident,
             gp.urlident AS grandparent_urlident
      FROM #{DB_PREFIX}redirect r
      LEFT JOIN #{DB_PREFIX}node n  ON n.nodeid  = r.nodeid
      LEFT JOIN #{DB_PREFIX}node p  ON p.nodeid  = n.parentid
      LEFT JOIN #{DB_PREFIX}node gp ON gp.nodeid = p.parentid
    SQL

    created   = 0
    skipped   = 0
    duplicate = 0

    redirects.each do |row|
      old_url =
        "#{URL_PREFIX}#{row["grandparent_urlident"]}/#{row["parent_urlident"]}" \
        "/#{row["nodeid"]}-#{row["urlident"]}"

      disc_topic = topic_lookup_from_imported_post_id("thread-#{row["tonodeid"]}")
      if disc_topic.nil?
        skipped += 1
        next
      end

      begin
        Permalink.create!(url: old_url, topic_id: disc_topic[:topic_id])
        created += 1
      rescue ActiveRecord::RecordNotUnique
        duplicate += 1
      rescue StandardError => e
        puts "  WARNING: could not create permalink for #{old_url}: #{e.message}"
        skipped += 1
      end
    end

    puts "  redirect permalinks: created=#{created}, duplicate=#{duplicate}, skipped=#{skipped}"
  end

  def import_tags
    puts "", "importing tags..."

    SiteSetting.tagging_enabled = true
    SiteSetting.max_tags_per_topic = 100
    staff_guardian = Guardian.new(Discourse.system_user)

    records = mysql_query(<<~SQL).to_a
      SELECT nodeid, GROUP_CONCAT(tagtext) tags
      FROM #{DB_PREFIX}tag t
      LEFT JOIN #{DB_PREFIX}tagnode tn ON tn.tagid = t.tagid
      WHERE t.tagid IS NOT NULL
      AND tn.nodeid IS NOT NULL
      GROUP BY nodeid
    SQL

    current_count = 0
    total_count = records.count

    records.each do |rec|
      current_count += 1
      print_status current_count, total_count
      tl = topic_lookup_from_imported_post_id("thread-#{rec["nodeid"]}")
      next if tl.nil? # topic might have been deleted

      topic = Topic.find(tl[:topic_id])
      tag_names = rec["tags"].force_encoding("UTF-8").split(",")
      DiscourseTagging.tag_topic_by_names(topic, staff_guardian, tag_names)
    end
  end

  def resume_group_id
    return 0 if ENV["FULL_RESCAN"] == "1"
    val = GroupCustomField
            .where(name: "import_id")
            .maximum("CAST(value AS bigint)")
    val || 0
  end

  def resume_user_id
    return 0 if ENV["FULL_RESCAN"] == "1"
    val = UserCustomField
            .where(name: "import_id")
            .maximum("CAST(value AS bigint)")
    val || 0
  end

  def resume_topic_id
    return 0 if ENV["FULL_RESCAN"] == "1"
    # Find the highest vBulletin thread nodeid already imported, regardless of
    # how the previous run was started. Falls back to 0 if nothing imported yet.
    val = PostCustomField
            .where(name: "import_id")
            .where("value LIKE 'thread-%'")
            .pluck(:value)
            .map { |v| v.sub("thread-", "").to_i }
            .max
    val || 0
  end

  def resume_post_id
    return 0 if ENV["FULL_RESCAN"] == "1"
    # Find the highest vBulletin post nodeid already imported (plain numeric IDs only).
    val = PostCustomField
            .where(name: "import_id")
            .where("value ~ '^[0-9]+$'")
            .maximum("CAST(value AS bigint)")
    val || 0
  end

  # Maps vBulletin smilie filename stems to Unicode emoji.
  # Extend as needed for other smilie sets.
  SMILIE_EMOJI = {
    "smile"    => "😊",
    "redface"  => "😳",
    "biggrin"  => "😁",
    "wink"     => "😉",
    "tongue"   => "😛",
    "cool"     => "😎",
    "rolleyes" => "🙄",
    "mad"      => "😡",
    "eek"      => "😱",
    "confused" => "😕",
    "frown"    => "🙁",
  }.freeze

  # Convert a local smilie image path to an emoji character.
  # Returns the emoji string if the path is a known local smilie,
  # nil if it's a local smilie path but unknown stem (caller should strip),
  # or :not_smilie if the path is not a local smilie at all (caller leaves it).
  def smilie_to_emoji(path)
    return :not_smilie unless path.match?(%r{\A/?forum/images/smilies/|images/smilies/}i)
    stem = File.basename(path.strip, ".*")
    SMILIE_EMOJI[stem]  # nil if unknown stem
  end
  # Used by build_link_post_body when vB5 didn't capture a url_title.
  def fetch_page_title(url)
    return nil if url.blank? || url == "http://none"

    uri = URI.parse(url)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    response =
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 5,
        read_timeout: 5,
      ) { |http| http.get(uri.request_uri, "User-Agent" => "Mozilla/5.0") }

    return nil unless response.code == "200"

    match = response.body.match(/<title[^>]*>(.*?)<\/title>/im)
    return nil unless match

    decode_html_entities(match[1].strip)
  rescue StandardError
    nil
  end

  # Build the post body for a Link node. The body is a Markdown link with an
  # optional description paragraph below it.
  def build_link_post_body(url, url_title, meta)
    url = url.to_s.strip

    if url.blank? || url == "http://none"
      return "*[Link post: URL unavailable]*"
    end

    title =
      decode_html_entities(url_title.to_s.strip).presence ||
      fetch_page_title(url) ||
      url

    body = "[#{title}](#{url})"
    meta_text = decode_html_entities(meta.to_s.strip)
    body += "\n\n#{meta_text}" if meta_text.present?
    body
  end

  def import_gallery_photos
    puts "", "importing gallery photos..."

    photos = mysql_query <<-SQL
      SELECT p.nodeid AS photo_nodeid, p.filedataid, p.caption,
             fd.extension, fd.userid,
             gallery.nodeid AS gallery_nodeid
      FROM #{DB_PREFIX}photo p
      LEFT JOIN #{DB_PREFIX}filedata fd ON fd.filedataid = p.filedataid
      LEFT JOIN #{DB_PREFIX}node photo_node ON photo_node.nodeid = p.nodeid
      LEFT JOIN #{DB_PREFIX}node gallery ON gallery.nodeid = photo_node.parentid
      WHERE gallery.contenttypeid = #{@gallery_typeid}
      ORDER BY p.filedataid
    SQL

    total_count = photos.count
    current_count = 0
    puts "  #{total_count} gallery photo(s) to process"

    photos.each do |photo|
      current_count += 1
      print_status(current_count, total_count)

      gallery_nodeid = photo["gallery_nodeid"]
      filedataid     = photo["filedataid"].to_i

      # Find the already-imported Discourse post for this Gallery node.
      # Topic starters use import_id "thread-<nodeid>"; replies use plain "<nodeid>".
      post_id =
        PostCustomField.where(name: "import_id", value: "thread-#{gallery_nodeid}").first&.post_id
      post_id ||=
        PostCustomField.where(name: "import_id", value: gallery_nodeid.to_s).first&.post_id
      if post_id.nil?
        puts "  [gallery-photo-#{filedataid}] SKIP: Gallery post #{gallery_nodeid} not imported"
        next
      end
      post = Post.find_by(id: post_id)
      if post.nil?
        puts "  [gallery-photo-#{filedataid}] SKIP: post_id=#{post_id} not found"
        next
      end

      # Synthesize filename from filedataid + extension (no filename column in filedata)
      real_filename = "#{filedataid}.#{photo["extension"]}"

      # Check already imported
      existing_upload =
        Upload.find_by(original_filename: "#{filedataid}.attach") ||
        Upload.find_by(original_filename: real_filename)
      if existing_upload
        html = html_for_upload(existing_upload, real_filename)
        unless post.raw.include?(html)
          post.raw += "\n\n#{html}\n\n"
          post.save!
          UploadReference.ensure_exist!(upload_ids: [existing_upload.id], target: post)
        end
        next
      end

      # Files on disk use the same path scheme as regular attachments
      filename =
        File.join(
          ATTACH_DIR,
          photo["userid"].to_s.split("").join("/"),
          "#{filedataid}.attach",
        )

      unless File.exist?(filename)
        missing_label = photo["caption"].present? ? "#{photo["caption"]} (#{filedataid}.#{photo["extension"]})" : "#{filedataid}.#{photo["extension"]}"
        puts "  [gallery-photo-#{filedataid}] SKIP: file not found at #{filename}"
        unless post.raw.include?("*(Missing photo:")
          post.raw += "\n* *(Missing photo: #{missing_label})*"
          post.save!
        end
        next
      end

      upl_obj = create_upload(post.user.id, filename, real_filename)
      if upl_obj&.persisted?
        html = html_for_upload(upl_obj, real_filename)
        unless post.raw.include?(html)
          candidate = post.raw + "\n\n#{html}\n\n"
          if candidate.length > SiteSetting.max_post_length
            puts "  [gallery-photo-#{filedataid}] WARNING: skipping, would exceed max_post_length"
          else
            post.raw = candidate
            post.save!
            UploadReference.ensure_exist!(upload_ids: [upl_obj.id], target: post)
          end
        end
      else
        puts "  [gallery-photo-#{filedataid}] WARNING: upload failed for #{filename}"
      end
    end
  end

  # Returns a placeholder string for gallery posts with no rawtext.
  # Queries the photo count so the placeholder is informative.
  def gallery_placeholder(nodeid)
    count = mysql_query(<<~SQL).first["cnt"].to_i
      SELECT COUNT(*) cnt
      FROM #{DB_PREFIX}photo p
      JOIN #{DB_PREFIX}node n ON n.nodeid = p.nodeid
      WHERE n.parentid = #{nodeid}
    SQL
    count > 0 ? "Photos (#{count}):" : "*(Gallery)*"
  end

  # Import attachments for a single node into an already-existing Discourse post. Queries the attach table
  # for children of nodeid, uploads any not yet imported, appends upload markdown to the post, and populates
  # upload_map. Safe to call multiple times - skips already-imported uploads.
  # Build a human-readable placeholder for an attachment that cannot be found
  # on disk or in the DB blob. Includes all available vBulletin metadata.
  def missing_attachment_placeholder(upload_row)
    parts = []
    parts << upload_row["filename"].to_s if upload_row["filename"].present?
    parts << "#{(upload_row["filesize"].to_i / 1024.0).round(1)} KB" if upload_row["filesize"].to_i > 0
    if upload_row["dateline"].to_i > 0
      parts << Time.at(upload_row["dateline"].to_i).utc.strftime("%Y-%m-%d")
    end
    label = parts.any? ? parts.join(", ") : "filedataid #{upload_row["filedataid"]}"
    "*(Attachment missing: #{label})*"
  end

  def import_attachments_for_node(nodeid, post, upload_map)
    attach_dir = ATTACH_DIR

    uploads = mysql_query(<<~SQL).to_a
      SELECT a.filename, fd.userid, fd.filedataid, fd.filesize, fd.dateline,
             fd.filedata, LENGTH(fd.filedata) AS dbsize,
             a.nodeid AS attach_nodeid
      FROM #{DB_PREFIX}attach a
      JOIN #{DB_PREFIX}filedata fd ON fd.filedataid = a.filedataid
      JOIN #{DB_PREFIX}node n ON n.nodeid = a.nodeid
      WHERE n.parentid = #{nodeid}
    SQL

    return if uploads.empty?

    uploads.each do |upload|
      filedataid    = upload["filedataid"].to_i
      real_filename = upload["filename"].to_s
      real_filename.prepend(SecureRandom.hex) if real_filename.start_with?(".")

      # Deduplicate only on the .attach filename - never fall back to real_filename
      # since generic names like "image.png" are not unique across imports.
      attach_filename = "#{filedataid}.attach"
      existing_upload = Upload.find_by(original_filename: attach_filename)

      if existing_upload
        html = html_for_upload(existing_upload, real_filename)
        upload_map[filedataid] = html
        upload_map[upload["attach_nodeid"].to_i] = html
        unless post.raw.include?(html)
          post.raw += "\n\n#{html}\n\n"
          post.save!
          UploadReference.ensure_exist!(upload_ids: [existing_upload.id], target: post)
        end
        next
      end

      filename =
        File.join(attach_dir, upload["userid"].to_s.split("").join("/"), "#{filedataid}.attach")

      unless File.exist?(filename)
        if upload["dbsize"].to_i == 0
          placeholder = missing_attachment_placeholder(upload)
          puts "  [#{filedataid}] SKIP: not on disk and no DB data - adding placeholder"
          unless post.raw.include?(placeholder)
            post.raw += "\n\n#{placeholder}\n\n"
            post.save!
          end
          next
        end
        tmpfile = File.join("/tmp", "attach_#{filedataid}")
        File.open(tmpfile, "wb") { |f| f.write(upload["filedata"]) }
        filename = tmpfile
      end

      upl_obj = create_upload(post.user.id, filename, real_filename)
      if upl_obj&.persisted?
        html = html_for_upload(upl_obj, real_filename)
        upload_map[filedataid] = html
        upload_map[upload["attach_nodeid"].to_i] = html
        unless post.raw.include?(html)
          post.raw += "\n\n#{html}\n\n"
          post.save!
          UploadReference.ensure_exist!(upload_ids: [upl_obj.id], target: post)
        end
        puts "  [#{filedataid}] imported: #{real_filename}"
      else
        puts "  [#{filedataid}] FAILED to import: #{real_filename}"
      end
    end
  end

  def build_poll_syntax(nodeid)
    poll = mysql_query(<<~SQL).first
      SELECT multiple, public, timeout FROM #{DB_PREFIX}poll WHERE nodeid = #{nodeid}
    SQL
    return nil unless poll

    options = mysql_query(<<~SQL).to_a
      SELECT title FROM #{DB_PREFIX}polloption WHERE nodeid = #{nodeid} ORDER BY polloptionid
    SQL
    return nil if options.empty?

    type    = poll["multiple"].to_i == 1 ? "multiple" : "regular"
    public  = poll["public"].to_i   == 1 ? "true"     : "false"
    timeout = poll["timeout"].to_i

    attrs = "type=#{type} results=always public=#{public}"
    if timeout > 0
      close_time = Time.at(timeout).utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      attrs += " close=#{close_time}"
    end

    lines = ["[poll name=poll #{attrs}]"]
    seen_titles = Set.new
    options.each do |opt|
      title = decode_html_entities(opt["title"].to_s).strip
      next unless seen_titles.add?(title)  # skip duplicates
      lines << "* #{title}"
    end
    lines << "[/poll]"
    lines.join("\n")
  end

  def import_poll_votes
    polls_with_votes =
      mysql_query(<<~SQL).to_a
        SELECT DISTINCT p.nodeid
        FROM #{DB_PREFIX}poll p
        JOIN #{DB_PREFIX}pollvote pv ON pv.nodeid = p.nodeid
        WHERE pv.userid IS NOT NULL
      SQL

    total   = polls_with_votes.size
    current = 0

    polls_with_votes.each do |row|
      current += 1
      nodeid = row["nodeid"]

      post_id =
        PostCustomField.where(name: "import_id", value: "thread-#{nodeid}").first&.post_id
      post_id ||=
        PostCustomField.where(name: "import_id", value: nodeid.to_s).first&.post_id
      unless post_id
        puts "  [poll-#{nodeid}] SKIP: post not found in Discourse"
        next
      end

      post = Post.find_by(id: post_id)
      unless post
        puts "  [poll-#{nodeid}] SKIP: post_id=#{post_id} not found"
        next
      end

      poll = Poll.find_by(post: post, name: "poll")
      unless poll
        puts "  [poll-#{nodeid}] SKIP: no Poll record (post may lack [poll] syntax)"
        next
      end

      # Build vB polloptionid => Discourse PollOption.id map.
      # Digest formula (confirmed): MD5(JSON.generate([option_title]))
      options =
        mysql_query(<<~SQL).to_a
          SELECT polloptionid, title FROM #{DB_PREFIX}polloption
          WHERE nodeid = #{nodeid} ORDER BY polloptionid
        SQL

      option_map = {}
      options.each do |opt|
        title  = decode_html_entities(opt["title"].to_s).strip
        digest = Digest::MD5.hexdigest(JSON.generate([title]))
        discourse_opt = PollOption.find_by(poll: poll, digest: digest)
        unless discourse_opt
          puts "  [poll-#{nodeid}] WARNING: no PollOption for #{title.inspect}"
        end
        option_map[opt["polloptionid"]] = discourse_opt&.id
      end

      votes =
        mysql_query(<<~SQL).to_a
          SELECT polloptionid, userid FROM #{DB_PREFIX}pollvote
          WHERE nodeid = #{nodeid} AND userid IS NOT NULL
        SQL

      rows_to_insert = []
      anon_counts = Hash.new(0)  # poll_option_id => count of deleted-user votes

      votes.each do |vote|
        discourse_uid  = user_id_from_imported_user_id(vote["userid"])
        poll_option_id = option_map[vote["polloptionid"]]
        next unless poll_option_id

        if discourse_uid
          rows_to_insert << {
            poll_id:        poll.id,
            poll_option_id: poll_option_id,
            user_id:        discourse_uid,
            created_at:     Time.now,
            updated_at:     Time.now,
          }
        else
          anon_counts[poll_option_id] += 1
        end
      end

      if rows_to_insert.any?
        # insert_all avoids the missing `id` column issue with PollVote.
        # unique_by matches the composite unique index: (poll_id, poll_option_id, user_id)
        PollVote.insert_all(rows_to_insert, unique_by: %i[poll_id poll_option_id user_id])
      end

      # Set anonymous_votes for deleted-user votes. Always set (not increment)
      # so re-runs are idempotent.
      anon_counts.each do |poll_option_id, count|
        PollOption.where(id: poll_option_id).update_all(anonymous_votes: count)
      end

      print_status(current, total)
    end
  end

  # We can get an invalid code point. E.g., &#xD810;. This is HTML syntactically valid,
  # but references an illegal unicode scalar value. This handles that by deleting any
  # illegal characters.
  def decode_html_entities(str)
    @htmlentities.decode(str)
    rescue RangeError
      str.gsub(/&#x[0-9a-fA-F]+;|&#\d+;/) { |m|
        cp = m.start_with?('&#x') ? m[3..-2].to_i(16) : m[2..-2].to_i
        (cp >= 0 && cp <= 0x10FFFF && !(0xD800..0xDFFF).include?(cp)) ? m : ''
      }.then { |s| @htmlentities.decode(s) }
  end

  def parse_timestamp(timestamp)
    Time.zone.at(@tz.utc_to_local(Time.at(timestamp)))
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: false)
  end
end

ImportScripts::VBulletin.new.perform unless ENV["IMPORT_LIBRARY_ONLY"]
