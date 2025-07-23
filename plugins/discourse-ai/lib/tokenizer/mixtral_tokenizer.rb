# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class MixtralTokenizer < BasicTokenizer
      def self.tokenizer
        @@tokenizer ||= Tokenizers.from_file("./plugins/discourse-ai/tokenizers/mixtral.json")
      end
    end
  end
end
