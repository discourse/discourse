# frozen_string_literal: true

RSpec.describe EnableLocalLoginsViaEmailValidator do
  subject { described_class.new }

  describe "#valid_value?" do
    describe "when 'enable_local_logins' is false" do
      before { SiteSetting.enable_local_logins = false }

      describe "when val is false" do
        it "should be valid" do
          expect(subject.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "should not be valid" do
          expect(subject.valid_value?("t")).to eq(false)

          expect(subject.error_message).to eq(
            I18n.t("site_settings.errors.enable_local_logins_disabled"),
          )
        end
      end
    end

    describe "when 'enable_local_logins' is true" do
      before { SiteSetting.enable_local_logins = true }

      describe "when val is false" do
        it "should be valid" do
          expect(subject.valid_value?("f")).to eq(true)
        end
      end

      describe "when value is true" do
        it "should be valid" do
          expect(subject.valid_value?("t")).to eq(true)
        end
      end
    end
  end
end
