# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  # What may trail a route without being part of it: the `/` a link generator
  # hangs off the end, and the `.json`/`.rss` extension Rails takes off before
  # it matches. Both stay in the suffix, so the rebuilt URL ends the way the
  # author wrote it.
  describe "internal links with a route tail" do
    let(:internal_link_hosts) { { source_host => nil } }

    it "reads a slug-only topic link that ends in a slash" do
      raw = "https://forum.example.com/t/discourse-tab-bar-for-mobile/"
      link, result = link_for(raw)

      expect(link).to include(
        url: raw,
        target_type: enums::LinkTarget::TOPIC,
        target_id: nil,
        target_name: "discourse-tab-bar-for-mobile",
        target_suffix: "/",
        original_markdown: raw,
        url_offset: 0,
      )
      expect(result).to eq(link[:placeholder])
    end

    it "keeps the slash in front of a slug-only topic link's query" do
      link, = link_for("[x](/t/how-to-fix-it/?page=2)")

      expect(link).to include(target_name: "how-to-fix-it", target_suffix: "/?page=2")
    end

    it "keeps a trailing slash out of the route for a topic with a slug and id" do
      link, = link_for("[x](/t/slug/18978/)")

      expect(link).to include(**{ target_id: 18_978 }, target_suffix: "/")
    end

    it "keeps a trailing slash out of the route for a category by id" do
      link, = link_for("[x](/c/support/6/)")

      expect(link).to include(**{ target_id: 6 }, target_suffix: "/")
    end

    it "keeps a trailing slash out of the route for a category by slug path" do
      link, = link_for("[x](/c/support/billing/)")

      expect(link).to include(**{ target_name: "support:billing" }, target_suffix: "/")
    end

    it "keeps a trailing slash out of the route for a badge" do
      link, = link_for("[x](/badges/9/great/)")

      expect(link).to include(**{ target_id: 9 }, target_suffix: "/")
    end

    it "keeps a trailing slash out of the route for a category+tag route" do
      link, = link_for("[x](/tags/c/food/wine/)")

      expect(link).to include(**{ target_tag_path: "wine" }, target_suffix: "/")
    end

    it "keeps a trailing slash out of the route for a tag intersection" do
      link, = link_for("[x](/tags/intersection/food/wine/)")

      expect(link).to include(**{ target_tag_path: "food/wine" }, target_suffix: "/")
    end

    # A digit run that overflows an id is still the numeric-title ambiguity, so
    # a trailing slash must not turn it into a slug-only link.
    it "still refuses an overlong digit run that ends in a slash" do
      raw = "see https://forum.example.com/t/77777777777777777789999/ there"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
      expect(extractor.engine_refusals).to eq(invalid_internal_route: 1)
    end

    it "reads a `.json` topic link, keeping the format in the suffix" do
      link, = link_for("[x](/t/some-slug/18978.json)")

      expect(link).to include(
        target_type: enums::LinkTarget::TOPIC,
        target_id: 18_978,
        target_suffix: ".json",
      )
    end

    it "reads an `.rss` topic link, keeping the format in the suffix" do
      link, = link_for("[x](/t/some-slug/233865.rss)")

      expect(link).to include(
        target_type: enums::LinkTarget::TOPIC,
        target_id: 233_865,
        target_suffix: ".rss",
      )
    end

    it "reads a `.json` id-only topic link, keeping the format in the suffix" do
      link, = link_for("[x](/t/18978.json)")

      expect(link).to include(
        target_type: enums::LinkTarget::TOPIC,
        target_id: 18_978,
        target_suffix: ".json",
      )
    end

    it "reads a `.json` post link" do
      link, = link_for("[x](/p/55.json)")

      expect(link).to include(
        target_type: enums::LinkTarget::POST,
        target_id: 55,
        target_suffix: ".json",
      )
    end

    # Without the format boundary the id folds into the slug path and the route
    # names a category that never existed.
    it "reads a `.json` category link by its id" do
      link, = link_for("[x](/c/support/6.json)")

      expect(link).to include(
        target_type: enums::LinkTarget::CATEGORY,
        target_id: 6,
        target_name: nil,
        target_suffix: ".json",
      )
    end

    it "reads a format extension after a post number" do
      link, = link_for("[x](/t/some-slug/18978/4.json)")

      expect(link).to include(
        target_type: enums::LinkTarget::POST,
        target_topic_id: 18_978,
        target_post_number: 4,
        target_suffix: ".json",
      )
    end

    it "keeps a query behind the format extension in the suffix" do
      raw = "https://forum.example.com/t/some-slug/18978.json?filter_top_level_replies=true"
      link, result = link_for(raw)

      expect(link).to include(
        url: raw,
        target_type: enums::LinkTarget::TOPIC,
        target_id: 18_978,
        target_suffix: ".json?filter_top_level_replies=true",
        original_markdown: raw,
        url_offset: 0,
      )
      expect(result).to eq(link[:placeholder])
    end

    # Only letters make a format extension, so a dotted number after the id
    # stays the ambiguity it is and refuses.
    it "refuses a dotted number after the topic id" do
      raw = "see https://forum.example.com/t/some-slug/18978.5 there"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
      expect(extractor.engine_refusals).to eq(invalid_internal_route: 1)
    end

    it "still reads the id of a topic whose slug holds a dot" do
      link, = link_for("[x](/t/rails-7.1-upgrade/18978)")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 18_978)
    end
  end

  describe "coordinate-free family pages" do
    let(:internal_link_hosts) { { source_host => nil } }

    it "records a bare family index page as a site link" do
      link, result = link_for("see https://#{source_host}/u/ now")

      expect(link).to include(
        target_type: enums::LinkTarget::SITE,
        url: "https://#{source_host}/u/",
      )
      expect(result).to eq("see #{link[:placeholder]} now")
    end

    it "records a family index page with a query as a site link" do
      link, = link_for("[badges](https://#{source_host}/badges/?_escaped_fragment_=1)")

      expect(link).to include(target_type: enums::LinkTarget::SITE)
    end

    it "keeps an empty slug in front of an id a refusal" do
      raw = "[x](https://#{source_host}/t//209)"

      expect(extract(raw)).to eq(raw)
      expect(extractor.engine_refusals).to eq(invalid_internal_route: 1)
    end

    it "takes a bare trailing dot after the id as an empty format" do
      link, = link_for("[x](https://#{source_host}/t/using-object-storage/148916.)")

      expect(link).to include(
        target_type: enums::LinkTarget::TOPIC,
        target_id: 148_916,
        target_suffix: ".",
      )
    end
  end
end
