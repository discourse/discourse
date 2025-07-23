# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class BgeM3Tokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||= Tokenizers.from_file("./plugins/discourse-ai/tokenizers/bge-m3.json")
      end
    end
  end
end
