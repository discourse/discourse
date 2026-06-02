# frozen_string_literal: true

RSpec.describe "Events Category Type Setup" do
  fab!(:admin)

  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_type_card) { PageObjects::Components::CategoryTypeCard.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:toast) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.enable_events_category_type_setup = true
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    sign_in(admin)
  end

  it "preloads defaults and configures site settings + calendar_categories on save" do
    visit("/new-category/setup")
    category_type_card.find_type_card("events").click
    expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "events"))

    expect(form.field("name").value).to eq("Events")
    expect(
      form.field("style_type").find(".form-kit__control-radio[type='radio'][value='emoji']")[
        "checked"
      ],
    ).to eq(true)
    expect(form.field("style_type").find("#control-emoji").find("img.emoji")["title"]).to eq(
      "spiral_calendar",
    )

    expect(banner).to be_visible
    banner.click_save

    expect(page).to have_content(I18n.t("js.category.edit_dialog_title", categoryName: "Events"))
    expect(page).to have_css(".d-nav-submenu__tabs .edit-category-events")
    expect(SiteSetting.calendar_enabled).to eq(true)
    expect(SiteSetting.discourse_post_event_enabled).to eq(true)

    category = Category.find_by(name: "Events")
    expect(SiteSetting.events_calendar_categories.split("|")).to include(category.id.to_s)
    expect(SiteSetting.calendar_categories).to include(
      "categoryId=#{category.id};weekends=true;defaultView=month",
    )
  end

  context "when the events category type setup is disabled" do
    before { SiteSetting.enable_events_category_type_setup = false }

    it "does not show the events category type" do
      visit("/new-category/setup")
      expect(page).to have_no_css(".category-type-cards__card.--category-type-events")
    end

    it "does not show the tab for the events category type when editing an existing category" do
      events_category = Fabricate(:category, name: "Events")
      DiscourseCalendar::Categories::Types::Events.configure_category(
        events_category,
        guardian: admin.guardian,
      )
      visit("/c/#{events_category.slug}/edit/events")
      expect(page).to have_no_css(".d-nav-submenu__tabs .edit-category-events")
    end
  end

  context "when there is an events category already configured" do
    fab!(:category)

    before do
      DiscourseCalendar::Categories::Types::Events.configure_category(
        category,
        guardian: admin.guardian,
      )
    end

    it "does not preload basic data for the events category type" do
      visit("/new-category/setup")
      category_type_card.find_type_card("events").click

      expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "events"))
      expect(form.field("name").value).to eq("")
      expect(
        form.field("style_type").find(".form-kit__control-radio[type='radio'][value='emoji']")[
          "checked"
        ],
      ).to eq(nil)
    end

    it "persists category_settings edits (Default calendar view, Display weekends)" do
      visit("/c/#{category.slug}/edit/events")

      form.field("category_type_settings.events_calendar_default_view").select("week")
      form.field("category_type_settings.events_calendar_display_weekends").toggle

      banner.click_save
      expect(toast).to have_success(I18n.t("js.saved"))

      expect(SiteSetting.calendar_categories).to include(
        "categoryId=#{category.id};weekends=false;defaultView=week",
      )
    end

    it "preloads stored category_settings values onto the edit form" do
      DiscourseCalendar::Categories::Types::Events.configure_category(
        category,
        guardian: admin.guardian,
        configuration_values: {
          events_calendar_default_view: "year",
          events_calendar_display_weekends: false,
        },
      )

      visit("/c/#{category.slug}/edit/events")

      expect(form.field("category_type_settings.events_calendar_default_view").value).to eq("year")
      expect(form.field("category_type_settings.events_calendar_display_weekends").value).to eq(
        false,
      )
    end

    it "persists site_settings edits on the Events tab" do
      visit("/c/#{category.slug}/edit/events")

      form.field("category_type_site_settings.sidebar_show_upcoming_events").toggle

      banner.click_save
      expect(toast).to have_success(I18n.t("js.saved"))

      expect(SiteSetting.sidebar_show_upcoming_events).to eq(false)
    end
  end
end
