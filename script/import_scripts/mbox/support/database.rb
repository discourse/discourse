require 'sqlite3'

module ImportScripts::Mbox
  class Database
    SCHEMA_VERSION = 2

    def initialize(directory, batch_size)
      @db = SQLite3::Database.new("#{directory}/index.db", results_as_hash: true)
      @batch_size = batch_size

      configure_database
      upgrade_schema_version
      create_table_for_categories
      create_table_for_imported_files
      create_table_for_emails
      create_table_for_replies
      create_table_for_users
    end

    def transaction
      @db.transaction
      yield self
      @db.commit

    rescue
      @db.rollback
    end

    def insert_category(category)
      @db.execute(<<-SQL, category)
        INSERT OR REPLACE INTO category (name, description)
        VALUES (:name, :description)
      SQL
    end

    def insert_imported_file(imported_file)
      @db.execute(<<-SQL, imported_file)
        INSERT OR REPLACE INTO imported_file (category, filename, checksum)
        VALUES (:category, :filename, :checksum)
      SQL
    end

    def insert_email(email)
      @db.execute(<<-SQL, email)
        INSERT OR REPLACE INTO email (msg_id, from_email, from_name, subject,
          email_date, raw_message, body, elided, format, attachment_count, charset,
          category, filename, first_line_number, last_line_number, index_duration)
        VALUES (:msg_id, :from_email, :from_name, :subject,
          :email_date, :raw_message, :body, :elided, :format, :attachment_count, :charset,
          :category, :filename, :first_line_number, :last_line_number, :index_duration)
      SQL
    end

    def insert_replies(msg_id, reply_message_ids)
      sql = <<-SQL
        INSERT OR REPLACE INTO reply (msg_id, in_reply_to)
        VALUES (:msg_id, :in_reply_to)
      SQL

      @db.prepare(sql) do |stmt|
        reply_message_ids.each do |in_reply_to|
          stmt.execute(msg_id, in_reply_to)
        end
      end
    end

    def update_in_reply_to_of_emails
      @db.execute <<-SQL
        UPDATE email
        SET in_reply_to = (
          SELECT e.msg_id
          FROM reply r
            JOIN email e ON (r.in_reply_to = e.msg_id)
          WHERE r.msg_id = email.msg_id
          ORDER BY e.email_date DESC
          LIMIT 1
        )
      SQL
    end

    def update_in_reply_to_by_email_subject
      @db.execute <<-SQL
        UPDATE email
        SET in_reply_to = NULLIF((
          SELECT e.msg_id
          FROM email e
            JOIN email_order o ON (e.msg_id = o.msg_id)
          WHERE e.subject = email.subject
          ORDER BY o.ROWID
          LIMIT 1
        ), msg_id)
      SQL
    end

    def sort_emails_by_date_and_reply_level
      @db.execute 'DELETE FROM email_order'

      @db.execute <<-SQL
        WITH RECURSIVE
          messages(msg_id, level, email_date) AS (
            SELECT msg_id, 0 AS level, email_date
            FROM email
            WHERE in_reply_to IS NULL
            UNION ALL
            SELECT e.msg_id, m.level + 1, e.email_date
            FROM email e
              JOIN messages m ON e.in_reply_to = m.msg_id
            ORDER BY level, email_date, msg_id
          )
        INSERT INTO email_order (msg_id)
        SELECT msg_id
        FROM messages
      SQL
    end

    def sort_emails_by_subject
      @db.execute 'DELETE FROM email_order'

      @db.execute <<-SQL
        INSERT INTO email_order (msg_id)
        SELECT msg_id
        FROM email
        ORDER BY subject, filename, ROWID
      SQL
    end

    def fill_users_from_emails
      @db.execute 'DELETE FROM user'

      @db.execute <<-SQL
        INSERT INTO user (email, name, date_of_first_message)
        SELECT from_email, MIN(from_name) AS from_name, MIN(email_date)
        FROM email
        WHERE from_email IS NOT NULL AND email_date IS NOT NULL
        GROUP BY from_email
        ORDER BY from_email
      SQL
    end

    def fetch_imported_files(category)
      @db.execute(<<-SQL, category)
        SELECT filename, checksum
        FROM imported_file
        WHERE category = :category
      SQL
    end

    def fetch_categories
      @db.execute <<-SQL
        SELECT name, description
        FROM category
        ORDER BY name
      SQL
    end

    def count_users
      @db.get_first_value <<-SQL
        SELECT COUNT(*)
        FROM user
      SQL
    end

    def fetch_users(last_email)
      rows = @db.execute(<<-SQL, last_email)
        SELECT email, name, date_of_first_message
        FROM user
        WHERE email > :last_email
        LIMIT #{@batch_size}
      SQL

      add_last_column_value(rows, 'email')
    end

    def count_messages
      @db.get_first_value <<-SQL
        SELECT COUNT(*)
        FROM email
        WHERE email_date IS NOT NULL
      SQL
    end

    def fetch_messages(last_row_id)
      rows = @db.execute(<<-SQL, last_row_id)
        SELECT o.ROWID, e.msg_id, from_email, subject, email_date, in_reply_to,
          raw_message, body, elided, format, attachment_count, category
        FROM email e
          JOIN email_order o USING (msg_id)
        WHERE email_date IS NOT NULL AND
          o.ROWID > :last_row_id
        ORDER BY o.ROWID
        LIMIT #{@batch_size}
      SQL

      add_last_column_value(rows, 'rowid')
    end

    private

    def configure_database
      @db.execute 'PRAGMA journal_mode = OFF'
      @db.execute 'PRAGMA locking_mode = EXCLUSIVE'
    end

    def upgrade_schema_version
      current_version = @db.get_first_value("PRAGMA user_version")

      case current_version
      when 1
        @db.execute "ALTER TABLE email ADD COLUMN index_duration REAL"
      end

      @db.execute "PRAGMA user_version = #{SCHEMA_VERSION}"
    end

    def create_table_for_categories
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS category (
          name TEXT NOT NULL PRIMARY KEY,
          description TEXT
        )
      SQL
    end

    def create_table_for_imported_files
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS imported_file (
          category TEXT NOT NULL,
          filename TEXT NOT NULL,
          checksum TEXT NOT NULL,
          PRIMARY KEY (category, filename),
          FOREIGN KEY(category) REFERENCES category(name)
        )
      SQL
    end

    def create_table_for_emails
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS email (
          msg_id TEXT NOT NULL PRIMARY KEY,
          from_email TEXT,
          from_name TEXT,
          subject TEXT,
          in_reply_to TEXT,
          email_date DATETIME,
          raw_message TEXT,
          body TEXT,
          elided TEXT,
          format INTEGER,
          attachment_count INTEGER NOT NULL DEFAULT 0,
          charset TEXT,
          category TEXT NOT NULL,
          filename TEXT NOT NULL,
          first_line_number INTEGER,
          last_line_number INTEGER,
          index_duration REAL,
          FOREIGN KEY(category) REFERENCES category(name)
        )
      SQL

      @db.execute 'CREATE INDEX IF NOT EXISTS email_by_from ON email (from_email)'
      @db.execute 'CREATE INDEX IF NOT EXISTS email_by_subject ON email (subject)'
      @db.execute 'CREATE INDEX IF NOT EXISTS email_by_in_reply_to ON email (in_reply_to)'
      @db.execute 'CREATE INDEX IF NOT EXISTS email_by_date ON email (email_date)'

      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS email_order (
          msg_id TEXT NOT NULL PRIMARY KEY
        )
      SQL
    end

    def create_table_for_replies
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS reply (
          msg_id TEXT NOT NULL,
          in_reply_to TEXT NOT NULL,
          PRIMARY KEY (msg_id, in_reply_to),
          FOREIGN KEY(msg_id) REFERENCES email(msg_id)
        )
      SQL

      @db.execute 'CREATE INDEX IF NOT EXISTS reply_by_in_reply_to ON reply (in_reply_to)'
    end

    def create_table_for_users
      @db.execute <<-SQL
        CREATE TABLE IF NOT EXISTS user (
          email TEXT NOT NULL PRIMARY KEY,
          name TEXT,
          date_of_first_message DATETIME NOT NULL
        )
      SQL
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
