# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubGistOnebox do
  before do
    @link = "https://gist.github.com/karreiro/208fdd59fc4b4c39283b"

    stub_request(:get, "https://api.github.com/gists/208fdd59fc4b4c39283b").to_return(
      status: 200,
      body: onebox_response(described_class.onebox_name),
    )
  end

  include_context "with engines"
  it_behaves_like "an engine"

  describe "#data" do
    let(:gist_files) { data[:gist_files] }

    it "includes contents with 10 lines at most" do
      gist_files.each do |gist_file|
        truncated_lines = gist_file.content.split("\n").size
        expect(truncated_lines).to be < 10
      end
    end
  end

  describe "#to_html" do
    describe "when Gist API responds correctly" do
      it "includes the link to original page" do
        expect(html).to include("https://gist.github.com/karreiro/208fdd59fc4b4c39283b")
      end

      it "includes three files" do
        expect(html).to include("0.rb")
        expect(html).to include("1.js")
        expect(html).to include("2.md")
      end

      it "does not include truncated files" do
        expect(html).not_to include("3.java")
      end

      it "includes gist contents" do
        expect(html).to include("3.times { puts &quot;Gist API test.&quot; }")
        expect(html).to include("console.log(&quot;Hey! ;)&quot;)")
        expect(html).to include("#### Hey, this is a test!")
      end

      it "does not include gist contents from truncated files" do
        expect(html).not_to include("System.out.println(&quot;Wow! This is a test!&quot;);")
      end
    end

    describe "when the rate limit has been reached" do
      before do
        stub_request(:get, "https://api.github.com/gists/208fdd59fc4b4c39283b").to_return(
          status: 403,
        )
      end

      it "includes the link to original page" do
        expect(html).to include("https://gist.github.com/karreiro/208fdd59fc4b4c39283b")
      end

      it "does not include any file" do
        expect(html).not_to include("0.rb")
        expect(html).not_to include("1.js")
        expect(html).not_to include("2.md")
        expect(html).not_to include("3.java")
      end
    end
  end
end
