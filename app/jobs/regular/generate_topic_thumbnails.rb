# frozen_string_literal: true

module Jobs
  class GenerateTopicThumbnails < ::Jobs::Base
    sidekiq_options queue: 'ultra_low'

    def execute(args)
      topic_id = args[:topic_id]
      extra_sizes = args[:extra_sizes]

      raise Discourse::InvalidParameters.new(:topic_id) if topic_id.blank?

      topic = Topic.find(topic_id)
      topic.thumbnails(generate_sync: true, extra_sizes: extra_sizes)
    end

  end
end
