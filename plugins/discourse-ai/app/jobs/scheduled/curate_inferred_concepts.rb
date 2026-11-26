# frozen_string_literal: true

module Jobs
  class CurateInferredConcepts < ::Jobs::Scheduled
    every 1.week

    def execute(_args)
      return unless SiteSetting.inferred_concepts_enabled && DiscourseAi::Embeddings.enabled?

      DiscourseAi::InferredConcepts::Curator.new.curate!
    end
  end
end
