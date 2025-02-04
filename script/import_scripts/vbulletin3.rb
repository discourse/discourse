# frozen_string_literal: true

require "mysql2"
require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require "htmlentities"
begin
  require "php_serialize" # https://github.com/jqr/php-serialize
rescue LoadError
  puts
  puts "php_serialize not found."
  puts "Add to Gemfile, like this: "
  puts
  puts "echo gem \\'php-serialize\\' >> Gemfile"
  puts "bundle install"
  exit
end

# For vBulletin 3, based on vbulletin.rb which is for vBulletin 4.

class ImportScripts::VBulletin < ImportScripts::Base
  BATCH_SIZE = 1000

  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  DB_HOST = ENV["DB_HOST"] || "localhost"
  DB_NAME = ENV["DB_NAME"] || "vbulletin"
  DB_PW = ENV["DB_PW"] || ""
  DB_USER = ENV["DB_USER"] || "root"
  TIMEZONE = ENV["TIMEZONE"] || "America/Los_Angeles"
  TABLE_PREFIX = ENV["TABLE_PREFIX"] || "vb_"
  ATTACHMENT_DIR = ENV["ATTACHMENT_DIR"] || "/path/to/your/attachment/folder"
  IMAGES_DIR = ENV["IMAGES_DIR"] || "/path/to/your/images/folder"

  # Hostname + path of the forum. Used to transform deeplinks to posts and attachments to internal links
  FORUM_URL = ENV["FORUM_URL"] || "localhost/"

  # vBulletin forum ID to make to pre-seeded categories
  FORUM_GENERAL_ID = ENV["FORUM_GENERAL_ID"].to_i || -1
  FORUM_FEEDBACK_ID = ENV["FORUM_FEEDBACK_ID"].to_i || -1
  FORUM_STAFF_ID = ENV["FORUM_STAFF_ID"].to_i || -1

  # If non zero, create a user field containing the user title
  CREATE_USERTITLE_FIELD = ENV["CREATE_USERTITLE_FIELD"].to_i != 0 || false

  # You might also want to change the title and message for the imported private message archive
  # search for "PM ARCHIVE MESSAGE" in this script

  puts "#{DB_USER}:#{DB_PW}@#{DB_HOST} wants #{DB_NAME}"

  def initialize
    @bbcode_to_md = true

    super

    @usernames = {}

    @tz = TZInfo::Timezone.get(TIMEZONE)

    @htmlentities = HTMLEntities.new

    @client =
      Mysql2::Client.new(host: DB_HOST, username: DB_USER, password: DB_PW, database: DB_NAME)
  rescue Exception => e
    puts "=" * 50
    puts e.message
    puts <<EOM
Cannot connect in to database.

Hostname: #{DB_HOST}
Username: #{DB_USER}
Password: #{DB_PW}
database: #{DB_NAME}

Edit the script or set these environment variables:

export DB_HOST="localhost"
export DB_NAME="vbulletin"
export DB_PW=""
export DB_USER="root"
export TABLE_PREFIX="vb_"
export ATTACHMENT_DIR="/path/to/your/attachment/folder"
export IMAGES_DIR="/path/to/your/images/folder"

export FORUM_URL="hostname/path"
export FORUM_GENERAL_ID=-1
export FORUM_FEEDBACK_ID=-1
export FORUM_STAFF_ID=-1
export CREATE_USERTITLE_FIELD=0

