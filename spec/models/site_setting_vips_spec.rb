# frozen_string_literal: true

RSpec.describe SiteSetting do
  describe ".use_vips_for_image_processing" do
    it "is disabled, hidden, and server-only by default" do
      client_settings = JSON.parse(described_class.client_settings_json_uncached)

      expect(
        {
          value: described_class.use_vips_for_image_processing,
          hidden: described_class.hidden_settings.include?(:use_vips_for_image_processing),
          client_exposed: client_settings.key?("use_vips_for_image_processing"),
          description: I18n.t("site_settings.use_vips_for_image_processing"),
        },
      ).to eq(
        {
          value: false,
          hidden: true,
          client_exposed: false,
          description:
            "Use stock libvips command-line tools instead of ImageMagick for upload processing, image probes, and optimized images.",
        },
      )
    end
  end
end
