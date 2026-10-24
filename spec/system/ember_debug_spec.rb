# frozen_string_literal: true

describe "JS assertions" do
  it "reports assertion failures to developers" do
    visit("/latest")

    assertion_message = page.evaluate_script <<~JS
      (() => {
        try {
          require("@ember/debug").assert("Application assertions stay enabled", false);
        } catch (error) {
          return error.message;
        }
        return null;
      })()
    JS

    expect(assertion_message).to eq("Assertion Failed: Application assertions stay enabled")
  end
end
