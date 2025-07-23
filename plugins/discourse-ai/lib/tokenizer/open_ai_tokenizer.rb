# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class OpenAiTokenizer < BasicTokenizer
      class << self
        def tokenizer
          @@tokenizer ||= Tiktoken.get_encoding("cl100k_base")
        end

        def tokenize(text)
          tokenizer.encode(text)
        end

        def encode(text)
          tokenizer.encode(text)
        end

        def decode(token_ids)
          tokenizer.decode(token_ids)
        end

        def truncate(text, max_length)
          # fast track common case, /2 to handle unicode chars
          # than can take more than 1 token per char
          return text if !SiteSetting.ai_strict_token_counting && text.size < max_length / 2

          tokenizer.decode(tokenize(text).take(max_length))
        rescue Tiktoken::UnicodeError
          max_length = max_length - 1
          retry
        end

        def below_limit?(text, limit)
          # fast track common case, /2 to handle unicode chars
          # than can take more than 1 token per char
          return true if !SiteSetting.ai_strict_token_counting && text.size < limit / 2

          tokenizer.encode(text).length < limit
        end
      end
    end
  end
end
