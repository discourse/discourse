require 'rails_helper'
require_dependency 'retrieve_title'

describe RetrieveTitle do

  context "extract_title" do

    it "will extract the value from the title tag" do
      title = RetrieveTitle.extract_title(
        "<html><title>My Cool Title</title></html>"
      )

      expect(title).to eq("My Cool Title")
    end

    it "will strip whitespace" do
      title = RetrieveTitle.extract_title(
        "<html><title>   Another Title\n\n </title></html>"
      )

      expect(title).to eq("Another Title")
    end

    it "will pick og:title if title is missing" do
      title = RetrieveTitle.extract_title(<<~HTML
        <html>
          <meta property="og:title" content="Good Title"
        </html>
        HTML
      )

      expect(title).to eq("Good Title")
    end

    it "will prefer the title from an opengraph tag" do
      title = RetrieveTitle.extract_title(<<~HTML
        <html>
          <title>Good Title</title>
          <meta property="og:title" content="Bad Title"
        </html>
        HTML
      )

      expect(title).to eq("Good Title")
    end

    it "will parse a YouTube url from javascript" do
      title = RetrieveTitle.extract_title(<<~HTML
        <html>
          <title>YouTube</title>
          <script>document.title = "Video Title";</script>
        </html>
        HTML
      )
      expect(title).to eq("Video Title")
    end

  end

end
