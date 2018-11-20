# Zendesk importer
#
# This one uses their API.

require 'reverse_markdown'
require_relative 'base'
require_relative 'base/generic_database'

# Call it like this:
#   RAILS_ENV=production bundle exec ruby script/import_scripts/zendesk_api.rb SOURCE_URL DIRNAME AUTH_EMAIL AUTH_TOKEN
class ImportScripts::Zendesk < ImportScripts::Base
  BATCH_SIZE = 1000

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
  end

  def fetch_from_api
    puts '', 'fetching categories...'

    get_from_api('/api/v2/community/topics.json', 'topics') do |row|
      @db.insert_category(
        id: row['id'],
        name: row['name'],
        description: row['description'],
        position: row['position'],
        url: row['html_url']
      )
    end

    puts '', 'fetching topics...'

    get_from_api('/api/v2/community/posts.json', 'posts') do |row|
      @db.insert_topic(
        id: row['id'],
        title: row['title'],
        raw: row['details'],
        category_id: row['topic_id'],
        closed: row['closed'],
        user_id: row['author_id'],
        created_at: row['created_at'],
        url: row['html_url']
      )
    end

    puts '', 'fetching posts...'
    total_count = @db.count_topics
    start_time = Time.now
    last_id = ''

    batches do |offset|
      rows, last_id = @db.fetch_topics(last_id)
      break if rows.empty?

      print_status(offset, total_count, start_time)

      rows.each do |topic_row|
        get_from_api("/api/v2/community/posts/#{topic_row['id']}/comments.json", 'comments', show_status: false) do |row|
          @db.insert_post(
            id: row['id'],
            raw: row['body'],
            topic_id: topic_row['id'],
            user_id: row['author_id'],
            created_at: row['created_at'],
            url: row['html_url']
          )
        end
      end
    end

    puts '', 'fetching users...'

    results = @db.execute_sql("SELECT user_id FROM topic")
    user_ids = results.map { |h| h['user_id']&.to_i }
    results = @db.execute_sql("SELECT user_id FROM post")
    user_ids += results.map { |h| h['user_id']&.to_i }
    user_ids.uniq!
    user_ids.sort!

    total_users = user_ids.size
    start_time = Time.now

    while !user_ids.empty?
      print_status(total_users - user_ids.size, total_users, start_time)
      get_from_api("/api/v2/users/show_many.json?ids=#{user_ids.shift(50).join(',')}", 'users', show_status: false) do |row|
        @db.insert_user(
          id: row['id'],
          email: row['email'],
          name: row['name'],
          created_at: row['created_at'],
          last_seen_at: row['last_login_at'],
          active: row['active']
        )
      end
    end

    @db.sort_posts_by_created_at
  end

  def import_categories
    puts "", "creating categories"
    rows = @db.fetch_categories

    create_categories(rows) do |row|
      {
        id: row['id'],
        name: row['name'],
        description: row['description'],
        position: row['position'],
        post_create_action: proc do |category|
          url = remove_domain(row['url'])
          Permalink.create(url: url, category_id: category.id) unless permalink_exists?(url)
        end
      }
    end
  end

  def import_users
    puts "", "creating users"
    total_count = @db.count_users
    last_id = ''

    batches do |offset|
      rows, last_id = @db.fetch_users(last_id)
      break if rows.empty?

      next if all_records_exist?(:users, rows.map { |row| row['id'] })

      create_users(rows, total: total_count, offset: offset) do |row|
        {
          id: row['id'],
          email: row['email'],
          name: row['name'],
          created_at: row['created_at'],
          last_seen_at: row['last_seen_at'],
          active: row['active'] == 1
        }
      end
    end
  end

  def import_topics
    puts "", "creating topics"
    total_count = @db.count_topics
    last_id = ''

    batches do |offset|
      rows, last_id = @db.fetch_topics(last_id)
      break if rows.empty?

      next if all_records_exist?(:posts, rows.map { |row| import_topic_id(row['id']) })

      create_posts(rows, total: total_count, offset: offset) do |row|
        {
          id: import_topic_id(row['id']),
          title: row['title'].present? ? row['title'].strip[0...255] : "Topic title missing",
          raw: normalize_raw(row['raw']),
          category: category_id_from_imported_category_id(row['category_id']),
          user_id: user_id_from_imported_user_id(row['user_id']) || Discourse.system_user.id,
          created_at: row['created_at'],
          closed: row['closed'] == 1,
          post_create_action: proc do |post|
            url = remove_domain(row['url'])
            Permalink.create(url: url, topic_id: post.topic.id) unless permalink_exists?(url)
          end
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
      rows, last_row_id = @db.fetch_posts(last_row_id)
      break if rows.empty?

      create_posts(rows, total: total_count, offset: offset) do |row|
        topic = topic_lookup_from_imported_post_id(import_topic_id(row['topic_id']))

        if topic.nil?
          p "MISSING TOPIC #{row['topic_id']}"
          p row
          next
        end

        {
          id: row['id'],
          raw: normalize_raw(row['raw']),
          user_id: user_id_from_imported_user_id(row['user_id']) || Discourse.system_user.id,
          topic_id: topic[:topic_id],
          created_at: row['created_at'],
          post_create_action: proc do |post|
            url = remove_domain(row['url'])
            Permalink.create(url: url, post_id: post.id) unless permalink_exists?(url)
          end
        }
      end
    end
  end

  def normalize_raw(raw)
    raw = raw.gsub('\n', '')
    raw = ReverseMarkdown.convert(raw)
    raw
  end

  def remove_domain(url)
    url.sub(@source_url, "")
  end

  def permalink_exists?(url)
    Permalink.find_by(url: url)
  end

  def connection
    @_connection ||= begin
      connect_uri = URI.parse(@source_url)

      http = Net::HTTP.new(connect_uri.host, connect_uri.port)
      http.open_timeout = 30
      http.read_timeout = 30
      http.use_ssl = connect_uri.scheme == "https"

      http
    end
  end

  def authorization
    @_authorization ||= begin
      auth_str = "#{@auth_email}/token:#{@auth_token}"
      "Basic #{Base64.strict_encode64(auth_str)}"
    end
  end

  def get_from_api(path, array_name, show_status: true)
    url = "#{@source_url}#{path}"
    start_time = Time.now

    while url
      get = Net::HTTP::Get.new(url)
      get['User-Agent'] = 'Discourse Zendesk Importer'
      get['Authorization'] = authorization

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

      json[array_name].each do |row|
        yield row
      end

      url = json['next_page']

      if show_status
        if json['page'] && json['page_count']
          print_status(json['page'], json['page_count'], start_time)
        else
          print '.'
        end
      end
    end
  end
end

unless ARGV.length == 4 && Dir.exist?(ARGV[1])
  puts "", "Usage:", "", "bundle exec ruby script/import_scripts/zendesk_api.rb SOURCE_URL DIRNAME AUTH_EMAIL AUTH_TOKEN", ""
  exit 1
end

ImportScripts::Zendesk.new(ARGV[0], ARGV[1], ARGV[2], ARGV[3]).perform
