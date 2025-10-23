# frozen_string_literal: true

RSpec.describe "constants match ruby" do
  let(:ctx) { MiniRacer::Context.new }

  def parse(file)
    # mini racer doesn't handle JS modules so we'll do this hack
    source = File.read("#{Rails.root}/frontend/#{file}")
    source.gsub!(/^export */, "")
    ctx.eval(source)
  end

  it "has the correct values" do
    parse("discourse/app/lib/constants.js")
    parse("pretty-text/addon/emoji/version.js")

    priorities = ctx.eval("SEARCH_PRIORITIES")
    Searchable::PRIORITIES.each { |key, value| expect(priorities[key.to_s]).to eq(value) }

    expect(ctx.eval("SEARCH_PHRASE_REGEXP")).to eq(Search::PHRASE_MATCH_REGEXP_PATTERN)
    expect(ctx.eval("IMAGE_VERSION")).to eq(Emoji::EMOJI_VERSION)
  end
end
