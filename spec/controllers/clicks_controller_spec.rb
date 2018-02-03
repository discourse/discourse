require 'rails_helper'

describe ClicksController do

  context 'create' do

    context 'missing params' do
      it 'raises a 404 without the url param' do
        get :track, params: { post_id: 123 }, format: :json
        expect(response).to be_not_found
      end

      it "redirects to the url even without the topic_id or post_id params" do
        get :track, params: { url: 'http://google.com' }, format: :json
        expect(response).not_to be_redirect
      end
    end

    context 'correct params' do
      let(:url) { "http://discourse.org" }

      before do
        request.headers.merge!('REMOTE_ADDR' => '192.168.0.1')
      end

      context "with a made up url" do
        it "doesn't redirect" do
          TopicLinkClick.expects(:create_from).returns(nil)

          get :track,
            params: { url: 'http://discourse.org', post_id: 123 },
            format: :json

          expect(response).not_to be_redirect
        end
      end

      context "with a query string" do
        it "redirects" do
          TopicLinkClick.expects(:create_from).with(has_entries('url' => 'http://discourse.org/?hello=123')).returns(url)

          get :track, params: {
            url: 'http://discourse.org/?hello=123', post_id: 123, format: :json
          }

          expect(response).to redirect_to(url)
        end
      end

      context 'with a post_id' do
        it 'redirects' do
          TopicLinkClick.expects(:create_from).with('url' => url, 'post_id' => '123', 'ip' => '192.168.0.1').returns(url)

          get :track, params: { url: url, post_id: 123, format: :json }

          expect(response).to redirect_to(url)
        end

        it "redirects links in whispers to staff members" do
          log_in(:admin)
          whisper = Fabricate(:post, post_type: Post.types[:whisper])

          get :track, params: { url: url, post_id: whisper.id, format: :json }

          expect(response).to redirect_to(url)
        end

        it "doesn't redirect with the redirect=false param" do
          TopicLinkClick.expects(:create_from).with('url' => url, 'post_id' => '123', 'ip' => '192.168.0.1', 'redirect' => 'false').returns(url)

          get :track, params: {
            url: url, post_id: 123, redirect: 'false', format: :json
          }

          expect(response).not_to be_redirect
        end
      end

      context 'with a topic_id' do
        it 'redirects' do
          TopicLinkClick.expects(:create_from).with('url' => url, 'topic_id' => '789', 'ip' => '192.168.0.1').returns(url)
          get :track, params: { url: url, topic_id: 789, format: :json }
          expect(response).to redirect_to(url)
        end
      end

    end

  end

end
