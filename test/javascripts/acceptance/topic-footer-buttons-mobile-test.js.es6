import selectKit from "helpers/select-kit-helper";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import { acceptance } from "helpers/qunit-helpers";

let _test;

acceptance("Topic footer buttons mobile", {
  loggedIn: true,
  mobileView: true,
  beforeEach() {
    I18n.translations[I18n.locale].js.test = {
      title: "My title",
      label: "My Label"
    };

    withPluginApi("0.8.28", api => {
      api.registerTopicFooterButton({
        id: "my-button",
        icon: "user",
        label: "test.label",
        title: "test.title",
        dropdown: true,
        action() {
          _test = 2;
        }
      });
    });
  },

  afterEach() {
    clearTopicFooterButtons();
    _test = undefined;
  }
});

QUnit.test("default", async assert => {
  await visit("/t/internationalization-localization/280");

  assert.equal(_test, null);

  const subject = selectKit(".topic-footer-mobile-dropdown");
  await subject.expand();
  await subject.selectRowByValue("my-button");

  assert.equal(_test, 2);
});
