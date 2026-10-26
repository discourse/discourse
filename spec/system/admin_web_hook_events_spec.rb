# frozen_string_literal: true

describe "Admin WebHook Events" do
  fab!(:web_hook)
  fab!(:admin)
  fab!(:web_hook_event1) { Fabricate(:web_hook_event, web_hook: web_hook, status: 200) }
  fab!(:web_hook_event2) { Fabricate(:web_hook_event, web_hook: web_hook, status: 404) }

  let(:admin_web_hooks_page) { PageObjects::Pages::AdminWebHookEvents.new }

  before { sign_in(admin) }

  it "lets the admin filter all, delivered and failed webhook events" do
    admin_web_hooks_page.visit(web_hook.id)

    aggregate_failures "all events" do
      expect(admin_web_hooks_page).to have_web_hook_event(web_hook_event1.id)
      expect(admin_web_hooks_page).to have_web_hook_event(web_hook_event2.id)
    end

    admin_web_hooks_page.click_filter_all
    admin_web_hooks_page.click_filter_delivered

    aggregate_failures "delivered events" do
      expect(admin_web_hooks_page).to have_web_hook_event(web_hook_event1.id)
      expect(admin_web_hooks_page).to have_no_web_hook_event(web_hook_event2.id)
    end

    admin_web_hooks_page.expand_filter
    admin_web_hooks_page.click_filter_failed

    aggregate_failures "failed events" do
      expect(admin_web_hooks_page).to have_no_web_hook_event(web_hook_event1.id)
      expect(admin_web_hooks_page).to have_web_hook_event(web_hook_event2.id)
    end
  end
end
