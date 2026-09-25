# frozen_string_literal: true
RSpec.describe NativeSystemDriver, type: :system do
  describe "#invalid_element_errors" do
    it "classifies a detached click target as a stale element" do
      visit "data:text/html;charset=utf-8,<button id='target'>Target</button>"
      target = page.driver.find_css("#target").first
      page.execute_script("document.querySelector('#target').remove()")

      expect { target.click }.to raise_error(NativeSystemDriver::StaleElement)
      expect { target.native.scroll_into_view_if_needed }.to raise_error(
        NativeSystemDriver::StaleElement,
      )
    end
  end
end

RSpec.describe NativeSystemDriver, type: :system do
  describe "#reset!" do
    it "leaves a page with an unload confirmation" do
      visit "data:text/html;charset=utf-8,<button id='activate'>Activate</button>"
      find("#activate").click
      page.execute_script(<<~JS)
        window.addEventListener('beforeunload', event => {
          event.preventDefault();
          event.returnValue = '';
        });
      JS

      driver = page.driver
      reset = Thread.new { driver.reset! }
      completed = reset.join(5)
      unless completed
        driver.command("Page.handleJavaScriptDialog", { accept: true })
        reset.join(5)
      end

      expect(completed).not_to eq(nil)
      expect(driver.current_url).to eq("about:blank")
    ensure
      reset&.join(5)
    end
  end
end
