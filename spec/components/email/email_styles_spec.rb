require 'spec_helper'
require 'email'

describe Email::Styles do

  def style_exists(html, css_rule)
    fragment = Nokogiri::HTML.fragment(Email::Styles.new(html).format)
    element = fragment.at(css_rule)
    expect(element["style"]).not_to be_blank
  end

  it "returns blank from an empty string" do
    Email::Styles.new("").format.should be_blank
  end

  it "attaches a style to h3 tags" do
    style_exists("<h3>hello</h3>", "h3")
  end

  it "attaches a style to hr tags" do
    style_exists("hello<hr>", "hr")
  end

  it "attaches a style to a tags" do
    style_exists("<a href='#'>wat</a>", "a")
  end

  it "attaches a style to ul tags" do
    style_exists("<ul><li>hello</li></ul>", "ul")
  end

  it "attaches a style to li tags" do
    style_exists("<ul><li>hello</li></ul>", "li")
  end

  it "removes pre tags but keeps their contents" do
    expect(Email::Styles.new("<pre>hello</pre>").format).to eq("hello")
  end

end
