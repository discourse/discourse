# frozen_string_literal: true

module ImportScripts::PhpBB3
  class CategoryImporter
    # @param lookup [ImportScripts::LookupContainer]
    # @param text_processor [ImportScripts::PhpBB3::TextProcessor]
    # @param permalink_importer [ImportScripts::PhpBB3::PermalinkImporter]
    # @param settings [ImportScripts::PhpBB3::Settings]
    def initialize(lookup, text_processor, permalink_importer, settings)
      @lookup = lookup
      @text_processor = text_processor
      @permalink_importer = permalink_importer
      @settings = settings
    end

    def map_category(row)
      return if @settings.category_mappings[row[:forum_id].to_s]

      if row[:parent_id] && @settings.category_mappings[row[:parent_id].to_s]
        puts "parent category (#{row[:parent_id]}) was mapped, but child was not (#{row[:forum_id]})"
      end

      {
        id: @settings.prefix(row[:forum_id]),
        name: CGI.unescapeHTML(row[:forum_name]),
        parent_category_id:
          @lookup.category_id_from_imported_category_id(@settings.prefix(row[:parent_id])),
        post_create_action:
          proc do |category|
            update_category_description(category, row)
            @permalink_importer.create_for_category(category, row[:forum_id]) # skip @settings.prefix because ID is used in permalink generation
          end,
      }
    end

    protected

    # @param category [Category]
    def update_category_description(category, row)
      return if row[:forum_desc].blank? && row[:first_post_time].blank?

      topic = category.topic
      post = topic.first_post

      if row[:first_post_time].present?
        created_at = Time.zone.at(row[:first_post_time])

        topic.created_at = created_at
        topic.save

        post.created_at = created_at
        post.save
      end

      if row[:forum_desc].present?
        changes = {
          raw:
            (
              begin
                @text_processor.process_raw_text(row[:forum_desc])
              rescue StandardError
                row[:forum_desc]
              end
            ),
        }
        opts = { revised_at: post.created_at, bypass_bump: true }
        post.revise(Discourse.system_user, changes, opts)
      end
    end
  end
end
