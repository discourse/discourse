# frozen_string_literal: true

require 'rails_helper'

describe HostListSettingValidator do
  subject(:validator) { described_class.new() }

  describe '#valid_value?' do
    describe "returns false for values containing *" do
      it { expect(validator.valid_value?("*")).to eq false }
      it { expect(validator.valid_value?("**")).to eq false }
      it { expect(validator.valid_value?(".*")).to eq false }
      it { expect(validator.valid_value?("a")).to eq true }
    end

    describe "returns false for values containing ?" do
      it { expect(validator.valid_value?("?")).to eq false }
      it { expect(validator.valid_value?("??")).to eq false }
      it { expect(validator.valid_value?(".?")).to eq false }
      it { expect(validator.valid_value?("a")).to eq true }
    end
  end

  describe "#error_message" do
    it "returns invalid domain hostname error" do
      expect(validator.error_message).to eq(I18n.t(
        'site_settings.errors.invalid_domain_hostname'
      ))
    end
  end
end
