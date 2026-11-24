# frozen_string_literal: true

RSpec.describe DiscourseChatIntegration::Provider::SlackProvider::SlackMessageFormatter do
  describe ".format" do
    context "with links" do
      it "returns the expected message" do
        expect(described_class.format("<a href='http://somepath.com'>test</a>")).to eq(
          "<http://somepath.com|test>",
        )
      end

      describe "when text contains a link with an incomplete URL" do
        it "returns the expected message" do
          expect(described_class.format("test <a href='//localhost:3000/some/path'></a>")).to eq(
            "test <http://localhost:3000/some/path|>",
          )

          SiteSetting.force_https = true

          expect(described_class.format("test <a href='//localhost:3000/some/path'></a>")).to eq(
            "test <https://localhost:3000/some/path|>",
          )
        end
      end

      it "does not raise an error for unparseable URLs" do
        expect(described_class.format("<a>test</a>")).to eq("<test.localhost|test>")
      end
    end

    context "with text typed by a user" do
      it "keeps characters that Slack reserves for its control sequences as entities" do
        expect(
          described_class.format(
            "<p>&lt;!channel&gt; &amp; &lt;#C123|general&gt; 1 &lt; 2 &gt; 0</p>",
          ),
        ).to eq("&lt;!channel&gt; &amp; &lt;#C123|general&gt; 1 &lt; 2 &gt; 0")
      end

      it "escapes link labels" do
        expect(
          described_class.format("<a href='http://somepath.com'>plan&gt;now&lt;!channel&gt;</a>"),
        ).to eq("<http://somepath.com|plan&gt;now&lt;!channel&gt;>")
      end
    end
  end
end
