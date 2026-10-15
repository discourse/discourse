# frozen_string_literal: true

describe "Theme qunit testing" do
  let!(:theme_without_tests) { Fabricate(:theme, name: "no-tests-guy") }
  let!(:theme_with_test) do
    t = Fabricate(:theme, name: "Theme With Tests")
    t.set_field(target: :tests_js, type: :js, name: "acceptance/some-test.js", value: <<~JS)
        import { module, test } from "qunit";
        
        module("theme test", function () {
          test("it works", function (assert) {
            assert.true(true)
          });
        });
      JS
    t.build_remote_theme(remote_url: "https://example.com/mytheme")
    t.save!
    t
  end

  it "lists themes and can run tests by id, name and url" do
    browser_page.goto("/theme-qunit").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator("a[href^='/theme-qunit?id=']").filter(visible: true),
    ).to PlaywrightMatchers.have_count(1)

    browser_root
      .locator("a[href=\"/theme-qunit?id=#{theme_with_test.id}\"]")
      .filter(visible: true)
      .click

    success_count =
      browser_root
        .locator("#qunit-testresult-display .passed")
        .filter(visible: true)
        .inner_text
        .strip
    expect(success_count).to eq("1")

    browser_page
      .goto("/theme-qunit?name=#{theme_with_test.name}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    success_count =
      browser_root
        .locator("#qunit-testresult-display .passed")
        .filter(visible: true)
        .inner_text
        .strip
    expect(success_count).to eq("1")

    browser_page
      .goto("/theme-qunit?url=#{theme_with_test.remote_theme.remote_url}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    success_count =
      browser_root
        .locator("#qunit-testresult-display .passed")
        .filter(visible: true)
        .inner_text
        .strip
    expect(success_count).to eq("1")
  end
end
