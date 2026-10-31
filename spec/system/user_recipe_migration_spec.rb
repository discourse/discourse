# frozen_string_literal: true

describe "User and group recipe migration" do
  with_select_controls(true)

  fab!(:admin)
  fab!(:recipient) { Fabricate(:user, username: "pickme") }
  fab!(:team) do
    Fabricate(:group, name: "pickteam", messageable_level: Group::ALIAS_LEVELS[:everyone])
  end

  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(admin) }

  it "sends a message to the picked user and group" do
    visit "/new-message"

    recipients = PageObjects::Components::UiKit::DSelect.at("#reply-control .d-select.user-chooser")
    recipients.search(recipient.username)
    recipients.select_value(recipient.username)
    recipients.search(team.name)
    recipients.select_value(team.name)
    recipients.close

    composer.fill_title("A message for the picked recipients")
    composer.fill_content("Hello to the user and the group that were picked")
    composer.submit

    expect(page).to have_css(".private-message-glyph-wrapper")
    topic = Topic.where(archetype: Archetype.private_message).last
    expect(topic.allowed_users).to include(recipient)
    expect(topic.allowed_groups).to include(team)
  end

  it "filters the review queue by the picked user" do
    visit "/review"
    find(".reviewable-filters .expand-secondary-filters").click

    flagged_user =
      PageObjects::Components::UiKit::DSelect.at("#review-filter-user-label ~ .d-select")
    flagged_user.search(recipient.username)
    flagged_user.select_value(recipient.username)
    find(".reviewable-filters .refresh").click

    expect(page).to have_current_path(/username=#{recipient.username}/)
  end

  it "saves the picked site contact user and group" do
    config_area = PageObjects::Pages::AdminAboutConfigArea.new
    config_area.visit

    section = ".admin-config-area-about__contact-information-section"
    user = PageObjects::Components::UiKit::DSelect.at("#{section} .d-select.user-chooser")
    user.search(recipient.username)
    user.select_value(recipient.username)

    group = PageObjects::Components::UiKit::DSelect.at("#{section} .d-select.group-chooser")
    group.search(team.name)
    group.select_value(team.id)

    config_area.contact_information_section.submit
    expect(config_area.contact_information_section).to have_saved_successfully

    expect(SiteSetting.site_contact_username).to eq(recipient.username)
    expect(SiteSetting.site_contact_group_name).to eq(team.id.to_s)
  end
end
