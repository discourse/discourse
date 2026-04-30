# frozen_string_literal: true

RSpec.describe "Ideas Category Type Setup" do
  fab!(:admin)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_type_card) { PageObjects::Components::CategoryTypeCard.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toast) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.enable_simplified_category_creation = true
    SiteSetting.enable_ideas_category_type_setup = true
    sign_in(admin)
  end

  it "works with correct defaults and configures site settings and category setting automatically" do
    visit("/new-category/setup")
    category_type_card.find_type_card("ideas").click
    expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "ideas"))

    expect(form.field("name").value).to eq("Ideas")
    expect(
      form.field("style_type").find(".form-kit__control-radio[type='radio'][value='emoji']")[
        "checked"
      ],
    ).to eq(true)
    expect(form.field("style_type").find("#control-emoji").find("img.emoji")["title"]).to eq("bulb")

    expect(banner).to be_visible
    banner.click_save

    expect(page).to have_content(I18n.t("js.category.edit_dialog_title", categoryName: "Ideas"))
    expect(page).to have_css(".d-nav-submenu__tabs .edit-category-ideas")
    expect(SiteSetting.topic_voting_enabled).to eq(true)
    category = Category.find_by(name: "Ideas")
    expect(Category.can_vote?(category.id)).to eq(true)
  end

  context "when the ideas category type setup is disabled" do
    before { SiteSetting.enable_ideas_category_type_setup = false }

    it "does not show the ideas category type" do
      visit("/new-category/setup")
      expect(page).to have_no_css(".category-type-cards__card.--category-type-ideas")
    end

    it "does not show the tab for the ideas category type when editing an existing category" do
      ideas_category = Fabricate(:category, name: "Ideas")
      DiscourseTopicVoting::Categories::Types::Ideas.configure_category(
        ideas_category,
        guardian: admin.guardian,
      )
      visit("/c/#{ideas_category.slug}/edit/ideas")
      expect(page).to have_no_css(".d-nav-submenu__tabs .edit-category-ideas")
    end
  end

  context "when there is an ideas category already configured" do
    fab!(:category)

    before do
      DiscourseTopicVoting::Categories::Types::Ideas.configure_category(
        category,
        guardian: admin.guardian,
      )
    end

    it "does not preload basic data for the ideas category type" do
      visit("/new-category/setup")
      category_type_card.find_type_card("ideas").click

      expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "ideas"))
      expect(form.field("name").value).to eq("")
      expect(
        form.field("style_type").find(".form-kit__control-radio[type='radio'][value='emoji']")[
          "checked"
        ],
      ).to eq(nil)
    end

    it "can edit the settings of the ideas category in a tab" do
      visit("/c/#{category.slug}/edit/ideas")

      form.field("category_type_site_settings.topic_voting_show_who_voted").toggle

      banner.click_save
      expect(toast).to have_success(I18n.t("js.saved"))

      expect(SiteSetting.topic_voting_show_who_voted).to eq(false)
    end

    it "hides vote limit settings when limit member votes is unchecked" do
      visit("/c/#{category.slug}/edit/ideas")

      expect(page).to have_field("category_type_site_settings.topic_voting_tl0_vote_limit")

      form.field("category_type_site_settings.topic_voting_enable_vote_limits").toggle

      expect(page).to have_no_field("category_type_site_settings.topic_voting_tl0_vote_limit")
      expect(page).to have_no_field("category_type_site_settings.topic_voting_alert_votes_left")
    end
  end

  context "when visiting the Ideas tab for a non-ideas category" do
    fab!(:category)

    it "shows the not ideas type message" do
      visit("/c/#{category.slug}/edit/ideas")
      expect(page).to have_content(I18n.t("js.topic_voting.category_type_ideas.not_ideas_type"))
    end
  end
end
