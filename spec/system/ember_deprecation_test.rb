# frozen_string_literal: true

describe "Production mode debug shims", type: :system do
  it "can successfully print a deprecation message after applying prod shims" do
    visit("/latest")
    expect(find("#main-outlet-wrapper")).to be_visible

    # Intercept console.warn so we can enumerate calls later
    page.execute_script <<~JS
      window.intercepted_warnings = [];
      console.warn = (msg) => window.intercepted_warnings.push([msg, (new Error()).stack])
    JS

    # Apply deprecate shims. These are applied automatically in production
    # builds, but running a full production build for system specs would be
    # too slow
    page.execute_script <<~JS
      require("discourse/lib/deprecate-shim").applyShim();
    JS

    # Trigger a deprecation, then return the console.warn calls
    warn_calls = page.execute_script <<~JS
      const { deprecate } = require('@ember/debug');
      deprecate("Some message", false, { id: "some.id" })
      return window.intercepted_warnings
    JS

    expect(warn_calls.size).to eq(1)
    call, backtrace = warn_calls[0]

    expect(call).to eq("DEPRECATION: Some message [deprecation id: some.id]")
    expect(backtrace).to include("shimLogDeprecationToConsole")
  end
end
