# frozen_string_literal: true

module ::Jobs
  class GenerateRagEmbeddings < ::Jobs::Base
    sidekiq_options queue: "ultra_low"
    # we could also restrict concurrency but this takes so long if it is not concurrent

    def execute(args)
      return if (fragments = RagDocumentFragment.where(id: args[:fragment_ids].to_a)).empty?

      vector = DiscourseAi::Embeddings::Vector.instance

      # generate_representation_from checks compares the digest value to make sure
      # the embedding is only generated once per fragment unless something changes.
      fragments.map { |fragment| vector.generate_representation_from(fragment) }

      last_fragment = fragments.last
      target = last_fragment.target
      upload = last_fragment.upload

      indexing_status = RagDocumentFragment.indexing_status(target, [upload])[upload.id]
      RagDocumentFragment.publish_status(upload, indexing_status)
    end
  end
end
