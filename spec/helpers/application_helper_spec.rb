require 'spec_helper'

describe ApplicationHelper do

  describe "escape_unicode" do
    it "encodes tags" do
      helper.escape_unicode("<tag>").should == "\u003ctag>"
    end
    it "survives junk text" do
      helper.escape_unicode("hello \xc3\x28 world").should =~ /hello.*world/
    end
  end

  describe "mobile_view?" do
    context "enable_mobile_theme is true" do
      before do
        SiteSetting.stubs(:enable_mobile_theme).returns(true)
      end

      it "is true if mobile_view is '1' in the session" do
        session[:mobile_view] = '1'
        helper.mobile_view?.should be_true
      end

      it "is false if mobile_view is '0' in the session" do
        session[:mobile_view] = '0'
        helper.mobile_view?.should be_false
      end

      context "mobile_view is not set" do
        it "is false if user agent is not mobile" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36')
          helper.mobile_view?.should be_false
        end

        it "is true for iPhone" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (iPhone; U; ru; CPU iPhone OS 4_2_1 like Mac OS X; ru) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8C148a Safari/6533.18.5')
          helper.mobile_view?.should be_true
        end

        it "is false for iPad" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (iPad; CPU OS 5_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Version/5.1 Mobile/9B176 Safari/7534.48.3")
          helper.mobile_view?.should be_false
        end

        it "is false for Nexus 10 tablet" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (Linux; Android 4.2.1; Nexus 10 Build/JOP40D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Safari/535.19")
          helper.mobile_view?.should be_false
        end

        it "is true for Nexus 7 tablet" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (Linux; Android 4.1.2; Nexus 7 Build/JZ054K) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Safari/535.19")
          helper.mobile_view?.should be_true
        end
      end
    end

    context "enable_mobile_theme is false" do
      before do
        SiteSetting.stubs(:enable_mobile_theme).returns(false)
      end

      it "is false if mobile_view is '1' in the session" do
        session[:mobile_view] = '1'
        helper.mobile_view?.should be_false
      end

      it "is false if mobile_view is '0' in the session" do
        session[:mobile_view] = '0'
        helper.mobile_view?.should be_false
      end

      context "mobile_view is not set" do
        it "is false if user agent is not mobile" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36')
          helper.mobile_view?.should be_false
        end

        it "is false for iPhone" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (iPhone; U; ru; CPU iPhone OS 4_2_1 like Mac OS X; ru) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8C148a Safari/6533.18.5')
          helper.mobile_view?.should be_false
        end
      end
    end
  end


end
