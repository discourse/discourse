require 'spec_helper'

describe UserAssociatedAccounts do
  it 'should correctly find social associations' do
    user = Fabricate(:user)
    UserAssociatedAccounts.new(user).associated_accounts.should == I18n.t("user.no_accounts_associated")

    TwitterUserInfo.create(user_id: user.id, screen_name: "sam", twitter_user_id: 1)
    FacebookUserInfo.create(user_id: user.id, username: "sam", facebook_user_id: 1)
    GoogleUserInfo.create(user_id: user.id, email: "sam@sam.com", google_user_id: 1)
    GithubUserInfo.create(user_id: user.id, screen_name: "sam", github_user_id: 1)

    user.reload
    UserAssociatedAccounts.new(user).associated_accounts.should == "Twitter(sam), Facebook(sam), Google(sam@sam.com), Github(sam)"
  end
end
