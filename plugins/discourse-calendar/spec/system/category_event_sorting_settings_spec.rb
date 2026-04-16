# frozen_string_literal: true

RSpec.describe "Event Sorting Category Settings" do
  fab!(:admin)
  fab!(:category)

  let(:category_page) { PageObjects::Pages::Category.new }
  let(:form) { PageObjects::Components::FormKit.new(".form-kit") }
  let(:banner) { PageObjects::Components::AdminChangesBanner.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.sort_categories_by_event_start_date_enabled = true
    SiteSetting.disable_resorting_on_categories_enabled = true
    sign_in(admin)
  end

  context "when simplified category creation is enabled" do
    before { SiteSetting.enable_simplified_category_creation = true }

    it "can toggle event sorting custom fields via FormKit" do
      category_page.visit_settings(category)

      form.field("custom_fields.sort_topics_by_event_start_date").toggle
      form.field("custom_fields.disable_topic_resorting").toggle
      banner.click_save

      expect(toasts).to have_success(I18n.t("js.saved"))
      category.reload
      expect(category.custom_fields["sort_topics_by_event_start_date"]).to eq(true)
      expect(category.custom_fields["disable_topic_resorting"]).to eq(true)
    end
  end

  context "when simplified category creation is disabled" do
    before { SiteSetting.enable_simplified_category_creation = false }

    it "can toggle event sorting custom fields via legacy form" do
      category_page.visit_settings(category)

      find("#sort-topics-by-event-start-date").click
      find("#disable-topic-resorting").click
      category_page.save_settings

      expect(toasts).to have_success(I18n.t("js.saved"))
      category.reload
      expect(category.custom_fields["sort_topics_by_event_start_date"]).to eq(true)
      expect(category.custom_fields["disable_topic_resorting"]).to eq(true)
    end
  end
end
