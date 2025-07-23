# frozen_string_literal: true
CompletionPrompt.seed do |cp|
  cp.id = -301
  cp.name = "translate"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.stop_sequences = ["\n</output>", "</output>"]
  cp.temperature = 0.2
  cp.messages = {
    insts: <<~TEXT,
      I want you to act as an %LANGUAGE% translator, spelling corrector and improver. I will write to you
      in any language and you will detect the language, translate it and answer in the corrected and
      improved version of my text, in %LANGUAGE%. I want you to replace my simplified A0-level words and
      sentences with more beautiful and elegant, upper level %LANGUAGE% words and sentences.
      Keep the meaning same, but make them more literary. I want you to only reply the correction,
      the improvements and nothing else, do not write explanations.
      You will find the text between <input></input> XML tags.
      Include your translation between <output></output> XML tags.
    TEXT
    examples: [["<input>Hello</input>", "<output>...%LANGUAGE% translation...</output>"]],
  }
end

CompletionPrompt.seed do |cp|
  cp.id = -303
  cp.name = "proofread"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.temperature = 0
  cp.stop_sequences = ["\n</output>"]
  cp.messages = {
    insts: <<~TEXT,
      You are a markdown proofreader. You correct egregious typos and phrasing issues but keep the user's original voice.
      You do not touch code blocks. I will provide you with text to proofread. If nothing needs fixing, then you will echo the text back.
      You will find the text between <input></input> XML tags.
      You will ALWAYS return the corrected text between <output></output> XML tags.
    TEXT
    examples: [
      [
        "<input>![amazing car|100x100, 22%](upload://hapy.png)</input>",
        "<output>![Amazing car|100x100, 22%](upload://hapy.png)</output>",
      ],
      [<<~TEXT, "The rain in Spain, stays mainly in the Plane."],
        <input>
          The rain in spain stays mainly in the plane.
        </input>
       TEXT
      [
        "<input>The rain in Spain, stays mainly in the Plane.</input>",
        "<output>The rain in Spain, stays mainly in the Plane.</output>",
      ],
      [<<~TEXT, <<~TEXT],
        <input>
          Hello,

          Sometimes the logo isn't changing automatically when color scheme changes.

          ![Screen Recording 2023-03-17 at 18.04.22|video](upload://2rcVL0ZMxHPNtPWQbZjwufKpWVU.mov)
        </input>
      TEXT
        <output>
        Hello,
        Sometimes the logo does not change automatically when the color scheme changes.
        ![Screen Recording 2023-03-17 at 18.04.22|video](upload://2rcVL0ZMxHPNtPWQbZjwufKpWVU.mov)
        </output>
      TEXT
      [<<~TEXT, <<~TEXT],
        <input>
          Any ideas what is wrong with this peace of cod?
          > This quot contains a typo
          ```ruby
          # this has speling mistakes
          testin.atypo = 11
          baad = "bad"
          ```
        </input>
      TEXT
        <output>
        Any ideas what is wrong with this piece of code?
        > This quot contains a typo
        ```ruby
        # This has spelling mistakes
        testing.a_typo = 11
        bad = "bad"
        ```
        </output>
    TEXT
    ],
  }
end

CompletionPrompt.seed do |cp|
  cp.id = -304
  cp.name = "markdown_table"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.temperature = 0.5
  cp.stop_sequences = ["\n</output>"]
  cp.messages = {
    insts: <<~TEXT,
    You are a markdown table formatter, I will provide you text inside <input></input> XML tags and you will format it into a markdown table
    TEXT
    examples: [
      ["<input>sam,joe,jane\nage: 22|  10|11</input>", <<~TEXT],
      <output>
      |   | sam | joe | jane |
      |---|---|---|---|
      | age | 22 | 10 | 11 |
      </output>
      TEXT
      [<<~TEXT, <<~TEXT],
        <input>
        sam: speed 100, age 22
        jane: age 10
        fred: height 22
        </input>
      TEXT
      <output>
      |   | speed | age | height |
      |---|---|---|---|
      | sam | 100 | 22 | - |
      | jane | - | 10 | - |
      | fred | - | - | 22 |
      </output>
      TEXT
      [<<~TEXT, <<~TEXT],
        <input>
        chrome 22ms (first load 10ms)
        firefox 10ms (first load: 9ms)
        </input>
      TEXT
      <output>
      | Browser | Load Time (ms) | First Load Time (ms) |
      |---|---|---|
      | Chrome | 22 | 10 |
      | Firefox | 10 | 9 |
      </output>
      TEXT
    ],
  }
end

CompletionPrompt.seed do |cp|
  cp.id = -305
  cp.name = "custom_prompt"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.messages = { insts: <<~TEXT }
    You are a helpful assistant. I will give you instructions inside <input></input> XML tags.
    You will look at them and reply with a result.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -306
  cp.name = "explain"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = { insts: <<~TEXT }
    You are a tutor explaining a term to a student in a specific context.

    I will provide everything you need to know inside <input> tags, which consists of the term I want you
    to explain inside <term> tags, the context of where it was used inside <context> tags, the title of
    the topic where it was used inside <topic> tags, and optionally, the previous post in the conversation
    in <replyTo> tags.

    Using all this information, write a paragraph with a brief explanation
    of what the term means. Format the response using Markdown. Reply only with the explanation and
    nothing more.
  TEXT
end

CompletionPrompt.seed do |cp|
  cp.id = -307
  cp.name = "generate_titles"
  cp.prompt_type = CompletionPrompt.prompt_types[:list]
  cp.messages = {
    insts: <<~TEXT,
      I want you to act as a title generator for written pieces. I will provide you with a text,
      and you will generate five titles. Please keep the title concise and under 20 words,
      and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
      I want you to only reply the list of options and nothing else, do not write explanations.
      Never ever use colons in the title. Always use sentence case, using a capital letter at
      the start of the title, never start the title with a lower case letter. Proper nouns in the title
      can have a capital letter, and acronyms like LLM can use capital letters. Format some titles
      as questions, some as statements. Make sure to use question marks if the title is a question.
      Each title you generate must be separated by *
      You will find the text between <input></input> XML tags.
    TEXT
    examples: [
      [
        "<input>In the labyrinth of time, a solitary horse, etched in gold by the setting sun, embarked on an infinite journey.</input>",
        "<item>The solitary horse</item><item>The horse etched in gold</item><item>A horse's infinite journey</item><item>A horse lost in time</item><item>A horse's last ride</item>",
      ],
    ],
    post_insts: "Wrap each title between <item></item> XML tags.",
  }
end

CompletionPrompt.seed do |cp|
  cp.id = -308
  cp.name = "illustrate_post"
  cp.prompt_type = CompletionPrompt.prompt_types[:list]
  cp.messages = {}
end

CompletionPrompt.seed do |cp|
  cp.id = -309
  cp.name = "detect_text_locale"
  cp.prompt_type = CompletionPrompt.prompt_types[:text]
  cp.messages = {
    insts: <<~TEXT,
      I want you to act as a language expert, determining the locale for a set of text.
      The locale is a language identifier, such as "en" for English, "de" for German, etc,
      and can also include a region identifier, such as "en-GB" for British English, or "zh-Hans" for Simplified Chinese.
      I will provide you with text, and you will determine the locale of the text.
      You will find the text between <input></input> XML tags.
      Include your locale between <output></output> XML tags.
    TEXT
    examples: [["<input>Hello my favourite colour is red</input>", "<output>en-GB</output>"]],
  }
end

CompletionPrompt.seed do |cp|
  cp.id = -310
  cp.name = "replace_dates"
  cp.prompt_type = CompletionPrompt.prompt_types[:diff]
  cp.temperature = 0
  cp.stop_sequences = ["\n</output>"]
  cp.messages = {
    insts: <<~TEXT,
      You are a date and time formatter for Discourse posts. Convert natural language time references into date placeholders.
      Do not modify any markdown, code blocks, or existing date formats.

      Here's the temporal context:
      {{temporal_context}}

      Available date placeholder formats:
      - Simple day without time: {{date:1}} for tomorrow, {{date:7}} for a week from today
      - Specific time: {{datetime:2pm+1}} for 2 PM tomorrow
      - Time range: {{datetime:2pm+1:4pm+1}} for tomorrow 2 PM to 4 PM

      You will find the text between <input></input> XML tags.
      Return the text with dates converted between <output></output> XML tags.
    TEXT
    examples: [
      [
        "<input>The meeting is at 2pm tomorrow</input>",
        "<output>The meeting is at {{datetime:2pm+1}}</output>",
      ],
      ["<input>Due in 3 days</input>", "<output>Due {{date:3}}</output>"],
      [
        "<input>Meeting next Tuesday at 2pm</input>",
        "<output>Meeting {{next_week:tuesday-2pm}}</output>",
      ],
      [
        "<input>Meeting from 2pm to 4pm tomorrow</input>",
        "<output>Meeting {{datetime:2pm+1:4pm+1}}</output>",
      ],
      [
        "<input>Meeting notes for tomorrow:
* Action items in `config.rb`
* Review PR #1234
* Deadline is 5pm
* Check [this link](https://example.com)</input>",
        "<output>Meeting notes for {{date:1}}:
* Action items in `config.rb`
* Review PR #1234
* Deadline is {{datetime:5pm+1}}
* Check [this link](https://example.com)</output>",
      ],
    ],
  }
end
