# frozen_string_literal: true

RSpec.describe IcalEncoder do
  describe ".encode" do
    it "returns empty string for nil" do
      expect(described_class.encode(nil)).to eq("")
    end

    it "returns empty string for blank string" do
      expect(described_class.encode("")).to eq("")
    end

    it "passes through plain text" do
      expect(described_class.encode("Hello World")).to eq("Hello World")
    end

    it "strips HTML tags" do
      expect(described_class.encode("<b>Bold</b> and <i>italic</i>")).to eq("Bold and italic")
    end

    it "decodes HTML entities" do
      expect(described_class.encode("Tom &amp; Jerry")).to eq("Tom & Jerry")
      expect(described_class.encode("1 &lt; 2 &gt; 0")).to eq("1 < 2 > 0")
      expect(described_class.encode("&quot;quoted&quot;")).to eq('"quoted"')
    end

    it "strips HTML tags then decodes entities" do
      expect(
        described_class.encode("&lt;a href=&quot;https://example.com&quot;&gt;link&lt;/a&gt;"),
      ).to eq('<a href="https://example.com">link</a>')
    end

    it "escapes commas" do
      expect(described_class.encode("New York, NY")).to eq("New York\\, NY")
    end

    it "escapes semicolons" do
      expect(described_class.encode("one; two")).to eq("one\\; two")
    end

    it "escapes backslashes" do
      expect(described_class.encode("path\\to\\file")).to eq("path\\\\to\\\\file")
    end

    it "escapes newlines" do
      expect(described_class.encode("line one\nline two")).to eq("line one\\nline two")
      expect(described_class.encode("line one\r\nline two")).to eq("line one\\nline two")
    end

    it "handles complex HTML content from Discourse posts" do
      html =
        '&lt;a class=&quot;lightbox&quot; href=&quot;https://example.com/image.jpg&quot;&gt;[Image]&lt;/a&gt; \nSome text with &amp; special chars'
      result = described_class.encode(html)
      expect(result).not_to include("&lt;")
      expect(result).not_to include("&amp;")
      expect(result).not_to include("&quot;")
      expect(result).to include("& special chars")
    end
  end
end
