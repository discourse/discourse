# frozen_string_literal: true

module DiscourseAi
  module Personas
    class SmartDates < Persona
      def self.default_enabled
        false
      end

      def system_prompt
        <<~PROMPT.strip
          You are a date and time formatter for Discourse posts. Convert natural language time references into date placeholders.
          Do not modify any markdown, code blocks, or existing date formats.
    
          Here's the temporal context:
          {temporal_context}
    
          Available date placeholder formats:
          - Simple day without time: {{date:1}} for tomorrow, {{date:7}} for a week from today
          - Specific time: {{datetime:2pm+1}} for 2 PM tomorrow
          - Time range: {{datetime:2pm+1:4pm+1}} for tomorrow 2 PM to 4 PM
    
          You will find the text between <input></input> XML tags.

          Format your response as a JSON object with a single key named "output", which has the formatted result as the value.
          Your output should be in the following format:

          {"output": "xx"}

          Where "xx" is replaced by the formatted result.
          reply with valid JSON only
        PROMPT
      end

      def response_format
        [{ "key" => "output", "type" => "string" }]
      end

      def examples
        [
          [
            "<input>The meeting is at 2pm tomorrow</input>",
            { output: "The meeting is at {{datetime:2pm+1}}" }.to_json,
          ],
          ["<input>Due in 3 days</input>", { output: "Due {{date:3}}" }.to_json],
          [
            "<input>Meeting next Tuesday at 2pm</input>",
            { output: "Meeting {{next_week:tuesday-2pm}}" }.to_json,
          ],
          [
            "<input>Meeting from 2pm to 4pm tomorrow</input>",
            { output: "Meeting {{datetime:2pm+1:4pm+1}}" }.to_json,
          ],
          [<<~TEXT, { output: <<~TEXT }.to_json],
            <input>Meeting notes for tomorrow:
            * Action items in `config.rb`
            * Review PR #1234
            * Deadline is 5pm
            * Check [this link](https://example.com)</input>
            TEXT
            Meeting notes for {{date:1}}:
            * Action items in `config.rb`
            * Review PR #1234
            * Deadline is {{datetime:5pm+1}}
            * Check [this link](https://example.com)
            TEXT
        ]
      end
    end
  end
end
