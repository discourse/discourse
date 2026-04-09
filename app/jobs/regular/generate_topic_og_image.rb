# frozen_string_literal: true

module Jobs
  class GenerateTopicOgImage < ::Jobs::Base
    sidekiq_options queue: "ultra_low"

    def execute(args)
      return if !SiteSetting.generate_topic_og_image

      topic_id = args[:topic_id]
      raise Discourse::InvalidParameters.new(:topic_id) if topic_id.blank?

      topic = Topic.find_by(id: topic_id)
      return if topic.nil?
      return if topic.image_upload_id.present?
      return if topic.custom_fields["og_image_upload_id"].present?

      generator = TopicOgImageGenerator.new(topic)
      upload = generator.generate
      return if upload.nil? || upload.errors.any?

      topic.custom_fields["og_image_upload_id"] = upload.id
      topic.save_custom_fields
    end
  end
end
