# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class Fake < Dialect
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "fake"
          end
        end

        def tokenizer
          DiscourseAi::Tokenizer::OpenAiTokenizer
        end

        def translate
          ""
        end
      end
    end
  end
end
