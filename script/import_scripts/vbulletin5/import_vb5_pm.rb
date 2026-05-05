# frozen_string_literal: true

# Private message importer for vBulletin 5 -> Discourse.
#
# Run after vbulletin5.rb has completed importing users, topics, and posts.
# Inherits from ImportScripts::VBulletin. By default, immports all users PMs.
# This does not import a message if (a) every recipient has marked it deleted
# or (b) no recipients are active Discourse users (they were deleted or not
# migrated)
#
# Normal usage:
#   bundle exec ruby script/import_scripts/vbulletin5/import_vb5_pm.rb
#
# Forcing a reprocessing of all PMs:
#   FORCE=1 bundle exec ruby script/import_scripts/vbulletin5/import_vb5_pm.rb
#
# Testing with a single VBulletin userid (e.g., 12345)
#   TEST_USERID=12345 bundle exec ruby script/import_scripts/vbulletin5/import_vb5_pm.rb
#

ENV["IMPORT_LIBRARY_ONLY"] = "1"
require_relative "vbulletin5"
ENV.delete("IMPORT_LIBRARY_ONLY")

class ImportScripts::VBulletin5PM < ImportScripts::VBulletin

  TEST_USERID = ENV.key?("TEST_USERID") ? (ENV["TEST_USERID"].presence&.to_i) : false

  def initialize
    super  # load base importer data + sets up MySQL connection and typeids

    if TEST_USERID
      puts "  TEST MODE: limiting import to vBulletin userid #{TEST_USERID}"
    end

    # Populated by build_pm_sentto_lookup; keyed by nodeid (Integer)
    @pm_sentto = {}
  end

  def setup_mysql
    super

    @pm_typeid =
      mysql_query("SELECT contenttypeid FROM #{DB_PREFIX}contenttype WHERE class='PrivateMessage'").first[
        "contenttypeid"
      ]
  end

  def execute
    build_old_username_map
    build_pm_sentto_lookup
    import_pm_roots
    import_pm_replies
    import_pm_attachments
  end

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  def test_filter_sql(node_alias = "n")
    return "" unless TEST_USERID
    " AND #{node_alias}.nodeid IN (SELECT nodeid FROM #{DB_PREFIX}sentto WHERE userid = #{TEST_USERID})"
  end

  # Rebuild the old->new username map from already-imported Discourse data.
  # vbulletin5.rb builds this during import_users; we reconstruct it here.
  def build_old_username_map
    # UserCustomField stores the original vBulletin username under the key
    # 'import_username' (set by the base importer when the username had to be
    # changed to satisfy Discourse's constraints).  When the username was
    # accepted unchanged, no UserCustomField row is written, so we fall back to
    # the current Discourse username as both old and new.
    User.joins("LEFT JOIN user_custom_fields ucf ON ucf.user_id = users.id AND ucf.name = 'import_username'")
        .pluck("COALESCE(ucf.value, users.username)", "users.username")
        .each do |old_username, new_username|
          @old_username_to_new_usernames[old_username] = new_username
        end
  end

  # Load the sentto table into @pm_sentto hash keyed by nodeid.
  # Each value is an array of {userid:, deleted:} covering every participant
  # (sender and all recipients - vB5 includes the sender as a sentto row).
  def build_pm_sentto_lookup
    filter =
      if TEST_USERID
        " WHERE nodeid IN (SELECT nodeid FROM #{DB_PREFIX}sentto WHERE userid = #{TEST_USERID})"
      else
        ""
      end

    row_count = 0
    mysql_query("SELECT nodeid, userid, deleted FROM #{DB_PREFIX}sentto#{filter}").each do |row|
      nodeid = row["nodeid"]
      @pm_sentto[nodeid] ||= []
      @pm_sentto[nodeid] << { userid: row["userid"], deleted: row["deleted"] }
      row_count += 1
    end

    puts "  #{row_count} sentto rows loaded covering #{@pm_sentto.size} PM nodes"
  end

  # ---------------------------------------------------------------------------
  # Resume helpers
  # ---------------------------------------------------------------------------

  # Return the highest vBulletin nodeid already imported as a PM root,
  # by scanning post_custom_fields for 'pm-N' values. Returns 0 if none.
  def resume_pm_root_id
    return 0 if ENV["FORCE"].present?
    val = PostCustomField
            .where(name: "import_id")
            .where("value ~ '^pm-[0-9]+$'")
            .maximum("CAST(SUBSTRING(value FROM 4) AS bigint)")
    val || 0
  end

  # Return the highest vBulletin nodeid already imported as a PM reply,
  # by scanning post_custom_fields for 'pm-reply-N' values. Returns 0 if none.
  def resume_pm_reply_id
    return 0 if ENV["FORCE"].present?
    val = PostCustomField
            .where(name: "import_id")
            .where("value ~ '^pm-reply-[0-9]+$'")
            .maximum("CAST(SUBSTRING(value FROM 10) AS bigint)")
    val || 0
  end

  # ---------------------------------------------------------------------------
  # Participant resolution
  # ---------------------------------------------------------------------------

  # Given a root node row and its sentto rows, determine whether this PM
  # should be imported and who the Discourse participants are.
  #
  # Returns nil if the PM should be skipped (all participants deleted their
  # copy, or no participant maps to an active Discourse user).
  #
  # Otherwise returns:
  #   {
  #     usernames:    ["alice", "bob"],  # Discourse usernames for target_usernames
  #     post_user_id: <integer>,         # Discourse user_id to attribute the root post to
  #     preamble:     "..." or nil       # prepended note listing deleted participants
  #   }
  def resolve_pm_participants(root_node, sentto_rows)
    nodeid = root_node["nodeid"]

    if sentto_rows.empty?
      puts "  [pm-#{nodeid}] SKIP: no sentto rows found (not in @pm_sentto)"
      return nil
    end

    # Skip if every participant deleted their copy
    if sentto_rows.all? { |r| r[:deleted] == 1 }
      puts "  [pm-#{nodeid}] SKIP: all participants deleted their copy"
      return nil
    end

    sender_vb_userid = root_node["userid"].to_i
    resolved_usernames = []
    unresolved_labels  = []

    sentto_rows.each do |row|
      vb_uid = row[:userid].to_i
      discourse_uid = user_id_from_imported_user_id(vb_uid)

      if discourse_uid
        u = User.find_by(id: discourse_uid)
        if u
          resolved_usernames << u.username
        else
          unresolved_labels << "deleted user ##{vb_uid}"
        end
      else
        label =
          if vb_uid == sender_vb_userid && root_node["authorname"].present?
            "#{root_node["authorname"]} (deleted user ##{vb_uid})"
          else
            "deleted user ##{vb_uid}"
          end
        puts "  [pm-#{nodeid}] participant vb##{vb_uid} not in Discourse -> #{label}"
        unresolved_labels << label
      end
    end

    if resolved_usernames.empty?
      puts "  [pm-#{nodeid}] SKIP: no participants resolved to active Discourse users"
      return nil
    end

    sender_discourse_uid = user_id_from_imported_user_id(sender_vb_userid)
    post_user_id =
      if sender_discourse_uid
        sender_discourse_uid
      else
        Discourse::SYSTEM_USER_ID
      end

    preamble = unresolved_labels.any? ? pm_attribution_preamble(unresolved_labels) : nil

    {
      usernames:    resolved_usernames.uniq,
      post_user_id: post_user_id,
      preamble:     preamble,
    }
  end

  # Builds the human-readable note to prepend that lists the userids of any deleted
  # users who originally were part of the PM.
  def pm_attribution_preamble(unresolved_labels)
    "*[This conversation included deleted users: #{unresolved_labels.join(", ")}]*\n\n"
  end

  # ---------------------------------------------------------------------------
  # Import passes
  # ---------------------------------------------------------------------------

  # Import PM conversation roots (starter == nodeid) as Discourse
  # private_message topics. Resumable via resume_pm_root_id.
  def import_pm_roots
    puts "", "importing PM conversations..."
    puts "  TEST MODE: filtering roots to nodes involving vBulletin userid #{TEST_USERID}" if TEST_USERID

    last_id = resume_pm_root_id
    puts "  Resuming PM roots from nodeid > #{last_id}" if last_id > 0

    pm_count = mysql_query(<<~SQL).first["cnt"]
      SELECT COUNT(n.nodeid) cnt
      FROM #{DB_PREFIX}node n
      WHERE n.contenttypeid = #{@pm_typeid}
        AND n.starter = n.nodeid
        AND n.nodeid > #{last_id}
        #{test_filter_sql("n")}
    SQL
    puts "  #{pm_count} PM root(s) to import"

    skipped_no_participants = 0
    skipped_blank_body      = 0
    created_count           = 0

    batches(BATCH_SIZE) do |offset|
      roots = mysql_query(<<~SQL).to_a
        SELECT n.nodeid, n.userid, n.authorname, n.title, n.publishdate,
               CONVERT(CAST(t.rawtext AS BINARY) USING utf8) AS raw
        FROM #{DB_PREFIX}node n
        LEFT JOIN #{DB_PREFIX}text t ON t.nodeid = n.nodeid
        WHERE n.contenttypeid = #{@pm_typeid}
          AND n.starter = n.nodeid
          AND n.nodeid > #{last_id}
          #{test_filter_sql("n")}
        ORDER BY n.nodeid
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL

      break if roots.empty?

      create_posts(roots, total: pm_count, offset: offset) do |root|
        nodeid      = root["nodeid"]
        sentto_rows = @pm_sentto[nodeid] || []

        participants = resolve_pm_participants(root, sentto_rows)
        if participants.nil?
          skipped_no_participants += 1
          next
        end

        title = decode_html_entities(root["title"].to_s).strip
        title = "Private Message" if title.blank?

        body = preprocess_post_raw(root["raw"].to_s)
        if body.blank?
          skipped_blank_body += 1
          next
        end

        body = participants[:preamble] + body if participants[:preamble]
        created_count += 1

        {
          id:               "pm-#{nodeid}",
          user_id:          participants[:post_user_id],
          title:            title,
          raw:              body,
          created_at:       Time.at(root["publishdate"].to_i),
          archetype:        "private_message",
          target_usernames: participants[:usernames].join(","),
        }
      end
    end

    puts "  PM roots done: created=#{created_count}, " \
         "skipped_no_participants=#{skipped_no_participants}, " \
         "skipped_blank_body=#{skipped_blank_body}"
  end

  # Import PM replies (starter != nodeid) as posts within already-imported
  # PM topics. Resumable via resume_pm_reply_id.
  def import_pm_replies
    puts "", "importing PM replies..."
    puts "  TEST MODE: filtering replies to conversations involving vBulletin userid #{TEST_USERID}" if TEST_USERID

    last_id = resume_pm_reply_id

    # For replies, TEST_USERID filtering is on the starter (root) node, not the
    # reply node itself - replies don't have their own sentto rows.
    reply_test_filter =
      if TEST_USERID
        " AND n.starter IN (SELECT nodeid FROM #{DB_PREFIX}sentto WHERE userid = #{TEST_USERID})"
      else
        ""
      end

    reply_count = mysql_query(<<~SQL).first["cnt"]
      SELECT COUNT(n.nodeid) cnt
      FROM #{DB_PREFIX}node n
      WHERE n.contenttypeid = #{@pm_typeid}
        AND n.starter != n.nodeid
        AND n.nodeid > #{last_id}
        #{reply_test_filter}
    SQL

    skipped_no_parent   = 0
    skipped_blank_body  = 0
    created_count       = 0

    batches(BATCH_SIZE) do |offset|
      replies = mysql_query(<<~SQL).to_a
        SELECT n.nodeid, n.userid, n.authorname, n.starter, n.publishdate,
               CONVERT(CAST(t.rawtext AS BINARY) USING utf8) AS raw
        FROM #{DB_PREFIX}node n
        LEFT JOIN #{DB_PREFIX}text t ON t.nodeid = n.nodeid
        WHERE n.contenttypeid = #{@pm_typeid}
          AND n.starter != n.nodeid
          AND n.nodeid > #{last_id}
          #{reply_test_filter}
        ORDER BY n.nodeid
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL

      break if replies.empty?

      create_posts(replies, total: reply_count, offset: offset) do |reply|
        nodeid  = reply["nodeid"]
        starter = reply["starter"]

        # Look up the already-imported root topic.
        # Rescue RecordNotFound: can happen when a previous partial run left a
        # soft-deleted post whose post_custom_field still exists - the base
        # importer finds the PCF row but then calls Post.find which blows up
        # because the default scope excludes soft-deleted records.
        parent =
          begin
            topic_lookup_from_imported_post_id("pm-#{starter}")
          rescue ActiveRecord::RecordNotFound => e
            puts "  [pm-reply-#{nodeid}] SKIP: RecordNotFound looking up pm-#{starter}: #{e.message}"
            nil
          end
        if parent.nil?
          puts "  [pm-reply-#{nodeid}] SKIP: parent topic for pm-#{starter} not found " \
               "(root was skipped, soft-deleted, or not yet imported)"
          skipped_no_parent += 1
          next
        end

        body = preprocess_post_raw(reply["raw"].to_s)
        if body.blank?
          puts "  [pm-reply-#{nodeid}] SKIP: body is blank after preprocessing " \
               "(raw length=#{reply["raw"].to_s.length})"
          skipped_blank_body += 1
          next
        end

        # Resolve sender; fall back to system user with attribution preamble
        sender_uid = user_id_from_imported_user_id(reply["userid"].to_i)
        unless sender_uid
          author_label =
            reply["authorname"].present? ?
              "#{reply["authorname"]} (deleted user ##{reply["userid"]})" :
              "deleted user ##{reply["userid"]}"
          puts "  [pm-reply-#{nodeid}] sender vb##{reply["userid"]} not in Discourse -> posting as system user (#{author_label})"
          body       = "*[Originally from: #{author_label}]*\n\n" + body
          sender_uid = Discourse::SYSTEM_USER_ID
        end

        created_count += 1

        {
          id:         "pm-reply-#{nodeid}",
          user_id:    sender_uid,
          topic_id:   parent[:topic_id],
          raw:        body,
          created_at: Time.at(reply["publishdate"].to_i),
        }
      end
    end
  end

  # Import attachments for PM posts. Filesystem-only (no DB fallback needed).
  # Uses the same ATTACH_DIR and path scheme as import_attachments in vbulletin5.rb:
  #   ATTACH_DIR/<userid digits as dirs>/<filedataid>.attach
  def import_pm_attachments
    puts "", "importing PM attachments..."
    puts "  TEST MODE: filtering attachments to conversations involving vBulletin userid #{TEST_USERID}" if TEST_USERID

    # Authorised extensions from site settings.
    ext =
      mysql_query("SELECT GROUP_CONCAT(DISTINCT(extension)) exts FROM #{DB_PREFIX}filedata").first[
        "exts"
      ]&.split(",") || []
    SiteSetting.authorized_extensions =
      (SiteSetting.authorized_extensions.split("|") + ext).uniq.join("|") if ext.any?

    # Restrict to the test user's conversations when TEST_USERID is set.
    attach_test_filter =
      if TEST_USERID
        " AND EXISTS (SELECT 1 FROM #{DB_PREFIX}sentto WHERE nodeid = pm.nodeid AND userid = #{TEST_USERID})"
      else
        ""
      end

    # Fetch all attachments whose parent node is a PrivateMessage.
    # a.nodeid  = the attachment's own node
    # pm.nodeid = the PM post node the attachment belongs to (parent of attachment)
    # pm.starter = the root nodeid of the conversation; if pm.starter == pm.nodeid
    #              then the PM post is a root, otherwise it's a reply
    uploads = mysql_query(<<~SQL).to_a
      SELECT a.filename, fd.userid, fd.filedataid,
             fd.filedata, LENGTH(fd.filedata) AS dbsize,
             pm.nodeid AS pm_nodeid, pm.starter AS pm_starter
      FROM #{DB_PREFIX}attach a
      LEFT JOIN #{DB_PREFIX}filedata fd ON fd.filedataid = a.filedataid
      LEFT JOIN #{DB_PREFIX}node a_node ON a_node.nodeid = a.nodeid
      LEFT JOIN #{DB_PREFIX}node pm ON pm.nodeid = a_node.parentid
      WHERE pm.contenttypeid = #{@pm_typeid}
        #{attach_test_filter}
    SQL

    total_count   = uploads.size
    puts "  #{total_count} PM attachment(s) to process"

    current_count    = 0
    skipped_no_post  = 0
    skipped_no_file  = 0
    skipped_upload_fail = 0
    already_attached = 0
    created_count    = 0

    uploads.each do |upload|
      current_count += 1
      print_status(current_count, total_count)

      pm_nodeid  = upload["pm_nodeid"].to_i
      pm_starter = upload["pm_starter"].to_i
      filedataid = upload["filedataid"]

      # A PM post is a root when starter == nodeid; otherwise it's a reply
      import_id = pm_starter == pm_nodeid ? "pm-#{pm_nodeid}" : "pm-reply-#{pm_nodeid}"

      post_id = PostCustomField.where(name: "import_id", value: import_id).first&.post_id
      if post_id.nil?
        skipped_no_post += 1
        next
      end
      post = Post.find_by(id: post_id)
      if post.nil?
        skipped_no_post += 1
        next
      end

      filename =
        File.join(ATTACH_DIR, upload["userid"].to_s.split("").join("/"), "#{filedataid}.attach")

      unless File.exist?(filename)
        if upload["dbsize"].to_i == 0
          skipped_no_file += 1
          next
        end
        tmpfile = File.join("/tmp", "pm_attach_#{filedataid}")
        File.open(tmpfile, "wb") { |f| f.write(upload["filedata"]) }
        filename = tmpfile
      end

      real_filename = upload["filename"].to_s
      real_filename.prepend(SecureRandom.hex) if real_filename.start_with?(".")

      upl_obj = create_upload(post.user.id, filename, real_filename)
      if upl_obj&.persisted?
        html = html_for_upload(upl_obj, real_filename)
        if post.raw.include?(html)
          already_attached += 1
        else
          post.raw += "\n\n#{html}\n\n"
          post.save!
          UploadReference.ensure_exist!(upload_ids: [upl_obj.id], target: post)
          created_count += 1
        end
      else
        skipped_upload_fail += 1
      end
    end

    puts "  PM attachments done: created=#{created_count}, already_attached=#{already_attached}, " \
         "skipped_no_post=#{skipped_no_post}, skipped_no_file=#{skipped_no_file}, " \
         "skipped_upload_fail=#{skipped_upload_fail}"
  end
end

ImportScripts::VBulletin5PM.new.perform
