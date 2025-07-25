# frozen_string_literal: true

describe DiscourseAi::Translation::ContentSplitter do
  before { enable_current_plugin }

  it "returns empty array for empty input" do
    expect(described_class.split(content: "")).to eq([""])
  end

  it "handles content with only spaces" do
    expect(described_class.split(content: " ")).to eq([" "])
    expect(described_class.split(content: "  ")).to eq(["  "])
  end

  it "handles nil input" do
    expect(described_class.split(content: nil)).to eq([])
  end

  it "doesn't split content under limit" do
    content = "hello world"
    expect(described_class.split(content:, chunk_size: 20)).to eq([content])
  end

  it "splits to max chunk size if unsplittable" do
    content = "a" * 100
    expect(described_class.split(content:, chunk_size: 10)).to eq(["a" * 10] * 10)
  end

  it "preserves HTML tags" do
    content = "<p>hello</p><p>meow</p>"
    expect(described_class.split(content:, chunk_size: 15)).to eq(%w[<p>hello</p> <p>meow</p>])

    content = "<div>hello</div> <div>jurassic</div> <p>world</p>"
    expect(described_class.split(content:, chunk_size: 40)).to eq(
      ["<div>hello</div> <div>jurassic</div> ", "<p>world</p>"],
    )
  end

  it "preserves BBCode tags" do
    content = "[quote]hello[/quote][details]world[/details]"
    expect(described_class.split(content:, chunk_size: 25)).to eq(
      ["[quote]hello[/quote]", "[details]world[/details]"],
    )
  end

  it "doesn't split in middle of words" do
    content = "my kitty best in the world"
    expect(described_class.split(content:, chunk_size: 10)).to eq(
      ["my kitty ", "best in ", "the world"],
    )
  end

  it "handles nested tags properly" do
    content = "<div>hello<p>cat</p>world</div><p>meow</p>"
    expect(described_class.split(content:, chunk_size: 35)).to eq(
      %w[<div>hello<p>cat</p>world</div> <p>meow</p>],
    )
  end

  it "handles mixed HTML and BBCode" do
    content = "<div>hello</div>[quote]world[/quote]<p>beautiful</p>"
    expect(described_class.split(content:, chunk_size: 20)).to eq(
      ["<div>hello</div>", "[quote]world[/quote]", "<p>beautiful</p>"],
    )
  end

  it "preserves newlines in sensible places" do
    content = "hello\nbeautiful\nworld\n"
    expect(described_class.split(content:, chunk_size: 10)).to eq(
      ["hello\n", "beautiful\n", "world\n"],
    )
  end

  it "handles email content properly" do
    content = "From: test@test.com\nTo: other@test.com\nSubject: Hello\n\nContent here"
    expect(described_class.split(content:, chunk_size: 20)).to eq(
      ["From: test@test.com\n", "To: other@test.com\n", "Subject: Hello\n\n", "Content here"],
    )
  end

  it "keeps code blocks intact" do
    content = "Text\n```\ncode block\nhere\n```\nmore text"
    expect(described_class.split(content:, chunk_size: 30)).to eq(
      ["Text\n```\ncode block\nhere\n```\n", "more text"],
    )
  end

  context "with multiple details tags" do
    it "splits correctly between details tags" do
      content = "<details>first content</details><details>second content</details>"
      expect(described_class.split(content:, chunk_size: 35)).to eq(
        ["<details>first content</details>", "<details>second content</details>"],
      )
    end
  end
end
