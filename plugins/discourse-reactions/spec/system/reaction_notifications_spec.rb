# frozen_string_literal: true

describe "Reactions | Notifications", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:acting_user_1) { Fabricate(:user, name: "Bruce Wayne I") }
  fab!(:acting_user_2) { Fabricate(:user, name: "Bruce Wayne II") }

  fab!(:one_reaction_notification) do
    Fabricate(:one_reaction_notification, user: current_user, acting_user: acting_user_1)
  end

  fab!(:two_reactions_notification) do
    Fabricate(
      :multiple_reactions_notification,
      user: current_user,
      count: 2,
      acting_user: acting_user_1,
      acting_user_2: acting_user_2,
    )
  end

  fab!(:three_reactions_notification) do
    Fabricate(
      :multiple_reactions_notification,
      user: current_user,
      count: 3,
      acting_user: acting_user_1,
      acting_user_2: acting_user_2,
    )
  end

  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before do
    SiteSetting.discourse_reactions_enabled = true
    sign_in(current_user)
  end

  it "renders reactions notifications correctly in the user menu" do
    visit("/")

    user_menu.open

    expect(page).to have_css(
      "#quick-access-all-notifications .notification.reaction .item-label",
      count: 3,
    )

    labels = page.all("#quick-access-all-notifications .notification.reaction .item-label")
    expect(labels[0]).to have_text(
      I18n.t(
        "js.notifications.reaction_multiple_users",
        username: acting_user_2.username,
        count: 2,
      ),
    )
    expect(labels[1]).to have_text(
      I18n.t(
        "js.notifications.reaction_2_users",
        username: acting_user_2.username,
        username2: acting_user_1.username,
      ),
    )
    expect(labels[2]).to have_text(acting_user_1.username)
  end

  context "when prioritize full names in ux site setting is on" do
    fab!(:acting_user_3) { Fabricate(:user, username: "missingno", name: nil) }
    fab!(:null_name_notification) do
      Fabricate(
        :multiple_reactions_notification,
        user: current_user,
        count: 2,
        acting_user: acting_user_3,
        acting_user_2: acting_user_2,
      )
    end

    before { SiteSetting.prioritize_full_name_in_ux = true }

    it "renders reaction notifications with full names" do
      visit("/")
      user_menu.open

      labels = page.all("#quick-access-all-notifications .notification.reaction .item-label")

      expect(labels[1]).to have_text(
        I18n.t("js.notifications.reaction_multiple_users", username: acting_user_2.name, count: 2),
      )

      expect(labels[2]).to have_text(
        I18n.t(
          "js.notifications.reaction_2_users",
          username: acting_user_2.name,
          username2: acting_user_1.name,
        ),
      )

      expect(labels[2]).to have_text(acting_user_1.name)
    end

    it "falls back to the username when name field is nil" do
      visit("/")
      user_menu.open

      labels = page.all("#quick-access-all-notifications .notification.reaction .item-label")
      expect(labels[0]).to have_text(acting_user_3.username)
    end
  end
end
