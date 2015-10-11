require 'rails_helper'

describe StaticController do

  context 'show' do
    before do
      post = create_post
      SiteSetting.stubs(:tos_topic_id).returns(post.topic.id)
      SiteSetting.stubs(:guidelines_topic_id).returns(post.topic.id)
      SiteSetting.stubs(:privacy_topic_id).returns(post.topic.id)
    end

    context "with a static file that's present" do

      before do
        xhr :get, :show, id: 'faq'
      end

      it 'renders the static file if present' do
        expect(response).to be_success
      end

      it "renders the file" do
        expect(response).to render_template('static/show')
        expect(assigns(:page)).to eq('faq')
      end
    end

    [ ['tos', :tos_url], ['privacy', :privacy_policy_url] ].each do |id, setting_name|
      context "#{id}" do
        subject { xhr :get, :show, id: id }

        context "when #{setting_name} site setting is NOT set" do
          it "renders the #{id} page" do
            expect(subject).to render_template("static/show")
            expect(assigns(:page)).to eq(id)
          end
        end

        context "when #{setting_name} site setting is set" do
          before  { SiteSetting.stubs(setting_name).returns('http://example.com/page') }

          it "redirects to the #{setting_name}" do
            expect(subject).to redirect_to('http://example.com/page')
          end
        end
      end
    end

    context "with a missing file" do
      it "should respond 404" do
        xhr :get, :show, id: 'does-not-exist'
        expect(response.response_code).to eq(404)
      end
    end

    it 'should redirect to / when logged in and path is /login' do
      log_in
      xhr :get, :show, id: 'login'
      expect(response).to redirect_to '/'
    end

    it "should display the login template when login is required" do
      SiteSetting.stubs(:login_required).returns(true)
      xhr :get, :show, id: 'login'
      expect(response).to be_success
    end
  end

  describe '#enter' do
    context 'without a redirect path' do
      it 'redirects to the root url' do
        xhr :post, :enter
        expect(response).to redirect_to '/'
      end
    end

    context 'with a redirect path' do
      it 'redirects to the redirect path' do
        xhr :post, :enter, redirect: '/foo'
        expect(response).to redirect_to '/foo'
      end
    end

    context 'with a full url' do
      it 'redirects to the correct path' do
        xhr :post, :enter, redirect: "#{Discourse.base_url}/foo"
        expect(response).to redirect_to '/foo'
      end
    end

    context 'with a period to force a new host' do
      it 'redirects to the root path' do
        xhr :post, :enter, redirect: ".org/foo"
        expect(response).to redirect_to '/'
      end
    end

    context 'with a full url to someone else' do
      it 'redirects to the root path' do
        xhr :post, :enter, redirect: "http://eviltrout.com/foo"
        expect(response).to redirect_to '/'
      end
    end

    context 'with an invalid URL' do
      it "redirects to the root" do
        xhr :post, :enter, redirect: "javascript:alert('trout')"
        expect(response).to redirect_to '/'
      end
    end

    context 'when the redirect path is the login page' do
      it 'redirects to the root url' do
        xhr :post, :enter, redirect: login_path
        expect(response).to redirect_to '/'
      end
    end
  end
end
