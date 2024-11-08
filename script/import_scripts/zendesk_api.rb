# frozen_string_literal: true

# Zendesk importer
#
# This one uses their API.

require "open-uri"
require "reverse_markdown"
require_relative "base"
require_relative "base/generic_database"

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/zendesk_api.rb SOURCE_URL DIRNAME AUTH_EMAIL AUTH_TOKEN
class ImportScripts::ZendeskApi < ImportScripts::Base
  BATCH_SIZE = 1000

  HTTP_ERRORS = [
    EOFError,
    Errno::ECONNRESET,
    Errno::EINVAL,
    Net::HTTPBadResponse,
    Net::HTTPHeaderSyntaxError,
    Net::ProtocolError,
    Timeout::Error,
    OpenURI::HTTPError,
    OpenSSL::SSL::SSLError,
  ].freeze

  MAX_RETRIES = 5

  IMAGE_DOWNLOAD_PATH = "replace-me"

  SUBDOMAIN = "replace-me"

  def initialize(source_url, path, auth_email, auth_token)
    super()

    @source_url = source_url
    @path = path
    @auth_email = auth_email
    @auth_token = auth_token
    @db = ImportScripts::GenericDatabase.new(@path, batch_size: BATCH_SIZE, recreate: true)
  end

  def execute
    fetch_from_api

    import_categories
    import_users
    import_topics
    import_posts
    import_likes
  end

  def fetch_from_api
    fetch_categories
    fetch_topics
    fetch_posts
    fetch_users

    @db.sort_posts_by_created_at
  end

  def fetch_categories
    puts "", "fetching categories..."

    get_from_api("/api/v2/community/topics.json", "topics", show_status: true) do |row|
      @db.insert_category(
        id: row["id"],
        name: row["name"],
        description: row["description"],
        position: row["position"],
        url: row["html_url"],
      )
    end
  end

  def fetch_topics
    puts "", "fetching topics..."

    get_from_api("/api/v2/community/posts.json", "posts", show_status: true) do |row|
      if row["vote_count"] > 0
        like_user_ids = fetch_likes("/api/v2/community/posts/#{row["id"]}/votes.json")
      end

      @db.insert_topic(
        id: row["id"],
        title: row["title"],
        raw: row["details"],
        category_id: row["topic_id"],
        closed: row["closed"],
        user_id: row["author_id"],
        created_at: row["created_at"],
        url: row["html_url"],
        like_user_ids: like_user_ids,
      )
    end
  end

  def fetch_posts
    puts "", "fetching posts..."
    current_count = 0
    total_count = @db.count_topics
    start_time = Time.now
    last_id = ""

    batches do |offset|
      rows, last_id = @db.fetch_topics(last_id)
      break if rows.empty?

      rows.each do |topic_row|
        get_from_api(
          "/api/v2/community/posts/#{topic_row["id"]}/comments.json",
          "comments",
        ) do |row|
          if row["vote_count"] > 0
            like_user_ids =
              fetch_likes(
                "/api/v2/community/posts/#{topic_row["id"]}/comments/#{row["id"]}/votes.json",
              )
          end

          @db.insert_post(
            id: row["id"],
            raw: row["body"],
            topic_id: topic_row["id"],
            user_id: row["author_id"],
            created_at: row["created_at"],
            url: row["html_url"],
            like_user_ids: like_user_ids,
          )
        end

        current_count += 1
        print_status(current_count, total_count, start_time)
      end
    end
  end

  def fetch_users
    puts "", "fetching users..."

    user_ids = @db.execute_sql(<<~SQL).map { |row| row["user_id"] }
      SELECT user_id FROM topic
      UNION
      SELECT user_id FROM post
      UNION
      SELECT user_id FROM like
    SQL

    current_count = 0
    total_count = user_ids.size
    start_time = Time.now

    while !user_ids.empty?
      get_from_api(
        "/api/v2/users/show_many.json?ids=#{user_ids.shift(50).join(",")}",
        "users",
      ) do |row|
        @db.insert_user(
          id: row["id"],
          email: row["email"],
          name: row["name"],
          created_at: row["created_at"],
          last_seen_at: row["last_login_at"],
          active: row["active"],
          avatar_path: row["photo"].present? ? row["photo"]["content_url"] : nil,
        )

        current_count += 1
        print_status(current_count, total_count, start_time)
      end
    end
  end

  def fetch_likes(url)
    user_ids = []

    get_from_api(url, "votes") do |row|
      user_ids << row["user_id"] if row["id"].present? && row["value"] == 1
    end

    user_ids
  end

  def import_categories
    puts "", "creating categories"
    rows = @db.fetch_categories

    create_categories(rows) do |row|
      {
        id: row["id"],
        name: row["name"],
        description: row["description"],
        position: row["position"],
        post_create_action:
          proc do |category|
            url = remove_domain(row["url"])
            Permalink.create(url: url, category_id: category.id) unless permalink_exists?(url)
          end,
      }
    end
  end

  def import_users
    puts "", "creating users"
    total_count = @db.count_users
    last_id = ""

    batches do |offset|
      rows, last_id = @db.fetch_users(last_id)
      break if rows.empty?

      next if all_records_exist?(:users, rows.map { |row| row["id"] })

      create_users(rows, total: total_count, offset: offset) do |row|
        {
          id: row["id"],
          email: row["email"],
          name: row["name"],
          created_at: row["created_at"],
          last_seen_at: row["last_seen_at"],
          active: row["active"] == 1,
          post_create_action:
            proc do |user|
              if row["avatar_path"].present?
                begin
                  UserAvatar.import_url_for_user(row["avatar_path"], user)
                rescue StandardError
                  nil
                end
              end
            end,
        }
      end
    end
  end

  def import_topics
    puts "", "creating topics"
    total_count = @db.count_topics
    last_id = ""

    batches do |offset|
      rows, last_id = @db.fetch_topics(last_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| import_topic_id(row["id"]) })

      create_posts(rows, total: total_count, offset: offset) do |row|
        {
          id: import_topic_id(row["id"]),
          title: row["title"].present? ? row["title"].strip[0...255] : "Topic title missing",
          raw:
            normalize_raw(
              row["raw"],
              user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id,
            ),
          category: category_id_from_imported_category_id(row["category_id"]),
          user_id: user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id,
          created_at: row["created_at"],
          closed: row["closed"] == 1,
          post_create_action:
            proc do |post|
              url = remove_domain(row["url"])
              Permalink.create(url: url, topic_id: post.topic.id) unless permalink_exists?(url)
            end,
        }
      end
    end
  end

  def import_topic_id(topic_id)
    "T#{topic_id}"
  end

  def import_posts
    puts "", "creating posts"
    total_count = @db.count_posts
    last_row_id = 0

    batches do |offset|
      rows, last_row_id = @db.fetch_sorted_posts(last_row_id)
      break if rows.empty?

      create_posts(rows, total: total_count, offset: offset) do |row|
        topic = topic_lookup_from_imported_post_id(import_topic_id(row["topic_id"]))

        if topic.nil?
          p "MISSING TOPIC #{row["topic_id"]}"
          p row
          next
        end

        {
          id: row["id"],
          raw:
            normalize_raw(
              row["raw"],
              user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id,
            ),
          user_id: user_id_from_imported_user_id(row["user_id"]) || Discourse.system_user.id,
          topic_id: topic[:topic_id],
          created_at: row["created_at"],
          post_create_action:
            proc do |post|
              url = remove_domain(row["url"])
              Permalink.create(url: url, post_id: post.id) unless permalink_exists?(url)
            end,
        }
      end
    end
  end

  def import_likes
    puts "", "importing likes..."
    start_time = Time.now
    current_count = 0
    total_count = @db.count_likes
    last_row_id = 0

    batches do |offset|
      rows, last_row_id = @db.fetch_likes(last_row_id)
      break if rows.empty?

      rows.each do |row|
        import_id = row["topic_id"] ? import_topic_id(row["topic_id"]) : row["post_id"]
        post = Post.find_by(id: post_id_from_imported_post_id(import_id)) if import_id
        user = User.find_by(id: user_id_from_imported_user_id(row["user_id"]))

        if post && user
          begin
            PostActionCreator.like(user, post) if user && post
          rescue => e
            puts "error acting on post #{e}"
          end
        else
          puts "Skipping Like from #{row["user_id"]} on topic #{row["topic_id"]} / post #{row["post_id"]}"
        end

        current_count += 1
        print_status(current_count, total_count, start_time)
      end
    end
  end

  def normalize_raw(raw, user_id)
    return "<missing>" if raw.blank?

    raw = raw.gsub('\n', "")
    raw = ReverseMarkdown.convert(raw)

    # Process images, after the ReverseMarkdown they look like
    # ![](https://<sub-domain>.zendesk.com/<hash>.<image-format>)
    raw.gsub!(%r{!\[\]\((https://#{SUBDOMAIN}\.zendesk\.com/hc/user_images/([^).]+\.[^)]+))\)}i) do
      image_url = $1
      filename = $2
      attempts = 0

      begin
        URI
          .parse(image_url)
          .open do |image|
            # IMAGE_DOWNLOAD_PATH is whatever image, it will be replaced with the downloaded image
            File.open(IMAGE_DOWNLOAD_PATH, "wb") { |file| file.write(image.read) }
          end
      rescue *HTTP_ERRORS => e
        if attempts < MAX_RETRIES
          attempts += 1
          sleep(2)
          retry
        else
          puts "Error downloading image"
        end
        next
      end

      upl_obj = create_upload(user_id, IMAGE_DOWNLOAD_PATH, filename)

      if upl_obj&.persisted?
        html = html_for_upload(upl_obj, filename)
        html
      else
        puts "Error creating image upload"
        exit
      end
    end

    raw
  end

  def remove_domain(url)
    url.sub(@source_url, "")
  end

  def permalink_exists?(url)
    Permalink.find_by(url: url)
  end

  def connection
    @_connection ||=
      begin
        connect_uri = URI.parse(@source_url)

        http = Net::HTTP.new(connect_uri.host, connect_uri.port)
        http.open_timeout = 30
        http.read_timeout = 30
        http.use_ssl = connect_uri.scheme == "https"

        http
      end
  end

  def authorization
    @_authorization ||=
      begin
        auth_str = "#{@auth_email}/token:#{@auth_token}"
        "Basic #{Base64.strict_encode64(auth_str)}"
      end
  end

  def get_from_api(path, array_name, show_status: false)
    url = "#{@source_url}#{path}"
    start_time = Time.now

    while url
      get = Net::HTTP::Get.new(url)
      get["User-Agent"] = "Discourse Zendesk Importer"
      get["Authorization"] = authorization

      retry_count = 0

      begin
        while retry_count < 5
          begin
            response = connection.request(get)
            puts("Retry successful!") if retry_count > 0
            break
          rescue => e
            puts "Request failed #{url}. Waiting and will retry. #{e.class.name} #{e.message}"
            sleep(20)
            retry_count += 1
          end
        end
      end

      json = JSON.parse(response.body)

      json[array_name].each { |row| yield row }

      url = json["next_page"]

      if show_status
        if json["page"] && json["page_count"]
          print_status(json["page"], json["page_count"], start_time)
        else
          print "."
        end
      end
    end
  end
end

unless ARGV.length == 4 && Dir.exist?(ARGV[1])
  puts "",
       "Usage:",
       "",
       "bundle exec ruby script/import_scripts/zendesk_api.rb SOURCE_URL DIRNAME AUTH_EMAIL AUTH_TOKEN",
       ""
  exit 1
end

ImportScripts::ZendeskApi.new(ARGV[0], ARGV[1], ARGV[2], ARGV[3]).perform
