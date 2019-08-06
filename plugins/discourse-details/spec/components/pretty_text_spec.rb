# frozen_string_literal: true

require 'rails_helper'
require 'pretty_text'

describe PrettyText do

  let(:post) { Fabricate(:post) }

  it "supports details tag" do
    cooked_html = <<~HTML
      <details>
      <summary>
      foo</summary>
      <p>bar</p>
      </details>
    HTML

    expect(cooked_html).to match_html(cooked_html)
    expect(PrettyText.cook("[details=foo]\nbar\n[/details]")).to match_html(cooked_html)
  end

  it "deletes elided content" do
    cooked_html = PrettyText.cook("Hello World\n\n<details class='elided'>42</details>")
    mail_html   = "<p>Hello World</p>\n<a href=\"http://test.localhost\">(click for more details)</a>"

    expect(PrettyText.format_for_email(cooked_html)).to match_html(mail_html)
  end

  it 'can replace spoilers in emails' do
    md = PrettyText.cook(<<~EOF)
      hello

      [details="Summary"]
      world
      [/details]
    EOF
    md = PrettyText.format_for_email(md, post)
    html = "<p>hello</p>\n\nSummary <a href=\"#{post.full_url}\">(click for more details)</a>"

    expect(md).to eq(html)
  end

  it 'escapes summary text' do
    md = PrettyText.cook(<<~EOF)
      <script>alert('hello')</script>
      [details="<script>alert('hello')</script>"]
      <script>alert('hello')</script>
      [/details]
    EOF
    md = PrettyText.format_for_email(md, post)

    expect(md).not_to include('<script>')
  end

end
