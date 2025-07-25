# frozen_string_literal: true

module DiscourseAi
  module Summarization
    module Strategies
      # Objects inheriting from this class will get passed as a dependency to `DiscourseAi::Summarization::FoldContent`.
      # This collaborator knows how to source the content to summarize and the prompts used in the process,
      # one for summarizing a chunk and another for concatenating them if necessary.
      class Base
        def initialize(target)
          @target = target
        end

        attr_reader :target, :opts

        # The summary type differentiates instances of `AiSummary` pointing to a single target.
        # See the `summary_type` enum for available options.
        def type
          raise NotImplementedError
        end

        # @returns { Array<Hash> } - Content to summarize.
        #
        # This method returns an array of hashes with the content to summarize using the following structure:
        #
        # {
        #  poster: A way to tell who write the content,
        #  id: A number to signal order,
        #  text: Text to summarize
        # }
        #
        def targets_data
          raise NotImplementedError
        end

        # @returns { Array } - Prompt messages to send to the LLM for summarizing content.
        def as_llm_messages(_input)
          raise NotImplementedError
        end

        # We'll pass this as the feature_name when doing LLM calls.
        def feature
          "summarize"
        end
      end
    end
  end
end
