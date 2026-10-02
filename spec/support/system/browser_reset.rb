# frozen_string_literal: true
module SystemBrowserReset
  def self.soft_reset(browser:, downloaded:)
    contexts = browser.contexts
    return unless contexts.size == 1
    return if downloaded

    context = contexts.first
    context.pages.each(&:close)
    page = yield context
    return if page.evaluate("() => setTimeout.toString()").exclude?("[native code]")

    clear_storage(page)
    context.clear_permissions
    page.bring_to_front
    page
  end

  def self.clear_storage(page)
    session = page.context.new_cdp_session(page)
    session.send_message("Storage.clearDataForOrigin", params: { origin: "*", storageTypes: "all" })
  ensure
    session&.detach
  end

  private_class_method :clear_storage
end
