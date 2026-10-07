# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "subdirectory installs" do
    let(:internal_link_hosts) { { "www.example.com" => "/forum" } }
    let(:internal_link_base_prefix) { "/forum" }

    it "detects a subfolder absolute link, stripping the prefix before the route" do
      link, = link_for("[x](https://www.example.com/forum/t/slug/5)")

      expect(link).to include(
        target_type: enums::LinkTarget::TOPIC,
        target_id: 5,
        target_suffix: nil,
      )
    end

    # The prefix is what belongs to the forum, so `/forum` is the front page here.
    it "records the prefix itself as the front page" do
      link, = link_for("https://www.example.com/forum")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: nil)
    end

    # The host's own root is somebody else's app, not the forum, so rewriting its
    # origin would move a link that never pointed at us.
    %w[https://www.example.com https://www.example.com/ https://www.example.com?ref=x].each do |raw|
      it "leaves #{raw} alone, since only the prefix belongs to the forum" do
        expect(extract(raw)).to eq(raw)
        expect(buffer.links).to be_empty
      end
    end

    it "detects a subfolder absolute bare URL in prose" do
      link, = link_for("look https://www.example.com/forum/t/slug/5 now")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
    end

    it "detects a relative link carrying the base prefix" do
      link, = link_for("[x](/forum/t/slug/5)")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
    end

    it "records a route-less path inside the prefix as a SITE link with the rest" do
      link, = link_for("[faq](https://www.example.com/forum/faq)")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: "/faq")
    end

    it "leaves a sibling app's path on the same host literal" do
      raw = "[x](https://www.example.com/other-app/x)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "does not strip the prefix off a host path that only shares its leading text" do
      raw = "[x](https://www.example.com/forumxyz/t/slug/5)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "does not fire the foreign-host signal for a sibling app on a prefixed host" do
      foreign_hosts = []
      signalling =
        described_class.new(
          embeds: buffer,
          markdown_engine:,
          mention_names:,
          hashtag_names:,
          internal_link_hosts: {
            "www.example.com" => "/forum",
          },
          internal_link_base_prefix: "/forum",
          on_foreign_host: ->(host) { foreign_hosts << host },
        )

      signalling.extract("[x](https://www.example.com/other-app/t/slug/5)")

      expect(foreign_hosts).to be_empty
      expect(buffer.links).to be_empty
    end
  end
end
