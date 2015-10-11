require 'rails_helper'
require_dependency 'digest_unsubscribe_key'

describe DigestUnsubscribeKey do

  it { is_expected.to belong_to :user }

  describe 'key' do

    let(:user) { Fabricate(:user) }
    let!(:key) { DigestUnsubscribeKey.create_key_for(user) }

    it 'has a temporary key' do
      expect(key).to be_present
    end

    describe '#user_for_key' do

      it 'can be used to find the user' do
        expect(DigestUnsubscribeKey.user_for_key(key)).to eq(user)
      end

      it 'returns nil with an invalid key' do
        expect(DigestUnsubscribeKey.user_for_key('asdfasdf')).to be_blank
      end

    end

  end

end
