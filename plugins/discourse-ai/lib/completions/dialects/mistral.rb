# frozen_string_literal: true

# basically the same as Open AI, except for no support for user names

module DiscourseAi
  module Completions
    module Dialects
      class Mistral < ChatGpt
        class << self
          def can_translate?(llm_model)
            llm_model.provider == "mistral"
          end
        end

        def translate
          corrected = super
          corrected.each do |msg|
            msg[:content] = "" if msg[:tool_calls] && msg[:role] == "assistant"
          end
          corrected
        end

        private

        def user_msg(msg)
          mapped = super
          if name = mapped.delete(:name)
            if mapped[:content].is_a?(String)
              mapped[:content] = "#{name}: #{mapped[:content]}"
            else
              mapped[:content].each do |inner|
                if inner[:text]
                  inner[:text] = "#{name}: #{inner[:text]}"
                  break
                end
              end
            end
          end
          mapped
        end
      end
    end
  end
end
