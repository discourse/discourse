# frozen_string_literal: true

describe "JS Deprecation Handling", type: :system do
  it "can successfully print a deprecation message after applying production-mode shims" do
    visit("/latest")
    expect(find("#main-outlet-wrapper")).to be_visible

    # Intercept console.warn so we can enumerate calls later
    page.execute_script <<~JS
      window.intercepted_warnings = [];
      console.warn = (msg) => window.intercepted_warnings.push([msg, (new Error()).stack])
    JS

    # Trigger a deprecation, then return the console.warn calls
    warn_calls = page.execute_script <<~JS
      const { deprecate } = require('@ember/debug');
      deprecate("Some message", false, { id: "some.id", for: "discourse", since: "3.4.0", until: "3.5.0" });
      return window.intercepted_warnings
    JS

    expect(warn_calls.size).to eq(1)
    call, backtrace = warn_calls[0]

    expect(call).to start_with("DEPRECATION: Some message [deprecation id: some.id]")
  end

  it "shows warnings to admins for critical deprecations" do
    sign_in Fabricate(:admin)

    SiteSetting.warn_critical_js_deprecations = true
    SiteSetting.warn_critical_js_deprecations_message =
      "Discourse core changes will be applied to your site on Jan 15."

    visit("/latest")

    page.execute_script <<~JS
      const deprecated = require("discourse/lib/deprecated").default;
      deprecated("Fake deprecation message", { id: "fake-deprecation" })
    JS

    message = find("#global-notice-critical-deprecation")
    expect(message).to have_text(
      "One of your themes or plugins needs updating for compatibility with upcoming Discourse core changes",
    )
    expect(message).to have_text(SiteSetting.warn_critical_js_deprecations_message)
  end

  it "can show warnings triggered during initial render" do
    sign_in Fabricate(:admin)

    t = Fabricate(:theme, name: "Theme With Tests")
    t.set_field(
      target: :extra_js,
      type: :js,
      name: "discourse/connectors/below-footer/my-connector.gjs",
      value: <<~JS,
        import deprecated from "discourse/lib/deprecated";
        function triggerDeprecation(){
          deprecated("Fake deprecation message", { id: "fake-deprecation" })
        }
        export default <template>
          {{triggerDeprecation}}
        </template>
      JS
    )
    t.save!
    SiteSetting.default_theme_id = t.id

    visit "/latest"

    expect(page).to have_css("#global-notice-critical-deprecation")
  end
end
