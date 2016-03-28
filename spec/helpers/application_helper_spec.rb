require 'rails_helper'

describe ApplicationHelper do

  describe "escape_unicode" do
    it "encodes tags" do
      expect(helper.escape_unicode("<tag>")).to eq("\u003ctag>")
    end
    it "survives junk text" do
      expect(helper.escape_unicode("hello \xc3\x28 world")).to match(/hello.*world/)
    end
  end

  describe "mobile_view?" do
    context "enable_mobile_theme is true" do
      before do
        SiteSetting.stubs(:enable_mobile_theme).returns(true)
      end

      it "is true if mobile_view is '1' in the session" do
        session[:mobile_view] = '1'
        expect(helper.mobile_view?).to eq(true)
      end

      it "is false if mobile_view is '0' in the session" do
        session[:mobile_view] = '0'
        expect(helper.mobile_view?).to eq(false)
      end

      context "mobile_view is not set" do
        it "is false if user agent is not mobile" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36')
          expect(helper.mobile_view?).to be_falsey
        end

        it "is true for iPhone" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (iPhone; CPU iPhone OS 9_2_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13D15 Safari/601.1')
          expect(helper.mobile_view?).to eq(true)
        end

        it "is true for Android Samsung Galaxy" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Linux; Android 5.0.2; SAMSUNG SM-G925F Build/LRX22G) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/4.0 Chrome/44.0.2403.133 Mobile Safari/537.36')
          expect(helper.mobile_view?).to eq(true)
        end

        it "is true for Android Google Nexus 5X" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Linux; Android 6.0; Nexus 5X Build/MDB08I) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.43 Mobile Safari/537.36')
          expect(helper.mobile_view?).to eq(true)
        end

        it "is false for iPad" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (iPad; CPU OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B14 3 Safari/601.1")
          expect(helper.mobile_view?).to eq(false)
        end

        it "is false for Nexus 10 tablet" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (Linux; Android 5.1.1; Nexus 10 Build/LMY49G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.91 Safari/537.36")
          expect(helper.mobile_view?).to be_falsey
        end

        it "is false for Nexus 7 tablet" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (Linux; Android 6.0.1; Nexus 7 Build/MMB29Q) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.91 Safari/537.36")
          expect(helper.mobile_view?).to be_falsey
        end
      end
    end

    context "enable_mobile_theme is false" do
      before do
        SiteSetting.stubs(:enable_mobile_theme).returns(false)
      end

      it "is false if mobile_view is '1' in the session" do
        session[:mobile_view] = '1'
        expect(helper.mobile_view?).to eq(false)
      end

      it "is false if mobile_view is '0' in the session" do
        session[:mobile_view] = '0'
        expect(helper.mobile_view?).to eq(false)
      end

      context "mobile_view is not set" do
        it "is false if user agent is not mobile" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36')
          expect(helper.mobile_view?).to eq(false)
        end

        it "is false for iPhone" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (iPhone; U; ru; CPU iPhone OS 4_2_1 like Mac OS X; ru) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8C148a Safari/6533.18.5')
          expect(helper.mobile_view?).to eq(false)
        end
      end
    end
  end

  describe '#rtl_class' do
    it "returns 'rtl' when the I18n.locale is rtl" do
      I18n.stubs(:locale).returns(:he)
      expect(helper.rtl_class).to eq('rtl')
    end

    it 'returns an empty string when the I18n.locale is not rtl' do
      I18n.stubs(:locale).returns(:zh_TW)
      expect(helper.rtl_class).to eq('')
    end
  end

end
