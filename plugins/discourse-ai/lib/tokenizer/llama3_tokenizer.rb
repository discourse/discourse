# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class Llama3Tokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/Meta-Llama-3-70B-Instruct.json")
      end
    end
  end
end
