# frozen_string_literal: true

RSpec.describe UploadSettingValidator do
  subject(:validator) { described_class.new(opts) }

  let(:opts) { {} }

  describe "#valid_value?" do
    context "when value is blank" do
      it "accepts nil" do
        expect(validator.valid_value?(nil)).to eq(true)
      end

      it "accepts empty string" do
        expect(validator.valid_value?("")).to eq(true)
      end
    end

    context "when value is a valid upload id" do
      fab!(:upload)

      it "returns true when no additional validation is required" do
        expect(validator.valid_value?(upload.id)).to eq(true)
      end

      context "when the upload no longer exists" do
        before { upload.destroy! }

        it "returns false" do
          expect(validator.valid_value?(upload.id)).to eq(false)
        end
      end
    end
  end

  describe "#error_message" do
    it "returns invalid_upload as a generic message" do
      expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_upload"))
    end
  end

  describe "svg upload" do
    subject(:validator) { described_class.new(name: :splash_screen_image) }

    describe "#valid_value?" do
      fab!(:upload)

      context "when upload content is missing or raises" do
        before { allow_any_instance_of(Upload).to receive(:content).and_raise(StandardError) }

        it "returns false" do
          expect(validator.valid_value?(upload.id)).to eq(false)
        end
      end

      context "when upload content is blank" do
        before { allow_any_instance_of(Upload).to receive(:content).and_return(nil) }

        it "returns false" do
          expect(validator.valid_value?(upload.id)).to eq(false)
        end
      end

      context "when content has no svg element" do
        before { allow_any_instance_of(Upload).to receive(:content).and_return("<html></html>") }

        it "returns false" do
          expect(validator.valid_value?(upload.id)).to eq(false)
        end
      end

      context "when SVG contains a script" do
        before { allow_any_instance_of(Upload).to receive(:content).and_return(<<~CONTENT) }
  <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" width="50" height="50">
    <circle cx="50" cy="50" r="40" stroke="#3498db" stroke-width="8" fill="none" stroke-linecap="round" stroke-dasharray="60 150">
      <animateTransform attributeName="transform" type="rotate" from="0 50 50" to="360 50 50" dur="1s" repeatCount="indefinite" />
    </circle>
    <script>
      console.log("Spinner loaded");
    </script>
  </svg>
            CONTENT

        it "returns false" do
          expect(validator.valid_value?(upload.id)).to eq(false)
        end
      end

      context "when SVG contains an event handler attribute" do
        before do
          allow_any_instance_of(Upload).to receive(:content).and_return(
            '<svg><rect onclick="evil()"/></svg>',
          )
        end

        it "returns false" do
          expect(validator.valid_value?(upload.id)).to eq(false)
        end
      end

      context "when SVG is clean" do
        before do
          allow_any_instance_of(Upload).to receive(:content).and_return(
            '<svg xmlns="http://www.w3.org/2000/svg"><rect width="10" height="10"/></svg>',
          )
        end

        it "returns true" do
          expect(validator.valid_value?(upload.id)).to eq(true)
        end
      end
    end

    describe "#error_message" do
      it "returns invalid_svg" do
        expect(validator.error_message).to eq(I18n.t("site_settings.errors.invalid_svg"))
      end
    end
  end
end
