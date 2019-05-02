# frozen_string_literal: true

require "import_export/base_exporter"

module ImportExport
  class TopicExporter < ImportExport::BaseExporter

    def initialize(topic_ids)
      @topics = Topic.where(id: topic_ids).to_a
      @export_data = {
        topics: [],
        users: []
      }
    end

    def perform
      export_topics!
      export_topic_users!
      # TODO: user actions

      self
    end

    def default_filename_prefix
      "topic-export"
    end

  end
end
