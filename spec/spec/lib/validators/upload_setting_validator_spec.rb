# frozen_string_literal: true

RSpec.describe UploadSettingValidator do
  describe "#valid_value?" do
    let(:safe_svg) { "<svg xmlns='http://www.w3.org/2000/svg'><circle /></svg>" }
    let(:script_svg) { "<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>" }
    let(:event_handler_svg) { "<svg xmlns='http://www.w3.org/2000/svg'><circle onclick='alert(1)' /></svg>" }

    shared_examples "validates splash screen SVG uploads" do |setting_name|
      subject(:validator) { described_class.new(name: setting_name) }

      it "accepts a safe SVG" do
        upload = instance_double(Upload, content: safe_svg)

        allow(Upload).to receive(:find_by).with(id: "1").and_return(upload)

        expect(validator.valid_value?("1")).to eq(true)
      end

      it "rejects an SVG containing a script tag" do
        upload = instance_double(Upload, content: script_svg)

        allow(Upload).to receive(:find_by).with(id: "1").and_return(upload)

        expect(validator.valid_value?("1")).to eq(false)
      end

      it "rejects an SVG containing an event handler" do
        upload = instance_double(Upload, content: event_handler_svg)

        allow(Upload).to receive(:find_by).with(id: "1").and_return(upload)

        expect(validator.valid_value?("1")).to eq(false)
      end

      it "uses the SVG error message" do
        expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_svg"))
      end
    end

    include_examples "validates splash screen SVG uploads", :splash_screen_image
    include_examples "validates splash screen SVG uploads", :splash_screen_image_dark

    it "accepts blank values" do
      validator = described_class.new(name: :splash_screen_image_dark)

      expect(validator.valid_value?(nil)).to eq(true)
      expect(validator.valid_value?("")).to eq(true)
    end

    it "accepts non-splash uploads without SVG validation" do
      validator = described_class.new(name: :site_logo)
      upload = instance_double(Upload)

      allow(Upload).to receive(:find_by).with(id: "1").and_return(upload)

      expect(validator.valid_value?("1")).to eq(true)
    end
  end
end
