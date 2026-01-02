# frozen_string_literal: true

RSpec.describe LlmsTxtController do
  describe "#index" do
    it "returns 404 when llms_txt_content setting is empty" do
      get "/llms.txt"
      expect(response.status).to eq(404)
    end

    it "returns the content as plain text when llms_txt_content has content" do
      SiteSetting.llms_txt_content = "# My Site\n\nThis is my llms.txt content."

      get "/llms.txt"

      expect(response.status).to eq(200)
      expect(response.content_type).to start_with("text/plain")
      expect(response.body).to eq("# My Site\n\nThis is my llms.txt content.")
    end
  end
end
