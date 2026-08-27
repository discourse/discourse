# frozen_string_literal: true

# The acceptance test for the self-contained engine context: the same posts
# scanned through (a) the standalone `Context` and (b) PrettyText's own booted
# engine must produce identical output. Any wrongly stubbed callback or
# mis-mapped option surfaces as a diff here. Needs a booted Rails environment,
# so it is tagged `:rails` and runs only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::MarkdownEngine::Context, :rails do
  let!(:category) { Fabricate(:category, slug: "parity-cat") }
  let!(:tag) { Fabricate(:tag, name: "paritytag") }

  let(:config) do
    source_settings =
      Migrations::Converters::MarkdownEngine::Config::SETTING_KEYS
        .filter_map { |key| [key, SiteSetting.public_send(key)] if SiteSetting.respond_to?(key) }
        .to_h

    Migrations::Converters::MarkdownEngine::Config.new(
      source_settings:,
      category_slugs: [category.slug],
      tag_names: [tag.name],
      additional_options: Site.markdown_additional_options,
    )
  end

  let(:context) do
    described_class.new(
      bundle: Migrations::Converters::MarkdownEngine::Bundle.load_or_build,
      config:,
    )
  end

  after { context.close }

  # Core constructs only: whether plugin features (poll etc.) are present on
  # the PrettyText side depends on which plugins the Rails process loaded, so
  # plugin bbcode has no stable parity target here.
  let(:fixtures) do
    [
      "plain paragraph, nothing to find",
      "a mention @someuser and a trailing-dot one @someuser.",
      "`@code` but @someuser\n\n    indented @code\n",
      "```\nfenced @code\n```\n\n@someuser",
      "#parity-cat and #paritytag and #unknown-slug",
      "#parity-cat::category #paritytag::tag",
      ":smile: and 😀 and :not_an_emoji:",
      "![pic|690x387](upload://2Yjf3WE4KOQ88YUb4fUMubKB9My.png)",
      "[attachment.pdf|attachment](upload://abcdefghijklmnopqrstuvwxy.pdf)",
      "bare example.com/t/slug/123 and <https://example.com/auto>",
      "[text](https://example.com/page \"a title\") and [ref link][1]\n\n[1]: https://example.com/ref",
      "https://example.com/percent%20encoded and [x](https://example.com/a(b))",
      %{[quote="someuser, post:2, topic:8"]\nquoted @someuser\n[/quote]},
      "> markdown quote with @someuser\n\nheading anchor test\n\n# A Heading",
      "<code>@someuser</code> and <pre>@someuser</pre>",
      "html block:\n\n<div>\n@someuser\n</div>",
      "a\rb\r\nc with @someuser",
    ]
  end

  def pretty_text_scan(posts)
    # `__PrettyText.cook` builds its engine locally, so a hook captures the
    # completed options of a real cook and rebuilds the identical engine as
    # `__pt` for the scan function — the exact configuration the site cooks
    # with, not a re-assembly that could drift.
    PrettyText.v8.eval(<<~JS)
      __parityOriginalCook = __PrettyText.cook;
      __PrettyText.cook = function (text, optInput) {
        const result = __parityOriginalCook.call(this, text, optInput);
        __pt = require("discourse-markdown-it").default
          .withCustomFeatures(require("discourse/static/markdown-it/features").default())
          .withOptions(optInput);
        return result;
      };
    JS
    PrettyText.markdown("warm up")
    PrettyText.v8.eval("__PrettyText.cook = __parityOriginalCook;")
    scan_js =
      File.read(
        File.join(
          Migrations::Converters.root_path,
          "lib/migrations/converters/markdown_engine/scan.js",
        ),
      )
    PrettyText.v8.eval(scan_js)
    PrettyText.v8.call("__scanPosts", posts)
  end

  it "produces the same scan output as PrettyText's booted engine" do
    posts = fixtures.each_with_index.map { |raw, index| { "id" => index, "raw" => raw } }

    standalone = context.scan(posts.map { |post| { id: post["id"], raw: post["raw"] } })
    booted = pretty_text_scan(posts)

    standalone.zip(booted).each { |ours, theirs| expect(ours).to eq(theirs), <<~MSG }
        scan mismatch for fixture #{ours["id"]}:
        #{fixtures[ours["id"]].inspect}

        standalone: #{ours.inspect}
        booted:     #{theirs.inspect}
      MSG
  end

  # The bundle ships the core-bundled plugins' markdown features because
  # their constructs must tokenize the way the destination cooks them — this
  # asserts exactly that, against each plugin PrettyText actually loaded in
  # this checkout (an absent plugin would make the booted side feature-less
  # and the comparison meaningless, so those fixtures are skipped).
  it "produces the same scan output for the bundled plugins' constructs" do
    plugin_fixtures = {
      "poll" => "[poll type=regular]\n* one\n* two @someuser\n[/poll]\n\nafter @someuser",
      "discourse-details" => %{[details="Summary"]\nhidden @someuser\n[/details]},
      "spoiler-alert" => "[spoiler]shh @someuser[/spoiler]",
      "footnote" => "noted[^1]\n\n[^1]: the note with @someuser",
      "discourse-local-dates" =>
        %{[date=2026-08-27 time=13:37:00 timezone="Europe/Vienna"] with @someuser},
      "checklist" => "[ ] open task @someuser\n[x] done task",
      "chat" =>
        "[chat quote=\"someuser;123;2026-08-27T00:00:00Z\" channel=\"general\" channelId=\"1\"]\nhi @someuser\n[/chat]",
    }
    loaded = Discourse.plugins.map(&:name)
    testable = plugin_fixtures.select { |plugin, _| loaded.include?(plugin) }
    skip "no bundled plugin is loaded — run with LOAD_PLUGINS=1" if testable.empty?

    posts = testable.values.each_with_index.map { |raw, index| { "id" => index, "raw" => raw } }
    standalone = context.scan(posts.map { |post| { id: post["id"], raw: post["raw"] } })
    booted = pretty_text_scan(posts)

    standalone
      .zip(booted, testable.keys)
      .each { |ours, theirs, plugin| expect(ours).to eq(theirs), <<~MSG }
        scan mismatch for the #{plugin} fixture:
        #{testable[plugin].inspect}

        standalone: #{ours.inspect}
        booted:     #{theirs.inspect}
      MSG
  end

  it "builds the same unicode emoji replacement table as the Emoji model" do
    expect(Migrations::Converters::MarkdownEngine::EmojiData.unicode_replacements).to eq(
      JSON.parse(Emoji.unicode_replacements_json),
    )
  end

  # The standalone build subprocess mirrors the host's core-bundle definition
  # because `PrettyText` itself cannot load there; this pins the mirror to the
  # host constants so a change on either side fails here instead of drifting.
  it "mirrors the host's core bundle definition" do
    bundle = Migrations::Converters::MarkdownEngine::Bundle
    expect(bundle::BUNDLED_DISCOURSE_MODULES).to eq(PrettyText::BUNDLED_DISCOURSE_MODULES)
    expect(bundle::CORE_BUNDLE_GLOBS).to eq(PrettyText::CORE_BUNDLE.dependency_globs)
  end
end
