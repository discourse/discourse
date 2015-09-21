require_relative '../base'
require_relative 'support/settings'
require_relative 'database/database'
require_relative 'importers/importer_factory'

module ImportScripts::PhpBB3
  class Importer < ImportScripts::Base
    # @param settings [ImportScripts::PhpBB3::Settings]
    # @param database [ImportScripts::PhpBB3::Database_3_0 | ImportScripts::PhpBB3::Database_3_1]
    def initialize(settings, database)
      @settings = settings
      super()

      @database = database
      @php_config = database.get_config_values
      @importers = ImporterFactory.new(@database, @lookup, @uploader, @settings, @php_config)
    end

    def perform
      super if settings_check_successful?
    end

    protected

    def execute
      puts '', "importing from phpBB #{@php_config[:phpbb_version]}"

      import_users
      import_anonymous_users if @settings.import_anonymous_users
      import_categories
      import_posts
      import_private_messages if @settings.import_private_messages
      import_bookmarks if @settings.import_bookmarks
    end

    def get_site_settings_for_import
      settings = super

      max_file_size_kb = @database.get_max_attachment_size
      settings[:max_image_size_kb] = [max_file_size_kb, SiteSetting.max_image_size_kb].max
      settings[:max_attachment_size_kb] = [max_file_size_kb, SiteSetting.max_attachment_size_kb].max

      settings
    end

    def settings_check_successful?
      true
    end

    def import_users
      puts '', 'creating users'
      total_count = @database.count_users
      importer = @importers.user_importer

      batches do |offset|
        rows = @database.fetch_users(offset)
        break if rows.size < 1

        next if all_records_exist? :users, importer.map_to_import_ids(rows)

        create_users(rows, total: total_count, offset: offset) do |row|
          importer.map_user(row)
        end
      end
    end

    def import_anonymous_users
      puts '', 'creating anonymous users'
      total_count = @database.count_anonymous_users
      importer = @importers.user_importer

      batches do |offset|
        rows = @database.fetch_anonymous_users(offset)
        break if rows.size < 1

        create_users(rows, total: total_count, offset: offset) do |row|
          importer.map_anonymous_user(row)
        end
      end
    end

    def import_categories
      puts '', 'creating categories'
      rows = @database.fetch_categories
      importer = @importers.category_importer

      create_categories(rows) do |row|
        importer.map_category(row)
      end
    end

    def import_posts
      puts '', 'creating topics and posts'
      total_count = @database.count_posts
      importer = @importers.post_importer

      batches do |offset|
        rows = @database.fetch_posts(offset)
        break if rows.size < 1

        create_posts(rows, total: total_count, offset: offset) do |row|
          importer.map_post(row)
        end
      end
    end

    def import_private_messages
      if @settings.fix_private_messages
        puts '', 'fixing private messages'
        @database.calculate_fixed_messages
      end

      puts '', 'creating private messages'
      total_count = @database.count_messages(@settings.fix_private_messages)
      importer = @importers.message_importer

      batches do |offset|
        rows = @database.fetch_messages(@settings.fix_private_messages, offset)
        break if rows.size < 1

        create_posts(rows, total: total_count, offset: offset) do |row|
          importer.map_message(row)
        end
      end
    end

    def import_bookmarks
      puts '', 'creating bookmarks'
      total_count = @database.count_bookmarks
      importer = @importers.bookmark_importer

      batches do |offset|
        rows = @database.fetch_bookmarks(offset)
        break if rows.size < 1

        create_bookmarks(rows, total: total_count, offset: offset) do |row|
          importer.map_bookmark(row)
        end
      end
    end

    def update_last_seen_at
      # no need for this since the importer sets last_seen_at for each user during the import
    end

    def use_bbcode_to_md?
      @settings.use_bbcode_to_md
    end

    def batches
      super(@settings.database.batch_size)
    end
  end
end
