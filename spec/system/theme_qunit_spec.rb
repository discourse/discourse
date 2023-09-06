# frozen_string_literal: true

describe "Theme qunit testing", type: :system do
  let!(:theme_with_test) do
    t = Fabricate(:theme, name: "My Theme")
    t.set_field(target: :tests_js, type: :js, name: "acceptance/some-test.js", value: <<~JS)
        import { module, test } from "qunit";
        
        module("theme test", function () {
          test("it works", function (assert) {
            assert.true(true)
          });
        });
      JS
    t.save!
    t
  end

  it "can run theme tests correctly" do
    visit "/theme-qunit"

    find("a[href=\"/theme-qunit?id=#{theme_with_test.id}\"]").click

    success_count = find("#qunit-testresult-display .passed").text
    expect(success_count).to eq("1")
  end
end
