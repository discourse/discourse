# frozen_string_literal: true

RSpec.describe EmberAssets do
  describe ".plain_error" do
    subject(:error) { described_class.plain_error("Build failed: <caf\xE9> & \"file\"") }

    it "repairs invalid UTF-8 and escapes the HTML error message" do
      expect(error["messageHtml"]).to eq("Build failed: &lt;café&gt; &amp; &quot;file&quot;")
    end
  end
end

RSpec.describe ERB::Util do
  let(:text) { "<caf\xE9> &amp;" }
  let(:value) { string_wrapper.new(text) }
  let(:string_wrapper) do
    Struct.new(:text) do
      def to_s
        text
      end
    end
  end

  describe ".html_escape" do
    subject(:escaped_text) { described_class.html_escape(value) }

    it "repairs invalid UTF-8 from an object's string before escaping" do
      expect(escaped_text).to eq("&lt;café&gt; &amp;amp;")
    end

    context "with an HTML-safe string" do
      let(:value) { text.html_safe }

      it "preserves the string without repair or escaping" do
        expect(escaped_text).to eq(value)
      end
    end

    context "with an object whose string is HTML-safe" do
      let(:text) { super().html_safe }

      it "preserves the string without repair or escaping" do
        expect(escaped_text).to eq(text)
      end
    end
  end

  describe ".html_escape_once" do
    subject(:escaped_text) { described_class.html_escape_once(value) }

    it "repairs an object's string and preserves existing HTML entities" do
      expect(escaped_text).to eq("&lt;café&gt; &amp;")
    end

    context "with an HTML-safe string" do
      let(:value) { text.html_safe }

      it "repairs and escapes the string while preserving existing HTML entities" do
        expect(escaped_text).to eq("&lt;café&gt; &amp;")
      end
    end
  end
end
