require 'rails_helper'

RSpec.describe SsoOverridesEmailValidator do
  subject { described_class.new }

  describe '#valid_value?' do
    describe "when 'email editable' is true" do
      before do
        SiteSetting.sso_url = "https://www.example.com/sso"
        SiteSetting.enable_sso = true
        SiteSetting.email_editable = true
      end

      describe 'when val is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end

      describe 'when value is true' do
        it 'should not be valid' do
          expect(subject.valid_value?('t')).to eq(false)

          expect(subject.error_message).to eq(I18n.t(
            'site_settings.errors.email_editable_enabled'
          ))
        end
      end
    end

    describe "when 'email editable' is false" do
      before do
        SiteSetting.sso_url = "https://www.example.com/sso"
        SiteSetting.enable_sso = true
        SiteSetting.email_editable = false
      end

      describe 'when value is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end

      describe 'when value is true' do
        it 'should be valid' do
          expect(subject.valid_value?('t')).to eq(true)
        end
      end
    end

    describe "when 'enable sso' is false" do
      before do
        SiteSetting.enable_sso = false
      end

      describe 'when value is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end

      describe 'when value is true' do
        it 'should not be valid' do
          expect(subject.valid_value?('t')).to eq(false)

          expect(subject.error_message).to eq(I18n.t(
            'site_settings.errors.enable_sso_disabled'
          ))
        end
      end
    end
  end
end
