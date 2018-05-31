require 'rails_helper'
require 'pretty_text'

describe PrettyText do

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
    mail_html   = PrettyText.cook("Hello World")

    expect(PrettyText.format_for_email(cooked_html)).to match_html(mail_html)
  end

end
