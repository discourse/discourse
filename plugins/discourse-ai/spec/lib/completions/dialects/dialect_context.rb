# frozen_string_literal: true

class DialectContext
  def initialize(dialect_klass, llm_model)
    @dialect_klass = dialect_klass
    @llm_model = llm_model
  end

  def dialect(prompt)
    @dialect_klass.new(prompt, @llm_model)
  end

  def prompt
    DiscourseAi::Completions::Prompt.new(system_insts, tools: tools)
  end

  def dialect_tools
    dialect(prompt).tools
  end

  def system_user_scenario
    a_prompt = prompt
    a_prompt.push(type: :user, content: simple_user_input)

    dialect(a_prompt).translate
  end

  def image_generation_scenario
    context_and_multi_turn = [
      { type: :user, id: "user1", content: "draw a cat" },
      {
        type: :tool_call,
        id: "tool_id",
        content: { name: "draw", arguments: { picture: "Cat" } }.to_json,
      },
      { type: :tool, id: "tool_id", content: "I'm a tool result".to_json },
      { type: :user, id: "user1", content: "draw another cat" },
    ]

    a_prompt = prompt
    context_and_multi_turn.each { |msg| a_prompt.push(**msg) }

    dialect(a_prompt).translate
  end

  def multi_turn_scenario
    context_and_multi_turn = [
      { type: :user, id: "user1", content: "This is a message by a user" },
      { type: :model, content: "I'm a previous bot reply, that's why there's no user" },
      { type: :user, id: "user1", content: "This is a new message by a user" },
      {
        type: :tool_call,
        id: "tool_id",
        name: "get_weather",
        content: { arguments: { location: "Sydney", unit: "c" } }.to_json,
      },
      { type: :tool, id: "tool_id", name: "get_weather", content: "I'm a tool result".to_json },
    ]

    a_prompt = prompt
    context_and_multi_turn.each { |msg| a_prompt.push(**msg) }

    dialect(a_prompt).translate
  end

  def long_user_input_scenario(length: 1_000)
    long_message = long_message_text(length: length)
    a_prompt = prompt
    a_prompt.push(type: :user, content: long_message, id: "user1")

    dialect(a_prompt).translate
  end

  def long_message_text(length: 1_000)
    "This a message by a user" * length
  end

  def simple_user_input
    <<~TEXT
      Here is the text, inside <input></input> XML tags:
      <input>
        To perfect his horror, Caesar, surrounded at the base of the statue by the impatient daggers of his friends,
        discovers among the faces and blades that of Marcus Brutus, his protege, perhaps his son, and he no longer
        defends himself, but instead exclaims: 'You too, my son!' Shakespeare and Quevedo capture the pathetic cry.

        Destiny favors repetitions, variants, symmetries; nineteen centuries later, in the southern province of Buenos Aires,
        a gaucho is attacked by other gauchos and, as he falls, recognizes a godson of his and says with gentle rebuke and
        slow surprise (these words must be heard, not read): 'But, my friend!' He is killed and does not know that he
        dies so that a scene may be repeated.
      </input>
      TEXT
  end

  def system_insts
    <<~TEXT
    I want you to act as a title generator for written pieces. I will provide you with a text,
    and you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,
    and ensure that the meaning is maintained. Replies will utilize the language type of the topic.
    TEXT
  end

  def tools
    [
      {
        name: "get_weather",
        description: "Get the weather in a city",
        parameters: [
          { name: "location", type: "string", description: "the city name", required: true },
          {
            name: "unit",
            type: "string",
            description: "the unit of measurement celcius c or fahrenheit f",
            enum: %w[c f],
            required: true,
          },
        ],
      },
    ].map { |tool| DiscourseAi::Completions::ToolDefinition.from_hash(tool) }
  end
end
