# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class AllMpnetBaseV2Tokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/all-mpnet-base-v2.json")
      end
    end
  end
end
