# frozen_string_literal: true

require "email/theme_renderer"

RSpec.describe Email::ThemeRenderer do
  fab!(:theme) do
    Fabricate(:theme).tap do |theme|
      theme.set_field(target: :email_header, name: "email_header", value: "<div>%{branding}</div>")
      theme.set_field(
        target: :email_footer,
        name: "email_footer",
        value: "<div>%{footer_text} <a href='%{unsubscribe_url}'>Unsubscribe</a> %{unknown}</div>",
      )
      theme.set_field(target: :translations, name: :en, value: <<~YAML)
          en:
            branding: "ACME Corp"
            footer_text: "All rights reserved"
        YAML
      theme.set_field(target: :translations, name: :fr, value: <<~YAML)
          fr:
            branding: "Société ACME"
            footer_text: "Tous droits réservés"
        YAML
      theme.save!
    end
  end

  before { SiteSetting.default_theme_id = theme.id }

  it "renders translated HTML and plain-text fragments around the content when enabled" do
    SiteSetting.enable_email_theme_header_and_footer = true
    unsubscribe_url = "https://example.com/unsubscribe"
    renderer = described_class.new(unsubscribe_url:, locale: :fr)

    expect(renderer.html_header).to eq("<div>Société ACME</div>")
    expect(renderer.html_footer).to eq(
      "<div>Tous droits réservés <a href='#{unsubscribe_url}'>Unsubscribe</a> %{unknown}</div>",
    )
    expect(renderer.html("<main>Body</main>")).to eq(
      "<div>Société ACME</div><main>Body</main><div>Tous droits réservés <a href='#{unsubscribe_url}'>Unsubscribe</a> %{unknown}</div>",
    )
    expect(renderer.text("Body")).to eq(
      "Société ACME\n\nBody\n\nTous droits réservés [Unsubscribe](#{unsubscribe_url}) %{unknown}",
    )
  end

  it "omits theme fragments by default" do
    expect(SiteSetting.enable_email_theme_header_and_footer).to eq(false)
    renderer = described_class.new

    expect(renderer.html_header).to eq("")
    expect(renderer.html_footer).to eq("")
    expect(renderer.html("<main>Body</main>")).to eq("<main>Body</main>")
    expect(renderer.text("Body")).to eq("Body")
  end

  it "uses the preferences URL when an unsubscribe URL is unavailable" do
    SiteSetting.enable_email_theme_header_and_footer = true
    text = described_class.new.text("Body")

    expect(text).to include("[Unsubscribe](#{Discourse.base_url}/my/preferences)")
  end

  it "returns the content unchanged without a default theme" do
    SiteSetting.enable_email_theme_header_and_footer = true
    SiteSetting.default_theme_id = -1
    renderer = described_class.new

    expect(renderer.html("<main>Body</main>")).to eq("<main>Body</main>")
    expect(renderer.text("Body")).to eq("Body")
  end
end
