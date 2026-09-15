# frozen_string_literal: true

RSpec.describe DiscourseVips do
  describe ".estimated_jpeg_quality" do
    it "returns the estimated JPEG quality" do
      result =
        described_class.estimated_jpeg_quality(
          input_path: file_from_fixtures("exif_orientation.jpg").path,
          timeout: 5,
        )

      expect(result).to eq(95)
    end

    it "rejects a non-JPEG image and keeps the worker available" do
      expect do
        described_class.estimated_jpeg_quality(
          input_path: file_from_fixtures("logo.png").path,
          timeout: 5,
        )
      end.to raise_error(DiscourseVips::InvalidImage)

      expect(described_class.version).to be_present
    end
  end
end
