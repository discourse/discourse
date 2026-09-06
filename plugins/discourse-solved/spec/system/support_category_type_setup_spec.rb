# frozen_string_literal: true

RSpec.describe "Support Category Type Setup" do
  fab!(:admin)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_type_card) { PageObjects::Components::CategoryTypeCard.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toast) { PageObjects::Components::Toasts.new }

  # The form binds site-text fields by a separator-free version of the i18n key
  # (dots and dashes aren't FormKit-safe), so derive it the same way.
  let(:shared_issue_field) { "site_texts.#{"js.solved.shared_issue.label".gsub(/\W/, "_")}" }

  before { sign_in(admin) }

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

  it "can add the support type via the selector while creating a category of another type" do
    visit("/new-category/setup")
    category_type_card.find_type_card("discussion").click
    expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "discussion"))

    form.field("name").fill_in("Discussion + Support")

    # The type selector is only available under advanced settings while creating.
    expect(page).to have_no_css(".category-type-selector")
    category_page.toggle_advanced_settings

    category_type_selector = PageObjects::Components::DMenu.new(".category-type-selector")
    category_type_selector.expand
    category_type_selector.option(".category-type-selector__result.--category-type-support").click
    banner.click_save

    expect(page).to have_css(".d-nav-submenu__tabs .edit-category-support")
    category = Category.find_by(name: "Discussion + Support")
    expect(category.category_types.keys).to include(:discussion, :support)
    expect(category.enable_accepted_answers?).to eq(true)
  end

  it "can remove the type picked on the setup screen while creating a category" do
    visit("/new-category/setup")
    category_type_card.find_type_card("support").click
    expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "support"))

    form.field("name").fill_in("No longer support")

    category_page.toggle_advanced_settings

    category_type_selector = PageObjects::Components::DMenu.new(".category-type-selector")
    category_type_selector.remove_selected_option("Support")
    banner.click_save

    expect(page).to have_no_css(".d-nav-submenu__tabs .edit-category-support")
    category = Category.find_by(name: "No longer support")
    expect(category.category_types.keys).to eq(%i[discussion])
    expect(category.enable_accepted_answers?).to eq(false)
  end

  it "is able to click the support tab when creating a new category when solved is disabled" do
    SiteSetting.solved_enabled = false
    visit("/new-category/setup")
    category_type_card.find_type_card("support").click
    expect(page).to have_content(I18n.t("js.category.create_with_type", typeName: "support"))
    expect(page).to have_css(".d-nav-submenu__tabs .edit-category-support")
  end

  context "for an existing category with no support category type" do
    fab!(:category)

    it "can add the support category type" do
      visit("/c/#{category.slug}/edit")
      category_type_selector = PageObjects::Components::DMenu.new(".category-type-selector")
      category_type_selector.expand
      category_type_selector.option(".category-type-selector__result.--category-type-support").click
      banner.click_save
      expect(page).to have_css(".nav-pills .edit-category-support")
      category.reload
      expect(category.category_types.keys).to eq(%i[discussion support])
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

    it "hides the empty box on unsolved toggle when the Horizon theme is the default" do
      Theme.horizon_theme.update_columns(enabled: true, user_selectable: true)
      SiteSetting.default_theme_id = Theme.horizon_theme.id

      visit("/c/#{category.slug}/edit/support")

      expect(form).to have_field_with_name("custom_fields.notify_on_staff_accept_solved")
      expect(form).to have_no_field_with_name("custom_fields.empty_box_on_unsolved")
    end

    it "edits the shared issue label as a translation override when enabled" do
      SiteSetting.enable_solved_shared_issues = true
      visit("/c/#{category.slug}/edit/support")

      expect(form.field("custom_fields.enable_shared_issues").value).to be_truthy
      expect(form.field(shared_issue_field).value).to eq("Me too")

      form.field(shared_issue_field).fill_in("We have this too")
      banner.click_save

      expect(form.field(shared_issue_field).value).to eq("We have this too")

      override =
        TranslationOverride.find_by(
          locale: SiteSetting.default_locale,
          translation_key: "js.solved.shared_issue.label",
        )
      expect(override.value).to eq("We have this too")
    end

    it "hides the shared issue label field when shared issues are disabled" do
      SiteSetting.enable_solved_shared_issues = true
      visit("/c/#{category.slug}/edit/support")

      expect(form).to have_field_with_name(shared_issue_field)

      form.field("custom_fields.enable_shared_issues").toggle

      expect(form).to have_no_field_with_name(shared_issue_field)
    end

    it "can remove the support category type" do
      visit("/c/#{category.slug}/edit")
      category_type_selector = PageObjects::Components::DMenu.new(".category-type-selector")
      category_type_selector.remove_selected_option("Support")
      banner.click_save
      expect(toast).to have_success(I18n.t("js.saved"))
      expect(page).to have_no_css(".nav-pills .edit-category-support")
      category.reload
      expect(category.category_types.keys).to eq(%i[discussion])
    end
  end

  context "when visiting the Support tab for a non-support category" do
    fab!(:category)

    it "shows the not support type message" do
      visit("/c/#{category.slug}/edit/support")
      expect(page).to have_content(
        I18n.t("js.category.unknown_category_type_description", categoryType: "support"),
      )
    end
  end
end
