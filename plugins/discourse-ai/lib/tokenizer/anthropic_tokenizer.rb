# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class AnthropicTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/claude-v1-tokenization.json")
      end
    end
  end
end
