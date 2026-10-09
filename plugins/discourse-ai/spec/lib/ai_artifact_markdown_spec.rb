# frozen_string_literal: true

RSpec.describe PrettyText do
  before { enable_current_plugin }

  it "cooks compact snapshot and versioned artifact embeds on the server" do
    SiteSetting.ai_artifact_security = "strict"
    share_key = SecureRandom.urlsafe_base64(32)

    cooked =
      PrettyText.cook(
        "[ai-artifact share=\"#{share_key}\"]\n\n[ai-artifact id=\"123\" version=\"2\"]",
      )
    fragment = Nokogiri::HTML5.fragment(cooked)

    expect(
      fragment.css("div.ai-artifact").map { |node| node.attributes.transform_values(&:value) },
    ).to eq(
      [
        { "class" => "ai-artifact", "data-ai-artifact-share-key" => share_key },
        {
          "class" => "ai-artifact",
          "data-ai-artifact-id" => "123",
          "data-ai-artifact-version" => "2",
        },
      ],
    )
  end

  it "cooks explicit autorun booleans on either compact embed form" do
    raw =
      '[ai-artifact share="snapshot-key" autorun="true"]' \
        "\n\n" \
        '[ai-artifact autorun="false" id="123" version="2"]' \
        "\n\n" \
        '[ai-artifact id="456"]'
    fragment = Nokogiri::HTML5.fragment(PrettyText.cook(raw))

    expect(
      fragment.css("div.ai-artifact").map { |node| node.attributes.transform_values(&:value) },
    ).to eq(
      [
        {
          "class" => "ai-artifact",
          "data-ai-artifact-share-key" => "snapshot-key",
          "data-ai-artifact-autorun" => "true",
        },
        {
          "class" => "ai-artifact",
          "data-ai-artifact-id" => "123",
          "data-ai-artifact-version" => "2",
          "data-ai-artifact-autorun" => "false",
        },
        { "class" => "ai-artifact", "data-ai-artifact-id" => "456" },
      ],
    )
  end

  it "keeps malformed autorun attributes inert on the server" do
    invalid_tags = [
      '[ai-artifact share="snapshot-key" autorun="1"]',
      '[ai-artifact id="123" autorun="TRUE"]',
      '[ai-artifact id="123" autorun="true" autorun="false"]',
      '[ai-artifact share="snapshot-key" autorun="false" width="100"]',
      '[ai-artifact id="123" autorun=true]',
    ]
    fragment = Nokogiri::HTML5.fragment(PrettyText.cook(invalid_tags.join("\n\n")))

    expect(fragment.css("div.ai-artifact")).to be_empty
    invalid_tags.each { |tag| expect(fragment.text.tr("“”", '"')).to include(tag) }
  end

  it "cooks compact layout attributes on share and source embeds" do
    raw =
      '[ai-artifact share="snapshot-key" height="2000" seamless="true"]' \
        "\n\n" \
        '[ai-artifact id="123" height="00042" seamless="false"]'
    fragment = Nokogiri::HTML5.fragment(PrettyText.cook(raw))

    expect(
      fragment.css("div.ai-artifact").map { |node| node.attributes.transform_values(&:value) },
    ).to eq(
      [
        {
          "class" => "ai-artifact",
          "data-ai-artifact-share-key" => "snapshot-key",
          "data-ai-artifact-height" => "2000",
          "data-ai-artifact-seamless" => "true",
        },
        {
          "class" => "ai-artifact",
          "data-ai-artifact-id" => "123",
          "data-ai-artifact-height" => "42",
          "data-ai-artifact-seamless" => "false",
        },
      ],
    )
  end

  it "keeps legacy artifact HTML attributes and malformed compact layout inert" do
    raw =
      '<div class="ai-artifact" data-ai-artifact-id="123" data-ai-artifact-seamless="true"></div>' \
        "\n\n" \
        '[ai-artifact id="123" height="2001"]' \
        "\n\n" \
        '[ai-artifact share="key" seamless="1"]'
    fragment = Nokogiri::HTML5.fragment(PrettyText.cook(raw))

    expect(fragment.at_css("div.ai-artifact")["data-ai-artifact-seamless"]).to eq("true")
    expect(fragment.css("div.ai-artifact").length).to eq(1)
    expect(fragment.text.tr("“”", '"')).to include('[ai-artifact id="123" height="2001"]')
    expect(fragment.text.tr("“”", '"')).to include('[ai-artifact share="key" seamless="1"]')
  end

  it "keeps legacy HTML when AI is disabled without parsing compact tags" do
    SiteSetting.discourse_ai_enabled = false
    raw =
      '<div class="ai-artifact" data-ai-artifact-id="123" data-ai-artifact-width="600"></div>' \
        "\n\n" \
        '[ai-artifact id="123" height="2000"]'
    fragment = Nokogiri::HTML5.fragment(PrettyText.cook(raw))

    expect(fragment.css("div.ai-artifact").length).to eq(1)
    expect(fragment.at_css("div.ai-artifact")["data-ai-artifact-width"]).to eq("600")
    expect(fragment.text.tr("“”", '"')).to include('[ai-artifact id="123" height="2000"]')
  end

  it "keeps malformed native artifact identifiers inert on the server" do
    invalid_tags = [
      '[ai-artifact share="snapshot-key" id="123"]',
      '[ai-artifact share="https://example.com/artifact"]',
      '[ai-artifact id="123" id="456"]',
      '[ai-artifact id="0"]',
    ]

    fragment = Nokogiri::HTML5.fragment(PrettyText.cook(invalid_tags.join("\n\n")))

    expect(fragment.css("div.ai-artifact")).to be_empty
    invalid_tags.each { |tag| expect(fragment.text.tr("“”", '"')).to include(tag) }
  end

  it "keeps compact snapshot embeds inside code inert" do
    raw = '[ai-artifact share="snapshot-key"]'
    fragment = Nokogiri::HTML5.fragment(PrettyText.cook("```\n#{raw}\n```"))

    expect(fragment.at_css("code").text.strip).to eq(raw)
    expect(fragment.css("div.ai-artifact")).to be_empty
  end
end
