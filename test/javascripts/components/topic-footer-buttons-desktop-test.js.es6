import { withPluginApi } from "discourse/lib/plugin-api";
import componentTest from "helpers/component-test";
import Topic from "discourse/models/topic";
import { clearTopicFooterButtons } from "discourse/lib/register-topic-footer-button";

const buildTopic = function() {
  return Topic.create({
    id: 1234,
    title: "Qunit Test Topic"
  });
};

moduleForComponent("topic-footer-buttons-desktop", {
  integration: true,
  beforeEach() {
    I18n.translations[I18n.locale].js.test = {
      title: "My title",
      label: "My Label"
    };
  },

  afterEach() {
    clearTopicFooterButtons();
  }
});

componentTest("default", {
  template: "{{topic-footer-buttons topic=topic}}",
  beforeEach() {
    withPluginApi("0.8.28", api => {
      api.registerTopicFooterButton({
        id: "my-button",
        icon: "user",
        label: "test.label",
        title: "test.title"
      });
    });

    this.set("topic", buildTopic());
  },
  async test(assert) {
    const button = await find("#topic-footer-button-my-button");
    assert.ok(exists(button), "it creates an inline button");

    const icon = await button.find(".d-icon-user");
    assert.ok(exists(icon), "the button has the correct icon");

    const label = await button.find(".d-button-label");
    assert.ok(exists(label), "the button has a label");
    assert.equal(
      label.text(),
      I18n.t("test.label"),
      "the button has the correct label"
    );

    const title = button.attr("title");
    assert.equal(
      title,
      I18n.t("test.title"),
      "the button has the correct title"
    );
  }
});

componentTest("priority", {
  template: "{{topic-footer-buttons topic=topic}}",
  beforeEach() {
    withPluginApi("0.8.28", api => {
      api.registerTopicFooterButton({
        id: "my-second-button",
        priority: 750,
        icon: "user"
      });

      api.registerTopicFooterButton({
        id: "my-third-button",
        priority: 500,
        icon: "flag"
      });

      api.registerTopicFooterButton({
        id: "my-first-button",
        priority: 1000,
        icon: "times"
      });
    });

    this.set("topic", buildTopic());
  },
  async test(assert) {
    const buttons = await find(".topic-footer-button");
    const firstButton = find("#topic-footer-button-my-first-button");
    const secondButton = find("#topic-footer-button-my-second-button");
    const thirdButton = find("#topic-footer-button-my-third-button");

    assert.ok(buttons.index(firstButton) < buttons.index(secondButton));
    assert.ok(buttons.index(secondButton) < buttons.index(thirdButton));
  }
});

componentTest("with functions", {
  template: "{{topic-footer-buttons topic=topic}}",
  beforeEach() {
    withPluginApi("0.8.28", api => {
      api.registerTopicFooterButton({
        id: "my-button",
        icon() {
          return "user";
        },
        label() {
          return "test.label";
        },
        title() {
          return "test.title";
        }
      });
    });

    this.set("topic", buildTopic());
  },
  async test(assert) {
    const button = await find("#topic-footer-button-my-button");
    assert.ok(exists(button), "it creates an inline button");

    const icon = await button.find(".d-icon-user");
    assert.ok(exists(icon), "the button has the correct icon");

    const label = await button.find(".d-button-label");
    assert.ok(exists(label), "the button has a label");
    assert.equal(
      label.text(),
      I18n.t("test.label"),
      "the button has the correct label"
    );

    const title = button.attr("title");
    assert.equal(
      title,
      I18n.t("test.title"),
      "the button has the correct title"
    );
  }
});

componentTest("action", {
  template: "<div id='test-action'></div>{{topic-footer-buttons topic=topic}}",
  beforeEach() {
    withPluginApi("0.8.28", api => {
      api.registerTopicFooterButton({
        id: "my-button",
        icon: "flag",
        action() {
          $("#test-action").text(this.get("topic.title"));
        }
      });
    });

    this.set("topic", buildTopic());
  },
  async test(assert) {
    await click("#topic-footer-button-my-button");

    assert.equal(find("#test-action").text(), this.get("topic.title"));
  }
});

componentTest("dropdown", {
  template: "{{topic-footer-buttons topic=topic}}",
  beforeEach() {
    withPluginApi("0.8.28", api => {
      api.registerTopicFooterButton({
        id: "my-button",
        icon: "flag",
        dropdown: true
      });
    });

    this.set("topic", buildTopic());
  },
  async test(assert) {
    const button = await find("#topic-footer-button-my-button");
    assert.notOk(exists(button), "it doesn’t create an inline button");
  }
});
