# frozen_string_literal: true

RSpec.describe "Post Voting Category Settings" do
  fab!(:admin)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before { sign_in(admin) }

  context "when simplified category creation is enabled" do
    before { SiteSetting.enable_simplified_category_creation = true }

    it "can toggle post voting custom fields via FormKit" do
      category_page.visit_settings(category)

      form.field("custom_fields.create_as_post_voting_default").toggle
      form.field("custom_fields.only_post_voting_in_this_category").toggle
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      category.reload
      expect(category.custom_fields["create_as_post_voting_default"]).to eq(true)
      expect(category.custom_fields["only_post_voting_in_this_category"]).to eq(true)
    end
  end

  context "when simplified category creation is disabled" do
    before { SiteSetting.enable_simplified_category_creation = false }

    it "can toggle post voting custom fields via legacy form" do
      category_page.visit_settings(category)

      find("#create-as-post-voting-default").click
      find("#only-post-voting-in-this-category").click
      category_page.save_settings

      expect(toasts).to have_success(I18n.t("js.saved"))
      category.reload
      expect(category.custom_fields["create_as_post_voting_default"]).to eq(true)
      expect(category.custom_fields["only_post_voting_in_this_category"]).to eq(true)
    end
  end
end
