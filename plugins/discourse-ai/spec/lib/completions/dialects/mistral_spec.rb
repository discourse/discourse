# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::Mistral do
  fab!(:model, :mistral_model)
  let(:context) { DialectContext.new(described_class, model) }
  let(:image100x100) { plugin_file_from_fixtures("100x100.jpg") }
  let(:upload100x100) do
    UploadCreator.new(image100x100, "image.jpg").create_for(Discourse.system_user.id)
  end

  before { enable_current_plugin }

  it "does not include user names" do
    prompt =
      DiscourseAi::Completions::Prompt.new(
        messages: [type: :user, content: "Hello, I am Bob", id: "bob"],
      )

    dialect = described_class.new(prompt, model)

    # mistral has no support for name
    expect(dialect.translate).to eq([{ role: "user", content: "bob: Hello, I am Bob" }])
  end

  it "can properly encode images" do
    model.update!(vision_enabled: true)

    prompt =
      DiscourseAi::Completions::Prompt.new(
        "You are image bot",
        messages: [type: :user, id: "user1", content: ["hello", { upload_id: upload100x100.id }]],
      )

    encoded = prompt.encoded_uploads(prompt.messages.last)

    image = "data:image/jpeg;base64,#{encoded[0][:base64]}"

    dialect = described_class.new(prompt, model)

    content = dialect.translate[1][:content]

    expect(content).to eq(
      [{ type: "text", text: "user1: hello" }, { type: "image_url", image_url: { url: image } }],
    )
  end

  it "can properly map tool calls to mistral format" do
    result = [
      {
        role: "system",
        content:
          "I want you to act as a title generator for written pieces. I will provide you with a text,\nand you will generate five attention-grabbing titles. Please keep the title concise and under 20 words,\nand ensure that the meaning is maintained. Replies will utilize the language type of the topic.\n",
      },
      { role: "user", content: "user1: This is a message by a user" },
      { role: "assistant", content: "I'm a previous bot reply, that's why there's no user" },
      { role: "user", content: "user1: This is a new message by a user" },
      {
        role: "assistant",
        content: "",
        tool_calls: [
          {
            type: "function",
            function: {
              arguments: "{\"location\":\"Sydney\",\"unit\":\"c\"}",
              name: "get_weather",
            },
            id: "tool_id",
          },
        ],
      },
      {
        role: "tool",
        tool_call_id: "tool_id",
        content: "\"I'm a tool result\"",
        name: "get_weather",
      },
    ]
    expect(context.multi_turn_scenario).to eq(result)
  end
end
