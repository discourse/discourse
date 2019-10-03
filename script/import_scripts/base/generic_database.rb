# frozen_string_literal: true

require 'sqlite3'

module ImportScripts
  class GenericDatabase
    def initialize(directory, batch_size:, recreate: false, numeric_keys: false)
      filename = "#{directory}/index.db"
      File.delete(filename) if recreate && File.exists?(filename)

      @db = SQLite3::Database.new(filename, results_as_hash: true)
      @batch_size = batch_size
      @numeric_keys = numeric_keys

      configure_database
      create_category_table
      create_like_table
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
        INSERT OR REPLACE
        INTO user (id, email, username, name, bio, avatar_path, created_at, last_seen_at, active)
        VALUES (:id, :email, :username, :name, :bio, :avatar_path, :created_at, :last_seen_at, :active)
      SQL
    end

    def insert_like(like)
      @db.execute(<<-SQL, prepare(like))
        INSERT OR REPLACE INTO like (id, user_id, post_id, topic)
        VALUES (:id, :user_id, :post_id, :topic)
      SQL
    end

    def insert_topic(topic)
      like_user_ids = topic.delete(:like_user_ids)
      attachments = topic.delete(:attachments)
      topic[:upload_count] = attachments&.size || 0

      @db.transaction do
        @db.execute(<<-SQL, prepare(topic))
          INSERT OR REPLACE INTO topic (id, title, raw, category_id, closed, user_id, created_at, url, upload_count)
          VALUES (:id, :title, :raw, :category_id, :closed, :user_id, :created_at, :url, :upload_count)
        SQL

        attachments&.each do |attachment|
          @db.execute(<<-SQL, topic_id: topic[:id], path: attachment)
            INSERT OR REPLACE INTO topic_upload (topic_id, path)
            VALUES (:topic_id, :path)
          SQL
        end

        like_user_ids&.each do |user_id|
          @db.execute(<<-SQL, topic_id: topic[:id], user_id: user_id)
            INSERT OR REPLACE INTO like (topic_id, user_id)
            VALUES (:topic_id, :user_id)
          SQL
        end
      end
    end

    def insert_post(post)
      like_user_ids = post.delete(:like_user_ids)
      attachments = post.delete(:attachments)
      post[:upload_count] = attachments&.size || 0

      @db.transaction do
        @db.execute(<<-SQL, prepare(post))
          INSERT OR REPLACE INTO post (id, raw, topic_id, user_id, created_at, reply_to_post_id, url, upload_count)
          VALUES (:id, :raw, :topic_id, :user_id, :created_at, :reply_to_post_id, :url, :upload_count)
        SQL

        attachments&.each do |attachment|
          @db.execute(<<-SQL, post_id: post[:id], path: attachment)
            INSERT OR REPLACE INTO post_upload (post_id, path)
            VALUES (:post_id, :path)
          SQL
        end

        like_user_ids&.each do |user_id|
          @db.execute(<<-SQL, post_id: post[:id], user_id: user_id)
            INSERT OR REPLACE INTO like (post_id, user_id)
            VALUES (:post_id, :user_id)
          SQL
        end
      end
    end

    def sort_posts_by_created_at
      @db.execute 'DELETE FROM post_order'

      @db.execute <<-SQL
        INSERT INTO post_order (post_id)
        SELECT id
        FROM post
        ORDER BY created_at, topic_id, id
      SQL
    end

    def delete_unused_users
      @db.execute <<~SQL
        DELETE FROM user
        WHERE NOT EXISTS(
            SELECT 1
            FROM topic
            WHERE topic.user_id = user.id
        ) AND NOT EXISTS(
            SELECT 1
            FROM post
            WHERE post.user_id = user.id
        )
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

    def get_user_id(username)
      @db.get_first_value(<<-SQL, username)
        SELECT id
        FROM user
        WHERE username = :username
      SQL
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

    def fetch_topic_attachments(topic_id)
      @db.execute(<<-SQL, topic_id)
        SELECT path
        FROM topic_upload
        WHERE topic_id = :topic_id
      SQL
    end

    def count_posts
      @db.get_first_value(<<-SQL)
        SELECT COUNT(*)
        FROM post
      SQL
    end

    def fetch_posts(last_row_id)
      rows = @db.execute(<<-SQL, last_row_id)
        SELECT ROWID AS rowid, *
        FROM post
        WHERE ROWID > :last_row_id
        ORDER BY ROWID
        LIMIT #{@batch_size}
      SQL

      add_last_column_value(rows, 'rowid')
    end

    def fetch_sorted_posts(last_row_id)
      rows = @db.execute(<<-SQL, last_row_id)
        SELECT o.ROWID AS rowid, p.*
        FROM post p
          JOIN post_order o ON (p.id = o.post_id)
        WHERE o.ROWID > :last_row_id
        ORDER BY o.ROWID
        LIMIT #{@batch_size}
      SQL

      add_last_column_value(rows, 'rowid')
    end

    def fetch_post_attachments(post_id)
      @db.execute(<<-SQL, post_id)
        SELECT path
        FROM post_upload
        WHERE post_id = :post_id
      SQL
    end

    def count_likes
      @db.get_first_value(<<-SQL)
        SELECT COUNT(*)
        FROM like
      SQL
    end

    def fetch_likes(last_row_id)
      rows = @db.execute(<<-SQL, last_row_id)
        SELECT ROWID AS rowid, *
        FROM like
        WHERE ROWID > :last_row_id
        ORDER BY ROWID
        LIMIT #{@batch_size}
      SQL

      add_last_column_value(rows, 'rowid')
    end

    def execute_sql(sql)
      @db.execute(sql)
    end

    def get_first_value(sql)
      @db.get_first_value(sql)
    end

    private

    def configure_database
      @db.execute 'PRAGMA journal_mode = OFF'
      @db.execute 'PRAGMA locking_mode = EXCLUSIVE'
    end

    def key_data_type
      @numeric_keys ? 'INTEGER' : 'TEXT'
    end

    def create_category_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS category (
          id #{key_data_type} NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          position INTEGER,
          url TEXT
        )
      SQL
    end

    def create_like_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS like (
          user_id #{key_data_type} NOT NULL,
          topic_id #{key_data_type},
          post_id #{key_data_type}
        )
      SQL
    end

    def create_user_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS user (
          id #{key_data_type} NOT NULL PRIMARY KEY,
          email TEXT,
          username TEXT,
          name TEXT,
          bio TEXT,
          avatar_path TEXT,
          created_at DATETIME,
          last_seen_at DATETIME,
          active BOOLEAN NOT NULL DEFAULT true
        )
      SQL

      @db.execute 'CREATE INDEX IF NOT EXISTS user_by_username ON user (username)'
    end

    def create_topic_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS topic (
          id #{key_data_type} NOT NULL PRIMARY KEY,
          title TEXT,
          raw TEXT,
          category_id #{key_data_type},
          closed BOOLEAN NOT NULL DEFAULT false,
          user_id #{key_data_type} NOT NULL,
          created_at DATETIME,
          url TEXT,
          upload_count INTEGER DEFAULT 0
        )
      SQL

      @db.execute 'CREATE INDEX IF NOT EXISTS topic_by_user_id ON topic (user_id)'

      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS topic_upload (
          topic_id #{key_data_type} NOT NULL,
          path TEXT NOT NULL
        )
      SQL

      @db.execute 'CREATE UNIQUE INDEX IF NOT EXISTS topic_upload_unique ON topic_upload(topic_id, path)'
    end

    def create_post_table
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS post (
          id #{key_data_type} NOT NULL PRIMARY KEY,
          raw TEXT,
          topic_id #{key_data_type} NOT NULL,
          user_id #{key_data_type} NOT NULL,
          created_at DATETIME,
          reply_to_post_id #{key_data_type},
          url TEXT,
          upload_count INTEGER DEFAULT 0
        )
      SQL

      @db.execute 'CREATE INDEX IF NOT EXISTS post_by_user_id ON post (user_id)'

      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS post_order (
          post_id #{key_data_type} NOT NULL PRIMARY KEY
        )
      SQL

      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS post_upload (
          post_id #{key_data_type} NOT NULL,
          path TEXT NOT NULL
        )
      SQL

      @db.execute 'CREATE UNIQUE INDEX IF NOT EXISTS post_upload_unique ON post_upload(post_id, path)'
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
