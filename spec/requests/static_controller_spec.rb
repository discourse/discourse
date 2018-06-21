require 'rails_helper'

describe StaticController do

  context '#favicon' do
    let(:png) { Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==") }

    before { FinalDestination.stubs(:lookup_ip).returns("1.2.3.4") }

    it 'returns the default favicon for a missing download' do
      url = "https://fav.icon/#{SecureRandom.hex}.png"

      stub_request(:get, url).to_return(status: 404)

      SiteSetting.favicon_url = url

      get '/favicon/proxied'

      favicon = File.read(Rails.root + "public/images/default-favicon.png")

      expect(response.status).to eq(200)
      expect(response.content_type).to eq('image/png')
      expect(response.body.bytesize).to eq(favicon.bytesize)
    end

    it 'can proxy a favicon correctly' do
      url = "https://fav.icon/#{SecureRandom.hex}.png"

      stub_request(:get, url).to_return(status: 200, body: png)

      SiteSetting.favicon_url = url

      get '/favicon/proxied'

      expect(response.status).to eq(200)
      expect(response.content_type).to eq('image/png')
      expect(response.body.bytesize).to eq(png.bytesize)
    end
  end

  context '#brotli_asset' do
    it 'returns a non brotli encoded 404 if asset is missing' do
      get "/brotli_asset/missing.js"

      expect(response.status).to eq(404)
      expect(response.headers['Content-Encoding']).not_to eq('br')
      expect(response.headers['Cache-Control']).to match(/max-age=1/)
    end

    it 'can handle fallback brotli assets' do
      begin
        assets_path = Rails.root.join("tmp/backup_assets")

        GlobalSetting.stubs(:fallback_assets_path).returns(assets_path.to_s)

        FileUtils.mkdir_p(assets_path)

        file_path = assets_path.join("test.js.br")
        File.write(file_path, 'fake brotli file')

        get "/brotli_asset/test.js"

        expect(response.status).to eq(200)
        expect(response.headers["Cache-Control"]).to match(/public/)
      ensure
        File.delete(file_path)
      end
    end

    it 'has correct headers for brotli assets' do
      begin
        assets_path = Rails.root.join("public/assets")

        FileUtils.mkdir_p(assets_path)

        file_path = assets_path.join("test.js.br")
        File.write(file_path, 'fake brotli file')

        get "/brotli_asset/test.js"

        expect(response.status).to eq(200)
        expect(response.headers["Cache-Control"]).to match(/public/)
      ensure
        File.delete(file_path)
      end
    end
  end

  context '#show' do
    before do
      post = create_post
      SiteSetting.tos_topic_id = post.topic.id
      SiteSetting.guidelines_topic_id = post.topic.id
      SiteSetting.privacy_topic_id = post.topic.id
    end

    context "with a static file that's present" do
      it "should return the right response" do
        get "/faq"

        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t('js.faq'))
      end
    end

    [
      ['tos', :tos_url, I18n.t('terms_of_service.title')],
      ['privacy', :privacy_policy_url, I18n.t('privacy')]
    ].each do |id, setting_name, text|

      context "#{id}" do
        context "when #{setting_name} site setting is NOT set" do
          it "renders the #{id} page" do
            get "/#{id}"

            expect(response.status).to eq(200)
            expect(response.body).to include(text)
          end
        end

        context "when #{setting_name} site setting is set" do
          before do
            SiteSetting.public_send("#{setting_name}=", 'http://example.com/page')
          end

          it "redirects to the #{setting_name}" do
            get "/#{id}"

            expect(response).to redirect_to('http://example.com/page')
          end
        end
      end
    end

    context "with a missing file" do
      it "should respond 404" do
        get "/static/does-not-exist"
        expect(response.status).to eq(404)
      end
    end

    it 'should redirect to / when logged in and path is /login' do
      sign_in(Fabricate(:user))
      get "/login"
      expect(response).to redirect_to('/')
    end

    it "should display the login template when login is required" do
      SiteSetting.login_required = true

      get "/login"

      expect(response.status).to eq(200)

      expect(response.body).to include(PrettyText.cook(I18n.t(
        'login_required.welcome_message', title: SiteSetting.title
      )))
    end

    context "when login_required is enabled" do
      before do
        SiteSetting.login_required = true
      end

      it 'faq page redirects to login page for anon' do
        get '/faq'
        expect(response).to redirect_to '/login'
      end

      it 'guidelines page redirects to login page for anon' do
        get '/guidelines'
        expect(response).to redirect_to '/login'
      end

      it 'faq page loads for logged in user' do
        sign_in(Fabricate(:user))

        get '/faq'

        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t('js.faq'))
      end

      it 'guidelines page loads for logged in user' do
        sign_in(Fabricate(:user))

        get '/guidelines'

        expect(response.status).to eq(200)
        expect(response.body).to include(I18n.t('guidelines'))
      end
    end
  end

  describe '#enter' do
    context 'without a redirect path' do
      it 'redirects to the root url' do
        post "/login.json"
        expect(response).to redirect_to('/')
      end
    end

    context 'with a redirect path' do
      it 'redirects to the redirect path' do
        post "/login.json", params: { redirect: '/foo' }
        expect(response).to redirect_to('/foo')
      end
    end

    context 'with a full url' do
      it 'redirects to the correct path' do
        post "/login.json", params: { redirect: "#{Discourse.base_url}/foo" }
        expect(response).to redirect_to('/foo')
      end
    end

    context 'with a period to force a new host' do
      it 'redirects to the root path' do
        post "/login.json", params: { redirect: ".org/foo" }
        expect(response).to redirect_to('/')
      end
    end

    context 'with a full url to someone else' do
      it 'redirects to the root path' do
        post "/login.json", params: { redirect: "http://eviltrout.com/foo" }
        expect(response).to redirect_to('/')
      end
    end

    context 'with an invalid URL' do
      it "redirects to the root" do
        post "/login.json", params: { redirect: "javascript:alert('trout')" }
        expect(response).to redirect_to('/')
      end
    end

    context 'when the redirect path is the login page' do
      it 'redirects to the root url' do
        post "/login.json", params: { redirect: login_path }
        expect(response).to redirect_to('/')
      end
    end
  end
end
