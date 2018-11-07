import { moduleForWidget, widgetTest } from "helpers/widget-test";
import { createWidget } from "discourse/widgets/widget";
import { withPluginApi } from "discourse/lib/plugin-api";
import hbs from "discourse/widgets/hbs-compiler";

moduleForWidget("base");

widgetTest("widget attributes are passed in via args", {
  template: `{{mount-widget widget="hello-test" args=args}}`,

  beforeEach() {
    createWidget("hello-test", {
      tagName: "div.test",
      template: hbs`Hello {{attrs.name}}`
    });

    this.set("args", { name: "Robin" });
  },

  test(assert) {
    assert.equal(this.$(".test").text(), "Hello Robin");
  }
});

widgetTest("hbs template - no tagName", {
  template: `{{mount-widget widget="hbs-test" args=args}}`,

  beforeEach() {
    createWidget("hbs-test", {
      template: hbs`<div class='test'>Hello {{attrs.name}}</div>`
    });

    this.set("args", { name: "Robin" });
  },

  test(assert) {
    assert.equal(this.$("div.test").text(), "Hello Robin");
  }
});

widgetTest("hbs template - with tagName", {
  template: `{{mount-widget widget="hbs-test" args=args}}`,

  beforeEach() {
    createWidget("hbs-test", {
      tagName: "div.test",
      template: hbs`Hello {{attrs.name}}`
    });

    this.set("args", { name: "Robin" });
  },

  test(assert) {
    assert.equal(this.$("div.test").text(), "Hello Robin");
  }
});

widgetTest("buildClasses", {
  template: `{{mount-widget widget="classname-test" args=args}}`,

  beforeEach() {
    createWidget("classname-test", {
      tagName: "div.test",

      buildClasses(attrs) {
        return ["static", attrs.dynamic];
      }
    });

    this.set("args", { dynamic: "cool-class" });
  },

  test(assert) {
    assert.ok(
      this.$(".test.static.cool-class").length,
      "it has all the classes"
    );
  }
});

widgetTest("buildAttributes", {
  template: `{{mount-widget widget="attributes-test" args=args}}`,

  beforeEach() {
    createWidget("attributes-test", {
      tagName: "div.test",

      buildAttributes(attrs) {
        return { "data-evil": "trout", "aria-label": attrs.label };
      }
    });

    this.set("args", { label: "accessibility" });
  },

  test(assert) {
    assert.ok(this.$(".test[data-evil=trout]").length);
    assert.ok(this.$(".test[aria-label=accessibility]").length);
  }
});

widgetTest("buildId", {
  template: `{{mount-widget widget="id-test" args=args}}`,

  beforeEach() {
    createWidget("id-test", {
      buildId(attrs) {
        return `test-${attrs.id}`;
      }
    });

    this.set("args", { id: 1234 });
  },

  test(assert) {
    assert.ok(this.$("#test-1234").length);
  }
});

widgetTest("widget state", {
  template: `{{mount-widget widget="state-test"}}`,

  beforeEach() {
    createWidget("state-test", {
      tagName: "button.test",
      buildKey: () => `button-test`,
      template: hbs`{{state.clicks}} clicks`,

      defaultState() {
        return { clicks: 0 };
      },

      click() {
        this.state.clicks++;
      }
    });
  },

  async test(assert) {
    assert.ok(this.$("button.test").length, "it renders the button");
    assert.equal(this.$("button.test").text(), "0 clicks");

    await click(this.$("button"));
    assert.equal(this.$("button.test").text(), "1 clicks");
  }
});

widgetTest("widget update with promise", {
  template: `{{mount-widget widget="promise-test"}}`,

  beforeEach() {
    createWidget("promise-test", {
      tagName: "button.test",
      buildKey: () => "promise-test",
      template: hbs`
        {{#if state.name}}
          {{state.name}}
        {{else}}
          No name
        {{/if}}
      `,

      click() {
        return new Ember.RSVP.Promise(resolve => {
          Ember.run.next(() => {
            this.state.name = "Robin";
            resolve();
          });
        });
      }
    });
  },

  async test(assert) {
    assert.equal(
      this.$("button.test")
        .text()
        .trim(),
      "No name"
    );

    await click(this.$("button"));
    assert.equal(
      this.$("button.test")
        .text()
        .trim(),
      "Robin"
    );
  }
});