Exiting.
EOM
    exit
  end

  def get_site_settings_for_import
    settings = super
    settings[:automatically_download_gravatars] = false
    settings[:max_post_length] = 150_000
    settings
  end

  def execute
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.max_category_nesting = 3
    SiteSetting.fixed_category_positions = true

    # showthread.php?.*t=19326.* -> showthread.php?t=19326
    # showthread.php?.*p=19326.* -> showpost.php?p=19326
    # showpost.php?.*p=19326.* -> showpost.php?p=19326
    SiteSetting.permalink_normalizations = <<~EOL.split("\n").join("|")
    /showthread\\.php.*[?&]t=(\\d+).*/showthread.php?t=\\1
    /showthread\\.php.*[?&]p=(\\d+).*/showpost.php?p=\\1
    /showpost\\.php.*[?&]p=(\\d+).*/showpost.php?p=\\1
    EOL

    begin
      mysql_query("CREATE INDEX firstpostid_index ON #{TABLE_PREFIX}thread (firstpostid)")
    rescue StandardError
      nil
    end

    import_settings

    import_groups
    # Do not enable while creating users, affects performance
    SiteSetting.migratepassword_enabled = false if SiteSetting.has_setting?(
      "migratepassword_enabled",
    )
    import_users
    SiteSetting.migratepassword_enabled = true if SiteSetting.has_setting?(
      "migratepassword_enabled",
    )
    create_groups_membership
    setup_group_membership_requests

    setup_default_categories
    import_categories
    setup_category_moderator_groups

    import_topics
    import_posts
    import_pm_archive
    import_attachments

    close_topics
    post_process_posts

    suspend_users
  end

  def import_settings
    puts "", "importing important forum settings..."
    settings =
      mysql_query(
        "SELECT varname, value FROM setting WHERE varname IN ('bbtitle', 'hometitle', 'companyname', 'webmasteremail')",
      ).map { |s| [s["varname"], s["value"]] }.to_h

    SiteSetting.title = settings["bbtitle"] if settings["bbtitle"] &&
      (SiteSetting.title == "Discourse" || !SiteSetting.title)
    SiteSetting.notification_email = settings["webmasteremail"] if settings["webmasteremail"] &&
      SiteSetting.notification_email == "noreply@unconfigured.discourse.org"
    if SiteSetting.company_name.nil? || SiteSetting.company_name.empty?
      if !settings["companyname"].empty?
        SiteSetting.company_name = settings["companyname"]
      elsif !settings["hometitle"].empty?
        SiteSetting.company_name = settings["hometitle"]
      end
    end
  end

  def import_groups
    puts "", "importing groups..."

    groups = mysql_query <<-SQL
        SELECT usergroupid, title, description, genericoptions, (SELECT count(*) > 0 FROM usergroupleader l WHERE l.usergroupid = g.usergroupid) as hasleaders
          FROM #{TABLE_PREFIX}usergroup g
         WHERE ispublicgroup = 1
      ORDER BY usergroupid
    SQL

    create_groups(groups) do |group|
      {
        id: group["usergroupid"],
        name: @htmlentities.decode(group["title"]).strip.downcase,
        full_name: group["title"],
        bio_raw: group["description"],
        public_admission: group["hasleaders"].to_i == 0,
        public_exit: true,
        visibility_level: 1,
        members_visibility_level: group["genericoptions"].to_i & 4 == 0 ? 4 : 0,
      }
    end
  end

  def setup_group_membership_requests
    puts "", "setting group membership requests..."
    groups = mysql_query <<-SQL
      SELECT distinct usergroupid
        FROM usergroupleader
    SQL
    groups.each do |gid|
      group_id = group_id_from_imported_group_id(gid["usergroupid"])
      next if !group_id
      group = Group.find(group_id)
      next if !group
      puts "\t#{group.name}"
      group.allow_membership_requests = true
      group.save()
    end
  end

  def get_username_for_old_username(old_username)
    @usernames.has_key?(old_username) ? @usernames[old_username] : old_username
  end

  def import_users
    puts "", "importing users..."

    leaders = mysql_query <<-SQL
      SELECT usergroupid, userid
        FROM usergroupleader
    SQL
    usergroupLeaders =
      leaders
        .map { |gl| [gl["usergroupid"], gl["userid"]] }
        .group_by { |gl| gl.shift }
        .transform_values { |values| values.flatten }

    # Exclude new users without confirmed email signed up more than 90 days ago
    user_count =
      mysql_query(
        "SELECT COUNT(userid) count FROM #{TABLE_PREFIX}user WHERE (usergroupid != 3 OR posts > 0 OR joindate > (unix_timestamp() - 90*259200))",
      ).first[
        "count"
      ]

    last_user_id = -1

    if CREATE_USERTITLE_FIELD
      userTitleField = UserField.find_by(name: "User title")
      if userTitleField.nil?
        userTitleField =
          UserField.new(
            name: "User title",
            description: "One line description about you.",
            editable: true,
            show_on_profile: true,
            requirement: "optional",
            field_type_enum: "text",
          )
        userTitleField.save!
        puts "created 'user title' user field"
      end
    end

    batches(BATCH_SIZE) do |offset|
      users = mysql_query(<<-SQL).to_a
          SELECT userid
               , username
               , homepage
               , usertitle
               , usergroupid
               , joindate
               , email
               , password
               , salt
               , membergroupids
               , ipaddress
               , birthday
            FROM #{TABLE_PREFIX}user
           WHERE userid > #{last_user_id}
             AND (usergroupid != 3 OR posts > 0 OR joindate > (unix_timestamp() - 90*259200))
        ORDER BY userid
           LIMIT #{BATCH_SIZE}
      SQL

      break if users.empty?

      last_user_id = users[-1]["userid"]
      users.reject! { |u| @lookup.user_already_imported?(u["userid"]) }

      create_users(users, total: user_count, offset: offset) do |user|
        email = user["email"].presence || fake_email
        email = fake_email if !EmailAddressValidator.valid_value?(email)

        password = [user["password"].presence, user["salt"].presence].compact
          .join(":")
          .delete("\000")

        username = @htmlentities.decode(user["username"]).strip
        group_ids = user["membergroupids"].split(",").map(&:to_i)
        ip_addr =
          begin
            IPAddr.new(user["ipaddress"])
          rescue StandardError
            nil
          end

        cfields = {}
        cfields["import_pass"] = password

        {
          id: user["userid"],
          username: username,
          password: password,
          email: email,
          merge: true,
          website: user["homepage"].strip,
          primary_group_id: group_id_from_imported_group_id(user["usergroupid"].to_i),
          created_at: parse_timestamp(user["joindate"]),
          last_seen_at: parse_timestamp(user["lastvisit"]),
          registration_ip_address: ip_addr,
          date_of_birth: parse_birthday(user["birthday"]),
          custom_fields: cfields,
          post_create_action:
            proc do |u|
              import_profile_picture(user, u)
              import_profile_background(user, u)
              if CREATE_USERTITLE_FIELD
                u.set_user_field(userTitleField.id, @htmlentities.decode(user["usertitle"]).strip)
              end
              u.grant_admin! if user["usergroupid"] == 6
              u.grant_moderation! if user["usergroupid"] == 5
              GroupUser.transaction do
                group_ids.each do |gid|
                  (group_id = group_id_from_imported_group_id(gid)) &&
                    GroupUser.find_or_create_by(user: u, group_id: group_id) do |groupUser|
                      groupUser.owner =
                        usergroupLeaders.include?(gid) &&
                          usergroupLeaders[gid].include?(user["userid"].to_i)
                    end
                end
              end
            end,
        }
      end
    end

    @usernames =
      UserCustomField
        .joins(:user)
        .where(name: "import_username")
        .pluck("user_custom_fields.value", "users.username")
        .to_h
  end

  def parse_birthday(birthday)
    return if birthday.blank?
    date_of_birth =
      begin
        Date.strptime(birthday.gsub(/[^\d-]+/, ""), "%m-%d-%Y")
      rescue StandardError
        nil
      end
    return if date_of_birth.nil?
    if date_of_birth.year < 1904
      Date.new(1904, date_of_birth.month, date_of_birth.day)
    else
      date_of_birth
    end
  end

  def create_groups_membership
    puts "", "creating groups membership..."

    Group.find_each do |group|
      begin
        next if group.automatic
        puts "\t#{group.name}"
        next if GroupUser.where(group_id: group.id).count > 0
        user_ids_in_group = User.where(primary_group_id: group.id).pluck(:id).to_a
        next if user_ids_in_group.size == 0
        values =
          user_ids_in_group
            .map { |user_id| "(#{group.id}, #{user_id}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)" }
            .join(",")

        DB.exec <<~SQL
          INSERT INTO group_users (group_id, user_id, created_at, updated_at) VALUES #{values}
        SQL

        Group.reset_counters(group.id, :group_users)
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
      end
    end
  end

  def import_profile_picture(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT c.filedata, c.filename, a.avatarpath
          FROM #{TABLE_PREFIX}user u
LEFT OUTER JOIN #{TABLE_PREFIX}customavatar c ON c.userid = u.userid AND c.visible = 1
LEFT OUTER JOIN #{TABLE_PREFIX}avatar a ON a.avatarid = u.avatarid
         WHERE u.userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    picture = query.first

    return if picture.nil?
    return if picture["filedata"].nil? && picture["avatarpath"].nil?

    customavatar = false
    file = nil
    filename = nil
    if !picture["filedata"].nil?
      file = Tempfile.new("profile-picture")
      file.write(picture["filedata"].encode("ASCII-8BIT").force_encoding("UTF-8"))
      file.rewind
      customavatar = true
      filename = picture["filename"]
    else
      filename = File.join(IMAGES_DIR, picture["avatarpath"])
      return unless File.exist?(filename)
      file = File.open(filename, "rb")
      filename = File.basename(filename)
    end

    upload = UploadCreator.new(file, filename).create_for(imported_user.id)

    return if !upload.persisted?

    imported_user.create_user_avatar
    imported_user.user_avatar.update(custom_upload_id: upload.id)
    imported_user.update(uploaded_avatar_id: upload.id)
  ensure
    begin
      file.close
    rescue StandardError
      nil
    end
    if customavatar
      begin
        file.unlind
      rescue StandardError
        nil
      end
    end
  end

  def import_profile_background(old_user, imported_user)
    query = mysql_query <<-SQL
        SELECT filedata, filename
          FROM #{TABLE_PREFIX}customprofilepic
         WHERE userid = #{old_user["userid"]}
      ORDER BY dateline DESC
         LIMIT 1
    SQL

    background = query.first

    return if background.nil?
    return if background["filedata"].nil?

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

  def setup_default_categories
    set_category_importid(SiteSetting.general_category_id, FORUM_GENERAL_ID)
    set_category_importid(SiteSetting.meta_category_id, FORUM_FEEDBACK_ID)
    set_category_importid(SiteSetting.staff_category_id, FORUM_STAFF_ID)
  end

  def set_category_importid(category_id, import_id)
    return if category_id == -1 || !import_id || import_id <= 0
    cat = Category.find_by_id(category_id)
    cat.custom_fields["import_id"] = import_id
    cat.save!
    add_category(import_id, cat)
  end

  def import_categories
    puts "", "importing top level categories..."

    categories = mysql_query(<<-SQL).to_a
          SELECT forumid, title, description, displayorder, parentid, parentId AS origParentId,
                 (options & 2 > 0) AS is_allow_posting,
                 (options & 4 = 0) AS is_category_only,
                 (SELECT forumpermissions & 524288 > 0 FROM #{TABLE_PREFIX}forumpermission fp WHERE fp.forumid = f.forumid AND usergroupid = 1) AS public_access,
                 (SELECT forumpermissions & 524288 > 0 FROM #{TABLE_PREFIX}forumpermission fp WHERE fp.forumid = f.forumid AND usergroupid = 2) AS registered_access,
                 (SELECT forumpermissions & 16 > 0 FROM #{TABLE_PREFIX}forumpermission fp WHERE fp.forumid = f.forumid AND usergroupid = 2) AS registered_create,
                 (SELECT forumpermissions & 96 > 0 FROM #{TABLE_PREFIX}forumpermission fp WHERE fp.forumid = f.forumid AND usergroupid = 2) AS registered_reply,
                 (SELECT max(forumpermissions & 524288 > 0) FROM #{TABLE_PREFIX}forumpermission fp WHERE fp.forumid = f.forumid AND usergroupid IN (5,6)) AS staff_access,
                 (SELECT count(DISTINCT coalesce(fp.forumpermissions & 524288 > 0, 2)) > 1 FROM #{TABLE_PREFIX}usergroup ug LEFT OUTER JOIN #{TABLE_PREFIX}forumpermission fp ON fp.forumid = f.forumid AND fp.usergroupid = ug.usergroupid WHERE ug.ispublicgroup = 1) AS special_access
            FROM #{TABLE_PREFIX}forum f 
        ORDER BY forumid
      SQL

    categories.each { |c| c["parent"] = categories.detect { |p| p["forumid"] == c["parentid"] } }

    top_level_categories = categories.select { |c| c["parentid"] == -1 }

    create_categories(top_level_categories) do |category|
      {
        id: category["forumid"],
        name: @htmlentities.decode(category["title"]).strip,
        position: category["displayorder"],
        description: @htmlentities.decode(category["description"]).strip,
      }
    end

    top_level_categories.each { |c| import_subcategories(c, categories, 1) }

    categories.each do |forum|
      cat_id = category_id_from_imported_category_id(forum["forumid"])
      if cat_id
        Permalink.find_or_create_by(
          url: "forumdisplay.php?f=#{forum["forumid"]}",
          category_id: cat_id,
        )
      end
    end

    puts "", "applying category permissions..."
    top_level_categories.each { |c| process_category_permissions(c, categories) }
  end

  def process_category_permissions(cat, categories)
    access = flatten_forum_access(cat, categories)
    apply_category_permissions(
      Category.find(category_id_from_imported_category_id(cat["forumid"])),
      cat,
      access,
    )

    children_categories = categories.select { |c| c["parentid"] == cat["forumid"] }
    children_categories.each { |c| process_category_permissions(c, categories) }
  end

  def flatten_forum_access(category, categories)
    access = {
      public_access: nil,
      registered_access: nil,
      registered_create: nil,
      registered_reply: nil,
      staff_access: nil,
      special_access: 0,
    }
    while category
      access.keys.each { |p| access[p] = category[p.to_s] if access[p].nil? }
      access[:special_access] = category["special_access"] if access[:special_access] == 0
      category = categories.detect { |c| c["forumid"] == category["origParentId"] }
    end
    # Assume standard access
    access[:public_access] = 1 if access[:public_access].nil?
    access[:registered_access] = 1 if access[:registered_access].nil?
    access[:registered_create] = 1 if access[:registered_create].nil?
    access[:registered_reply] = 1 if access[:registered_reply].nil?

    access
  end

  def apply_category_permissions(category, forum, access)
    if !category.subcategories.empty?
      category.show_subcategory_list = true
      category.subcategory_list_style = "rows_with_featured_topics"
    end

    if forum["is_category_only"] == 1
      # Mimmic vbulletin behavior to not show any posts
      category.default_list_filter = "none"
    end
    if !category.subcategories.empty? && forum["is_category_only"] == 0
      # Also a forum, don't show content of subforum
      category.default_list_filter = "none"
    end

    if (forum["is_category_only"] == 1 && access[:public_access] == 1)
      puts "\t#{category.name} is a public category only"
      category.permissions = { everyone: :readonly }
      category.save()
      return
    end

    permissions = {}
    base_level = "trust_level_0"
    base_level = :everyone if access[:public_access] == 1

    if access[:registered_access] == 1
      if forum["is_allow_posting"] == 0 || forum["is_category_only"] == 1
        permissions[base_level] = :readonly
      elsif access[:registered_create] == 1
        permissions[base_level] = :full
      elsif access[:registered_reply] == 1
        permissions[base_level] = :create_post
      else
        permissions[base_level] = :readonly
      end
    end

    permissions["staff"] = :full if access[:staff_access] == 1

    apply_special_category_permissions(category, forum, permissions) if access[:special_access] == 1

    puts "\t#{category.name} permissions: #{permissions}"
    category.permissions = permissions
    category.save()
  end

  def apply_special_category_permissions(category, forum, permissions)
    parent_public = true
    parent_parent_public = true
    if !category.parent_category.nil?
      parent_public =
        category.parent_category.category_groups.any? { |g| g.group.id == 0 } ||
          category.parent_category.category_groups.empty?
      if !category.parent_category.parent_category.nil?
        parent_parent_public =
          category.parent_category.parent_category.category_groups.any? { |g| g.group.id == 0 } ||
            category.parent_category.parent_category.category_groups.empty?
      end
    end
    apply_defaults = permissions.empty?
    specials = {}
    while !forum.nil?
      forumid = forum["forumid"]
      result = mysql_query(<<-SQL)
          SELECT ug.usergroupid, ug.title,
                   fp.forumpermissions IS NOT NULL as non_default,
                   coalesce(fp.forumpermissions & 524288 > 0, ug.forumpermissions & 524288 > 0) as can_see,
                   coalesce(fp.forumpermissions & 16 > 0, ug.forumpermissions & 16> 0) as can_create,
                   coalesce(fp.forumpermissions & 96 > 0, ug.forumpermissions & 96 > 0) as can_reply
            FROM #{TABLE_PREFIX}usergroup ug
       LEFT JOIN #{TABLE_PREFIX}forumpermission fp ON fp.usergroupid = ug.usergroupid AND fp.forumid = #{forumid}
           WHERE ug.ispublicgroup = 1
             AND (fp.forumpermissions & 524288 > 0
              OR ug.forumpermissions & 524288 > 0)
        SQL
      forum = forum["parent"]
      result.each do |perms|
        groupid = perms["usergroupid"]
        if specials[groupid].nil?
          specials[groupid] = perms
        elsif specials[groupid]["non_default"] == 0
          specials[groupid] = perms
        end
      end
    end

    specials.each_value do |perms|
      next if perms["can_see"] == 0
      next if !apply_defaults && perms["non_default"] == 0
      groupid = group_id_from_imported_group_id(perms["usergroupid"])
      if perms["can_create"] == 1
        permissions[groupid] = :full
      elsif perms["can_reply"] == 1
        permissions[groupid] = :create_post
      else
        permissions[groupid] = :readonly
      end
      # If parents are not public the group must also have readonly access to parent
      if !parent_parent_public
        add_minimal_access_to_category(category.parent_category.parent_category, groupid)
      end
      add_minimal_access_to_category(category.parent_category, groupid) if !parent_public
    end
  end

  def add_minimal_access_to_category(category, groupid)
    return if category.parent_category.category_groups.any? { |g| g.group.id == groupid }
    category.category_groups.build(group_id: groupid, permission_type: :readonly)
    category.save()
  end

  def import_subcategories(parent, categories, depth)
    children_categories = categories.select { |c| c["parentid"] == parent["forumid"] }
    return if children_categories.empty?

    puts "",
         "importing #{children_categories.length} child categories for \"#{parent["title"]}\" (depth #{depth})..."

    if depth >= SiteSetting.max_category_nesting
      puts "\treducing category depth"
      children_categories.each do |cc|
        while cc["parentid"] != parent["forumid"]
          cc["parentid"] = categories.detect { |c| c["forumid"] == cc["parentid"] }["parentid"]
        end
      end
    end

    create_categories(children_categories) do |category|
      {
        id: category["forumid"],
        name: @htmlentities.decode(category["title"]).strip,
        position: category["displayorder"],
        description: @htmlentities.decode(category["description"]).strip,
        parent_category_id: category_id_from_imported_category_id(category["parentid"]),
      }
    end

    children_categories.each { |c| import_subcategories(c, categories, depth + 1) }
  end

  def setup_category_moderator_groups
    puts "", "creating category moderator groups..."
    forums = mysql_query("SELECT forumid, parentid, title FROM #{TABLE_PREFIX}forum").to_a
    forums.each { |f| f["children"] = forums.select { |c| c["parentid"] == f["forumid"] } }
    forum_map = forums.map { |f| [f["forumid"], f] }.to_h
    modentries = mysql_query(<<-SQL).to_a
      SELECT m.forumid, m.userid, u.usergroupid IN (5,6) is_staff
        FROM #{TABLE_PREFIX}moderator m
        JOIN #{TABLE_PREFIX}user u ON u.userid = m.userid
       WHERE permissions & 1 > 0
         AND forumid > -1
    SQL

    forum_mods = {}
    modentries.each do |mod|
      forumid = mod["forumid"]
      forum_mods[forumid] = [] if forum_mods[forumid].nil?
      forum_mods[forumid] << mod
    end

    forum_mods.each do |forumid, mods|
      forum = forum_map[forumid]
      puts "\tcreating moderator group for #{forumid}: " + forum["title"]
      group = {
        id: "forummod-#{forumid}",
        name: "mods_" + @htmlentities.decode(forum["title"]).strip.downcase,
        full_name: "Moderators: " + forum["title"],
        public_admission: false,
        public_exit: true,
        visibility_level: 2,
        members_visibility_level: 2,
      }
      group_id = group_id_from_imported_group_id(group[:id])
      group_id = create_group(group, group[:id]).id if !group_id
      mods.each do |m|
        GroupUser.find_or_create_by(
          user_id: user_id_from_imported_user_id(m["userid"]),
          group_id: group_id,
        )
      end
      parent_forum = forum_map[forum["parentid"]]
      while parent_forum
        parent_id = parent_forum["forumid"]
        parent_mods = forum_mods[parent_id]
        if parent_mods
          parent_mods.each do |m|
            GroupUser.find_or_create_by(
              user_id: user_id_from_imported_user_id(m["userid"]),
              group_id: group_id,
            )
          end
        end
        parent_forum = forum_map[parent_forum["parentid"]]
      end
      apply_category_moderator_group(forum_map, forumid, Group.find(group_id))
    end
  end

  def apply_category_moderator_group(forum_map, forum_id, group)
    category = Category.find(category_id_from_imported_category_id(forum_id))
    category.reviewable_by_group = group
    category.save()

    forum_map[forum_id]["children"].each do |c|
      apply_category_moderator_group(forum_map, c["forumid"], group)
    end
  end

  def import_topics
    puts "", "importing topics..."

    topic_count =
      mysql_query(
        "SELECT COUNT(threadid) count FROM #{TABLE_PREFIX}thread WHERE visible <> 2 AND firstpostid <> 0",
      ).first[
        "count"
      ]

    last_topic_id = -1

    batches(BATCH_SIZE) do |offset|
      topics = mysql_query(<<-SQL).to_a
          SELECT t.threadid threadid, t.title title, forumid, open, postuserid, t.dateline dateline, views, t.visible visible, sticky,
                 p.postid, p.pagetext raw, t.pollid pollid
            FROM #{TABLE_PREFIX}thread t
            JOIN #{TABLE_PREFIX}post p ON p.postid = t.firstpostid
           WHERE t.threadid > #{last_topic_id} AND t.visible <> 2
        ORDER BY t.threadid
           LIMIT #{BATCH_SIZE}
      SQL

      break if topics.empty?

      last_topic_id = topics[-1]["threadid"]
      topics.reject! { |t| @lookup.post_already_imported?("thread-#{t["threadid"]}") }

      create_posts(topics, total: topic_count, offset: offset) do |topic|
        raw =
          begin
            preprocess_post_raw(topic["raw"])
          rescue StandardError => e
            puts "",
                 "\tFailed preprocessing raw for thread #{topic["threadid"]}",
                 e.message,
                 e.backtrace
            nil
          end

        if raw.blank?
          puts "", "\tNo body for thread #{topic["threadid"]}"
          next
        end

        poll_data, poll_raw = retrieve_poll_data(topic["pollid"])
        raw = poll_raw << "\n\n" << raw if poll_raw

        topic_id = "thread-#{topic["threadid"]}"
        t = {
          id: topic_id,
          user_id: user_id_from_imported_user_id(topic["postuserid"]) || Discourse::SYSTEM_USER_ID,
          title: @htmlentities.decode(topic["title"]).strip[0...255],
          category: category_id_from_imported_category_id(topic["forumid"]),
          raw: raw,
          created_at: parse_timestamp(topic["dateline"]),
          visible: topic["visible"].to_i == 1,
          views: topic["views"],
          custom_fields: {
            import_post_id: topic["postid"],
          },
          post_create_action:
            proc do |post|
              add_post(topic["postid"].to_s, post)
              post_process_poll(post, poll_data) if poll_data
              Permalink.create(
                url: "showthread.php?t=#{topic["threadid"]}",
                topic_id: post.topic_id,
              )
              Permalink.create(url: "showpost.php?p=#{topic["postid"]}", topic_id: post.topic_id)
            end,
        }
        t[:pinned_at] = t[:created_at] if topic["sticky"].to_i == 1
        t
      end
    end
  end

  def retrieve_poll_data(pollid)
    return nil, nil if pollid <= 0
    poll_data = mysql_query("SELECT * FROM #{TABLE_PREFIX}poll WHERE pollid = #{pollid}").first.to_h
    return nil, nil if !poll_data["pollid"]

    options = poll_data["options"].split("|||")
    # Ensure unique values
    options.each_index do |x|
      cnt = 1
      val = preprocess_post_raw(options[x])
      val.strip!
      # escape some markdown which probably shouldn't be there
      val.gsub!(/^([*#>_-])/) { "\\#{$1}" }
      val = "." if val == ""
      idx = options.find_index(val)
      while !idx.nil? && idx < x
        cnt += 1
        val = options[x].strip << " (#{cnt})"
        idx = options.find_index(val)
      end
      options[x] = val
    end

    arguments = ["results=on_vote"]
    arguments << "status=closed" if poll_data["active"] == 0
    arguments << "type=multiple" if poll_data["multiple"] == 1
    arguments << "public=true" if poll_data["public"] == 1
    if poll_data["timeout"] > 0
      arguments << "close=" + parse_timestamp(poll_data["timeout"]).iso8601
    end

    raw = poll_data["question"].dup
    raw << "\n\n[poll #{arguments.join(" ")}]"
    options.each { |opt| raw << "\n* #{opt}" }
    raw << "\n[/poll]"

    [poll_data, raw]
  end

  def post_process_poll(post, poll_data)
    poll = post.polls.first
    return if !poll

    option_map = {}
    poll.poll_options.each_with_index { |option, index| option_map[index + 1] = option.id }
    poll_votes =
      mysql_query(
        "SELECT * FROM #{TABLE_PREFIX}pollvote WHERE pollid = #{poll_data["pollid"]} AND votetype = 0",
      )
    poll_votes.each do |vote|
      PollVote.create!(
        poll: poll,
        poll_option_id: option_map[vote["voteoption"]],
        user_id: user_id_from_imported_user_id(vote["userid"]),
      )
    end
  end

  def import_posts
    puts "", "importing posts..."

    post_count = mysql_query(<<-SQL).first["count"]
      SELECT COUNT(postid) count
        FROM #{TABLE_PREFIX}post p
        JOIN #{TABLE_PREFIX}thread t ON t.threadid = p.threadid
       WHERE t.firstpostid <> p.postid
         AND p.visible <> 2
         AND t.visible <> 2
    SQL

    last_post_id = -1

    batches(BATCH_SIZE) do |offset|
      posts = mysql_query(<<-SQL).to_a
          SELECT p.postid, p.userid, p.threadid, p.pagetext raw, p.dateline, p.visible, p.parentid, p.attach
            FROM #{TABLE_PREFIX}post p
            JOIN #{TABLE_PREFIX}thread t ON t.threadid = p.threadid
           WHERE t.firstpostid <> p.postid AND t.visible <> 2 AND p.visible <> 2
             AND p.postid > #{last_post_id}
        ORDER BY p.postid
           LIMIT #{BATCH_SIZE}
      SQL

      break if posts.empty?

      last_post_id = posts[-1]["postid"]
      posts.reject! { |p| @lookup.post_already_imported?(p["postid"].to_i) }

      create_posts(posts, total: post_count, offset: offset) do |post|
        raw =
          begin
            preprocess_post_raw(post["raw"])
          rescue StandardError => e
            puts "", "\tFailed preprocessing raw for post #{post["postid"]}", e.message, e.backtrace
            nil
          end

        if raw.blank?
          if post["attach"] > 0
            # Post with no text, but does have attachments
            raw = "[attach]0[/attach]"
          else
            puts "", "\tNo body for post #{post["postid"]}"
            next
          end
        end

        unless topic = topic_lookup_from_imported_post_id("thread-#{post["threadid"]}")
          puts "", "\tMissing thread for post #{post["postid"]}: thread-#{post["threadid"]}"
          next
        end

        p = {
          id: post["postid"],
          user_id: user_id_from_imported_user_id(post["userid"]) || Discourse::SYSTEM_USER_ID,
          topic_id: topic[:topic_id],
          raw: raw,
          created_at: parse_timestamp(post["dateline"]),
          hidden: post["visible"].to_i != 1,
          post_create_action:
            proc do |realpost|
              Permalink.create(url: "showpost.php?p=#{post["postid"]}", post_id: realpost.id)
            end,
        }
        if parent = topic_lookup_from_imported_post_id(post["parentid"])
          p[:reply_to_post_number] = parent[:post_number]
        end
        p
      end
    end
  end

  # find the uploaded file information from the db
  def find_upload(post, attachment_id)
    sql =
      "SELECT a.attachmentid attachment_id, a.userid user_id, a.attachmentid file_id, a.filename filename,
                  LENGTH(a.filedata) AS dbsize, filedata
             FROM #{TABLE_PREFIX}attachment a
            WHERE a.attachmentid = #{attachment_id}"
    results = mysql_query(sql)

    unless row = results.first
      puts "",
           "\tCouldn't find attachment record #{attachment_id} for post.id = #{post.id}, import_id = #{post.custom_fields["import_id"]}"
      return nil, nil
    end

    filename =
      File.join(ATTACHMENT_DIR, row["user_id"].to_s.split("").join("/"), "#{row["file_id"]}.attach")
    real_filename = row["filename"]
    real_filename.prepend SecureRandom.hex if real_filename[0] == "."

    unless File.exist?(filename)
      if row["dbsize"].to_i == 0
        puts "",
             "\tAttachment file #{row["attachment_id"]} doesn't exist. Filename: #{real_filename}. Path: #{filename}"
        return nil, real_filename
      end

      tmpfile = "attach_" + row["filedataid"].to_s
      filename = File.join("/tmp/", tmpfile)
      File.open(filename, "wb") { |f| f.write(row["filedata"]) }
    end

    upload = create_upload(post.user.id, filename, real_filename)

    if upload.nil? || !upload.valid?
      puts "", "\tUpload not valid :( Attachment #{attachment_id}"
      puts upload.errors.inspect if upload
      return nil, real_filename
    end

    [upload, real_filename]
  rescue Mysql2::Error => e
    puts "SQL Error"
    puts e.message
    puts sql
  end

  def import_pm_archive
    puts "", "importing private message archives..."
    pm_count = mysql_query("SELECT COUNT(pmid) count FROM #{TABLE_PREFIX}pm").first["count"]
    current_count = 0
    start = Time.now

    users = mysql_query("SELECT distinct userid FROM #{TABLE_PREFIX}pm").to_a
    users.each do |row|
      userid = row["userid"]
      real_userid = user_id_from_imported_user_id(userid)

      if @lookup.post_already_imported?("pmarchive-#{userid}") || real_userid.nil?
        usrcnt =
          mysql_query(
            "SELECT COUNT(pmid) count FROM #{TABLE_PREFIX}pm WHERE userid = #{userid}",
          ).first[
            "count"
          ]
        current_count += usrcnt
        print_status current_count, pm_count, start
        next
      end

      filename = "pm-archive-#{userid}.txt"
      filepath = File.join("/tmp/", "pm-archive-#{userid}.txt")

      File.open(filepath, "wb") do |f|
        user_pm = mysql_query(<<-SQL)
          SELECT p.pmid, p.parentpmid, t.fromuserid, t.fromusername, t.title, t.message, t.dateline, t.touserarray
            FROM #{TABLE_PREFIX}pm p
            JOIN #{TABLE_PREFIX}pmtext t on t.pmtextid = p.pmtextid
           WHERE p.userid = #{userid}
           ORDER BY t.dateline
        SQL

        user_pm.each do |pm|
          current_count += 1
          print_status current_count, pm_count, start

          f << "---\n"
          f << "id: #{pm["pmid"]}\n"
          f << "in_reply_to: #{pm["parentpmid"]}\n" if pm["parentpmid"] > 0
          ts = parse_timestamp(pm["dateline"]).iso8601
          f << "timestamp: #{ts}\n"
          title =
            @htmlentities.decode(
              pm["title"].encode("UTF-8", invalid: :replace, undef: :replace, replace: ""),
            )
          f << "title: #{title}\n"
          f << "from: #{pm["fromusername"]}\n"
          to_usernames, to_userids = get_pm_recipients(pm)
          if to_usernames.length() == 0
            f << "to: \n"
          elsif to_usernames.length() == 1
            f << "to: #{to_usernames[0]}\n"
          else
            lst = "  - " + to_usernames.join("\n  -")
            f << "to:\n#{lst}\n"
          end
          f << "message: |+\n  "
          raw = pm["message"]
          raw =
            @htmlentities.decode(
              raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: ""),
            ).gsub(/[^[[:print:]]\t\n]/, "")
          raw = raw.gsub(/(\r)?\n/, "\n  ")
          f << raw
          f << "\n\n"
        end
      end

      upload = create_upload(real_userid, filepath, filename)
      File.delete(filepath)

      # PM ARCHIVE MESSAGE
      # Private message title
      title = "Your private message archive from the previous forum software."
      # Private message body explaining the attached PM archive from vBulletin
      raw = <<~EOL
        Attached is your private message archive from the previous forum software.
        The text file contains all the private messages you had saved at the moment of migration.
        The file should also be a valid YAML file containing a single document per message.

        EOL
      raw += html_for_upload(upload, filename)

      newpost = {
        archetype: Archetype.private_message,
        user_id: Discourse::SYSTEM_USER_ID,
        target_usernames: User.find_by(id: real_userid).try(:username),
        title: title,
        raw: raw,
        closed: true,
        archived: true,
        post_create_action:
          proc do |post|
            UploadReference.ensure_exist!(upload_ids: [upload.id], target: post)
            post.topic.closed = true
            post.topic.save()
          end,
      }
      create_post(newpost, "pmarchive-#{userid}")
    end
  end

  def get_pm_recipients(pm)
    target_usernames = []
    target_userids = []
    begin
      to_user_array = PHP.unserialize(pm["touserarray"])
    rescue StandardError
      return target_usernames, target_userids
    end

    begin
      to_user_array.each do |to_user|
        if to_user[0] == "cc" || to_user[0] == "bcc" # not sure if we should include bcc users
          to_user[1].each do |to_user_cc|
            user_id = user_id_from_imported_user_id(to_user_cc[0])
            username = User.find_by(id: user_id).try(:username)
            target_userids << user_id || Discourse::SYSTEM_USER_ID
            target_usernames << username if username
          end
        else
          user_id = user_id_from_imported_user_id(to_user[0])
          username = User.find_by(id: user_id).try(:username)
          target_userids << user_id || Discourse::SYSTEM_USER_ID
          target_usernames << username if username
        end
      end
    rescue StandardError
      return target_usernames, target_userids
    end
    [target_usernames, target_userids]
  end

  def import_attachments
    puts "", "importing attachments..."

    mapping = {}
    attachments = mysql_query(<<-SQL)
      SELECT a.attachmentid, a.postid as postid, p.threadid
        FROM #{TABLE_PREFIX}attachment a, #{TABLE_PREFIX}post p, #{TABLE_PREFIX}thread t
       WHERE a.postid = p.postid
        AND t.threadid = p.threadid
        AND a.visible = 1
        AND p.visible <> 2
        AND t.visible <> 2
    SQL
    attachments.each do |attachment|
      post_id = post_id_from_imported_post_id(attachment["postid"])
      post_id = post_id_from_imported_post_id("thread-#{attachment["threadid"]}") unless post_id
      if post_id.nil?
        puts "\tPost for attachment #{attachment["attachmentid"]} not found"
        next
      end
      mapping[post_id] ||= []
      mapping[post_id] << attachment["attachmentid"].to_i
    end

    current_count = 0
    total_count = Post.count
    success_count = 0
    fail_count = 0
    start = Time.now

    attachment_regex = %r{\[attach[^\]]*\](\d+)\[/attach\]}i
    attachment_regex2 =
      %r{!\[\]\((https?:)?//#{Regexp.escape(FORUM_URL)}attachment\.php\?attachmentid=(\d+)(&stc=1)?(&d=\d+)?\)}i

    Post.find_each do |post|
      current_count += 1
      print_status current_count, total_count, start
      upload_ids = []

      new_raw = post.raw.dup
      new_raw.gsub!(attachment_regex) do |s|
        matches = attachment_regex.match(s)
        attachment_id = matches[1]
        next "" if attachment_id.to_i == 0

        mapping[post.id].delete(attachment_id.to_i) unless mapping[post.id].nil?

        upload, filename = find_upload(post, attachment_id)
        unless upload
          fail_count += 1
          next "\n:x: ERROR: missing attachment #{filename}\n"
        end

        upload_ids << upload.id
        html_for_upload(upload, filename)
      end

      new_raw.gsub!(attachment_regex2) do |s|
        matches = attachment_regex2.match(s)
        attachment_id = matches[2]
        next "" if attachment_id.to_i == 0

        mapping[post.id].delete(attachment_id.to_i) unless mapping[post.id].nil?

        upload, filename = find_upload(post, attachment_id)
        unless upload
          fail_count += 1
          next "\n:x: ERROR: missing attachment #{filename}\n"
        end

        upload_ids << upload.id
        html_for_upload(upload, filename)
      end

      # make resumed imports faster
      if new_raw == post.raw
        unless mapping[post.id].nil? || mapping[post.id].empty?
          imported_text = mysql_query(<<-SQL).first["pagetext"]
            SELECT p.pagetext
              FROM #{TABLE_PREFIX}attachment a, #{TABLE_PREFIX}post p
             WHERE a.postid = p.postid
             AND a.attachmentid = #{mapping[post.id][0]}
          SQL

          imported_text.scan(attachment_regex) do |match|
            attachment_id = match[0]
            mapping[post.id].delete(attachment_id.to_i)
          end
          imported_text.scan(attachment_regex2) do |match|
            attachment_id = match[1]
            mapping[post.id].delete(attachment_id.to_i)
          end
        end
      end

      unless mapping[post.id].nil? || mapping[post.id].empty?
        mapping[post.id].each do |attachment_id|
          upload, filename = find_upload(post, attachment_id)
          unless upload
            fail_count += 1
            next
          end

          upload_ids << upload.id
          # internal upload deduplication will make sure that we do not import attachments again
          html = html_for_upload(upload, filename)
          new_raw += "\n\n#{html}\n\n" if !new_raw[html]
        end
      end

      if new_raw != post.raw
        post.raw = new_raw
        post.save
      end

      UploadReference.ensure_exist!(upload_ids: upload_ids, target: post)

      success_count += 1
    end
  end

  def close_topics
    puts "", "closing topics..."

    # keep track of closed topics
    closed_topic_ids = []

    topics = mysql_query <<-MYSQL
        SELECT t.threadid threadid, firstpostid, open
          FROM #{TABLE_PREFIX}thread t
          JOIN #{TABLE_PREFIX}post p ON p.postid = t.firstpostid
      ORDER BY t.threadid
    MYSQL
    topics.each do |topic|
      topic_id = "thread-#{topic["threadid"]}"
      closed_topic_ids << topic_id if topic["open"] == 0
    end

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

    DB.exec(sql, closed_topic_ids)
  end

  def post_process_posts
    puts "", "postprocessing posts..."

    current = 0
    max = Post.count
    start = Time.now

    Post.find_each do |post|
      begin
        old_raw = post.raw.dup
        new_raw = postprocess_post_raw(post, post.raw)
        if new_raw != old_raw
          post.raw = new_raw
          post.save
        end
      rescue PrettyText::JavaScriptError
        nil
      ensure
        print_status(current += 1, max, start)
      end
    end
  end

  def preprocess_post_raw(raw)
    return "" if raw.blank?

    raw = raw.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")

    # decode HTML entities
    raw = @htmlentities.decode(raw)

    # fix whitespaces
    raw.gsub!(/(\r)?\n/, "\n")

    # [HTML]...[/HTML]
    raw.gsub!(/\[html\]/i, "\n```html\n")
    raw.gsub!(%r{\[/html\]}i, "\n```\n")

    # [PHP]...[/PHP]
    raw.gsub!(/\[php\]/i, "\n```php\n")
    raw.gsub!(%r{\[/php\]}i, "\n```\n")

    # [CODE]...[/CODE]
    # [HIGHLIGHT]...[/HIGHLIGHT]
    raw.gsub!(%r{\[/?code\]}i, "\n```\n")

    # [SAMP]...[/SAMP]
    raw.gsub!(%r{\[/?samp\]}i, "`")

    # replace all chevrons with HTML entities
    # NOTE: must be done
    #  - AFTER all the "code" processing
    #  - BEFORE the "quote" processing
    raw.gsub!(/`([^`]+)`/im) { "`" + $1.gsub("<", "\u2603") + "`" }
    raw.gsub!("<", "&lt;")
    raw.gsub!("\u2603", "<")

    raw.gsub!(/`([^`]+)`/im) { "`" + $1.gsub(">", "\u2603") + "`" }
    raw.gsub!(">", "&gt;")
    raw.gsub!("\u2603", ">")

    # Thread/post links via URL
    raw.gsub!(
      %r{\[url\](https?:)?//#{Regexp.escape(FORUM_URL)}show(thread|post)\.php(.*?)\[/url\]}i,
    ) do
      params = $3
      val = ""
      /[?&]p(ostid)?=(\d+)/i.match(params) { val = "[post]#{$2}[/post]" }
      /[?&]t(hreadid)?=(\d+)/i.match(params) { val = "[thread]#{$2}[/thread]" }
      val
    end
    raw.gsub!(
      %r{\[url="?(https?:)?//#{Regexp.escape(FORUM_URL)}show(thread|post)\.php(.*?)"?\](.*?)\[/url\]}im,
    ) do
      params = $3
      text = $4
      val = $4
      /[?&]p(ostid)?=(\d+)/i.match(params) { val = "[post=#{$2}]#{text}[/post]" }
      /[?&]t(hreadid)?=(\d+)/i.match(params) { val = "[thread=#{$2}]#{text}[/thread]" }
      val
    end

    # [URL=...]...[/URL]
    raw.gsub!(%r{\[url="?([^"]+?)"?\](.*?)\[/url\]}im) { "[#{$2.strip}](#{$1})" }
    raw.gsub!(%r{\[url="?(.+?)"?\](.*?)\[/url\]}im) { "[#{$2.strip}](#{$1})" }

    # [URL]...[/URL]
    # [MP3]...[/MP3]
    raw.gsub!(%r{\[/?url\]}i, "")
    raw.gsub!(%r{\[/?mp3\]}i, "")

    # [MENTION]<username>[/MENTION]
    raw.gsub!(%r{\[mention\](.+?)\[/mention\]}i) do
      new_username = get_username_for_old_username($1)
      "@#{new_username}"
    end

    # [FONT=blah] and [COLOR=blah]
    raw.gsub!(%r{\[/?font(=.*?)?\]}i, "")
    raw.gsub!(%r{\[/?color(=.*?)?\]}i, "")
    raw.gsub!(%r{\[/?size(=.*?)?\]}i, "")
    raw.gsub!(%r{\[/?sup\]}i, "")
    raw.gsub!(%r{\[/?big\]}i, "")
    raw.gsub!(%r{\[/?small\]}i, "")
    raw.gsub!(%r{\[/?h(=.*?)?\]}i, "")
    raw.gsub!(%r{\[/?float(=.*?)?\]}i, "")

    # [highlight]...[/highlight]
    raw.gsub!(%r{\[highlight\](.*?)\[/highlight\]}i, '<mark>\1</mark>')

    # [CENTER]...[/CENTER]
    raw.gsub!(%r{\[/?center\]}i, "")
    raw.gsub!(%r{\[/?left\]}i, "")
    raw.gsub!(%r{\[/?right\]}i, "")

    # [INDENT]...[/INDENT]
    raw.gsub!(%r{\[/?indent\]}i, "")

    raw.gsub!(%r{\[/?sigpic\]}i, "")

    # [ame]...[/ame]
    raw.gsub!(%r{\[ame="?(.*?)"?\](.*?)\[/ame\]}i) { "\n#{$1}\n" }
    raw.gsub!(%r{\[ame\](.*?)\[/ame\]}i) { "\n#{$1}\n" }

    raw.gsub!(%r{\[/?fp\]}i, "")

    # Tables to MD
    raw.gsub!(%r{\[TABLE.*?\](.*?)\[/TABLE\]}im) do |t|
      rows =
        $1.gsub!(%r{\s*\[TR\](.*?)\[/TR\]\s*}im) do |r|
          cols = $1.gsub! %r{\s*\[TD.*?\](.*?)\[/TD\]\s*}im, '|\1'
          "#{cols}|\n"
        end
      header, rest = rows.split "\n", 2
      c = header.count "|"
      sep = "|---" * (c - 1)
      "#{header}\n#{sep}|\n#{rest}\n"
    end

    # Prevent a leading * to make a list
    raw.gsub!(/^\*/, '\*')
    raw.gsub!(/^-/, '\-')
    raw.gsub!(/^\+/, '\+')

    # Basic list conversion
    #raw.gsub!(%r{\[list(=.*?)?\](.*?)\[/list\]}im) { "\n#{$1}\n" }
    #raw.gsub!(/\[\*\]\s*(.*?)\n/) { "* #{$1}\n" }
    raw = bbcode_list_to_md(raw)

    # [hr]...[/hr]
    raw.gsub! %r{\[hr\](.*?)\[/hr\]}im, "\n\n---\n\n"

    # [QUOTE(=<username>)]...[/QUOTE]
    raw.gsub!(/\n?\[quote(=([^;\]]+))?\]\n?/im) do
      if $1
        old_username = $2
        new_username = get_username_for_old_username(old_username)
        "\n[quote=\"#{new_username}\"]\n"
      else
        "\n[quote]\n"
      end
    end
    raw.gsub! %r{\n?\[/quote\]\n?}im, "\n[/quote]\n"

    # [YOUTUBE]<id>[/YOUTUBE]
    raw.gsub!(%r{\[youtube\](.+?)\[/youtube\]}i) { "\n//youtu.be/#{$1}\n" }

    # [VIDEO=youtube;<id>]...[/VIDEO]
    raw.gsub!(%r{\[video=youtube;([^\]]+)\].*?\[/video\]}i) { "\n//youtu.be/#{$1}\n" }

    # Fix uppercase B U and I tags
    raw.gsub!(%r{(\[/?[BUI]\])}i) { $1.downcase }

    # More Additions ....

    # [spoiler=Some hidden stuff]SPOILER HERE!![/spoiler]
    raw.gsub!(%r{\[spoiler="?(.+?)"?\](.+?)\[/spoiler\]}im) do
      "\n#{$1}\n[spoiler]#{$2}[/spoiler]\n"
    end

    # [IMG][IMG]http://i63.tinypic.com/akga3r.jpg[/IMG][/IMG]
    raw.gsub!(%r{\[IMG\]\[IMG\](.+?)\[/IMG\]\[/IMG\]}i) { "![](#{$1})" }
    raw.gsub!(%r{\[IMG\](.+?)\[/IMG\]}i) { "![](#{$1})" }

    raw
  end

  def bbcode_list_to_md(input)
    head, match, input = input.partition(/\[list(=.*?)?\]/i)
    return head unless match
    result = head
    input.lstrip!
    type = []
    if /\[list=.*?\]/.match(match)
      type << "1. "
    else
      type << "* "
    end
    until input.empty?
      head, match, input = input.partition(%r{\[(/?list(=.*?)?|\*)\]}i)
      result << head
      if match == ""
        break
      elsif match == "[*]"
        input.lstrip!
        result << "\n" unless result[-1] == "\n" || result.length == 0
        if type.length == 0
          # List-less list
          result << "* "
        else
          result << ("    " * (type.length - 1))
          result << type.last
        end
      elsif match.downcase == "[/list]"
        type.pop
        if type.length > 0
          input.lstrip!
        else
          result << "\n" unless result[-1] == "\n"
        end
      else
        if type.length == 0
          result << "\n" unless result[-1] == "\n" || result.length == 0
        end
        input.lstrip!
        if /\[list=.*?\]/i.match(match)
          type << "1. "
        else
          type << "* "
        end
      end
    end
    result
  end

  def postprocess_post_raw(post, raw)
    # [QUOTE=<username>;<post_id>]
    raw.gsub!(/\[quote=([^;]+);(\d+)\]/im) do
      old_username, post_id = $1, $2

      new_username = get_username_for_old_username(old_username)

      # There is a bug here when the first post in a topic is quoted.
      # The first post in a topic does not have an post_custom_field referring to the post number,
      # but it refers to thread-XXX instead, so this lookup fails miserably then.
      # Fixing this would imply rewriting that logic completely.

      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        post_number = topic_lookup[:post_number]
        topic_id = topic_lookup[:topic_id]
        "\n[quote=\"#{new_username},post:#{post_number},topic:#{topic_id}\"]\n"
      else
        "\n[quote=\"#{new_username}\"]\n"
      end
    end

    # remove attachments
    raw.gsub!(%r{\[attach[^\]]*\]\d+\[/attach\]}i, "")

    # [THREAD]<thread_id>[/THREAD]
    # ==> http://my.discourse.org/t/slug/<topic_id>
    raw.gsub!(%r{\[thread\](\d+)\[/thread\]}i) do
      thread_id = $1
      if topic_lookup = topic_lookup_from_imported_post_id("thread-#{thread_id}")
        topic_lookup[:url]
      else
        $&
      end
    end

    # [THREAD=<thread_id>]...[/THREAD]
    # ==> [...](http://my.discourse.org/t/slug/<topic_id>)
    raw.gsub!(%r{\[thread=(\d+)\](.+?)\[/thread\]}i) do
      thread_id, link = $1, $2
      if topic_lookup = topic_lookup_from_imported_post_id("thread-#{thread_id}")
        url = topic_lookup[:url]
        "[#{link}](#{url})"
      else
        $&
      end
    end

    # [POST]<post_id>[/POST]
    # ==> http://my.discourse.org/t/slug/<topic_id>/<post_number>
    raw.gsub!(%r{\[post\](\d+)\[/post\]}i) do
      post_id = $1
      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        topic_lookup[:url]
      else
        $&
      end
    end

    # [POST=<post_id>]...[/POST]
    # ==> [...](http://my.discourse.org/t/<topic_slug>/<topic_id>/<post_number>)
    raw.gsub!(%r{\[post=(\d+)\](.+?)\[/post\]}i) do
      post_id, link = $1, $2
      if topic_lookup = topic_lookup_from_imported_post_id(post_id)
        url = topic_lookup[:url]
        "[#{link}](#{url})"
      else
        $&
      end
    end

    raw.gsub!(
      %r{\[(.*?)\]\((https?:)?//#{Regexp.escape(FORUM_URL)}attachment\.php\?attachmentid=(\d+).*?\)}i,
    ) do
      upload, filename = find_upload(post, $3)
      next "#{$1}\n:x: ERROR: unknown attachment reference #{$3}\n" unless upload

      html_for_upload(upload, filename)
    end

    raw
  end

  def suspend_users
    puts "", "updating banned users"

    banned = 0
    failed = 0
    total = mysql_query("SELECT count(*) count FROM #{TABLE_PREFIX}userban").first["count"]

    system_user = Discourse.system_user

    mysql_query("SELECT userid, bandate, liftdate, reason FROM #{TABLE_PREFIX}userban").each do |b|
      user = User.find_by_id(user_id_from_imported_user_id(b["userid"]))
      if user
        user.suspended_at = parse_timestamp(b["bandate"])
        if b["liftdate"] > 0
          user.suspended_till = parse_timestamp(b["liftdate"])
        else
          user.suspended_till = 200.years.from_now
        end

        if user.save
          StaffActionLogger.new(system_user).log_user_suspend(
            user,
            "#{b["reason"]} (source: initial import from vBulletin)",
          )
          banned += 1
        else
          puts "",
               "\tFailed to suspend user #{user.username}. #{user.errors.try(:full_messages).try(:inspect)}"
          failed += 1
        end
      else
        puts "", "\tNot found: #{b["userid"]}"
        failed += 1
      end

      print_status banned + failed, total
    end
  end

  def parse_timestamp(timestamp)
    return if timestamp.nil?
    Time.zone.at(@tz.utc_to_local(TZInfo::Timestamp.new(timestamp)).to_datetime)
  end

  def mysql_query(sql)
    @client.query(sql, cache_rows: true)
  end
end

ImportScripts::VBulletin.new.perform
