require 'rails_helper'

describe RTL do

  let(:user) { Fabricate.build(:user) }

  describe '.css_class' do

    context 'user locale is allowed' do
      before { SiteSetting.stubs(:allow_user_locale).returns(true) }

      context 'user locale is RTL' do
        before { user.stubs(:locale).returns('he') }

        it 'returns rtl class' do
          expect(RTL.new(user).css_class).to eq('rtl')
        end
      end

      context 'user locale is not RTL' do
        it 'returns empty class' do
          expect(RTL.new(user).css_class).to eq('')
        end
      end

    end

    context 'user locale is not allowed' do
      before { SiteSetting.stubs(:allow_user_locale).returns(false) }

      context 'site default locale is RTL' do
        before { SiteSetting.stubs(:default_locale).returns('he') }

        it 'returns rtl class' do
          expect(RTL.new(user).css_class).to eq('rtl')
        end
      end

      context 'site default locale is LTR' do
        before { SiteSetting.stubs(:default_locale).returns('en') }

        context 'user locale is RTL' do
          before { user.stubs(:locale).returns('he') }

          it 'returns empty class' do
            expect(RTL.new(user).css_class).to eq('')
          end
        end
      end
    end

  end
end
