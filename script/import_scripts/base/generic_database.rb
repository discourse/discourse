require 'sqlite3'

module ImportScripts
  class GenericDatabase
    def initialize(directory, batch_size:, recreate: false)
      filename = "#{directory}/index.db"
      File.delete(filename) if recreate && File.exists?(filename)

      @db = SQLite3::Database.new(filename, results_as_hash: true)
      @batch_size = batch_size

      configure_database
      create_category_table
      create_user_table
      create_topic_table
      create_post_table
    end

    def insert_category(category)
      @db.execute(<<-SQL, prepare(category))
        INSERT OR REPLACE INTO category (id, name, description, position, url)
        VALUES (:id, :name, :description, :position, :url)
      SQL
    end

    def insert_user(user)
      @db.execute(<<-SQL, prepare(user))
        INSERT OR REPLACE INTO user (id, email, username, name, created_at, last_seen_at, active)
        VALUES (:id, :email, :username, :name, :created_at, :last_seen_at, :active)
      SQL
    end

    def insert_topic(topic)
      @db.execute(<<-SQL, prepare(topic))
        INSERT OR REPLACE INTO topic (id, title, raw, category_id, closed, user_id, created_at, url)
        VALUES (:id, :title, :raw, :category_id, :closed, :user_id, :created_at, :url)
      SQL
    end

    def insert_post(post)
      @db.execute(<<-SQL, prepare(post))
        INSERT OR REPLACE INTO post (id, raw, topic_id, user_id, created_at, reply_to_post_id, url)
        VALUES (:id, :raw, :topic_id, :user_id, :created_at, :reply_to_post_id, :url)
      SQL
    end

    def sort_posts_by_created_at
      @db.execute 'DELETE FROM post_order'

      @db.execute <<-SQL
        INSERT INTO post_order (id)
        SELECT id
        FROM post
        ORDER BY created_at, topic_id, id
      SQL
    end

    def fetch_categories
      @db.execute(<<-SQL)
        SELECT *
        FROM category
        ORDER BY position, name
      SQL
    end

    def count_users
      @db.get_first_value(<<-SQL)
        SELECT COUNT(*)
        FROM user
      SQL
    end

    def fetch_users(last_id)
      rows = @db.execute(<<-SQL, last_id)
        SELECT *
        FROM user
        WHERE id > :last_id
        ORDER BY id
        LIMIT #{@batch_size}
      SQL

      add_last_column_value(rows, 'id')
    end

    def count_topics
      @db.get_first_value(<<-SQL)
        SELECT COUNT(*)
        FROM topic
      SQL
    end

    def fetch_topics(last_id)
      rows = @db.execute(<<-SQL, last_id)
        SELECT *
        FROM topic
        WHERE id > :last_id
        ORDER BY id
        LIMIT #{@batch_size}
      SQL

      add_last_column_value(rows, 'id')
    end

    def count_posts
      @db.get_first_value(<<-SQL)
        SELECT COUNT(*)
        FROM post
      SQL
    end

    def fetch_posts(last_row_id)
      rows = @db.execute(<<-SQL, last_row_id)
        SELECT o.ROWID, p.*
        FROM post p
          JOIN post_order o USING (id)
        WHERE o.ROWID > :last_row_id
        ORDER BY o.ROWID
        LIMIT #{@batch_size}
      SQL

      add_last_column_value(rows, 'rowid')
    end

    def execute_sql(sql)
      @db.execute(sql)
    end

    private

    def configure_database
      @db.execute 'PRAGMA journal_mode = OFF'
      @db.execute 'PRAGMA locking_mode = EXCLUSIVE'
    end

    def create_category_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS category (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          position INTEGER,
          url TEXT
        )
      SQL
    end

    def create_user_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS user (
          id TEXT NOT NULL PRIMARY KEY,
          email TEXT,
          username TEXT,
          name TEXT,
          created_at DATETIME,
          last_seen_at DATETIME,
          active BOOLEAN NOT NULL DEFAULT true
        )
      SQL
    end

    def create_topic_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS topic (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT,
          raw TEXT,
          category_id TEXT NOT NULL,
          closed BOOLEAN NOT NULL DEFAULT false,
          user_id TEXT NOT NULL,
          created_at DATETIME,
          url TEXT
        )
      SQL

      @db.execute 'CREATE INDEX IF NOT EXISTS topic_by_user_id ON topic (user_id)'
    end

    def create_post_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS post (
          id TEXT NOT NULL PRIMARY KEY,
          raw TEXT,
          topic_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          created_at DATETIME,
          reply_to_post_id TEXT,
          url TEXT
        )
      SQL

      @db.execute 'CREATE INDEX IF NOT EXISTS post_by_user_id ON post (user_id)'

      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS post_order (
          id TEXT NOT NULL PRIMARY KEY
        )
      SQL
    end

    def prepare(hash)
      hash.each do |key, value|
        if value.is_a?(TrueClass) || value.is_a?(FalseClass)
          hash[key] = value ? 1 : 0
        elsif value.is_a?(Date)
          hash[key] = value.to_s
        end
      end
    end

    def add_last_column_value(rows, *last_columns)
      return rows if last_columns.empty?

      result = [rows]
      last_row = rows.last

      last_columns.each { |column| result.push(last_row ? last_row[column] : nil) }
      result
    end
  end
end
