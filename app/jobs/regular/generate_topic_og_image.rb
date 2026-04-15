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
      return if topic.og_image_upload_id.present?
      return if !TopicOgImageGenerator.eligible?(topic)

      generator = TopicOgImageGenerator.new(topic)
      upload = generator.generate
      return if upload.nil? || upload.errors.any?

      topic.update_column(:og_image_upload_id, upload.id)
      UploadReference.ensure_exist!(upload_ids: [upload.id], target: topic)
    end
  end
end
