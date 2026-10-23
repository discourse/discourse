# frozen_string_literal: true

module Jobs
  class GenerateRagEmbeddings < ::Jobs::Base
    sidekiq_options queue: "ultra_low"
    # we could also restrict concurrency but this takes so long if it is not concurrent

    def execute(args)
      return if (fragments = RagDocumentFragment.where(id: args[:fragment_ids].to_a)).empty?

      last_fragment = fragments.last
      target = last_fragment.target
      upload = last_fragment.upload
      vector = DiscourseAi::Embeddings::Vector.instance

      # generate_representation_from checks compares the digest value to make sure
      # the embedding is only generated once per fragment unless something changes.
      fragments.map { |fragment| vector.generate_representation_from(fragment) }

      indexing_status = RagDocumentFragment.indexing_status(target, [upload])[upload.id]
      RagDocumentFragment.publish_status(upload, indexing_status)
      if indexing_status[:total].to_i.positive? && indexing_status[:left].to_i.zero?
        RagDocumentSource.promote_pending_upload(target:, upload:)
      end
    rescue StandardError => error
      if upload.present? && target.present?
        RagDocumentSource.mark_indexing_failed(target:, upload:, error:)
      end
      raise
    end
  end
end
