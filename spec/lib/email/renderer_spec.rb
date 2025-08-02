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

  it "escapes HTML entities from text" do
    expect(renderer.text).to eq("Key & Peele")
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
