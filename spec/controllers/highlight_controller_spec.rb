require 'spec_helper'

describe HighlightController do

  context '.show' do

    it "route matches controller with key" do
      filename = HighlightController.generate_path
      key = HighlightController.generate_key
      {:get => "/javascripts/#{filename}"}.should route_to(
        {controller: "highlight", action: "show", key: key}
      )
    end

    it "route matches controller without key" do
      filename = HighlightController.generate_path
      {:get => "/javascripts/highlight.js"}.should route_to(
        {controller: "highlight", action: "show"}
      )
    end

    it "returns custom highlight.js with multiple languages" do
      SiteSetting.stubs(:enabled_languages).returns("Axapta|Bash")

      get :show
      assert_response :success
      response.body.should include("var hljs=new function(){")
      response.body.should include("registerLanguage(\"axapta")
      response.body.should include("registerLanguage(\"bash")
    end

    it "returns Not-Modified when If-Modified-Since and config not updated" do
      SiteSetting.stubs(:enabled_languages).returns("")
      key = HighlightController.generate_key

      get :show, key: key
      assert_response :success
      response.header['Last-Modified'].should_not be_nil
      response.body.should_not include("registerLanguage(\"apache")

      request.headers['If-Modified-Since'] = response.header['Last-Modified']
      get :show, key: key
      assert_response :not_modified
      response.body.should eql("")
    end

    it "redirects with Moved Permenantly on old resource when config update" do
      SiteSetting.stubs(:enabled_languages).returns("")
      key = HighlightController.generate_key

      get :show, key: key
      assert_response :success
      response.header['Last-Modified'].should_not be_nil
      response.body.should_not include("registerLanguage(\"apache")

      SiteSetting.stubs(:enabled_languages).returns("Apache")
      get :show, key: key
      assert_response :redirect
      response.should redirect_to("/javascripts/#{HighlightController.generate_path}")
    end

    it "redirects with Moved Permenantly when If-Modified-Since request on old resource when config update" do
      SiteSetting.stubs(:enabled_languages).returns("")
      key = HighlightController.generate_key

      get :show, key: key
      assert_response :success
      response.header['Last-Modified'].should_not be_nil
      response.body.should_not include("registerLanguage(\"apache")

      SiteSetting.stubs(:enabled_languages).returns("Apache")
      request.headers['If-Modified-Since'] = response.header['Last-Modified']
      get :show, key: key
      assert_response :redirect
      response.should redirect_to("/javascripts/#{HighlightController.generate_path}")
    end
  end
end
