# frozen_string_literal: true

RSpec.describe "Support Category Type Setup" do
  fab!(:admin)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_type_card) { PageObjects::Components::CategoryTypeCard.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toast) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.enable_simplified_category_creation = true
    SiteSetting.enable_support_category_type_setup = true
    sign_in(admin)
  end

  it "works with correct defaults and configures site settings and category custom field automatically" do
    visit("/new-category/setup")
    category_type_card.find_type_card("support").click
    expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "support"))

    # Preload basic data for this category type
    expect(form.field("name").value).to eq("Support")
    expect(
      form.field("style_type").find(".form-kit__control-radio[type='radio'][value='emoji']")[
        "checked"
      ],
    ).to eq(true)
    expect(form.field("style_type").find("#control-emoji").find("img.emoji")["title"]).to eq(
      "red_question_mark",
    )

    expect(banner).to be_visible
    banner.click_save

    expect(page).to have_content(I18n.t("js.category.edit_dialog_title", categoryName: "Support"))
    expect(page).to have_css(".d-nav-submenu__tabs .edit-category-support")
    expect(SiteSetting.solved_enabled).to eq(true)
    expect(SiteSetting.show_filter_by_solved_status).to eq(true)
    category = Category.find_by(name: "Support")
    expect(category.custom_fields["enable_accepted_answers"]).to eq("true")
    expect(category.custom_fields["solved_topics_auto_close_hours"]).to eq("48")
    expect(category.custom_fields["notify_on_staff_accept_solved"]).to eq("true")
    expect(category.custom_fields["empty_box_on_unsolved"]).to eq("true")
  end

  context "when the support category type setup is disabled" do
    before { SiteSetting.enable_support_category_type_setup = false }

    it "does not show the support category type" do
      visit("/new-category/setup")
      expect(page).not_to have_content(I18n.t("js.category.create_with_type", typeName: "support"))
      expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "discussion"))
    end

    it "does not show the tab for the support category type when editing an existing category" do
      support_category = Fabricate(:category, name: "Support")
      DiscourseSolved::Categories::Types::Support.configure_category(
        support_category,
        guardian: admin.guardian,
      )
      visit("/c/#{support_category.slug}/edit/support")
      expect(page).to have_no_css(".d-nav-submenu__tabs .edit-category-support")
    end
  end

  context "when there is a support category already configured" do
    fab!(:category)

    before do
      DiscourseSolved::Categories::Types::Support.configure_category(
        category,
        guardian: admin.guardian,
      )
    end

    it "does not preload basic data for the support category type" do
      visit("/new-category/setup")
      category_type_card.find_type_card("support").click

      expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "support"))
      expect(form.field("name").value).to eq("")
      expect(
        form.field("style_type").find(".form-kit__control-radio[type='radio'][value='emoji']")[
          "checked"
        ],
      ).to eq(nil)
    end

    it "can edit the settings of the support category in a tab" do
      visit("/c/#{category.slug}/edit/support")

      expect(
        form
          .field("custom_fields.solved_topics_auto_close_hours")
          .component
          .find("input.relative-time-duration")
          .value,
      ).to eq("2")
      expect(form.field("custom_fields.notify_on_staff_accept_solved").value).to be_truthy
      expect(form.field("custom_fields.empty_box_on_unsolved").value).to be_truthy

      form.field("custom_fields.notify_on_staff_accept_solved").toggle
      form.field("custom_fields.empty_box_on_unsolved").toggle
      form
        .field("custom_fields.solved_topics_auto_close_hours")
        .component
        .find("input.relative-time-duration")
        .fill_in(with: "3")
      form.field("category_type_site_settings.show_who_marked_solved").toggle

      banner.click_save
      expect(toast).to have_success(I18n.t("js.saved"))
      category.reload

      expect(category.custom_fields["notify_on_staff_accept_solved"]).to eq("false")
      expect(category.custom_fields["empty_box_on_unsolved"]).to eq("false")
      expect(category.custom_fields["solved_topics_auto_close_hours"]).to eq("72")
      expect(SiteSetting.show_who_marked_solved).to eq(true)
    end

    it "can remove the support type from the category" do
      visit("/c/#{category.slug}/edit/support")
      page.find(".support-category--danger-zone .support-category__remove-type").click
      expect(dialog).to have_content(
        I18n.t("js.solved.category_type_support.confirm_remove_support_type"),
      )
      dialog.click_yes
      expect(toast).to have_success(I18n.t("js.saved"))
      expect(page).to have_css(".edit-category-general.active")
      expect(page).to have_current_path("/c/#{category.slug}/edit/general")
      expect(category.reload.custom_fields["enable_accepted_answers"]).to eq("false")
    end
  end

  context "when visiting the Support tab for a non-support category" do
    fab!(:category)

    it "shows the not support type message" do
      visit("/c/#{category.slug}/edit/support")
      expect(page).to have_content(I18n.t("js.solved.category_type_support.not_support_type"))
    end
  end
end
