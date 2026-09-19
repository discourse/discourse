# frozen_string_literal: true

module Jobs
  class RefreshRagDocumentSource < ::Jobs::Base
    def execute(args)
      source = RagDocumentSource.find_by(id: args[:rag_document_source_id])
      return if source.blank? || !source.due?

      DistributedMutex.synchronize(
        "refresh_rag_document_source_#{source.id}",
        validity: 5.minutes,
      ) do
        source.reload
        next if !source.due?

        DiscourseAi::Rag::DocumentSourceRefresher.refresh(source)
      end
    end
  end
end
