require File.expand_path(File.dirname(__FILE__) + "/base.rb")
require 'pg'

class ImportScripts::MyAskBot < ImportScripts::Base
  # CHANGE THESE BEFORE RUNNING THE IMPORTER

  BATCH_SIZE = 1000

  OLD_SITE   = "ask.cvxr.com"
  DB_NAME    = "cvxforum"
  DB_USER    = "cvxforum"
  DB_PORT    = 5432
  DB_HOST    = "ask.cvxr.com"
  DB_PASS    = 'yeah, right'

  # A list of categories to create. Any post with one of these tags will be
  # assigned to that category. Ties are broken by list orer.
  CATEGORIES = [ 'Nonconvex', 'TFOCS', 'MIDCP', 'FAQ' ]

  def initialize
    super

    @thread_parents = {}
    @tagmap = []
    @td = PG::TextDecoder::TimestampWithTimeZone.new
    @client = PG.connect(
      :dbname   => DB_NAME,
      :host     => DB_HOST,
      :port     => DB_PORT,
      :user     => DB_USER,
      :password => DB_PASS
    )
  end

  def execute
    create_cats
    import_users
    read_tags
    import_posts
    import_replies
    post_process_posts
  end

  def create_cats
    puts "", "creating categories"
    CATEGORIES.each do |cat|
      unless Category.where("LOWER(name) = ?", cat.downcase).first
        Category.new(name: cat, user_id: -1).save!
      end
    end
  end

  def read_tags
    puts "", "reading thread tags..."

    tag_count = @client.exec(<<-SQL
          SELECT COUNT(A.id)
          FROM askbot_thread_tags A
          JOIN tag B
          ON A.tag_id = B.id
          WHERE A.tag_id > 0
      SQL
    )[0]["count"]

    tags_done = 0
    batches(BATCH_SIZE) do |offset|
      tags = @client.exec(<<-SQL
        SELECT A.thread_id, B.name
        FROM askbot_thread_tags A
        JOIN tag B
        ON A.tag_id = B.id
        WHERE A.tag_id > 0
        LIMIT #{BATCH_SIZE}
        OFFSET #{offset}
      SQL
      )
      break if tags.ntuples() < 1
      tags.each do |tag|
        tid = tag["thread_id"].to_i
        tnm = tag["name"].downcase
        if @tagmap[tid]
          @tagmap[tid].push( tnm )
        else
          @tagmap[tid] = [ tnm ]
        end
        tags_done += 1
        print_status tags_done, tag_count
      end
    end
  end

  def import_users
    puts "", "importing users"

    total_count = @client.exec(<<-SQL
          SELECT COUNT(id)
            FROM auth_user
      SQL
    )[0]["count"]

    batches(BATCH_SIZE) do |offset|
      users = @client.query(<<-SQL
          SELECT id, username, email, is_staff, date_joined, last_seen, real_name, website, location, about
            FROM auth_user
        ORDER BY date_joined
           LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL
      )

      break if users.ntuples() < 1

      next if all_records_exist? :users, users.map {|u| u["id"].to_i}

      create_users(users, total: total_count, offset: offset) do |user|
        {
          id:           user["id"],
          username:     user["username"],
          email:        user["email"] || (SecureRandom.hex << "@domain.com"),
          admin:        user["is_staff"],
          created_at:   Time.zone.at(@td.decode(user["date_joined"])),
          last_seen_at: Time.zone.at(@td.decode(user["last_seen"])),
          name:         user["real_name"],
          website:      user["website"],
          location:     user["location"],
        }
      end
    end
  end

  def import_posts
    puts "", "importing questions..."

    post_count = @client.exec(<<-SQL
          SELECT COUNT(A.id)
            FROM askbot_post A
            JOIN askbot_thread B
              ON A.thread_id = B.id
           WHERE NOT B.closed AND A.post_type='question'
      SQL
    )[0]["count"]

    batches(BATCH_SIZE) do |offset|
      posts = @client.exec(<<-SQL
          SELECT A.id, A.author_id, A.added_at, A.text, A.thread_id, B.title
            FROM askbot_post A
            JOIN askbot_thread B
              ON A.thread_id = B.id
           WHERE NOT B.closed AND A.post_type = 'question'
        ORDER BY A.added_at
          LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL
      )

      break if posts.ntuples() < 1

      next if all_records_exist? :posts, posts.map {|p| p["id"].to_i}

      create_posts(posts, total: post_count, offset: offset) do |post|
        pid = post["id"]
        tid = post["thread_id"].to_i
        tags = @tagmap[tid]
        cat = nil
        if tags
          CATEGORIES.each do |cname|
            next unless tags.include?(cname.downcase)
            cat = cname
            break
          end
        end
        @thread_parents[tid] = pid
        {
          id: pid,
          title: post["title"],
          category: cat,
          custom_fields: {import_id: pid, import_thread_id: tid, import_tags: tags},
          user_id: user_id_from_imported_user_id(post["author_id"]) || Discourse::SYSTEM_USER_ID,
          created_at: Time.zone.at(@td.decode(post["added_at"])),
          raw: post["text"],
        }
      end
    end
  end

  def import_replies
    puts "", "importing answers and comments..."

    post_count = @client.exec(<<-SQL
          SELECT COUNT(A.id)
            FROM askbot_post A
            JOIN askbot_thread B
              ON A.thread_id = B.id
           WHERE NOT B.closed AND A.post_type<>'question'
      SQL
    )[0]["count"]

    batches(BATCH_SIZE) do |offset|
      posts = @client.exec(<<-SQL
          SELECT A.id, A.author_id, A.added_at, A.text, A.thread_id, B.title
            FROM askbot_post A
            JOIN askbot_thread B
              ON A.thread_id = B.id
           WHERE NOT B.closed AND A.post_type <> 'question'
        ORDER BY A.added_at
          LIMIT #{BATCH_SIZE}
          OFFSET #{offset}
      SQL
      )

      break if posts.ntuples() < 1

      next if all_records_exist? :posts, posts.map {|p| p["id"].to_i}

      create_posts(posts, total: post_count, offset: offset) do |post|
        tid = post["thread_id"].to_i
        next unless thread = @thread_parents[tid]
        next unless parent = topic_lookup_from_imported_post_id(thread)
        pid = post["id"]
        {
          id: pid,
          topic_id: parent[:topic_id],
          custom_fields: {import_id: pid},
          user_id: user_id_from_imported_user_id(post["author_id"]) || Discourse::SYSTEM_USER_ID,
          created_at: Time.zone.at(@td.decode(post["added_at"])),
          raw: post["text"]
        }
      end
    end
  end

  def post_process_posts
      puts "", "Postprocessing posts..."
      current = 0
      max = Post.count
      # Rewrite internal links; e.g.
      # ask.cvxr.com/question/(\d+)/[^'"}]*
      # I am sure this is incomplete, but we didn't make heavy use of internal
      # links on our site.
      tmp = Regexp.quote("http://" << OLD_SITE)
      r1 = /"(#{tmp})?\/question\/(\d+)\/[a-zA-Z-]*\/?"/
      r2 = /\((#{tmp})?\/question\/(\d+)\/[a-zA-Z-]*\/?\)/
      r3 = /<?#tmp\/question\/(\d+)\/[a-zA-Z-]*\/?>?/
      Post.find_each do |post|
        raw = post.raw.gsub(r1) do
          if topic = topic_lookup_from_imported_post_id($2)
            "\"#{topic[:url]}\""
          else
            $&
          end
        end
        raw = raw.gsub(r2) do
          if topic = topic_lookup_from_imported_post_id($2)
            "(#{topic[:url]})"
          else
            $&
          end
        end
        raw = raw.gsub(r3) do
           if topic = topic_lookup_from_imported_post_id($1)
            trec = Topic.find_by(id: topic[:topic_id])
            "[#{trec.title}](#{topic[:url]})"
          else
            $&
          end
        end
        if raw != post.raw
          post.raw = raw
          post.save
        end
        print_status(current += 1, max)
      end
    end
  end

ImportScripts::MyAskBot.new.perform
