# frozen_string_literal: true
require 'rails_helper'

describe "CommonMark" do
  it 'passes spec' do

    SiteSetting.traditional_markdown_linebreaks = true
    SiteSetting.enable_markdown_typographer = false

    html, state, md = nil
    failed = 0

    File.readlines(Rails.root + 'spec/fixtures/md/spec.txt').each do |line|
      if line == "```````````````````````````````` example\n"
        state = :example
        next
      end

      if line == "````````````````````````````````\n"
        md.gsub!('→', "\t")
        html ||= String.new
        html.gsub!('→', "\t")
        html.strip!

        # normalize brs
        html.gsub!('<br />', '<br>')
        html.gsub!('<hr />', '<hr>')
        html.gsub!(/<img([^>]+) \/>/, "<img\\1>")

        SiteSetting.enable_markdown_linkify = false
        cooked = PrettyText.markdown(md, sanitize: false)
        cooked.strip!
        cooked.gsub!(" class=\"lang-auto\"", '')
        cooked.gsub!(/<span class="hashtag">(.*)<\/span>/, "\\1")
        # we don't care about this
        cooked.gsub!("<blockquote>\n</blockquote>", "<blockquote></blockquote>")
        html.gsub!("<blockquote>\n</blockquote>", "<blockquote></blockquote>")
        html.gsub!("language-ruby", "lang-ruby")
        # strip out unsupported languages
        html.gsub!(/ class="language-[;f].*"/, "")

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

      if state == :example
        md = (md || String.new) << line
      end

      if state == :html
        html = (html || String.new) << line
      end

    end

    expect(failed).to eq(0)
  end
end
