require 'rails_helper'

describe "Discobot Certificate" do
  let(:user) { Fabricate(:user, name: 'Jeff Atwood') }

  describe 'when viewing the certificate' do
    describe 'when params are missing' do
      it "should raise the right errors" do
        params = {
          date: Time.zone.now.strftime("%b %d %Y"),
          user_id: user.id
        }

        params.each do |key, _|
          expect { xhr :get, '/discobot/certificate.svg', params.except(key) }
            .to raise_error(Discourse::InvalidParameters)
        end
      end
    end

    describe 'when date is invalid' do
      it 'should raise the right error' do
        expect do
          xhr :get, '/discobot/certificate.svg',
            name: user.name,
            date: "<script type=\"text/javascript\">alert('This app is probably vulnerable to XSS attacks!');</script>",
            avatar_url: 'https://somesite.com/someavatar',
            user_id: user.id
        end.to raise_error(ArgumentError, 'invalid date')
      end
    end
  end
end
