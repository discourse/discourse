# frozen_string_literal: true

module Jobs
  class RefreshRagDocumentSources < ::Jobs::Scheduled
    every 1.hour

    def execute(_args)
      RagDocumentSource.due.find_each do |source|
        Jobs.enqueue(:refresh_rag_document_source, rag_document_source_id: source.id)
      end
    end
  end
end
