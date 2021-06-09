import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { Promise } from "rsvp";
import { click } from "@ember/test-helpers";
import { createWidget } from "discourse/widgets/widget";
import hbs from "htmlbars-inline-precompile";
import widgetHbs from "discourse/widgets/hbs-compiler";
import { next } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";

discourseModule("Integration | Component | Widget | base", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("widget attributes are passed in via args", {
    template: hbs`{{mount-widget widget="hello-test" args=args}}`,

    beforeEach() {
      createWidget("hello-test", {
        tagName: "div.test",
        template: widgetHbs`Hello {{attrs.name}}`,
      });

      this.set("args", { name: "Robin" });
    },

    test(assert) {
      assert.equal(queryAll(".test").text(), "Hello Robin");
    },
  });

  componentTest("hbs template - no tagName", {
    template: hbs`{{mount-widget widget="hbs-test" args=args}}`,

    beforeEach() {
      createWidget("hbs-test", {
        template: widgetHbs`<div class='test'>Hello {{attrs.name}}</div>`,
      });

      this.set("args", { name: "Robin" });
    },

    test(assert) {
      assert.equal(queryAll("div.test").text(), "Hello Robin");
    },
  });

  componentTest("hbs template - with tagName", {
    template: hbs`{{mount-widget widget="hbs-test" args=args}}`,

    beforeEach() {
      createWidget("hbs-test", {
        tagName: "div.test",
        template: widgetHbs`Hello {{attrs.name}}`,
      });

      this.set("args", { name: "Robin" });
    },

    test(assert) {
      assert.equal(queryAll("div.test").text(), "Hello Robin");
    },
  });

  componentTest("hbs template - with data attributes", {
    template: hbs`{{mount-widget widget="hbs-test" args=args}}`,

    beforeEach() {
      createWidget("hbs-test", {
        template: widgetHbs`<div class='mydiv' data-my-test='hello world'></div>`,
      });
    },

    test(assert) {
      assert.equal(queryAll("div.mydiv").data("my-test"), "hello world");
    },
  });

  componentTest("buildClasses", {
    template: hbs`{{mount-widget widget="classname-test" args=args}}`,

    beforeEach() {
      createWidget("classname-test", {
        tagName: "div.test",

        buildClasses(attrs) {
          return ["static", attrs.dynamic];
        },
      });

      this.set("args", { dynamic: "cool-class" });
    },

    test(assert) {
      assert.ok(exists(".test.static.cool-class"), "it has all the classes");
    },
  });

  componentTest("buildAttributes", {
    template: hbs`{{mount-widget widget="attributes-test" args=args}}`,

    beforeEach() {
      createWidget("attributes-test", {
        tagName: "div.test",

        buildAttributes(attrs) {
          return { "data-evil": "trout", "aria-label": attrs.label };
        },
      });

      this.set("args", { label: "accessibility" });
    },

    test(assert) {
      assert.ok(exists('.test[data-evil="trout"]'));
      assert.ok(exists('.test[aria-label="accessibility"]'));
    },
  });

  componentTest("buildId", {
    template: hbs`{{mount-widget widget="id-test" args=args}}`,

    beforeEach() {
      createWidget("id-test", {
        buildId(attrs) {
          return `test-${attrs.id}`;
        },
      });

      this.set("args", { id: 1234 });
    },

    test(assert) {
      assert.ok(exists("#test-1234"));
    },
  });

  componentTest("widget state", {
    template: hbs`{{mount-widget widget="state-test"}}`,

    beforeEach() {
      createWidget("state-test", {
        tagName: "button.test",
        buildKey: () => `button-test`,
        template: widgetHbs`{{state.clicks}} clicks`,

        defaultState() {
          return { clicks: 0 };
        },

        click() {
          this.state.clicks++;
        },
      });
    },

    async test(assert) {
      assert.ok(exists("button.test"), "it renders the button");
      assert.equal(queryAll("button.test").text(), "0 clicks");

      await click(query("button"));
      assert.equal(queryAll("button.test").text(), "1 clicks");
    },
  });

  componentTest("widget update with promise", {
    template: hbs`{{mount-widget widget="promise-test"}}`,

    beforeEach() {
      createWidget("promise-test", {
        tagName: "button.test",
        buildKey: () => "promise-test",
        template: widgetHbs`
          {{#if state.name}}
            {{state.name}}
          {{else}}
            No name
          {{/if}}
        `,

        click() {
          return new Promise((resolve) => {
            next(() => {
              this.state.name = "Robin";
              resolve();
            });
          });
        },
      });
    },

    async test(assert) {
      assert.equal(queryAll("button.test").text().trim(), "No name");

      await click(query("button"));
      assert.equal(queryAll("button.test").text().trim(), "Robin");
    },
  });

  componentTest("widget attaching", {
    template: hbs`{{mount-widget widget="attach-test"}}`,

    beforeEach() {
      createWidget("test-embedded", { tagName: "div.embedded" });

      createWidget("attach-test", {
        tagName: "div.container",
        template: widgetHbs`{{attach widget="test-embedded" attrs=attrs}}`,
      });
    },

    test(assert) {
      assert.ok(exists(".container"), "renders container");
      assert.ok(exists(".container .embedded"), "renders attached");
    },
  });

  componentTest("magic attaching by name", {
    template: hbs`{{mount-widget widget="attach-test"}}`,

    beforeEach() {
      createWidget("test-embedded", { tagName: "div.embedded" });

      createWidget("attach-test", {
        tagName: "div.container",
        template: widgetHbs`{{test-embedded attrs=attrs}}`,
      });
    },

    test(assert) {
      assert.ok(exists(".container"), "renders container");
      assert.ok(exists(".container .embedded"), "renders attached");
    },
  });

  componentTest("custom attrs to a magic attached widget", {
    template: hbs`{{mount-widget widget="attach-test"}}`,

    beforeEach() {
      createWidget("testing", {
        tagName: "span.value",
        template: widgetHbs`{{attrs.value}}`,
      });

      createWidget("attach-test", {
        tagName: "div.container",
        template: widgetHbs`{{testing value=(concat "hello" " " "world")}}`,
      });
    },

    test(assert) {
      assert.ok(exists(".container"), "renders container");
      assert.equal(queryAll(".container .value").text(), "hello world");
    },
  });

  componentTest("using transformed values in a subexpression", {
    template: hbs`{{mount-widget widget="attach-test"}}`,

    beforeEach() {
      createWidget("testing", {
        tagName: "span.value",
        template: widgetHbs`{{attrs.value}}`,
      });

      createWidget("attach-test", {
        transform() {
          return { someValue: "world" };
        },
        tagName: "div.container",
        template: widgetHbs`{{testing value=(concat "hello" " " transformed.someValue)}}`,
      });
    },

    test(assert) {
      assert.ok(queryAll(".container").length, "renders container");
      assert.equal(queryAll(".container .value").text(), "hello world");
    },
  });

  componentTest("handlebars d-icon", {
    template: hbs`{{mount-widget widget="hbs-icon-test" args=args}}`,

    beforeEach() {
      createWidget("hbs-icon-test", {
        template: widgetHbs`{{d-icon "arrow-down"}}`,
      });
    },

    test(assert) {
      assert.equal(count(".d-icon-arrow-down"), 1);
    },
  });

  componentTest("handlebars i18n", {
    _translations: I18n.translations,

    template: hbs`{{mount-widget widget="hbs-i18n-test" args=args}}`,

    beforeEach() {
      createWidget("hbs-i18n-test", {
        template: widgetHbs`
          <span class='string'>{{i18n "hbs_test0"}}</span>
          <span class='var'>{{i18n attrs.key}}</span>
          <a href title={{i18n "hbs_test0"}}>test</a>
        `,
      });
      I18n.translations = {
        en: {
          js: {
            hbs_test0: "evil",
            hbs_test1: "trout",
          },
        },
      };
      this.set("args", { key: "hbs_test1" });
    },

    afterEach() {
      I18n.translations = this._translations;
    },

    test(assert) {
      // coming up
      assert.equal(queryAll("span.string").text(), "evil");
      assert.equal(queryAll("span.var").text(), "trout");
      assert.equal(queryAll("a").prop("title"), "evil");
    },
  });

  componentTest("handlebars #each", {
    template: hbs`{{mount-widget widget="hbs-each-test" args=args}}`,

    beforeEach() {
      createWidget("hbs-each-test", {
        tagName: "ul",
        template: widgetHbs`
          {{#each attrs.items as |item|}}
            <li>{{item}}</li>
          {{/each}}
        `,
      });

      this.set("args", {
        items: ["one", "two", "three"],
      });
    },

    test(assert) {
      assert.equal(count("ul li"), 3);
      assert.equal(queryAll("ul li:nth-of-type(1)").text(), "one");
    },
  });

  componentTest("widget decorating", {
    template: hbs`{{mount-widget widget="decorate-test"}}`,

    beforeEach() {
      createWidget("decorate-test", {
        tagName: "div.decorate",
        template: widgetHbs`main content`,
      });

      withPluginApi("0.1", (api) => {
        api.decorateWidget("decorate-test:before", (dec) => {
          return dec.h("b", "before");
        });

        api.decorateWidget("decorate-test:after", (dec) => {
          return dec.h("i", "after");
        });
      });
    },

    test(assert) {
      assert.ok(exists(".decorate"));
      assert.equal(queryAll(".decorate b").text(), "before");
      assert.equal(queryAll(".decorate i").text(), "after");
    },
  });

  componentTest("widget settings", {
    template: hbs`{{mount-widget widget="settings-test"}}`,

    beforeEach() {
      createWidget("settings-test", {
        tagName: "div.settings",
        template: widgetHbs`age is {{settings.age}}`,
        settings: { age: 36 },
      });
    },

    test(assert) {
      assert.equal(queryAll(".settings").text(), "age is 36");
    },
  });

  componentTest("override settings", {
    template: hbs`{{mount-widget widget="ov-settings-test"}}`,

    beforeEach() {
      createWidget("ov-settings-test", {
        tagName: "div.settings",
        template: widgetHbs`age is {{settings.age}}`,
        settings: { age: 36 },
      });

      withPluginApi("0.1", (api) => {
        api.changeWidgetSetting("ov-settings-test", "age", 37);
      });
    },

    test(assert) {
      assert.equal(queryAll(".settings").text(), "age is 37");
    },
  });

  componentTest("get accessor", {
    template: hbs`{{mount-widget widget="get-accessor-test"}}`,

    beforeEach() {
      createWidget("get-accessor-test", {
        tagName: "div.test",
        template: widgetHbs`Hello {{transformed.name}}`,
        transform() {
          return {
            name: this.get("currentUser.username"),
          };
        },
      });
    },

    test(assert) {
      assert.equal(queryAll("div.test").text(), "Hello eviltrout");
    },
  });

  componentTest("tagName", {
    template: hbs`{{mount-widget widget="tag-name-override-test"}}`,

    beforeEach() {
      createWidget("test-override", { tagName: "div.not-override" });

      createWidget("tag-name-override-test", {
        template: widgetHbs`{{attach widget="test-override" attrs=attrs otherOpts=(hash tagName="section.override")}}`,
      });
    },

    test(assert) {
      assert.ok(
        exists("section.override"),
        "renders container with overrided tagName"
      );
    },
  });
});
