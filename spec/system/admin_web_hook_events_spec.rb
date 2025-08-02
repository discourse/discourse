# frozen_string_literal: true

describe "Admin WebHook Events", type: :system do
  fab!(:web_hook)
  fab!(:admin)
  fab!(:web_hook_event1) { Fabricate(:web_hook_event, web_hook: web_hook, status: 200) }
  fab!(:web_hook_event2) { Fabricate(:web_hook_event, web_hook: web_hook, status: 404) }

  let(:admin_web_hooks_page) { PageObjects::Pages::AdminWebHookEvents.new }

  before { sign_in(admin) }

  it "shows all webhook events when filter is on 'All Events'" do
    admin_web_hooks_page.visit(web_hook.id)

    expect(admin_web_hooks_page).to have_web_hook_event(web_hook_event1.id)
    expect(admin_web_hooks_page).to have_web_hook_event(web_hook_event2.id)
  end

  it "shows only successfully delivered webhook events when filter is on 'Delivered'" do
    admin_web_hooks_page.visit(web_hook.id)
    admin_web_hooks_page.click_filter_all
    admin_web_hooks_page.click_filter_delivered

    expect(admin_web_hooks_page).to have_web_hook_event(web_hook_event1.id)
    expect(admin_web_hooks_page).to have_no_web_hook_event(web_hook_event2.id)
  end

  it "shows only webhook events that are failed to deliver when filter is on 'Failed'" do
    admin_web_hooks_page.visit(web_hook.id)
    admin_web_hooks_page.click_filter_all
    admin_web_hooks_page.click_filter_failed

    expect(admin_web_hooks_page).to have_no_web_hook_event(web_hook_event1.id)
    expect(admin_web_hooks_page).to have_web_hook_event(web_hook_event2.id)
  end
end
