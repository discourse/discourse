# frozen_string_literal: true

module ::Blog
  class Current < ActiveSupport::CurrentAttributes
    attribute :copy_source_id, :copy_category_id

    def copying_into?(category_id)
      !copy_source_id.nil? && copy_category_id == category_id
    end
  end
end
