# frozen_string_literal: true

require "rails_helper"

describe "Composer category selection", type: :system do
  fab!(:moderator)
  fab!(:default_category) { Fabricate(:category, name: "Features", slug: "features") }

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before do
    SiteSetting.default_composer_category = default_category.id
    SiteSetting.open_composer_without_category = true
  end

  it "opens the composer with no category selected" do
    sign_in(moderator)
    category_page.visit(default_category)
    category_page.new_topic_button.click

    expect(composer).to be_opened

    expect(find(".category-chooser .badge-category__name").text.strip).to eq("")
  end
end
