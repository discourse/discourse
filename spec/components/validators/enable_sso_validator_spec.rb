# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnableSsoValidator do
  subject { described_class.new }

  describe '#valid_value?' do
    describe "when 'sso url' is empty" do
      before do
        SiteSetting.sso_url = ""
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
            'site_settings.errors.sso_url_is_empty'
          ))
        end
      end
    end

    describe "when invite_only is set" do
      before do
        SiteSetting.invite_only = true
        SiteSetting.sso_url = 'https://example.com/sso'
      end

      it 'allows a false value' do
        expect(subject.valid_value?('f')).to eq(true)
      end

      it "doesn't allow true" do
        expect(subject.valid_value?('t')).to eq(false)
        expect(subject.error_message).to eq(I18n.t(
          'site_settings.errors.sso_invite_only'
        ))
      end
    end

    describe "when 'sso url' is present" do
      before do
        SiteSetting.sso_url = "https://www.example.com/sso"
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

  end
end
