# frozen_string_literal: true
RSpec.describe "CommonMark" do
  it "passes spec" do
    SiteSetting.traditional_markdown_linebreaks = true
    SiteSetting.enable_markdown_typographer = false
    SiteSetting.highlighted_languages = "ruby|aa"

    html, state, md = nil
    failed = 0

    File
      .readlines(Rails.root + "spec/fixtures/md/spec.txt")
      .each do |line|
        if line == "```````````````````````````````` example\n"
          state = :example
          next
        end

        if line == "````````````````````````````````\n"
          md.gsub!("→", "\t")
          html ||= String.new
          html.gsub!("→", "\t")
          html.strip!

          # normalize brs
          html.gsub!("<br />", "<br>")
          html.gsub!("<hr />", "<hr>")
          html.gsub!(%r{<img([^>]+) />}, "<img\\1>")

          SiteSetting.enable_markdown_linkify = false
          cooked = PrettyText.markdown(md, sanitize: false)
          cooked.strip!
          cooked.gsub!(" class=\"lang-auto\"", "")
          cooked.gsub!(%r{<span class="hashtag-raw">(.*)</span>}, "\\1")
          cooked.gsub!(%r{<a name="(.*)" class="anchor" href="#\1*"></a>}, "")
          # we support data-attributes which is not in the spec
          cooked.gsub!(" data-code-startline=\"3\"", "")
          cooked.gsub!(%r{ data-code-wrap="[^"]+"}, "")
          # we don't care about this
          cooked.gsub!("<blockquote>\n</blockquote>", "<blockquote></blockquote>")
          html.gsub!("<blockquote>\n</blockquote>", "<blockquote></blockquote>")
          html.gsub!("language-ruby", "lang-ruby")
          html.gsub!("language-aa", "lang-aa")
          # strip out unsupported languages
          html.gsub!(%r{ class="language-[;f].*"}, "")

          unless cooked == html
            failed += 1
            puts "FAILED SPEC"
            puts "Expected: "
            puts html
            puts "Got: "
            puts cooked
            puts "Markdown: "
            puts md
            puts
          end
          html, state, md = nil
          next
        end

        if state == :example && line == ".\n"
          state = :html
          next
        end

        md = (md || String.new) << line if state == :example

        html = (html || String.new) << line if state == :html
      end

    expect(failed).to eq(0)
  end
end
