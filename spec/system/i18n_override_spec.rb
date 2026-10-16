# frozen_string_literal: true

describe "I18n translation overrides" do
  describe "module-scope i18n() lookups" do
    fab!(:theme) { Fabricate(:theme, name: "Test Theme") }
    fab!(:translation_override) do
      TranslationOverride.upsert!("en", "js.topic.create", "Overridden at module scope")
    end

    before do
      theme.set_field(
        target: :extra_js,
        type: :js,
        name: "discourse/connectors/below-footer/i18n-test-connector.gjs",
        value: <<~JS,
          import { i18n } from "discourse-i18n";

          const translatedString = i18n("topic.create");

          export default <template>
            <div class="i18n-test-output">{{translatedString}}</div>
          </template>
        JS
      )
      theme.save!
      SiteSetting.default_theme_id = theme.id
    end

    it "applies translation overrides to module-scope i18n() calls" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator(".i18n-test-output").filter(visible: true)).to contain_text(
        [browser_text_pattern("Overridden at module scope")],
        useInnerText: true,
      )
    end
  end

  describe "overrides" do
    before do
      TranslationOverride.upsert!("en", "js.dates.tiny.half_a_minute", "override for js key")
      TranslationOverride.upsert!("en", "admin_js.admin.title", "override for admin_js key")
    end

    it "applies overrides to js and admin_js keys" do
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      js_result =
        browser_page.evaluate(
          "function(arguments) { return I18n.t('dates.tiny.half_a_minute') }",
          arg: [],
        )
      expect(js_result).to eq("override for js key")

      admin_js_result =
        browser_page.evaluate("function(arguments) { return I18n.t('admin.title') }", arg: [])
      expect(admin_js_result).to eq("override for admin_js key")
    end
  end

  describe "fallback locale behavior" do
    fab!(:user) { Fabricate(:user, locale: "de") }

    before do
      TranslationOverride.upsert!("de", "js.dates.tiny.half_a_minute", "de override")
      # Override in fallback locale (en) for a key that exists in both
      TranslationOverride.upsert!("en", "js.dates.tiny.x_minutes.one", "en override")
    end

    it "applies override from user locale and prefers user locale translation over fallback override" do
      sign_in(user)
      browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      # Override in user's locale is applied
      de_override =
        browser_page.evaluate(
          "function(arguments) { return I18n.t('dates.tiny.half_a_minute') }",
          arg: [],
        )
      expect(de_override).to eq("de override")

      # User locale translation is preferred over fallback locale override
      # (de has this key, so en override should not be used)
      fallback_result =
        browser_page.evaluate(
          "function(arguments) { return I18n.t('dates.tiny.x_minutes', { count: 1 }) }",
          arg: [],
        )
      expect(fallback_result).not_to eq("en override")
    end
  end
end
