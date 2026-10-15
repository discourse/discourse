# frozen_string_literal: true

describe "PM user removal" do
  fab!(:current_user, :admin)
  fab!(:other_user, :user)

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(current_user) }

  it "removes a user from the PM list" do
    pm =
      create_post(
        user: current_user,
        target_usernames: [other_user.username],
        archetype: Archetype.private_message,
      ).topic

    topic_page.visit_topic(pm)

    browser_root
      .locator(".user[data-id='#{other_user.id}'] .remove-invited")
      .filter(visible: true)
      .click

    expect(
      browser_root.locator(".small-action-contents").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Removed @#{other_user.username} just now")],
      useInnerText: true,
    )
  end

  it "removes yourself from the PM list" do
    pm =
      create_post(
        user: current_user,
        target_usernames: [other_user.username],
        archetype: Archetype.private_message,
      ).topic
    topic_page.visit_topic(pm)
    browser_root
      .locator(".user[data-id='#{current_user.id}'] .remove-invited")
      .filter(visible: true)
      .click
    dialog.click_yes

    expect(browser_page).to PlaywrightMatchers.have_url("/u/#{current_user.username}/messages")
  end

  it "removes a group from the PM list" do
    group =
      Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap do |g|
        g.add(other_user)
      end

    pm =
      create_post(
        user: current_user,
        target_group_names: [group.name],
        archetype: Archetype.private_message,
      ).topic

    topic_page.visit_topic(pm)

    browser_root
      .locator(".group[data-id='#{group.id}'] .remove-invited")
      .filter(visible: true)
      .click

    expect(
      browser_root.locator(".small-action-contents").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("Removed @#{group.name} just now")],
      useInnerText: true,
    )
  end
end
