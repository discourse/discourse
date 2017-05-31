require 'rails_helper'

describe TrustLevelGranter do

  describe 'grant' do

    it 'grants trust level' do
      user = Fabricate(:user, email: "foo@bar.com", trust_level: 0)
      TrustLevelGranter.grant(3, user)

      user.reload
      expect(user.trust_level).to eq(3)
    end
  end
end
