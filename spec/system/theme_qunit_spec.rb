# frozen_string_literal: true

describe "Theme qunit testing", type: :system do
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
    visit "/theme-qunit"

    expect(page).to have_css("a[href^='/theme-qunit?id=']", count: 1)

    find("a[href=\"/theme-qunit?id=#{theme_with_test.id}\"]").click

    success_count = find("#qunit-testresult-display .passed").text
    expect(success_count).to eq("1")

    visit "/theme-qunit?name=#{theme_with_test.name}"
    success_count = find("#qunit-testresult-display .passed").text
    expect(success_count).to eq("1")

    visit "/theme-qunit?url=#{theme_with_test.remote_theme.remote_url}"
    success_count = find("#qunit-testresult-display .passed").text
    expect(success_count).to eq("1")
  end
end
