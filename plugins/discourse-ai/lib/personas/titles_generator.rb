# frozen_string_literal: true

module DiscourseAi
  module Personas
    class TitlesGenerator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          I want you to act as a title generator for written pieces. I will provide you with a text,
          and you will generate five titles. Please keep the title concise and under 20 words,
          and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
          I want you to only reply the list of options and nothing else, do not write explanations.
          Never ever use colons in the title. Always use sentence case, using a capital letter at
          the start of the title, never start the title with a lower case letter. Proper nouns in the title
          can have a capital letter, and acronyms like LLM can use capital letters. Format some titles
          as questions, some as statements. Make sure to use question marks if the title is a question.
          You will find the text between <input></input> XML tags.

          The title suggestions should be returned in a JSON array, under the `output` key, like this:

          {
            "output": [
              "suggeested title #1",
              "suggeested title #2",
              "suggeested title #3",
              "suggeested title #4",
              "suggeested title #5"
            ]
          }

          Return only the JSON
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "array", "array_type" => "string" }]
      end

      def examples
        [
          [
            "<input>In the labyrinth of time, a solitary horse, etched in gold by the setting sun, embarked on an infinite journey.</input>",
            <<~OUTPUT,
            {
              "output": [
                "The solitary horse",
                "The horse etched in gold",
                "A horse's infinite journey",
                "A horse lost in time",
                "A horse's last rid"
              ]
            }
            OUTPUT
          ],
        ]
      end
    end
  end
end
