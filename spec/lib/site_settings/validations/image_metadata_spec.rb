# frozen_string_literal: true

require "site_settings/validations"

RSpec.describe SiteSettings::Validations do
  subject(:validations) { Class.new.include(described_class).new }

  describe "#validate_strip_image_metadata" do
    let(:error_message) do
      I18n.t(
        "errors.site_settings.strip_image_metadata_cannot_be_disabled_if_composer_media_optimization_image_enabled",
      )
    end

    context "when the new value is false" do
      context "when composer_media_optimization_image_enabled is enabled" do
        before { SiteSetting.composer_media_optimization_image_enabled = true }

        it "raises an error" do
          expect { validations.validate_strip_image_metadata("f") }.to raise_error(
            Discourse::InvalidParameters,
            error_message,
          )
        end
      end

      context "when composer_media_optimization_image_enabled is disabled" do
        before { SiteSetting.composer_media_optimization_image_enabled = false }

        it "is ok" do
          expect { validations.validate_strip_image_metadata("f") }.not_to raise_error
        end
      end
    end

    context "when the new value is true" do
      it "is ok" do
        expect { validations.validate_strip_image_metadata("t") }.not_to raise_error
      end
    end
  end
end
