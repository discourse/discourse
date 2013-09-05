require 'spec_helper'

describe ApplicationHelper do

  describe 'mobile_view?' do
    it "is true if mobile_view is '1' in the session" do
      session[:mobile_view] = '1'
      helper.mobile_view?.should be_true
    end

    it "is false if mobile_view is '0' in the session" do
      session[:mobile_view] = '0'
      helper.mobile_view?.should be_false
    end

    it "is false if mobile_view is not set and user agent is not mobile" do
      controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36')
      helper.mobile_view?.should be_false
    end

    #it "is true if mobile_view is not set and user agent is mobile" do
    it "is always false, even if user agent is for mobile device... for now..." do
      controller.request.stubs(:user_agent).returns('Mozilla/5.0 (iPhone; U; ru; CPU iPhone OS 4_2_1 like Mac OS X; ru) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8C148a Safari/6533.18.5')
      #helper.mobile_view?.should be_true
      # TODO: It's always false for now
      helper.mobile_view?.should be_false
    end
  end

end
