# frozen_string_literal: true

describe DiscourseAi::Agents::Discover do
  it "allows useful Markdown without treating generated links as evidence" do
    prompt = described_class.new.system_prompt

    expect(prompt).to include("Use Markdown")
    expect(prompt).to include("relative links")
    expect(prompt).to include("generate external links")
    expect(prompt).to include("selected discussions separately")
  end

  it "omits the title for quiet summaries" do
    prompt = described_class.new.system_prompt

    expect(prompt).to include("quiet has no title and uses one concise sentence")
    expect(prompt).to include("leave every requested title or answer field empty")
  end

  it "formats detailed summaries for scanning" do
    prompt = described_class.new.system_prompt

    expect(prompt).to include("two or three short paragraphs separated by a blank line")
    expect(prompt).to include("put every Markdown list item on its own line")
  end

  it "uses candidate metadata to choose broadly useful sources" do
    prompt = described_class.new.system_prompt

    expect(prompt).to include("category")
    expect(prompt).to include("last_updated_at")
    expect(prompt).to include("general guides")
    expect(prompt).to include("newer does not automatically mean better")
  end
end
