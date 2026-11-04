# frozen_string_literal: true

RSpec.describe Blog::TemplateRenderer do
  describe ".render" do
    it "escapes dynamic text while allowing only server-produced HTML fragments" do
      output =
        described_class.render(
          "article",
          {
            "title" => '<img src=x onerror="alert(1)">',
            "body" => described_class::Html.new("<p>Safe cooked content</p>"),
          },
          theme: {
            "template_article" => "<h1>{{ title }}</h1><div>{{ body }}</div>",
          },
        )
      document = Nokogiri::HTML5.fragment(output)
      expect(document.at_css("h1").text).to eq('<img src=x onerror="alert(1)">')
      expect(document.css("img")).to be_empty
      expect(document.at_css("div p").text).to eq("Safe cooked content")
    end

    it "does not expose request, session, model methods, or global Liquid registrations" do
      output =
        described_class.render(
          "article",
          { "article" => { "title" => "Public title" } },
          theme: {
            "template_article" =>
              "{{ article.title }}|{{ article.class }}|{{ request }}|{{ session }}|{{ site_settings }}",
          },
        )
      expect(output).to eq("Public title||||")
      expect(described_class::ENVIRONMENT).not_to equal(Liquid::Environment.default)
    end

    it "falls back to the built-in page after resource exhaustion or an unknown filter" do
      assigns = { "site" => {}, "labels" => { "about" => "About fallback" } }
      [
        "{% for item in (1..1000000000) %}x{% endfor %}",
        "{% for a in (1..1000) %}{% for b in (1..1000) %}x{% endfor %}{% endfor %}",
        '{{ "hello" | unsupported_filter }}',
      ].each do |source|
        output = described_class.render("about", assigns, theme: { "template_about" => source })
        expect(output).to include("About fallback")
      end
    end

    it "ignores custom templates when custom rendering is disabled" do
      output =
        described_class.render(
          "not_found",
          { "labels" => { "not_found_title" => "Not found" }, "site" => {} },
          theme: {
            "template_not_found" => "custom markup",
          },
          custom: false,
        )
      expect(output).to include("Not found")
      expect(output).not_to include("custom markup")
    end
  end

  describe ".validate!" do
    it "rejects includes, render tags, invalid syntax, excessive nesting, and oversized sources" do
      [
        '{% include "/etc/passwd" %}',
        '{% render "secret" %}',
        "{% if %}",
        "{% if true %}" * 110 + "{% endif %}" * 110,
        "x" * 65_537,
      ].each do |source|
        expect { described_class.validate!(source) }.to raise_error(Discourse::InvalidParameters)
      end
    end
  end
end
