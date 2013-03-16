require 'spec_helper'
require 'diff_engine'

describe DiffEngine do

  let(:html_before) do
    <<-HTML.strip_heredoc
    <context>
    <original>text</original>
    </context>
    HTML
  end

  let(:markdown_special_characters) do
    "=\`*_{}[]()#+-.!"
  end

  it "escapes input html to markup with diff html" do
    diff = DiffEngine.html_diff("<html>", "")

    diff.should include("&lt;html&gt;")
  end

  it "generates an html diff with ins and dels for changed" do
    html_after = html_before
      .gsub(/original/, "changed")

    diff = DiffEngine.html_diff(html_before, html_after)

    diff.should match(/del.*?original.*?del/)
    diff.should match(/ins.*?changed.*?ins/)
  end

  it "generates an html diff with only ins for inserted" do
    html_after = "#{html_before}\nnew"

    diff = DiffEngine.html_diff(html_before, html_after)

    diff.should include("ins")
    diff.should_not include("del")
  end

  it "generates an html diff with only unchanged for unchanged" do
    html_after = html_before

    diff = DiffEngine.html_diff(html_before, html_after)

    diff.should include("unchanged")
    diff.should_not include("del", "ins")
  end

  it "handles markdown special characters" do
    diff = DiffEngine.markdown_diff(markdown_special_characters, "")

    diff.should include(markdown_special_characters)
  end

end
