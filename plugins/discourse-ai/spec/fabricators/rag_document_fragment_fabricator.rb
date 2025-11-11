# frozen_string_literal: true

Fabricator(:rag_document_fragment) do
  fragment { sequence(:fragment) { |n| "Document fragment #{n}" } }
  upload
  fragment_number { sequence(:fragment_number) { |n| n + 1 } }
end
