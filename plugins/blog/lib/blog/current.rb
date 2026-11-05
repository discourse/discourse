# frozen_string_literal: true

module ::Blog
  class Current < ActiveSupport::CurrentAttributes
    attribute :copy_source_id, :copy_category_id, :publishing_topic_id

    def copying_into?(category_id)
      !copy_source_id.nil? && copy_category_id == category_id
    end

    def publishing_topic?(topic_id)
      !topic_id.nil? && publishing_topic_id == topic_id
    end
  end
end
