# frozen_string_literal: true

RSpec.describe "System spec page isolation", order: :defined do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:composer) { PageObjects::Components::Composer.new }

  it "leaves a draft in the open composer and browser state for teardown" do
    sign_in(user)
    visit "/about"
    topic_page.visit_topic_and_open_composer(topic)
    composer.fill_content("A draft left open at the end of the example")
    expect(composer).to be_opened

    page.execute_script(<<~JS)
      localStorage.setItem('page_reuse', 'local');
      sessionStorage.setItem('page_reuse', 'session');
      document.cookie = 'page_reuse=1; path=/';
      window.name = 'previous example';
      console.info('previous example log');
      // Ensure this exercises a real beforeunload dialog as well as the draft beacon.
      window.addEventListener('beforeunload', (event) => {
        sessionStorage.setItem('page_reuse', 'written during teardown');
        event.preventDefault();
      });
    JS
    page.driver.with_playwright_page do |pw_page|
      pw_page.mouse.move(250, 250)
      pw_page.mouse.down
      pw_page.keyboard.down("Shift")
    end
  end

  it "starts with empty storage and history and no retained input or logs" do
    expected_reset =
      if ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] == "0"
        :hard_reset
      elsif ENV["CAPYBARA_PLAYWRIGHT_REUSE_PAGE"] == "0"
        :new_tab
      else
        :reused
      end
    expect(PlaywrightSoftReset.last_result).to eq(expected_reset)
    expect(page.status_code).to eq(0)

    visit "/"
    expect(page.evaluate_script(<<~JS)).to eq([true, true, false, "", 2, ""])
      [localStorage.getItem('page_reuse') === null, sessionStorage.getItem('page_reuse') === null,
       document.cookie.includes('page_reuse='), window.name, history.length, document.referrer]
    JS
    expect($playwright_logger.logs.pluck(:message)).not_to include("previous example log")

    page.execute_script(<<~JS)
      window.addEventListener('mousemove', (event) => {
        window.reuseMouse ??= [event.clientX, event.clientY, event.buttons, event.shiftKey];
      });
    JS
    page.driver.with_playwright_page { |pw_page| pw_page.mouse.move(100, 100, steps: 2) }
    expect(page.evaluate_script("window.reuseMouse")).to eq([50, 50, 0, false])

    page.go_back
    expect(page.current_url).to eq("about:blank").or end_with(
           BlockRequestsMiddleware::BROWSER_PARK_PATH,
         )
  end

  it "uses a different viewport and timezone", timezone: "Pacific/Chatham" do
    visit "/"
    page.current_window.resize_to(900, 700)
    expect(page.evaluate_script("window.innerWidth")).to be <= 900
    expect(page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")).to eq(
      "Pacific/Chatham",
    )
  end

  it "restores the configured viewport and browser timezone" do
    expect(PlaywrightSoftReset.last_result).to eq(
      ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] == "0" ? :hard_reset : :new_tab,
    )
    if ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] != "0" && ENV["CAPYBARA_PLAYWRIGHT_REUSE_PAGE"] != "0"
      expect(PlaywrightSoftReset.last_reason).to eq(:cdp_session)
    end

    visit "/"
    expect(page.evaluate_script("window.innerWidth")).to eq(1400)
    expect(page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")).not_to eq(
      "Pacific/Chatham",
    )
  end

  it "opens a replacement tab when reset is called with requests allowed" do
    visit "/"
    page.reset!

    expect(page.current_url).to eq("about:blank")
    if ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] != "0" && ENV["CAPYBARA_PLAYWRIGHT_REUSE_PAGE"] != "0"
      expect(PlaywrightSoftReset.last_result).to eq(:new_tab)
      expect(PlaywrightSoftReset.last_reason).to eq(:requests_allowed)
    end
  end

  it "discards a tab with extra headers and a context with a timeout override" do
    visit "/"
    page.driver.with_playwright_page do |pw_page|
      pw_page.extra_http_headers = { "X-Isolation-Probe" => "set" }
    end

    BlockRequestsMiddleware.block_requests!
    page.reset!
    expect(page.current_url).to eq("about:blank")
    if ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] != "0" && ENV["CAPYBARA_PLAYWRIGHT_REUSE_PAGE"] != "0"
      expect([PlaywrightSoftReset.last_result, PlaywrightSoftReset.last_reason]).to eq(
        %i[new_tab set_extra_http_headers],
      )
    end

    BlockRequestsMiddleware.allow_requests!
    visit "/srv/status"
    context = page.driver.with_playwright_page { |pw_page| pw_page.context }
    context.default_timeout = 1000
    BlockRequestsMiddleware.block_requests!
    page.reset!
    expect(context).to be_closed
  ensure
    BlockRequestsMiddleware.allow_requests!
  end

  it "replaces the tab when the parked heap exceeds the threshold" do
    if ENV["CAPYBARA_PLAYWRIGHT_SOFT_RESET"] == "0" || ENV["CAPYBARA_PLAYWRIGHT_REUSE_PAGE"] == "0"
      skip "requires page reuse"
    end

    visit "/srv/status"
    original = page.driver.with_playwright_page { |pw_page| pw_page }
    page.execute_script("window.largeArray = Array(8_000_000).fill(42)")

    stub_const(PlaywrightSoftReset, :PARKED_HEAP_RECYCLE_THRESHOLD, 16 * 1024 * 1024) do
      BlockRequestsMiddleware.block_requests!
      page.reset!
    end

    expect([PlaywrightSoftReset.last_result, PlaywrightSoftReset.last_reason]).to eq(
      %i[new_tab recycle],
    )
    replacement = page.driver.with_playwright_page { |pw_page| pw_page }
    expect(original).to be_closed
    expect(replacement.context.pages).to eq([replacement])
    expect(page.current_url).to eq("about:blank")
  ensure
    BlockRequestsMiddleware.allow_requests!
  end

  it "rejects non-XHR requests carrying a stale example cookie" do
    url = URI("#{page.server_url}/srv/status")
    cookie = BlockRequestsMiddleware::RSPEC_CURRENT_EXAMPLE_COOKIE_STRING
    Net::HTTP.start(url.host, url.port) do |http|
      expect(http.get(url.path, "Cookie" => "#{cookie}=previous_example").code).to eq("503")
      expect(
        http.get(url.path, "Cookie" => "#{cookie}=#{RSpec.current_example.location}").code,
      ).to eq("200")
      expect(http.get(url.path).code).to eq("200")
    end
  end
end
