# frozen_string_literal: true

require 'rails_helper'

describe Rtl do

  let(:user) { Fabricate.build(:user) }

  describe '.css_class' do

    context 'user locale is allowed' do
      before {
        SiteSetting.allow_user_locale = true
      }

      context 'user locale is RTL' do
        before { user.locale = 'he' }

        it 'returns rtl class' do
          expect(Rtl.new(user).css_class).to eq('rtl')
        end
      end

      context 'user locale is not RTL' do
        it 'returns empty class' do
          expect(Rtl.new(user).css_class).to eq('')
        end
      end

    end

    context 'user locale is not allowed' do
      before { SiteSetting.allow_user_locale = false }

      context 'site default locale is RTL' do
        before { SiteSetting.default_locale = 'he' }

        it 'returns rtl class' do
          expect(Rtl.new(user).css_class).to eq('rtl')
        end
      end

      context 'site default locale is LTR' do
        before { SiteSetting.default_locale = 'en' }

        context 'user locale is RTL' do
          before { user.stubs(:locale).returns('he') }

          it 'returns empty class' do
            expect(Rtl.new(user).css_class).to eq('')
          end
        end
      end
    end

  end
end
