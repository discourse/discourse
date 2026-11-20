# frozen_string_literal: true

module Jobs
  class UpdateCategoryUploadSecurity < ::Jobs::Base
    def execute(args)
      category = Category.find_by(id: args[:category_id])
      return if category.blank?

      category
        .topics
        .with_deleted
        .select(:id)
        .find_each { |topic| Jobs.enqueue(:update_topic_upload_security, topic_id: topic.id) }
    end
  end
end
