# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class BertTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||=
          Tokenizers.from_file("./plugins/discourse-ai/tokenizers/bert-base-uncased.json")
      end
    end
  end
end
