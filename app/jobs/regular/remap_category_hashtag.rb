# frozen_string_literal: true

module Jobs
  class RemapCategoryHashtag < ::Jobs::Base
    sidekiq_options queue: "low"
    cluster_concurrency 1

    def execute(args)
      Jobs::RemapHashtag.new.execute(
        remaps: [
          { type: CategoryHashtagDataSource.type, id: args[:category_id], old_ref: args[:old_ref] },
        ],
      )
    end
  end
end
