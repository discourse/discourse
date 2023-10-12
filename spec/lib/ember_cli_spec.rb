# frozen_string_literal: true

describe EmberCli do
  describe ".ember_version" do
    it "works" do
      expect(EmberCli.ember_version).to match(/\A\d+\.\d+/)
    end
  end

  describe ".parse_chunks_from_html" do
    def generate_html
      <<~HTML
        <html>
          <head>
            <discourse-chunked-script entrypoint="discourse">
              <script src="#{Discourse.base_path}/assets/firstchunk.js"></script>
              <script src="#{Discourse.base_path}/assets/secondchunk.js"></script>
            </discourse-chunked-script>
          </head>
          <body>
            Hello world
          </body>
        </html>
      HTML
    end

    it "can parse chunks for a normal site" do
      chunks = EmberCli.parse_chunks_from_html generate_html
      expect(chunks["discourse"]).to eq(%w[firstchunk secondchunk])
    end

    it "can parse chunks for a subfolder site" do
      set_subfolder "/discuss"

      html = generate_html

      # sanity check that our fixture is working
      expect(html).to include("/discuss/assets/firstchunk.js")

      chunks = EmberCli.parse_chunks_from_html html
      expect(chunks["discourse"]).to eq(%w[firstchunk secondchunk])
    end
  end
end
