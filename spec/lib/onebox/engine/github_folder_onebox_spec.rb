# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::GithubFolderOnebox do
  context 'without fragments' do
    before do
      @link = "https://github.com/discourse/discourse/tree/main/spec/fixtures"
      @uri = "https://github.com/discourse/discourse/tree/main/spec/fixtures"

      stub_request(:get, @uri).to_return(status: 200, body: onebox_response(described_class.onebox_name))
    end

    include_context "engines"
    it_behaves_like "an engine"

    describe "#to_html" do
      it "includes link to folder with truncated display path" do
        expect(html).to include('<a href="https://github.com/discourse/discourse/tree/main/spec/fixtures" target="_blank" rel="noopener">main/spec/fixtures</a>')
      end

      it "includes repository name" do
        expect(html).to include("discourse/discourse")
      end

      it "includes logo" do
        expect(html).to include("")
      end
    end
  end

  context 'with fragments' do
    before do
      @link = "https://github.com/discourse/discourse#setting-up-discourse"
      @uri = "https://github.com/discourse/discourse"
      stub_request(:get, @uri).to_return(status: 200, body: onebox_response("githubfolder-discourse-root"))
      @onebox = described_class.new(@link)
    end

    it "extracts subtitles when linking to docs" do
      expect(@onebox.to_html).to include("<a href=\"https://github.com/discourse/discourse#setting-up-discourse\" target=\"_blank\" rel=\"noopener\">discourse/discourse - Setting up Discourse</a>")
    end
  end

  context 'with rdoc fragments' do
    before do
      @link = "https://github.com/ruby/rdoc#description-"
      @uri = "https://github.com/ruby/rdoc"
      stub_request(:get, @uri).to_return(status: 200, body: onebox_response("githubfolder-rdoc-root"))
      @onebox = described_class.new(@link)
    end

    it "extracts subtitles when linking to docs" do
      expect(@onebox.to_html).to include("<a href=\"https://github.com/ruby/rdoc#description-\" target=\"_blank\" rel=\"noopener\">GitHub - ruby/rdoc: RDoc produces HTML and online documentation for Ruby... - Description¶ ↑</a>")
    end
  end
end
