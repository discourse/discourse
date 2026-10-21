# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  # With `unicode_usernames` on, a username, group name or tag name holds
  # characters a URL has to percent-encode. Email notifications write the link
  # that way, and the engine's normalized href is encoded even where the author
  # typed the name literally — so the route grammar has to read the encoded
  # spelling and hand the importer the decoded name it stores.
  describe "internal links with percent-encoded names" do
    let(:internal_link_hosts) { { source_host => nil } }

    it "decodes a user name while keeping the URL's own spelling" do
      raw = "https://forum.example.com/u/dawid_gawe%C5%82"
      link, result = link_for(raw)

      expect(link).to include(
        url: raw,
        target_type: enums::LinkTarget::USER,
        target_id: nil,
        target_name: "dawid_gaweł",
        target_suffix: nil,
        original_markdown: raw,
        url_offset: 0,
      )
      expect(result).to eq(link[:placeholder])
    end

    it "decodes a name written entirely in encoded bytes" do
      link, result = link_for("[x](/u/%EC%9C%A0%EC%86%8C%ED%98%84)")

      expect(link).to include(
        url: "/u/%EC%9C%A0%EC%86%8C%ED%98%84",
        target_type: enums::LinkTarget::USER,
        target_name: "유소현",
        url_offset: 4,
      )
      expect(result).to eq(link[:placeholder])
    end

    it "decodes an encoded byte in the middle of a `/users/` name" do
      link, = link_for("[x](/users/hasan_%C3%B6zdemir/summary)")

      expect(link).to include(target_name: "hasan_özdemir", target_suffix: "/summary")
    end

    it "reads lowercase hex the same way" do
      link, = link_for("[x](/u/dawid_gawe%c5%82)")

      expect(link).to include(target_name: "dawid_gaweł")
    end

    # The two spellings have to reach the importer as the same name, or the
    # encoded one resolves against nothing.
    it "records the same name for the encoded and the literal spelling" do
      encoded, = link_for("[x](/u/hasan_%C3%B6zdemir)")
      buffer.clear
      literal, = link_for("[x](/u/hasan_özdemir)")

      expect(encoded[:target_name]).to eq(literal[:target_name])
    end

    it "keeps a query string out of a decoded name" do
      link, = link_for("[x](/u/dawid_gawe%C5%82?u=x)")

      expect(link).to include(target_name: "dawid_gaweł", target_suffix: "?u=x")
    end

    it "keeps a fragment out of a decoded name" do
      link, = link_for("[x](/u/dawid_gawe%C5%82#bio)")

      expect(link).to include(target_name: "dawid_gaweł", target_suffix: "#bio")
    end

    it "decodes a group name" do
      link, = link_for("[x](/g/te%C3%A4m/members)")

      expect(link).to include(
        target_type: enums::LinkTarget::GROUP,
        target_name: "teäm",
        target_suffix: "/members",
      )
    end

    it "decodes a tag name" do
      link, = link_for("[x](/tag/%C3%A9tude)")

      expect(link).to include(target_type: enums::LinkTarget::TAG, target_name: "étude")
    end

    it "decodes the tag of a category+tag route" do
      link, = link_for("[x](/tags/c/plugin/22/offi%C3%A7ial)")

      expect(link).to include(
        target_type: enums::LinkTarget::CATEGORY_TAG,
        target_id: 22,
        target_tag_path: "offiçial",
      )
    end

    it "decodes every tag of an intersection route" do
      link, = link_for("[x](/tags/intersection/f%C3%B6od/wine)")

      expect(link).to include(
        target_type: enums::LinkTarget::TAG_INTERSECTION,
        target_tag_path: "föod/wine",
      )
    end

    # Core writes an encoded-method slug into the column percent-encoded, so a
    # slug is compared the way it arrives; decoding it would miss the row.
    it "leaves a category slug path encoded" do
      link, = link_for("[x](/c/caf%C3%A9/billing)")

      expect(link).to include(
        target_type: enums::LinkTarget::CATEGORY,
        target_id: nil,
        target_name: "caf%C3%A9:billing",
      )
    end

    it "leaves a topic slug encoded" do
      link, = link_for("[x](/t/caf%C3%A9-time)")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_name: "caf%C3%A9-time")
    end

    # Bytes that decode to no valid UTF-8 name no record, and a `%2F` would
    # invent path structure the author never wrote — both refuse rather than
    # rewrite a coordinate-shaped path onto the destination.
    {
      "invalid UTF-8 bytes" => "/u/%FF%FE",
      "an encoded slash" => "/u/a%2Fb",
      "an encoded newline" => "/g/te%0Aam",
    }.each do |label, path|
      it "refuses a name holding #{label}" do
        raw = "see https://forum.example.com#{path} there"

        expect(extract(raw)).to eq(raw)
        expect(buffer.links).to be_empty
        expect(extractor.engine_refusals).to eq(invalid_internal_route: 1)
      end
    end

    it "still refuses a name holding a character no route grammar admits" do
      raw = "[x](/u/bob!!!)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end
  end
end
