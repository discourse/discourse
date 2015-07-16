module ImportScripts::PhpBB3
  class CategoryImporter
    # @param lookup [ImportScripts::LookupContainer]
    # @param text_processor [ImportScripts::PhpBB3::TextProcessor]
    def initialize(lookup, text_processor)
      @lookup = lookup
      @text_processor = text_processor
    end

    def map_category(row)
      {
        id: row[:forum_id],
        name: CGI.unescapeHTML(row[:forum_name]),
        parent_category_id: @lookup.category_id_from_imported_category_id(row[:parent_id]),
        post_create_action: proc do |category|
          update_category_description(category, row)
        end
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
        changes = {raw: @text_processor.process_raw_text(row[:forum_desc])}
        opts = {revised_at: post.created_at, bypass_bump: true}
        post.revise(Discourse.system_user, changes, opts)
      end
    end
  end
end
