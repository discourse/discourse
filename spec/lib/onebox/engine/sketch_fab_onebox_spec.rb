# frozen_string_literal: true

RSpec.describe Onebox::Engine::SketchFabOnebox do
  describe ".===" do
    it "matches valid Sketchfab models URL" do
      valid_url = URI("https://sketchfab.com/models/1234567890abcdef1234567890abcdef")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Sketchfab 3d-models URL with title" do
      valid_url_with_title =
        URI("https://sketchfab.com/3d-models/example-title-1234567890abcdef1234567890abcdef")
      expect(described_class === valid_url_with_title).to eq(true)
    end

    it "does not match URL with invalid path" do
      invalid_path_url = URI("https://sketchfab.com/invalid/path")
      expect(described_class === invalid_path_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/models/1234567890abcdef1234567890abcdef")
      expect(described_class === unrelated_url).to eq(false)
    end

    it "does not match Sketchfab URL with incorrect ID length" do
      invalid_id_url = URI("https://sketchfab.com/models/12345")
      expect(described_class === invalid_id_url).to eq(false)
    end
  end
end
