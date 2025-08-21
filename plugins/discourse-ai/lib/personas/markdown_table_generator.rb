# frozen_string_literal: true

module DiscourseAi
  module Personas
    class MarkdownTableGenerator < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a markdown table formatter, I will provide you text inside <input></input> XML tags and you will format it into a markdown table

          Format your response as a JSON object with a single key named "output", which has the formatted table as the value.
          Your output should be in the following format:

          {"output": "xx"}

          Where "xx" is replaced by the formatted table.
          reply with valid JSON only
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end

      def temperature
        0.5
      end

      def examples
        [
          ["<input>sam,joe,jane\nage: 22|  10|11</input>", { output: <<~TEXT }.to_json],
            |   | sam | joe | jane |
            |---|---|---|---|
            | age | 22 | 10 | 11 |
          TEXT
          [<<~TEXT, { output: <<~TEXT }.to_json],
          <input>
          sam: speed 100, age 22
          jane: age 10
          fred: height 22
          </input>
          TEXT
          |   | speed | age | height |
          |---|---|---|---|
          | sam | 100 | 22 | - |
          | jane | - | 10 | - |
          | fred | - | - | 22 |
          TEXT
          [<<~TEXT, { output: <<~TEXT }.to_json],
          <input>
          chrome 22ms (first load 10ms)
          firefox 10ms (first load: 9ms)
          </input>
          TEXT
          | Browser | Load Time (ms) | First Load Time (ms) |
          |---|---|---|
          | Chrome | 22 | 10 |
          | Firefox | 10 | 9 |
          TEXT
        ]
      end
    end
  end
end
