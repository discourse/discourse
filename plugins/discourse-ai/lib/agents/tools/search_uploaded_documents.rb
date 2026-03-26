# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class SearchUploadedDocuments < Tool
        DEFAULT_LIMIT = 10

        attr_reader :last_query, :result_count

        class << self
          def signature
            {
              name: name,
              description:
                "Search the documents uploaded to this agent and return the most relevant excerpts",
              parameters: [
                {
                  name: "query",
                  description:
                    "What to look for in the uploaded documents. Use a focused search query.",
                  type: "string",
                  required: true,
                },
                {
                  name: "filenames",
                  description:
                    "Optional list of filenames to restrict the search to when the user refers to specific uploaded documents",
                  type: "array",
                  item_type: "string",
                },
                {
                  name: "limit",
                  description:
                    "Maximum number of excerpts to return. Prefer the default unless the user clearly asks for more or less context.",
                  type: "integer",
                },
              ],
            }
          end

          def name
            "search_uploaded_documents"
          end

          def custom_system_message
            <<~TEXT
              Use the `search_uploaded_documents` tool when the answer may depend on documents uploaded to this agent.
              Do not assume uploaded document snippets are already in the prompt.
            TEXT
          end
        end

        def query
          parameters[:query].to_s.strip
        end

        def filenames
          Array(parameters[:filenames]).map(&:to_s).reject(&:blank?).uniq
        end

        def invoke
          if agent.blank? || agent.id.blank?
            return { error: "No uploaded documents are available for this agent." }
          end
          return { error: "A query is required." } if query.blank?

          @last_query = query

          yield("Searching uploaded documents for '#{query}'") if block_given?

          fragments =
            RagDocumentFragment.search(
              target_id: agent.id,
              target_type: "AiAgent",
              query: query,
              filenames: filenames,
              limit: result_limit,
            )

          @result_count = fragments.length

          result = {
            query: query,
            excerpts:
              fragments.map do |fragment|
                {
                  filename: fragment[:filename],
                  metadata: fragment[:metadata],
                  fragment_number: fragment[:fragment_number],
                  content: fragment[:fragment],
                }
              end,
          }
          result[:filenames] = filenames if filenames.present?
          result
        end

        protected

        def description_args
          { count: result_count || 0, query: last_query || "" }
        end

        private

        def result_limit
          requested_limit = parameters[:limit].to_i
          configured_limit = agent.class.rag_conversation_chunks || DEFAULT_LIMIT

          requested_limit = configured_limit if requested_limit <= 0
          [requested_limit, configured_limit].min
        end
      end
    end
  end
end
