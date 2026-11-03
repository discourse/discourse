# frozen_string_literal: true

require "email/renderer"

RSpec.describe Email::Renderer do
  let(:message) do
    mail = Mail.new

    mail.text_part = Mail::Part.new { body "Key &amp; Peele" }

    mail.html_part =
      Mail::Part.new do
        content_type "text/html; charset=UTF-8"
        body "<h1>Key &amp; Peele</h1> <a href=\"https://discourse.org\">Discourse link</a>"
      end

    mail
  end

  let(:renderer) { Email::Renderer.new(message) }

  it "preserves HTML entities in the original plain-text body" do
    expect(renderer.text).to eq(message.text_part.body.decoded)
  end

  context "with theme email branding" do
    before do
      theme = Fabricate(:theme)
      theme.set_field(target: :email, name: "header_text", value: "Theme header")
      theme.save!
      SiteSetting.default_theme_id = theme.id
      SiteSetting.enable_email_theme_header_and_footer = true
    end

    it "does not brand the text part when the HTML part was built outside the email layout" do
      expect(renderer.text).to eq(message.text_part.body.decoded)
    end

    it "brands the text part when the HTML part will come from the email layout" do
      message = Mail.new(body: "Body")

      expect(Email::Renderer.new(message).text).to eq("Theme header\n\nBody")
    end
  end

  context "with email_renderer_html modifier" do
    after { DiscoursePluginRegistry.reset! }

    it "can modify the html" do
      Plugin::Instance
        .new
        .register_modifier(:email_renderer_html) do |styles, _|
          styles.fragment.css("a").each { |link| link["href"] = "httpz://hijacked.sorry" }
        end

      expect(renderer.html).not_to include("href=\"https://discourse.org\"")
      expect(renderer.html).to include("href=\"httpz://hijacked.sorry\"")
    end
  end
end
