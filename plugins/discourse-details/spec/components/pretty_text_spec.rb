# frozen_string_literal: true

require "pretty_text"

RSpec.describe PrettyText do
  let(:post) { Fabricate(:post) }

  it "supports details tag" do
    cooked_html = PrettyText.cook <<~MARKDOWN
      [details="foo"]
      bar
      [/details]
    MARKDOWN

    expect(cooked_html).to match_html <<~HTML
      <details>
        <summary>foo</summary>
        <p>bar</p>
      </details>
    HTML
  end

  it "supports open attribute" do
    cooked_html = PrettyText.cook <<~MARKDOWN
      [details open]
      bar
      [/details]
    MARKDOWN

    expect(cooked_html).to match_html <<~HTML
      <details open="">
      <summary></summary>
        <p>bar</p>
      </details>
    HTML
  end

  it "deletes elided content" do
    cooked_html = PrettyText.cook <<~MARKDOWN
      Hello World

      <details class='elided'>42</details>
    MARKDOWN

    email_html = PrettyText.format_for_email(cooked_html)

    expect(email_html).to match_html <<~HTML
      <p>Hello World</p>
      <a href="#{Discourse.base_url}">#{I18n.t("details.excerpt_details")}</a>
    HTML
  end

  it "can replace spoilers in emails" do
    cooked_html = PrettyText.cook <<~MARKDOWN
      hello

      [details="Summary"]
      world
      [/details]
    MARKDOWN

    email_html = PrettyText.format_for_email(cooked_html, post)

    expect(email_html).to match_html <<~HTML
      <p>hello</p>
      Summary <a href="#{post.full_url}">#{I18n.t("details.excerpt_details")}</a>
    HTML
  end

  it "properly handles multiple spoiler blocks in a post" do
    cooked_html = PrettyText.cook <<~MARKDOWN
      [details="First"]
      body secret stuff very long
      [/details]
      [details="Second"]
      body secret stuff very long
      [/details]

      Hey there.

      [details="Third"]
      body secret stuff very long
      [/details]
    MARKDOWN

    email_html = PrettyText.format_for_email(cooked_html, post)

    expect(email_html).to match_html <<~HTML
      First <a href="#{post.full_url}">#{I18n.t("details.excerpt_details")}</a>
      Second <a href="#{post.full_url}">#{I18n.t("details.excerpt_details")}</a>
      <p>Hey there.</p>
      Third <a href="#{post.full_url}">#{I18n.t("details.excerpt_details")}</a>
    HTML
  end

  it "escapes summary text" do
    cooked_html = PrettyText.cook <<~MARKDOWN
      <script>alert('hello')</script>

      [details="<script>alert('hello')</script>"]
      <script>alert('hello')</script>
      [/details]
    MARKDOWN

    email_html = PrettyText.format_for_email(cooked_html, post)

    expect(email_html).to match_html <<~HTML
      &lt;script&gt;alert('hello')&lt;/script&gt; <a href="#{post.full_url}">#{I18n.t("details.excerpt_details")}</a>
    HTML
  end
end
