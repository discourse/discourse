# frozen_string_literal: true

RSpec.describe "Support Category Type Setup", type: :system do
  fab!(:admin)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:category_type_card) { PageObjects::Components::CategoryTypeCard.new }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }

  before do
    SiteSetting.enable_simplified_category_creation = true
    SiteSetting.enable_category_type_setup = true
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
  end
end
