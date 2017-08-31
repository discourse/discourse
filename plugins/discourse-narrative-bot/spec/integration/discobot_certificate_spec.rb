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
          expect { get '/discobot/certificate.svg', params: params.except(key) }
            .to raise_error(Discourse::InvalidParameters)
        end
      end
    end

    describe 'when date is invalid' do
      it 'should raise the right error' do
        expect do
          get '/discobot/certificate.svg', params: {
            name: user.name,
            date: "<script type=\"text/javascript\">alert('This app is probably vulnerable to XSS attacks!');</script>",
            avatar_url: 'https://somesite.com/someavatar',
            user_id: user.id
          }
        end.to raise_error(ArgumentError, 'invalid date')
      end
    end
  end
end
