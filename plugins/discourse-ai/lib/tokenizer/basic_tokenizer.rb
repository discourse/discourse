# frozen_string_literal: true

module DiscourseAi
  module Tokenizer
    class BasicTokenizer
      class << self
        def available_llm_tokenizers
          [
            DiscourseAi::Tokenizer::AnthropicTokenizer,
            DiscourseAi::Tokenizer::GeminiTokenizer,
            DiscourseAi::Tokenizer::Llama3Tokenizer,
            DiscourseAi::Tokenizer::MixtralTokenizer,
            DiscourseAi::Tokenizer::OpenAiTokenizer,
          ]
        end

        def tokenizer
          raise NotImplementedError
        end

        def tokenize(text)
          tokenizer.encode(text).tokens
        end

        def size(text)
          tokenize(text).size
        end

        def decode(token_ids)
          tokenizer.decode(token_ids)
        end

        def encode(tokens)
          tokenizer.encode(tokens).ids
        end

        def truncate(text, max_length)
          # fast track common case, /2 to handle unicode chars
          # than can take more than 1 token per char
          return text if !SiteSetting.ai_strict_token_counting && text.size < max_length / 2
          tokenizer.decode(tokenizer.encode(text).ids.take(max_length))
        end

        def below_limit?(text, limit)
          # fast track common case, /2 to handle unicode chars
          # than can take more than 1 token per char
          return true if !SiteSetting.ai_strict_token_counting && text.size < limit / 2

          tokenizer.encode(text).ids.length < limit
        end
      end
    end
  end
end
