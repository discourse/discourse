# frozen_string_literal: true

module Jobs
  class SeedInferredConcepts < ::Jobs::Base
    sidekiq_options queue: "low", retry: false

    def execute(args = {})
      return unless SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?

      DiscourseAi::InferredConcepts::Seeder.new.seed!(limit: args[:limit])
    end
  end
end
