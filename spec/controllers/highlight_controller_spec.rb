require 'spec_helper'

describe HighlightController do

  context '.show' do

    it "returns custom highlight.js with multiple languages" do
      SiteSetting.stubs(:enabled_languages).returns("Apache|Bash")
      get :show
      assert_response :success
      response.body.should include("var hljs=new function(){")
      response.body.should include("registerLanguage(\"apache")
      response.body.should include("registerLanguage(\"bash")
    end

    it "returns Last-Modified date and 304 on If-Modified-Since" do
      SiteSetting.stubs(:enabled_languages).returns("")
      get :show
      assert_response :success
      response.header['Last-Modified'].should_not be_nil

      request.headers['If-Modified-Since'] = response.header['Last-Modified']
      get :show
      assert_response :not_modified
      response.body.should eql("")
    end

  end
end
