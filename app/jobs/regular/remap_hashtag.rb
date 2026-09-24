# frozen_string_literal: true

module Jobs
  class RemapHashtag < ::Jobs::Base
    sidekiq_options queue: "low"
    cluster_concurrency 1

    def execute(args)
      rewritten = Set.new

      Array(args[:remaps]).each do |remap|
        remap = remap.symbolize_keys

        counts =
          HashtagRemapper.remap!(
            type: remap[:type],
            id: remap[:id],
            old_ref: remap[:old_ref],
            rewritten:,
          )
        next if counts.blank?

        Rails.logger.warn("Remapped #{remap[:type]} hashtag ##{remap[:old_ref]}: #{counts.to_json}")
      rescue => error
        Discourse.warn_exception(
          error,
          message: "Failed to remap #{remap[:type]} hashtag ##{remap[:old_ref]}",
        )
      end
    end
  end
end
