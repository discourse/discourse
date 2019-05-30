require 'rails_helper'

RSpec.describe InlineUploads do
  fab!(:upload) { Fabricate(:upload) }
  fab!(:upload2) { Fabricate(:upload) }
  fab!(:upload3) { Fabricate(:upload) }

  describe '.process' do
    it "should not correct existing inline uploads" do
      md = "![test](#{upload.short_url})"

      expect(InlineUploads.process(md)).to eq(md)

      md = "![test](#{upload.short_url})haha"

      expect(InlineUploads.process(md)).to eq(md)
    end

    it "should not correct code blocks" do
      md = "`<a class=\"attachment\" href=\"#{upload2.url}\">In Code Block</a>`"

      expect(InlineUploads.process(md)).to eq(md)

      md = "    <a class=\"attachment\" href=\"#{upload2.url}\">In Code Block</a>"

      expect(InlineUploads.process(md)).to eq(md)
    end

    it "should correct attachment URLs to the short version" do
      md = <<~MD
      <a class="attachment" href="#{upload.url}">
        this
        is
        some
        attachment

      </a>

      - <a class="attachment" href="#{upload2.url}">test2</a>
        - <a class="attachment" href="#{upload2.url}">test2</a>
          - <a class="attachment" href="#{upload2.url}">test2</a>

      <a class="test attachment" href="#{upload3.url}">test3</a>
      MD

      expect(InlineUploads.process(md)).to eq(<<~MD)
      [this is some attachment|attachment](#{upload.short_url})

      - [test2|attachment](#{upload2.short_url})
        - [test2|attachment](#{upload2.short_url})
          - [test2|attachment](#{upload2.short_url})

      [test3|attachment](#{upload3.short_url})
      MD
    end

    it 'should correct full upload url to the shorter version' do
      md = <<~MD
      Some random text

      ![test](#{upload.short_url})

      <a class="test attachment" href="#{upload.url}">
        test
      </a>

      `<a class="attachment" href="#{upload2.url}">In Code Block</a>`

          <a class="attachment" href="#{upload3.url}">In Code Block</a>

      <a href="#{upload.url}">test</a>
      <a href="#{Discourse.base_url_no_prefix}#{upload.url}">test</a>

      <a href="https://somerandomesite.com#{upload.url}">test</a>
      <a class="attachment" href="https://somerandom.com/url">test</a>
      MD

      expect(InlineUploads.process(md)).to eq(<<~MD)
      Some random text

      ![test](#{upload.short_url})

      [test|attachment](#{upload.short_url})

      `<a class="attachment" href="#{upload2.url}">In Code Block</a>`

          <a class="attachment" href="#{upload3.url}">In Code Block</a>

      [test](#{upload.short_url})
      [test](#{upload.short_url})

      <a href="https://somerandomesite.com#{upload.url}">test</a>
      <a class="attachment" href="https://somerandom.com/url">test</a>
      MD
    end
  end
end
