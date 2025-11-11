# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::XmlToolProcessor do
  let(:processor) { DiscourseAi::Completions::XmlToolProcessor.new }

  before { enable_current_plugin }

  it "can process simple text" do
    result = []
    result << (processor << "hello")
    result << (processor << " world ")
    expect(result).to eq([["hello"], [" world "]])
    expect(processor.finish).to eq([])
    expect(processor.should_cancel?).to eq(false)
  end

  it "can handle partial tool calls" do
    processor = DiscourseAi::Completions::XmlToolProcessor.new(partial_tool_calls: true)

    xml = (<<~XML).strip
      <function|_calls>
      <invoke>
      <tool_name>h|ell|o<|/tool_name>
      <parameters>
       <hello>wo|r|ld</hello>
      </parameters>
      </invoke>
      <invoke>
      <tool_name>tool|2</tool_name>
      <parameters>
        <param>v|alue</param>
        <para|m2><![CDA|TA[va|lue2]]></param2>
      </parame|ters>
      </invoke>
    XML

    result = []

    xml.split("|").each { |part| result << (processor << part).map(&:dup) }

    result << (processor.finish)
    result.flatten!

    tool1_params =
      result
        .select do |r|
          r.is_a?(DiscourseAi::Completions::ToolCall) && r.name == "hello" && r.partial
        end
        .map(&:parameters)

    expect(tool1_params).to eq([{ hello: "wo" }, { hello: "wor" }, { hello: "world" }])

    tool2_params =
      result
        .select do |r|
          r.is_a?(DiscourseAi::Completions::ToolCall) && r.name == "tool2" && r.partial
        end
        .map(&:parameters)

    expect(tool2_params).to eq(
      [
        { param: "v" },
        { param: "value" },
        { param: "value", param2: "va" },
        { param: "value", param2: "value2" },
      ],
    )
  end

  it "can handle mix and match xml cause tool llms may not encode" do
    xml = (<<~XML).strip
      <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      <parameters>
       <hello>world <sam>sam</sam></hello>
       <test><![CDATA[</h1>\n</div>\n]]></test>
      </parameters>
      </invoke>
    XML

    result = []
    result << (processor << xml)
    result << (processor.finish)

    tool_call = result.last.first
    expect(tool_call.parameters).to eq(hello: "world <sam>sam</sam>", test: "</h1>\n</div>\n")
  end

  it "is usable for simple single message mode" do
    xml = (<<~XML)
       world <function_calls>
      <invoke>
      <tool_name>hello</tool_name>
      <parameters>
       <hello>world</hello>
       <test>value</test>
       <bool>true</bool>
      </parameters>
      </invoke>
    XML

    tool_definition =
      DiscourseAi::Completions::ToolDefinition.from_hash(
        name: "hello",
        description: "hello world",
        parameters: [
          { name: "hello", type: "string", description: "hello" },
          { name: "test", type: "string", description: "test" },
          { name: "bool", type: "boolean", description: "bool" },
        ],
      )

    processor = DiscourseAi::Completions::XmlToolProcessor.new(tool_definitions: [tool_definition])

    result = []
    result << (processor << "hello")
    result << (processor << xml)
    result << (processor.finish)

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "tool_0",
        name: "hello",
        parameters: {
          hello: "world",
          test: "value",
          bool: true,
        },
      )
    expect(result).to eq([["hello"], [" world"], [tool_call]])
    expect(processor.should_cancel?).to eq(false)
  end

  it "handles multiple tool calls in sequence" do
    xml = (<<~XML).strip
      start
      <function_calls>
      <invoke>
      <tool_name>first_tool</tool_name>
      <parameters>
       <param1>value1</param1>
      </parameters>
      </invoke>
      <invoke>
      <tool_name>second_tool</tool_name>
      <parameters>
       <param2>value2</param2>
      </parameters>
      </invoke>
      </function_calls>
      end
    XML

    result = []
    result << (processor << xml)
    result << (processor.finish)

    first_tool =
      DiscourseAi::Completions::ToolCall.new(
        id: "tool_0",
        name: "first_tool",
        parameters: {
          param1: "value1",
        },
      )

    second_tool =
      DiscourseAi::Completions::ToolCall.new(
        id: "tool_1",
        name: "second_tool",
        parameters: {
          param2: "value2",
        },
      )

    expect(result).to eq([["start"], [first_tool, second_tool]])
    expect(processor.should_cancel?).to eq(true)
  end

  it "handles non-English parameters correctly" do
    xml = (<<~XML).strip
      こんにちは
      <function_calls>
      <invoke>
      <tool_name>translator</tool_name>
      <parameters>
       <text>世界</text>
      </parameters>
      </invoke>
    XML

    result = []
    result << (processor << xml)
    result << (processor.finish)

    tool_call =
      DiscourseAi::Completions::ToolCall.new(
        id: "tool_0",
        name: "translator",
        parameters: {
          text: "世界",
        },
      )

    expect(result).to eq([["こんにちは"], [tool_call]])
  end

  it "processes input character by character" do
    xml =
      "hi<function_calls><invoke><tool_name>test</tool_name><parameters><p>v</p></parameters></invoke>"

    result = []
    xml.each_char { |char| result << (processor << char) }
    result << processor.finish

    tool_call =
      DiscourseAi::Completions::ToolCall.new(id: "tool_0", name: "test", parameters: { p: "v" })

    filtered_result = result.reject(&:empty?)
    expect(filtered_result).to eq([["h"], ["i"], [tool_call]])
  end

  it "handles malformed XML gracefully" do
    xml = (<<~XML).strip
      text
      <function_calls>
      <invoke>
      <tool_name>test</tool_name>
      <parameters>
       <param>value
      </parameters>
      </invoke>
      malformed
    XML

    result = []
    result << (processor << xml)
    result << (processor.finish)

    # Should just do its best to parse the XML
    tool_call = DiscourseAi::Completions::ToolCall.new(id: "tool_0", name: "test", parameters: {})
    expect(result).to eq([["text"], [tool_call]])
  end

  it "correctly processes empty parameter sets" do
    xml = (<<~XML).strip
      hello
      <function_calls>
      <invoke>
      <tool_name>no_params</tool_name>
      <parameters>
      </parameters>
      </invoke>
    XML

    result = []
    result << (processor << xml)
    result << (processor.finish)

    tool_call =
      DiscourseAi::Completions::ToolCall.new(id: "tool_0", name: "no_params", parameters: {})

    expect(result).to eq([["hello"], [tool_call]])
  end

  it "properly handles cancelled processing" do
    xml = "start<function_calls></function_calls>"
    result = []
    result << (processor << xml)
    result << (processor << "more text")
    result << processor.finish

    expect(result).to eq([["start"], [], []])
    expect(processor.should_cancel?).to eq(true)
  end
end
