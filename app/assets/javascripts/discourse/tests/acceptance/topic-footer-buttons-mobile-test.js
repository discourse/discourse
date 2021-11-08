import I18n from "I18n";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { clearTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { withPluginApi } from "discourse/lib/plugin-api";

let _test;

acceptance("Topic footer buttons mobile", function (needs) {
  needs.user();
  needs.mobileView();

  needs.hooks.beforeEach(() => {
    I18n.translations[I18n.locale].js.test = {
      title: "My title",
      label: "My Label",
    };

    withPluginApi("0.8.28", (api) => {
      api.registerTopicFooterButton({
        id: "my-button",
        icon: "user",
        label: "test.label",
        title: "test.title",
        dropdown: true,
        action() {
          _test = 2;
        },
      });
    });
  });

  needs.hooks.afterEach(() => {
    clearTopicFooterButtons();
    _test = undefined;
  });

  test("default", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.strictEqual(_test, undefined);

    const subject = selectKit(".topic-footer-mobile-dropdown");
    await subject.expand();
    await subject.selectRowByValue("my-button");

    assert.strictEqual(_test, 2);
  });
});