widgetTest("widget attaching", {
  template: `{{mount-widget widget="attach-test"}}`,

  beforeEach() {
    createWidget("test-embedded", { tagName: "div.embedded" });

    createWidget("attach-test", {
      tagName: "div.container",
      template: hbs`{{attach widget="test-embedded" attrs=attrs}}`
    });
  },

  test(assert) {
    assert.ok(this.$(".container").length, "renders container");
    assert.ok(this.$(".container .embedded").length, "renders attached");
  }
});

widgetTest("handlebars d-icon", {
  template: `{{mount-widget widget="hbs-icon-test" args=args}}`,

  beforeEach() {
    createWidget("hbs-icon-test", {
      template: hbs`{{d-icon "arrow-down"}}`
    });
  },

  test(assert) {
    assert.equal(this.$(".d-icon-arrow-down").length, 1);
  }
});

widgetTest("handlebars i18n", {
  template: `{{mount-widget widget="hbs-i18n-test" args=args}}`,

  beforeEach() {
    createWidget("hbs-i18n-test", {
      template: hbs`
        <span class='string'>{{i18n "hbs_test0"}}</span>
        <span class='var'>{{i18n attrs.key}}</span>
        <a href title={{i18n "hbs_test0"}}>test</a>
      `
    });
    I18n.extras = [
      {
        hbs_test0: "evil",
        hbs_test1: "trout"
      }
    ];
    this.set("args", { key: "hbs_test1" });
  },

  test(assert) {
    // comin up
    assert.equal(this.$("span.string").text(), "evil");
    assert.equal(this.$("span.var").text(), "trout");
    assert.equal(this.$("a").prop("title"), "evil");
  }
});

widgetTest("handlebars #each", {
  template: `{{mount-widget widget="hbs-each-test" args=args}}`,

  beforeEach() {
    createWidget("hbs-each-test", {
      tagName: "ul",
      template: hbs`
        {{#each attrs.items as |item|}}
          <li>{{item}}</li>
        {{/each}}
      `
    });

    this.set("args", {
      items: ["one", "two", "three"]
    });
  },

  test(assert) {
    assert.equal(this.$("ul li").length, 3);
    assert.equal(this.$("ul li:eq(0)").text(), "one");
  }
});

widgetTest("widget decorating", {
  template: `{{mount-widget widget="decorate-test"}}`,

  beforeEach() {
    createWidget("decorate-test", {
      tagName: "div.decorate",
      template: hbs`main content`
    });

    withPluginApi("0.1", api => {
      api.decorateWidget("decorate-test:before", dec => {
        return dec.h("b", "before");
      });

      api.decorateWidget("decorate-test:after", dec => {
        return dec.h("i", "after");
      });
    });
  },

  test(assert) {
    assert.ok(this.$(".decorate").length);
    assert.equal(this.$(".decorate b").text(), "before");
    assert.equal(this.$(".decorate i").text(), "after");
  }
});

widgetTest("widget settings", {
  template: `{{mount-widget widget="settings-test"}}`,

  beforeEach() {
    createWidget("settings-test", {
      tagName: "div.settings",
      template: hbs`age is {{settings.age}}`,
      settings: { age: 36 }
    });
  },

  test(assert) {
    assert.equal(this.$(".settings").text(), "age is 36");
  }
});

widgetTest("override settings", {
  template: `{{mount-widget widget="ov-settings-test"}}`,

  beforeEach() {
    createWidget("ov-settings-test", {
      tagName: "div.settings",
      template: hbs`age is {{settings.age}}`,
      settings: { age: 36 }
    });

    withPluginApi("0.1", api => {
      api.changeWidgetSetting("ov-settings-test", "age", 37);
    });
  },

  test(assert) {
    assert.equal(this.$(".settings").text(), "age is 37");
  }
});
