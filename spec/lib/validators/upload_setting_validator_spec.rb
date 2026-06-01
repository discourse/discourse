# frozen_string_literal: true

RSpec.describe UploadSettingValidator do
  let(:safe_svg) { "<svg xmlns='http://www.w3.org/2000/svg'><circle /></svg>" }
  let(:script_svg) { "<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>" }
  let(:event_handler_svg) do
    "<svg xmlns='http://www.w3.org/2000/svg'><circle onclick='alert(1)' /></svg>"
  end

  def stub_upload(content)
    upload = instance_double(Upload, content: content)
    allow(Upload).to receive(:find_by).with(id: "1").and_return(upload)
  end

  describe "#valid_value?" do
    context "with a splash screen SVG setting" do
      subject(:validator) { described_class.new(name: :splash_screen_image) }

      it "accepts blank values" do
        expect(validator.valid_value?(nil)).to eq(true)
        expect(validator.valid_value?("")).to eq(true)
      end

      it "accepts a safe SVG" do
        stub_upload(safe_svg)
        expect(validator.valid_value?("1")).to eq(true)
      end

      it "rejects an SVG containing a script tag" do
        stub_upload(script_svg)
        expect(validator.valid_value?("1")).to eq(false)
      end

      it "rejects an SVG containing an event handler attribute" do
        stub_upload(event_handler_svg)
        expect(validator.valid_value?("1")).to eq(false)
      end

      it "uses the SVG error message" do
        expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_svg"))
      end
    end

    it "validates splash_screen_image_dark as an SVG setting too" do
      validator = described_class.new(name: :splash_screen_image_dark)
      stub_upload(script_svg)

      expect(validator.valid_value?("1")).to eq(false)
      expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_svg"))
    end

    context "with a non-splash upload setting" do
      subject(:validator) { described_class.new(name: :site_logo) }

      it "skips SVG validation" do
        stub_upload(script_svg)
        expect(validator.valid_value?("1")).to eq(true)
      end

      it "uses the generic upload error message" do
        expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_upload"))
      end
    end
  end
end
