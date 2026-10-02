# frozen_string_literal: true
RSpec.describe "Teardown fault isolation", type: :system, order: :defined do
  [false, true].each do |native|
    context "with native=#{native}", native_playwright: native, order: :defined do
      it "emits a fatal deprecation after establishing browser state" do
        user = Fabricate(:user, username: "cleanup_fault_user")
        sign_in(user)
        if native
          browser_page.goto("/latest")
          expect(browser_page.locator(".header-dropdown-toggle.current-user:visible")).to be_visible
          playwright_page = browser_page
        else
          visit("/latest")
          expect(page).to have_css(".header-dropdown-toggle.current-user")
          page.driver.with_playwright_page { |current_page| playwright_page = current_page }
        end
        fatal_logged = false
        playwright_page.on(
          "console",
          ->(message) { fatal_logged = true if message.type == "trace" },
        )
        playwright_page.evaluate(
          '() => { localStorage.setItem("cleanup-fault", "previous"); console.trace("fatal_deprecation:" + JSON.stringify("cleanup fault injection")); }',
        )
        wait_for { fatal_logged }
      end

      it "starts the next example with a fresh page" do
        if native
          expect(browser_page.url).to eq("about:blank")
        else
          page.driver.with_playwright_page do |current_page|
            expect(current_page.url).to eq("about:blank")
          end
        end
        expect(User.exists?(username: "cleanup_fault_user")).to eq(false)
        if native
          browser_page.goto("/latest")
          expect(
            browser_page.locator(".header-dropdown-toggle.current-user:visible"),
          ).to have_count(0)
          expect(
            browser_page.evaluate('() => localStorage.getItem("cleanup-fault") === null'),
          ).to eq(true)
        else
          visit("/latest")
          expect(page).to have_no_css(".header-dropdown-toggle.current-user")
          expect(page.evaluate_script('localStorage.getItem("cleanup-fault") === null')).to eq(true)
        end
      end
    end
  end
end
