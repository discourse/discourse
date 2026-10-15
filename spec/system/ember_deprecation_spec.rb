# frozen_string_literal: true

describe "JS Deprecation Handling" do
  it "can successfully print a deprecation message after applying production-mode shims" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator("#main-outlet-wrapper").filter(visible: true),
    ).to PlaywrightMatchers.be_visible

    # Intercept console.warn so we can enumerate calls later
    browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
      window.intercepted_warnings = [];
      console.warn = (msg) => window.intercepted_warnings.push([msg, (new Error()).stack])
    JS

    warn_calls = nil
    browser_page.then { |playwright_page| warn_calls = playwright_page.evaluate <<~JS }
        () => {
          const { deprecate } = require('@ember/debug');
          deprecate("Some message", false, { id: "fake.deprecation", for: "discourse", since: "3.4.0", until: "3.5.0" });
          return window.intercepted_warnings;
        }
      JS

    expect(warn_calls.size).to eq(1)
    call, backtrace = warn_calls[0]

    expect(call).to start_with("DEPRECATION: Some message [deprecation id: fake.deprecation]")
  end

  it "shows warnings to admins for critical deprecations" do
    sign_in Fabricate(:admin)

    SiteSetting.warn_critical_js_deprecations = true
    SiteSetting.warn_critical_js_deprecations_message =
      "Discourse core changes will be applied to your site on Jan 15."

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator("#site-logo").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)

    browser_page.evaluate("function(arguments) { #{<<~JS} }", arg: [])
      const deprecated = require("discourse/lib/deprecated").default;
      deprecated("Fake deprecation message", { id: "fake.deprecation1" })
      deprecated("Other fake deprecation message", { id: "fake.deprecation2" })
    JS

    message =
      browser_root.locator("#global-notice-critical-deprecation--fake-deprecation1").filter(
        visible: true,
      )
    expect(message).to PlaywrightMatchers.contain_text(
      browser_text_pattern("One of your themes or plugins contains code which needs updating"),
      useInnerText: true,
    )
    expect(message).to PlaywrightMatchers.contain_text(
      browser_text_pattern("fake.deprecation1"),
      useInnerText: true,
    )
    expect(message).to PlaywrightMatchers.contain_text(
      browser_text_pattern(SiteSetting.warn_critical_js_deprecations_message),
      useInnerText: true,
    )

    message =
      browser_root.locator("#global-notice-critical-deprecation--fake-deprecation2").filter(
        visible: true,
      )
    expect(message).to PlaywrightMatchers.contain_text(
      browser_text_pattern("One of your themes or plugins contains code which needs updating"),
      useInnerText: true,
    )
    expect(message).to PlaywrightMatchers.contain_text(
      browser_text_pattern("fake.deprecation2"),
      useInnerText: true,
    )
    expect(message).to PlaywrightMatchers.contain_text(
      browser_text_pattern(SiteSetting.warn_critical_js_deprecations_message),
      useInnerText: true,
    )
  end

  it "emits ember-this-fallback deprecation for theme .hbs connectors using property fallback",
     expected_js_deprecations: %w[ember-this-fallback.this-property-fallback] do
    t = Fabricate(:theme, name: "Theme With Hbs Connector")
    t.set_field(
      target: :extra_js,
      name: "discourse/connectors/below-footer/my-connector.hbs",
      value: "{{someProperty}}",
    )
    t.save!
    SiteSetting.default_theme_id = t.id

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator("#main-outlet-wrapper").filter(visible: true),
    ).to PlaywrightMatchers.be_visible

    try_until_success do
      expect(
        $playwright_logger.logs.any? do |log|
          log[:message].include?("ember-this-fallback.this-property-fallback")
        end,
      ).to eq(true)
    end
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
          deprecated("Fake deprecation message", { id: "fake.deprecation" })
        }
        export default <template>
          {{triggerDeprecation}}
        </template>
      JS
    )
    t.save!
    SiteSetting.default_theme_id = t.id

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator("#global-notice-critical-deprecation--fake-deprecation").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it "shows warnings for Discourse and Ember deprecations triggered before the handler is set up" do
    sign_in Fabricate(:admin)

    SiteSetting.warn_critical_js_deprecations = true

    t = Fabricate(:theme, name: "Theme With Early Deprecations")
    t.set_field(
      target: :extra_js,
      type: :js,
      name: "discourse/api-initializers/trigger-early-deprecations.js",
      value: <<~JS,
        import { deprecate } from "@ember/debug";
        import { apiInitializer } from "discourse/lib/api";
        import deprecated from "discourse/lib/deprecated";

        // Both fire during boot, before the admin-banner handler exists.
        deprecated("Fake deprecation message", { id: "fake.deprecation1" });
        deprecate("Fake ember deprecation message", false, {
          id: "fake.deprecation2",
          for: "discourse",
          since: "3.4.0",
          until: "3.5.0",
        });

        export default apiInitializer(() => {});
      JS
    )
    t.save!
    SiteSetting.default_theme_id = t.id

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator("#global-notice-critical-deprecation--fake-deprecation1").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator("#global-notice-critical-deprecation--fake-deprecation2").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)
  end
end
