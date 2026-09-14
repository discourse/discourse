# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".jpeg_quality" do
    it "estimates JPEG quality in the image worker" do
      result =
        described_class.jpeg_quality(
          input_path: file_from_fixtures("exif_orientation.jpg").path,
          timeout: 5,
        )

      expect(result).to eq(95)
    end

    it "rejects a non-JPEG image and keeps the worker available" do
      expect do
        described_class.jpeg_quality(input_path: file_from_fixtures("logo.png").path, timeout: 5)
      end.to raise_error(DiscourseVips::InvalidImage)

      expect(described_class.version).to be_present
    end
  end
end
