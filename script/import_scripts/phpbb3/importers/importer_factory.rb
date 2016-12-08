require_relative 'attachment_importer'
require_relative 'avatar_importer'
require_relative 'bookmark_importer'
require_relative 'category_importer'
require_relative 'message_importer'
require_relative 'poll_importer'
require_relative 'post_importer'
require_relative 'permalink_importer'
require_relative 'user_importer'
require_relative '../support/smiley_processor'
require_relative '../support/text_processor'

module ImportScripts::PhpBB3
  class ImporterFactory
    # @param database [ImportScripts::PhpBB3::Database_3_0 | ImportScripts::PhpBB3::Database_3_1]
    # @param lookup [ImportScripts::LookupContainer]
    # @param uploader [ImportScripts::Uploader]
    # @param settings [ImportScripts::PhpBB3::Settings]
    # @param phpbb_config [Hash]
    def initialize(database, lookup, uploader, settings, phpbb_config)
      @database = database
      @lookup = lookup
      @uploader = uploader
      @settings = settings
      @phpbb_config = phpbb_config
    end

    def user_importer
      UserImporter.new(avatar_importer, @settings)
    end

    def category_importer
      CategoryImporter.new(@lookup, text_processor, permalink_importer)
    end

    def post_importer
      PostImporter.new(@lookup, text_processor, attachment_importer, poll_importer, permalink_importer, @settings)
    end

    def message_importer
      MessageImporter.new(@database, @lookup, text_processor, attachment_importer, @settings)
    end

    def bookmark_importer
      BookmarkImporter.new
    end

    def permalink_importer
      @permalink_importer ||= PermalinkImporter.new(@settings.permalinks)
    end

    protected

    def attachment_importer
      AttachmentImporter.new(@database, @uploader, @settings, @phpbb_config)
    end

    def avatar_importer
      AvatarImporter.new(@uploader, @settings, @phpbb_config)
    end

    def poll_importer
      PollImporter.new(@lookup, @database, text_processor)
    end

    def text_processor
      @text_processor ||= TextProcessor.new(@lookup, @database, smiley_processor, @settings)
    end

    def smiley_processor
      SmileyProcessor.new(@uploader, @settings, @phpbb_config)
    end
  end
end
