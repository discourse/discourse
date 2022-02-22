# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + "/base.rb")

# Edit the constants and initialize method for your import data.

class ImportScripts::Ning < ImportScripts::Base

  JSON_FILES_DIR = "/Users/techapj/Downloads/ben/ADEM"
  ATTACHMENT_PREFIXES = ["discussions", "pages", "blogs", "members", "photos"]
  EXTRA_AUTHORIZED_EXTENSIONS = ["bmp", "ico", "txt", "pdf", "gif", "jpg", "jpeg", "html"]

  def initialize
    super

    @system_user = Discourse.system_user

    @users_json       = load_ning_json("ning-members-local.json")
    @discussions_json = load_ning_json("ning-discussions-local.json")

    # An example of a custom category from Ning:
    @blogs_json = load_ning_json("ning-blogs-local.json")

    @photos_json      = load_ning_json("ning-photos-local.json")
    @pages_json       = load_ning_json("ning-pages-local.json")

    SiteSetting.max_image_size_kb = 10240
    SiteSetting.max_attachment_size_kb = 10240
    SiteSetting.authorized_extensions = (SiteSetting.authorized_extensions.split("|") + EXTRA_AUTHORIZED_EXTENSIONS).uniq.join("|")

    # Example of importing a custom profile field:
    # @interests_field = UserField.find_by_name("My interests")
    # unless @interests_field
    #   @interests_field = UserField.create(name: "My interests", description: "Do you like stuff?", field_type: "text", editable: true, required: false, show_on_profile: true, show_on_user_card: true)
    # end
  end

  def execute
    puts "", "Importing from Ning..."

    import_users
    import_categories
    import_discussions

    import_blogs # Remove this and/or add more as necessary

    import_photos
    import_pages

    suspend_users
    update_tl0

    puts "", "Done"
  end

  def load_ning_json(arg)
    filename = File.join(JSON_FILES_DIR, arg)
    raise RuntimeError.new("File #{filename} not found!") if !File.exist?(filename)
    JSON.parse(repair_json(File.read(filename))).reverse
  end

  def repair_json(arg)
    arg.gsub!(/^\(/, "")     # content of file is surround by ( )
    arg.gsub!(/\)$/, "")

    arg.gsub!(/\]\]$/, "]")  # there can be an extra ] at the end

    arg.gsub!(/\}\{/, "},{") # missing commas sometimes!

    arg.gsub!("}]{", "},{")  # surprise square brackets
    arg.gsub!("}[{", "},{")  # :troll:

    arg
  end

  def import_users
    puts '', "Importing users"

    staff_levels = ["admin", "moderator", "owner"]

    create_users(@users_json) do |u|
      {
        id: u["contributorName"],
        name: u["fullName"],
        email: u["email"],
        created_at: Time.zone.parse(u["createdDate"]),
        date_of_birth: u["birthdate"] ? Time.zone.parse(u["birthdate"]) : nil,
        location: "#{u["location"]} #{u["country"]}",
        avatar_url: u["profilePhoto"],
        bio_raw: u["profileQuestions"].is_a?(Hash) ? u["profileQuestions"]["About Me"] : nil,
        post_create_action: proc do |newuser|
          # if u["profileQuestions"].is_a?(Hash)
          #   newuser.custom_fields = {"user_field_#{@interests_field.id}" => u["profileQuestions"]["My interests"]}
          # end

          if staff_levels.include?(u["level"].downcase)
            if u["level"].downcase == "admin" || u["level"].downcase == "owner"
              newuser.admin = true
            else
              newuser.moderator = true
            end
          end

          # states: ["active", "suspended", "left", "pending"]
          if u["state"] == "active" && newuser.approved_at.nil?
            newuser.approved = true
            newuser.approved_by_id = @system_user.id
            newuser.approved_at = newuser.created_at
          end

          newuser.save

          if u["profilePhoto"] && newuser.user_avatar.try(:custom_upload_id).nil?
            photo_path = file_full_path(u["profilePhoto"])
            if File.exist?(photo_path)
              begin
                upload = create_upload(newuser.id, photo_path, File.basename(photo_path))
                if upload.persisted?
                  newuser.import_mode = false
                  newuser.create_user_avatar
                  newuser.import_mode = true
                  newuser.user_avatar.update(custom_upload_id: upload.id)
                  newuser.update(uploaded_avatar_id: upload.id)
                else
                  puts "Error: Upload did not persist for #{photo_path}!"
                end
              rescue SystemCallError => err
                puts "Could not import avatar #{photo_path}: #{err.message}"
              end
            else
              puts "avatar file not found at #{photo_path}"
            end
          end
        end
      }
    end
    EmailToken.delete_all
  end

  def suspend_users
    puts '', "Updating suspended users"

    count = 0
    suspended = 0
    total = @users_json.size

    @users_json.each do |u|
      if u["state"].downcase == "suspended"
        if user = find_user_by_import_id(u["contributorName"])
          user.suspended_at = Time.zone.now
          user.suspended_till = 200.years.from_now

          if user.save
            StaffActionLogger.new(@system_user).log_user_suspend(user, "Import data indicates account is suspended.")
            suspended += 1
          else
            puts "Failed to suspend user #{user.username}. #{user.errors.try(:full_messages).try(:inspect)}"
          end
        end
      end

      count += 1
      print_status count, total
    end

    puts "", "Marked #{suspended} users as suspended."
  end

  def import_categories
    puts "", "Importing categories"
    create_categories((["Blog", "Pages", "Photos"] + @discussions_json.map { |d| d["category"] }).uniq.compact) do |name|
      if name.downcase == "uncategorized"
        nil
      else
        {
          id: name, # ning has no id for categories, so use the name
          name: name
        }
      end
    end
  end

  def import_discussions
    puts "", "Importing discussions"
    import_topics(@discussions_json)
  end

  def import_blogs
    puts "", "Importing blogs"
    import_topics(@blogs_json, "Blog")
  end

  def import_photos
    puts "", "Importing photos"
    import_topics(@photos_json, "Photos")
  end

  def import_pages
    puts "", "Importing pages"
    import_topics(@pages_json, "Pages")
  end

  def import_topics(topics_json, default_category = nil)
    topics = 0
    posts = 0
    total = topics_json.size # number of topics. posts are embedded in the topic json, so we can't get total post count quickly.

    topics_json.each do |topic|
      if topic["title"].present? && topic["description"].present?
        @current_topic_title = topic["title"] # for debugging
        parent_post = nil

        if parent_post_id = post_id_from_imported_post_id(topic["id"])
          parent_post = Post.find(parent_post_id) # already imported this post
        else
          mapped = {}
          mapped[:id] = topic["id"]
          mapped[:user_id] = user_id_from_imported_user_id(topic["contributorName"]) || -1
          mapped[:created_at] = Time.zone.parse(topic["createdDate"])
          unless topic["category"].nil? || topic["category"].downcase == "uncategorized"
            mapped[:category] = category_id_from_imported_category_id(topic["category"])
          end
          if topic["category"].nil? && default_category
            mapped[:category] = default_category
          end
          mapped[:title] = CGI.unescapeHTML(topic["title"])
          mapped[:raw] = process_ning_post_body(topic["description"])

          if topic["fileAttachments"]
            mapped[:raw] = add_file_attachments(mapped[:raw], topic["fileAttachments"])
          end

          if topic["photoUrl"]
            mapped[:raw] = add_photo(mapped[:raw], topic["photoUrl"])
          end

          if topic["embedCode"]
            mapped[:raw] = add_video(mapped[:raw], topic["embedCode"])
          end

          parent_post = create_post(mapped, mapped[:id])
          unless parent_post.is_a?(Post)
            puts "Error creating topic #{mapped[:id]}. Skipping."
            puts parent_post.inspect
          end
        end

        if topic["comments"].present?
          topic["comments"].reverse.each do |post|

            if post_id_from_imported_post_id(post["id"])
              next # already imported this post
            end

            raw = process_ning_post_body(post["description"])
            if post["fileAttachments"]
              raw = add_file_attachments(raw, post["fileAttachments"])
            end

            new_post = create_post({
                id: post["id"],
                topic_id: parent_post.topic_id,
                user_id: user_id_from_imported_user_id(post["contributorName"]) || -1,
                raw: raw,
                created_at: Time.zone.parse(post["createdDate"])
              }, post["id"])

            if new_post.is_a?(Post)
              posts += 1
            else
              puts "Error creating post #{post["id"]}. Skipping."
              puts new_post.inspect
            end
          end
        end
      end
      topics += 1
      print_status topics, total
    end

    puts "", "Imported #{topics} topics with #{topics + posts} posts."

    [topics, posts]
  end

  def file_full_path(relpath)
    File.join JSON_FILES_DIR, relpath.split("?").first
  end

  def attachment_regex
    @_attachment_regex ||= Regexp.new(%Q[<a (?:[^>]*)href="(?:#{ATTACHMENT_PREFIXES.join('|')})\/(?:[^"]+)"(?:[^>]*)><img (?:[^>]*)src="([^"]+)"(?:[^>]*)><\/a>])
  end

  def youtube_iframe_regex
    @_youtube_iframe_regex ||= Regexp.new(%Q[<p><iframe(?:[^>]*)src="\/\/www.youtube.com\/embed\/([^"]+)"(?:[^>]*)><\/iframe>(?:[^<]*)<\/p>])
  end

  def process_ning_post_body(arg)
    return "" if arg.nil?
    raw = arg.gsub("</p>\n", "</p>")

    # youtube iframe
    raw.gsub!(youtube_iframe_regex) do |s|
      matches = youtube_iframe_regex.match(s)
      video_id = matches[1].split("?").first

      next s unless video_id

      "\n\nhttps://www.youtube.com/watch?v=#{video_id}\n"
    end

    # attachments
    raw.gsub!(attachment_regex) do |s|
      matches = attachment_regex.match(s)
      ning_filename = matches[1]

      filename = File.join(JSON_FILES_DIR, ning_filename.split("?").first)
      if !File.exist?(filename)
        puts "Attachment file doesn't exist: #{filename}"
        next s
      end

      upload = create_upload(@system_user.id, filename, File.basename(filename))

      if upload.nil? || !upload.valid?
        puts "Upload not valid :(  #{filename}"
        puts upload.errors.inspect if upload
        next s
      end

      html_for_upload(upload, File.basename(filename))
    end

    raw
  end

  def add_file_attachments(arg, file_names)
    raw = arg

    file_names.each do |f|
      filename = File.join(JSON_FILES_DIR, f.split("?").first)
      if !File.exist?(filename)
        puts "Attachment file doesn't exist: #{filename}"
        next
      end

      upload = create_upload(@system_user.id, filename, File.basename(filename))

      if upload.nil? || !upload.valid?
        puts "Upload not valid :(  #{filename}"
        puts upload.errors.inspect if upload
        next
      end

      raw += "\n" + attachment_html(upload, File.basename(filename))
    end

    raw
  end

  def add_photo(arg, file_name)
    raw = arg

    # filename = File.join(JSON_FILES_DIR, file_name)
    filename = file_full_path(file_name)
    if File.exist?(filename)
      upload = create_upload(@system_user.id, filename, File.basename(filename))

      if upload.nil? || !upload.valid?
        puts "Upload not valid :(  #{filename}"
        puts upload.errors.inspect if upload
        return
      end

      raw += "\n" + embedded_image_html(upload)
    else
      puts "Attachment file doesn't exist: #{filename}"
    end

    raw
  end

  def add_video(arg, embed_code)
    raw = arg
    youtube_regex = Regexp.new(%Q[<iframe(?:[^>]*)src="http:\/\/www.youtube.com\/embed\/([^"]+)"(?:[^>]*)><\/iframe>])

    raw.gsub!(youtube_regex) do |s|
      matches = youtube_regex.match(s)
      video_id = matches[1].split("?").first

      if video_id
        raw += "\n\nhttps://www.youtube.com/watch?v=#{video_id}\n"
      end
    end

    raw += "\n" + embed_code + "\n"
    raw
  end
end

if __FILE__ == $0
  ImportScripts::Ning.new.perform
end
