# frozen_string_literal: true

module OneboxHelpers
  def onebox_response(file)
    file = File.join("spec", "fixtures", "onebox", "#{file}.response")
    File.exist?(file) ? File.read(file) : ""
  end

  def inspect_html_fragment(raw_fragment, tag_name, attribute = "src")
    preview = Nokogiri::HTML::DocumentFragment.parse(raw_fragment)
    preview.css(tag_name).first[attribute]
  end
end
