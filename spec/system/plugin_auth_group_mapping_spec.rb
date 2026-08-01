# frozen_string_literal: true

RSpec.describe "Plugin auth group mapping" do
  include DiscourseConnectHelpers
  include OmniauthHelpers

  fab!(:discourse_connect_group) { Fabricate(:group, name: "discourse-connect-members") }
  fab!(:discourse_connect_user) do
    Fabricate(:user, email: "discourse-connect-user@example.com", username: "dc_plugin_user")
  end
  fab!(:oauth_group) { Fabricate(:group, name: "oauth-members") }
  fab!(:oauth_user) do
    Fabricate(:user, email: "oauth-user@example.com", username: "oauth_plugin_user")
  end

  let(:group_page) { PageObjects::Pages::Group.new }
  let(:header) { PageObjects::Pages::Header.new }
  let(:login_page) { PageObjects::Pages::Login.new }
  let(:signup_page) { PageObjects::Pages::Signup.new }
  let(:plugin) { Plugin::Instance.new }
  let(:provider_group) { { id: "plugin-oauth-members", name: "Plugin OAuth Members" } }
  let(:sso_secret) { SecureRandom.alphanumeric(32) }
  let!(:sso_port) { setup_test_discourse_connect_server(user: discourse_connect_user, sso_secret:) }
  let(:sso_url) { "http://localhost:#{sso_port}/sso" }

  let(:discourse_connect_groups_modifier) do
    lambda do |group_names, sso|
      names =
        (
          if group_names.present?
            [group_names, discourse_connect_group.name]
          else
            [discourse_connect_group.name]
          end
        )

      sso.email == discourse_connect_user.email ? names.join(",") : group_names
    end
  end

  let(:oauth_associated_groups_modifier) do
    lambda do |associated_groups, auth_token, _result|
      if auth_token.info.email == oauth_user.email
        (associated_groups || []) + [provider_group]
      else
        associated_groups
      end
    end
  end

  let(:oauth_link_groups_modifier) do
    lambda do |_value, associated_groups, _user, extra_data|
      associated_groups.each do |associated_group|
        associated_group_record =
          AssociatedGroup.find_by!(
            provider_name: extra_data[:provider],
            provider_id: associated_group[:id],
          )

        GroupAssociatedGroup.find_or_create_by!(
          group: oauth_group,
          associated_group: associated_group_record,
        )
      end
    end
  end

  before do
    SiteSetting.full_name_requirement = "optional_at_signup"
    SiteSetting.enable_google_oauth2_logins = true
    SiteSetting.discourse_connect_url = sso_url
    SiteSetting.discourse_connect_secret = sso_secret
    SiteSetting.enable_discourse_connect = true
    OmniAuth.config.test_mode = true

    DiscoursePluginRegistry.register_modifier(
      plugin,
      :discourse_connect_add_groups,
      &discourse_connect_groups_modifier
    )
    DiscoursePluginRegistry.register_modifier(
      plugin,
      :auth_managed_authenticator_associated_groups,
      &oauth_associated_groups_modifier
    )
    DiscoursePluginRegistry.register_modifier(
      plugin,
      :auth_result_after_associated_groups_created,
      &oauth_link_groups_modifier
    )
  end

  after do
    reset_omniauth_config(:google_oauth2)
    DiscoursePluginRegistry.unregister_modifier(
      plugin,
      :discourse_connect_add_groups,
      &discourse_connect_groups_modifier
    )
    DiscoursePluginRegistry.unregister_modifier(
      plugin,
      :auth_managed_authenticator_associated_groups,
      &oauth_associated_groups_modifier
    )
    DiscoursePluginRegistry.unregister_modifier(
      plugin,
      :auth_result_after_associated_groups_created,
      &oauth_link_groups_modifier
    )
  end

  it "lets a DiscourseConnect user enter a plugin group" do
    login_page.open

    expect(header).to have_logged_in_user

    group_page.visit_members(discourse_connect_group)

    expect(group_page).to have_member(discourse_connect_user)
  end

  it "lets an OAuth user enter a plugin group" do
    mock_google_auth(email: oauth_user.email)

    signup_page.open.click_social_button("google_oauth2")

    expect(header).to have_logged_in_user

    group_page.visit_members(oauth_group)

    expect(group_page).to have_member(oauth_user)
  end
end
