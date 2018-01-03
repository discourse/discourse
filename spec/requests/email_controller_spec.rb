require 'rails_helper'

RSpec.describe EmailController do
  describe '#unsubscribed' do
    describe 'when email is invalid' do
      it 'should return the right response' do
        get '/email/unsubscribed', params: { email: 'somerandomstring' }

        expect(response.status).to eq(404)
      end
    end
  end
end
