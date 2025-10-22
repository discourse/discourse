# frozen_string_literal: true

RSpec.describe "Chat message onebox", type: :system do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  fab!(:current_user, :user)
  fab!(:channel_1, :category_channel)

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when sending a message with a link" do
    before do
      SiteSetting.enable_inline_onebox_on_all_domains = true

      full_onebox_html = <<~HTML.chomp
        <aside class="onebox wikipedia" data-onebox-src="https://en.wikipedia.org/wiki/Hyperlink">
          <article class="onebox-body">
            <p>This is a test</p>
          </article>
        </aside>
      HTML

      inline_onebox_html = <<~HTML.chomp
        <a class="inline-onebox" href="https://example.com">example.com</a>
      HTML

      Oneboxer
        .stubs(:cached_onebox)
        .with("https://en.wikipedia.org/wiki/Hyperlink")
        .returns(full_onebox_html)

      Oneboxer.stubs(:cached_onebox).with("https://example.com").returns(inline_onebox_html)

      stub_request(:get, "https://en.wikipedia.org/wiki/Hyperlink").to_return(
        status: 200,
        body: "<html><head><title>a</title></head></html>",
      )

      stub_request(:get, "https://example.com").to_return(
        status: 200,
        body: "<html><head><title>b</title></head></html>",
      )
    end

    it "is oneboxed" do
      chat_page.visit_channel(channel_1)
      channel_page.send_message("https://en.wikipedia.org/wiki/Hyperlink")

      expect(page).to have_content("This is a test", wait: 20)
    end

    it "is inline oneboxed with _blank target attribute" do
      chat_page.visit_channel(channel_1)
      channel_page.send_message("test message - https://example.com")

      expect(page).to have_selector(".chat-cooked a[target='_blank']", text: "example.com")
    end
  end
end
