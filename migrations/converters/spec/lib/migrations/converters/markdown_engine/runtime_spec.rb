# frozen_string_literal: true

require "mini_racer"

RSpec.describe Migrations::Converters::MarkdownEngine do
  let(:context) { MiniRacer::Context.new }

  before do
    root = Migrations::Converters::MarkdownEngine.discourse_root
    context.eval(
      File.read(
        File.join(
          root,
          "migrations/converters/lib/migrations/converters/markdown_engine/runtime.js",
        ),
      ),
    )
    context.eval(<<~JS)
      __scanConfig = { categorySlugs: {}, tagNames: { "κοσμος": true, "κοσμοσ": true } };
      function lookup(slug) { return __Ruby.hashtag_lookup(slug, null, ["tag"]); }
    JS
  end

  after { context.dispose }

  it "matches Ruby identity normalization without conflating lowercase sigmas" do
    refs = %w[κοσμος κοσμοσ ΚΟΣΜΟΣ].map { |name| context.call("lookup", name).fetch("ref") }

    expect(refs).to eq(%w[κοσμος κοσμοσ κοσμοσ])
  end

  it "rejects a name when only the other lowercase sigma exists" do
    context.eval('delete __scanConfig.tagNames["κοσμος"];')

    expect(context.call("lookup", "κοσμος")).to be_nil
    expect(context.call("lookup", "ΚΟΣΜΟΣ").fetch("ref")).to eq("κοσμοσ")
  end
end
