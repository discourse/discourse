# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class OpenAiGpt4oTokenizer < OpenAiTokenizer
      class << self
        def tokenizer
          @@tokenizer ||= Tiktoken.get_encoding("o200k_base")
        end
      end
    end
  end
end
