require 'spec_helper'

describe ClicksController do

  context 'create' do

    context 'missing params' do
      it 'raises an error without the url param' do
        lambda { xhr :get, :track, post_id: 123 }.should raise_error(ActionController::ParameterMissing)
      end

      it "redirects to the url even without the topic_id or post_id params" do
        xhr :get, :track, url: 'http://google.com'
        response.should_not be_redirect
      end
    end

    context 'correct params' do
      let(:url) { "http://discourse.org" }

      before do
        request.stubs(:remote_ip).returns('192.168.0.1')
      end

      context "with a made up url" do
        it "doesn't redirect" do
          TopicLinkClick.expects(:create_from).returns(nil)
          xhr :get, :track, url: 'http://discourse.org', post_id: 123
          response.should_not be_redirect
        end

      end

      context 'with a post_id' do
        it 'calls create_from' do
          TopicLinkClick.expects(:create_from).with('url' => url, 'post_id' => '123', 'ip' => '192.168.0.1').returns(url)
          xhr :get, :track, url: url, post_id: 123
          response.should redirect_to(url)
        end

        it 'redirects to the url' do
          TopicLinkClick.stubs(:create_from).returns(url)
          xhr :get, :track, url: url, post_id: 123
          response.should redirect_to(url)
        end

        it 'will pass the user_id to create_from' do
          TopicLinkClick.expects(:create_from).with('url' => url, 'post_id' => '123', 'ip' => '192.168.0.1').returns(url)
          xhr :get, :track, url: url, post_id: 123
          response.should redirect_to(url)
        end

        it "doesn't redirect with the redirect=false param" do
          TopicLinkClick.expects(:create_from).with('url' => url, 'post_id' => '123', 'ip' => '192.168.0.1', 'redirect' => 'false').returns(url)
          xhr :get, :track, url: url, post_id: 123, redirect: 'false'
          response.should_not be_redirect
        end

      end

      context 'with a topic_id' do
        it 'calls create_from' do
          TopicLinkClick.expects(:create_from).with('url' => url, 'topic_id' => '789', 'ip' => '192.168.0.1').returns(url)
          xhr :get, :track, url: url, topic_id: 789
          response.should redirect_to(url)
        end
      end

    end

  end

end
