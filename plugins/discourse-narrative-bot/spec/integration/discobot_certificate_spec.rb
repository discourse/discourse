require 'rails_helper'

describe "Discobot Certificate" do
  let(:user) { Fabricate(:user, name: 'Jeff Atwood') }

  describe 'when viewing the certificate' do
    it 'should return the right text' do
      params = {
        date: Time.zone.now.strftime("%b %d %Y"),
        user_id: user.id
      }

      stub_request(:get, /letter_avatar_proxy/).to_return(status: 200)

      stub_request(:get, "http://test.localhost//images/d-logo-sketch-small.png")
        .to_return(status: 200)

      get '/discobot/certificate.svg', params: params

      expect(response.status).to eq(200)
    end

    describe 'when params are missing' do
      it "should raise the right errors" do
        params = {
          date: Time.zone.now.strftime("%b %d %Y"),
          user_id: user.id
        }

        params.each do |key, _|
          get '/discobot/certificate.svg', params: params.except(key)
          expect(response.status).to eq(400)
        end
      end
    end
  end
end
