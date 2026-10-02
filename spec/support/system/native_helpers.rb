# frozen_string_literal: true
module NativeSystemHelpers
  include Playwright::Test::Matchers

  def native_browser
    @native_browser ||= NativeSystemBrowser.for_example(RSpec.current_example)
  end

  def browser_page
    native_browser.page
  end

  def sign_in(user)
    browser_page.goto(
      File.join(
        GlobalSetting.relative_url_root || "",
        "/session/#{user.encoded_username}/become.json?redirect=false",
      ),
    )
    expect(browser_page.locator("body")).to contain_text(
      "Signed in to #{user.encoded_username} successfully",
    )
  end

  private

  def save_image
    FileUtils.mkdir_p(File.dirname(absolute_image_path))
    browser_page.screenshot(path: absolute_image_path.to_s)
  end

  def save_html
    FileUtils.mkdir_p(File.dirname(absolute_html_path))
    File.write(absolute_html_path, browser_page.content)
  end
end
