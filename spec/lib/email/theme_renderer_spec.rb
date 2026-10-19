# frozen_string_literal: true

require "email/theme_renderer"

RSpec.describe Email::ThemeRenderer do
  fab!(:theme) do
    Fabricate(:theme).tap do |theme|
      theme.set_field(target: :email, name: "header", value: "<div>%{branding}</div>")
      theme.set_field(
        target: :email,
        name: "footer",
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

  it "preserves semantic containers and relative links in derived text" do
    SiteSetting.enable_email_theme_header_and_footer = true
    set_subfolder "/forum"
    theme.set_field(
      target: :email,
      name: "footer",
      value:
        '<footer><section>Compliance <a href="/forum/faq">FAQ</a> <a href="//example.org/privacy">Privacy</a></section></footer>',
    )
    theme.save!

    text = described_class.new.text("Body")

    expect(text).to include(
      "Compliance",
      "[FAQ](#{Discourse.base_url}/faq)",
      "[Privacy](http://example.org/privacy)",
    )
  end

  it "escapes substitutions in HTML without losing literal text" do
    SiteSetting.enable_email_theme_header_and_footer = true
    theme.set_field(target: :translations, name: :en, value: <<~YAML)
      en:
        branding: "Terms & <strong>Privacy</strong>"
    YAML
    theme.save!
    renderer = described_class.new(unsubscribe_url: 'https://example.com/?a=1&b="two"')

    expect(renderer.html_header).to eq(
      "<div>Terms &amp; &lt;strong&gt;Privacy&lt;/strong&gt;</div>",
    )
    expect(renderer.html_footer).to include("&amp;b=&quot;two&quot;")
    expect(renderer.text("Body")).to include("Terms & <strong>Privacy</strong>")
  end

  it "uses explicit plain-text fragments without HTML conversion" do
    SiteSetting.enable_email_theme_header_and_footer = true
    theme.set_field(
      target: :email,
      name: "footer_text",
      value: "Plain %{footer_text}: <literal> %{unsubscribe_url}",
    )
    theme.save!

    text = described_class.new(locale: :fr).text("Body &lt;literal&gt;")

    expect(text).to include("Body &lt;literal&gt;", "Plain Tous droits réservés: <literal>")
    expect(text).not_to include("[Unsubscribe]")
  end

  it "previews a non-default theme without enabling live branding" do
    other_theme = Fabricate(:theme)
    other_theme.set_field(target: :email, name: "header", value: "<header>Draft branding</header>")
    other_theme.save!

    renderer = described_class.new(theme_id: other_theme.id, preview_theme: true)

    expect(renderer.html_header).to eq("<header>Draft branding</header>")
    expect(renderer.text("Body")).to eq("Draft branding\n\nBody")
    expect(described_class.new.html_header).to eq("")
    expect(SiteSetting.default_theme_id).to eq(theme.id)
    expect(SiteSetting.enable_email_theme_header_and_footer).to eq(false)
  end
end
