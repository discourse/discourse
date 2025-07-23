# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class MultilingualE5LargeTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/multilingual-e5-large.json")
      end
    end
  end
end
