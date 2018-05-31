require "rails_helper"

RSpec.describe RegexPresenceValidator do
  subject { described_class.new(regex: 'latest', regex_error: 'site_settings.errors.must_include_latest') }

  describe "#valid_value?" do
    describe "when value is present" do
      it "without regex match" do
        expect(subject.valid_value?("categories|new")).to eq(false)

        expect(subject.error_message).to eq(I18n.t(
          "site_settings.errors.must_include_latest"
        ))
      end

      it "with regex match" do
        expect(subject.valid_value?("latest|categories")).to eq(true)
      end
    end

    describe "when value is empty" do
      it "should not be valid" do
        expect(subject.valid_value?("")).to eq(false)

        expect(subject.error_message).to eq(I18n.t(
          "site_settings.errors.must_include_latest"
        ))
      end
    end
  end
end
