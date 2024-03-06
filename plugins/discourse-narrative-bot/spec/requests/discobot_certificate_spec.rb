# frozen_string_literal: true

RSpec.describe "Discobot Certificate" do
  let(:user) { Fabricate(:user, name: "Jeff Atwood") }
  let(:params) { { date: Time.zone.now.strftime("%b %d %Y"), user_id: user.id } }

  before { SiteSetting.discourse_narrative_bot_enabled = true }

  describe "when viewing the certificate" do
    describe "when no logged in" do
      it "should return the right response" do
        get "/discobot/certificate.svg", params: params

        expect(response.status).to eq(404)
      end
    end

    describe "when logged in" do
      before { sign_in(user) }

      it "should return the right text" do
        stub_request(:get, /letter_avatar_proxy/).to_return(
          status: 200,
          body: "http://test.localhost/cdn/avatar.png",
        )
        stub_request(:get, /avatar.png/).to_return(status: 200)

        stub_request(:get, SiteSetting.site_logo_small_url).to_return(status: 200)

        get "/discobot/certificate.svg", params: params

        expect(response.status).to eq(200)
        expect(response.body).to include("<svg")
        expect(response.body).to include(user.avatar_template.gsub("{size}", "250"))
        expect(response.body).to include(SiteSetting.site_logo_small_url)
      end

      describe "when params are missing" do
        it "should raise the right errors" do
          params.each do |key, _|
            get "/discobot/certificate.svg", params: params.except(key)
            expect(response.status).to eq(400)
          end
        end
      end
    end
  end
end
