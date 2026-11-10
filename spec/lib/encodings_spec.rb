# frozen_string_literal: true

RSpec.describe Encodings do
  it "strips a leading BOM" do
    expect(Encodings.delete_bom!(+"#{Encodings::BOM}hello")).to eq("hello")
  end

  it "replaces invalid bytes" do
    expect(Encodings.force_utf8("caf\xFFe")).to eq("cafe")
  end

  describe ".charset_from_content_type" do
    it "returns the lowercase charset from the header" do
      expect(Encodings.charset_from_content_type("text/html; charset=UTF-8")).to eq("utf-8")
    end

    it "returns the charset when quoted" do
      expect(Encodings.charset_from_content_type('text/html; charset="utf-8"')).to eq("utf-8")
    end

    it "returns the charset when no space precedes it" do
      expect(Encodings.charset_from_content_type("text/html;charset=euc-jp")).to eq("euc-jp")
    end

    it "returns the charset when whitespace surrounds the equals sign" do
      expect(Encodings.charset_from_content_type("text/html; charset = Shift_JIS")).to eq(
        "shift_jis",
      )
    end

    it "returns nil when no charset is declared" do
      expect(Encodings.charset_from_content_type("text/html")).to be_nil
    end

    it "returns nil when the charset is unsupported" do
      expect(Encodings.charset_from_content_type("text/html; charset=not-an-encoding")).to be_nil
    end

    it "returns nil for dummy encodings without a UTF-8 converter" do
      expect(Encodings.charset_from_content_type("text/html; charset=UTF-7")).to be_nil
      expect(Encodings.charset_from_content_type("text/html; charset=UTF-16")).to be_nil
    end

    it "returns nil when the header is blank" do
      expect(Encodings.charset_from_content_type(nil)).to be_nil
      expect(Encodings.charset_from_content_type("")).to be_nil
    end
  end

  describe ".charset_from_document" do
    it "reads the charset from a meta tag" do
      html = "<html><head><meta charset=\"UTF-8\"><title>x</title></head><body></body></html>"
      expect(Encodings.charset_from_document(html)).to eq("utf-8")
    end

    it "reads the charset from the content attribute" do
      html =
        '<html><head><meta http-equiv="Content-Type" content="text/html; charset=windows-1252"></head></html>'
      expect(Encodings.charset_from_document(html)).to eq("windows-1252")
    end

    it "ignores meta tags beyond the sniffing window" do
      html = +"<html><head>#{"x" * 1024}<meta charset='utf-8'></head></html>"
      expect(Encodings.charset_from_document(html)).to be_nil
    end

    it "returns nil when the document declares no charset" do
      expect(
        Encodings.charset_from_document("<html><head><title>x</title></head></html>"),
      ).to be_nil
    end
  end

  describe ".valid_utf8?" do
    it "returns true for UTF-8 bytes" do
      expect(Encodings.valid_utf8?("Iran’s".b)).to eq(true)
    end

    it "returns false for single-byte bytes" do
      expect(Encodings.valid_utf8?("caf\xE9".b)).to eq(false)
    end

    it "does not mutate the input string's encoding" do
      string = "Iran’s".dup.force_encoding(Encoding::Windows_1252)
      Encodings.valid_utf8?(string)
      expect(string.encoding).to eq(Encoding::Windows_1252)
    end
  end

  describe ".unicode_encoding?" do
    it "returns true for Unicode charsets" do
      expect(Encodings.unicode_encoding?("utf-8")).to eq(true)
    end

    it "returns false for single-byte charsets" do
      expect(Encodings.unicode_encoding?("windows-1252")).to eq(false)
      expect(Encodings.unicode_encoding?("iso-8859-1")).to eq(false)
    end
  end
end
