require 'rails_helper'

describe ClicksController do
  context 'create' do
    context 'missing params' do
      it 'raises a 404 without a url' do
        get "/clicks/track", params: { post_id: 123 }
        expect(response).to be_not_found
      end
    end

    context 'correct params' do
      let(:url) { "https://discourse.org/" }
      let(:headers) { { REMOTE_ADDR: "192.168.0.1" } }
      let(:post) { create_post(raw: "this is a post with a link #{url}") }

      context "with a made up url" do
        it "doesn't redirect" do
          get "/clicks/track", params: { url: 'https://fakewebsite.com', post_id: post.id }, headers: headers
          expect(response).not_to be_redirect
          expect(response.body).to include(I18n.t("redirect_warning"))
        end
      end

      context "with a valid url" do
        it "redirects" do
          get "/clicks/track", params: { url: 'https://discourse.org/?hello=123', post_id: post.id }, headers: headers
          expect(response).to redirect_to("https://discourse.org/?hello=123")
        end
      end

      context 'with a post_id' do
        it 'redirects' do
          get "/clicks/track", params: { url: url, post_id: post.id }, headers: headers
          expect(response).to redirect_to(url)
        end

        it "redirects links in whispers to staff members" do
          sign_in(Fabricate(:admin))
          whisper = Fabricate(:post, post_type: Post.types[:whisper])

          get "/clicks/track", params: { url: url, post_id: whisper.id }, headers: headers

          expect(response).to redirect_to(url)
        end

        it "doesn't redirect with the redirect=false param" do
          get "/clicks/track", params: { url: url, post_id: post.id, redirect: 'false' }, headers: headers
          expect(response).not_to be_redirect
        end
      end

      context 'with a topic_id' do
        it 'redirects' do
          get "/clicks/track", params: { url: url, topic_id: post.topic.id }, headers: headers
          expect(response).to redirect_to(url)
        end
      end
    end
  end
end
