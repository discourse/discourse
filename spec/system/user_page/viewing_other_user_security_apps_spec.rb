# frozen_string_literal: true

describe "Viewing another user's security and apps preferences" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  fab!(:user_api_key) { Fabricate(:user_api_key, user:, last_used_at: Time.zone.now) }

  let(:user_api_keys) { PageObjects::Components::UserApiKeys.new }

  it "hides the revoke button from moderators" do
    sign_in(moderator)
    PageObjects::Pages::UserPreferencesApps.new.visit(user)

    expect(user_api_keys).to have_api_key
    expect(user_api_keys).to have_no_revoke_button
  end

  it "lets admins revoke and restore the user's apps" do
    sign_in(admin)
    PageObjects::Pages::UserPreferencesSecurity.new.visit(user)

    user_api_keys.toggle_revoke

    expect(user_api_keys).to have_undo_revoke_button

    user_api_keys.toggle_revoke

    expect(user_api_keys).to have_revoke_button
  end
end
