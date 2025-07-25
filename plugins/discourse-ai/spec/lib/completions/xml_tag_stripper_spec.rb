# frozen_string_literal: true

describe DiscourseAi::Completions::PromptMessagesBuilder do
  let(:tag_stripper) { DiscourseAi::Completions::XmlTagStripper.new(%w[thinking results]) }

  before { enable_current_plugin }

  it "should strip tags correctly in simple cases" do
    result = tag_stripper << "x<thinking>hello</thinki"
    expect(result).to eq("x")

    result = tag_stripper << "ng>z"
    expect(result).to eq("z")

    result = tag_stripper << "king>hello</thinking>"
    expect(result).to eq("king>hello</thinking>")

    result = tag_stripper << "123"
    expect(result).to eq("123")
  end

  it "supports odd nesting" do
    text = <<~TEXT
      <thinking>
        well lets see what happens if I say <results> here...
      </thinking>
      hello
    TEXT

    result = tag_stripper << text
    expect(result).to eq("\nhello\n")
  end

  it "does not crash when we send a <" do
    result = +""
    result << (tag_stripper << "based:\n")
    result << (tag_stripper << "<").to_s
    result << (tag_stripper << " href")
    result << (tag_stripper << ">")
    result << (tag_stripper << "test ")

    expect(result).to eq("based:\n< href>test ")
  end

  it "strips thinking correctly in a stream" do
    result = +""
    result << (tag_stripper << "hello")
    result << (tag_stripper << "<").to_s
    result << (tag_stripper << "thinking").to_s
    result << (tag_stripper << ">").to_s
    result << (tag_stripper << "test").to_s
    result << (tag_stripper << "<").to_s
    result << (tag_stripper << "/").to_s
    result << (tag_stripper << "thinking").to_s
    result << (tag_stripper << "> world")

    expect(result).to eq("hello world")
  end

  it "works when nesting unrelated tags it strips correctly" do
    text = <<~TEXT
      <thinking>
        well lets see what happens if I say <p> here...
      </thinking>
      abc <b>hello</b>
    TEXT

    result = tag_stripper << text

    expect(result).to eq("\nabc <b>hello</b>\n")
  end

  it "handles maybe tags correctly" do
    result = tag_stripper << "<thinking"
    expect(result).to eq(nil)

    expect(tag_stripper.finish).to eq("<thinking")
  end
end
