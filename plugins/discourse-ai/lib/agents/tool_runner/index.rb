# frozen_string_literal: true

module DiscourseAi
  module Agents
    class ToolRunner
      module Index
        def attach_index(mini_racer_context)
          mini_racer_context.attach(
            "_index_search",
            ->(*params) do
              in_attached_function do
                query, options = params
                self.running_attached_function = true
                options ||= {}
                options = options.symbolize_keys
                self.rag_search(query, **options)
              end
            end,
          )

          mini_racer_context.attach(
            "_index_get_file",
            ->(filename) { in_attached_function { rag_get_file(filename) } },
          )
        end

        private

        def rag_search(query, filenames: nil, limit: 10)
          RagDocumentFragment
            .search(
              target_id: tool.id,
              target_type: "AiTool",
              query: query,
              filenames: filenames,
              limit: limit,
            )
            .map { |fragment| { fragment: fragment[:fragment], metadata: fragment[:metadata] } }
        end

        def rag_get_file(filename)
          RagDocumentFragment.read_file(
            target_id: tool.id,
            target_type: "AiTool",
            filename: filename,
          )
        end
      end
    end
  end
end
