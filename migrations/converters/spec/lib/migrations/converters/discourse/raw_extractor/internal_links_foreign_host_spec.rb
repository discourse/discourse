# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "foreign-host internal-link signal" do
    subject(:extractor) do
      described_class.new(
        embeds: buffer,
        mention_names:,
        hashtag_names:,
        internal_link_hosts: {
          "forum.example.com" => nil,
        },
        on_foreign_host: ->(host) { foreign_hosts << host },
      )
    end

    let(:foreign_hosts) { [] }

    it "fires the callback for an absolute route-shaped link on an unconfigured host" do
      extract("elsewhere https://old-forum.example.com/t/slug/99 done")

      expect(foreign_hosts).to eq(["old-forum.example.com"])
      expect(buffer.links).to be_empty
    end

    it "fires for a foreign-host markdown link too" do
      extract("[a topic](https://old-forum.example.com/t/slug/99)")

      expect(foreign_hosts).to eq(["old-forum.example.com"])
    end

    it "reports a non-default port as part of the host" do
      extract("https://old-forum.example.com:8080/t/slug/99")

      expect(foreign_hosts).to eq(["old-forum.example.com:8080"])
    end

    it "reports each host once, however often it appears" do
      extract("https://old-forum.example.com/t/slug/99")
      extract("https://old-forum.example.com/t/other/100")

      expect(foreign_hosts).to eq(["old-forum.example.com"])
    end

    it "does not fire for a foreign host whose path is not an internal route" do
      extract("see https://old-forum.example.com/about/team here")

      expect(foreign_hosts).to be_empty
    end

    it "does not fire for a configured host" do
      extract("read https://forum.example.com/t/slug/99 now")

      expect(foreign_hosts).to be_empty
    end

    it "does not fire for a relative link" do
      extract("go to /t/slug/99")

      expect(foreign_hosts).to be_empty
    end

    it "treats every absolute route-shaped link as foreign when no host is configured" do
      no_host =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          on_foreign_host: ->(host) { foreign_hosts << host },
        )
      no_host.extract("read https://any.example.com/t/slug/99 now")

      expect(foreign_hosts).to eq(["any.example.com"])
    end

    it "is a no-op when no callback is given" do
      plain =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          internal_link_hosts: {
            "forum.example.com" => nil,
          },
        )

      expect(plain.extract("elsewhere https://old-forum.example.com/t/slug/99 done")).to eq(
        "elsewhere https://old-forum.example.com/t/slug/99 done",
      )
    end
  end
end
