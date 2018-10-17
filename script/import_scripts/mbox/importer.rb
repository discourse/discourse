require_relative '../base'
require_relative 'support/database'
require_relative 'support/indexer'
require_relative 'support/settings'

module ImportScripts::Mbox
  class Importer < ImportScripts::Base
    # @param settings [ImportScripts::Mbox::Settings]
    def initialize(settings)
      @settings = settings
      super()

      @database = Database.new(@settings.data_dir, @settings.batch_size)
    end

    def get_site_settings_for_import
      settings = super
      settings[:enable_staged_users] = true
      settings[:incoming_email_prefer_html] = @settings.prefer_html
      settings
    end

    protected

    def execute
      index_messages

      if @settings.index_only
        @skip_updates = true
      else
        import_categories
        import_users
        import_posts
      end
    end

    def index_messages
      puts '', 'creating index'
      indexer = Indexer.new(@database, @settings)
      indexer.execute
    end

    def import_categories
      puts '', 'creating categories'
      rows = @database.fetch_categories

      create_categories(rows) do |row|
        {
          id: row['name'],
          name: row['name']
        }
      end
    end

    def import_users
      puts '', 'creating users'
      total_count = @database.count_users
      last_email = ''

      batches do |offset|
        rows, last_email = @database.fetch_users(last_email)
        break if rows.empty?

        next if all_records_exist?(:users, rows.map { |row| row['email'] })

        create_users(rows, total: total_count, offset: offset) do |row|
          {
            id: row['email'],
            email: row['email'],
            name: row['name'],
            trust_level: @settings.trust_level,
            staged: @settings.staged,
            active: !@settings.staged,
            created_at: to_time(row['date_of_first_message'])
          }
        end
      end
    end

    def batches
      super(@settings.batch_size)
    end

    def import_posts
      puts '', 'creating topics and posts'
      total_count = @database.count_messages
      last_row_id = 0

      batches do |offset|
        rows, last_row_id = @database.fetch_messages(last_row_id)
        break if rows.empty?

        next if all_records_exist?(:posts, rows.map { |row| row['msg_id'] })

        create_posts(rows, total: total_count, offset: offset) do |row|
          begin
            if row['email_date'].blank?
              puts "Date is missing. Skipping #{row['msg_id']}"
              nil
            elsif row['in_reply_to'].blank?
              map_first_post(row)
            else
              map_reply(row)
            end
          rescue => e
            puts "Failed to map post for #{row['msg_id']}", e, e.backtrace.join("\n")
          end
        end
      end
    end

    def map_post(row)
      user_id = user_id_from_imported_user_id(row['from_email']) || Discourse::SYSTEM_USER_ID

      {
        id: row['msg_id'],
        user_id: user_id,
        created_at: to_time(row['email_date']),
        raw: format_raw(row, user_id),
        raw_email: row['raw_message'],
        via_email: true,
        post_create_action: proc do |post|
          create_incoming_email(post, row)
        end
      }
    end

    def format_raw(row, user_id)
      body = row['body'] || ''
      elided = row['elided']

      if row['attachment_count'].positive?
        receiver = Email::Receiver.new(row['raw_message'])
        user = User.find(user_id)
        body = receiver.add_attachments(body, user)
      end

      body << Email::Receiver.elided_html(elided) if elided.present?
      body
    end

    def map_first_post(row)
      mapped = map_post(row)
      mapped[:category] = category_id_from_imported_category_id(row['category'])
      mapped[:title] = row['subject'].strip[0...255]
      mapped
    end

    def map_reply(row)
      parent = @lookup.topic_lookup_from_imported_post_id(row['in_reply_to'])

      if parent.blank?
        puts "Parent message #{row['in_reply_to']} doesn't exist. Skipping #{row['msg_id']}: #{row['subject'][0..40]}"
        return nil
      end

      mapped = map_post(row)
      mapped[:topic_id] = parent[:topic_id]
      mapped
    end

    def create_incoming_email(post, row)
      IncomingEmail.create(
        message_id: row['msg_id'],
        raw: row['raw_message'],
        subject: row['subject'],
        from_address: row['from_email'],
        user_id: post.user_id,
        topic_id: post.topic_id,
        post_id: post.id
      )
    end

    def to_time(timestamp)
      Time.zone.at(timestamp) if timestamp
    end
  end
end
