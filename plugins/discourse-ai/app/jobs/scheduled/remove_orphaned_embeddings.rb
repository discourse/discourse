# frozen_string_literal: true

module Jobs
  class RemoveOrphanedEmbeddings < ::Jobs::Scheduled
    every 1.week

    def execute(_args)
      DiscourseAi::Embeddings::Schema.remove_orphaned_data
    end
  end
end
