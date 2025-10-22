import { next } from "@ember/runloop";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { Promise } from "rsvp";
import { h } from "virtual-dom";
import MountWidget from "discourse/components/mount-widget";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import widgetHbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import I18n from "discourse-i18n";

module("Integration | Component | Widget | base", function (hooks) {
  setupRenderingTest(hooks);

  let _translations = I18n.translations;

  hooks.beforeEach(function () {
    this.siteSettings.deactivate_widgets_rendering = false;
  });

  hooks.afterEach(function () {
    I18n.translations = _translations;
  });

  test("widget attributes are passed in via args", async function (assert) {
    const self = this;

    createWidget("hello-test", {
      tagName: "div.test",
      template: widgetHbs`Hello {{attrs.name}}`,
    });

    this.set("args", { name: "Robin" });

    await render(
      <template>
        <MountWidget @widget="hello-test" @args={{self.args}} />
      </template>
    );

    assert.dom(".test").hasText("Hello Robin");
  });

  test("widget rerenders when args change", async function (assert) {
    const self = this;

    createWidget("hello-test", {
      tagName: "div.test",
      template: widgetHbs`Hello {{attrs.name}}`,
    });

    this.set("args", { name: "Robin" });

    await render(
      <template>
        <MountWidget @widget="hello-test" @args={{self.args}} />
      </template>
    );

    assert.dom(".test").hasText("Hello Robin");

    this.set("args", { name: "David" });
    await settled();

    assert.dom(".test").hasText("Hello David");
  });

  test("widget services", async function (assert) {
    createWidget("service-test", {
      tagName: "div.base-url-test",
      services: ["router"],
      html() {
        return this.router.rootURL;
      },
    });

    await render(<template><MountWidget @widget="service-test" /></template>);

    assert.dom(".base-url-test").hasText("/");
  });

  test("hbs template - no tagName", async function (assert) {
    const self = this;

    createWidget("hbs-test", {
      template: widgetHbs`<div class='test'>Hello {{attrs.name}}</div>`,
    });

    this.set("args", { name: "Robin" });

    await render(
      <template>
        <MountWidget @widget="hbs-test" @args={{self.args}} />
      </template>
    );

    assert.dom("div.test").hasText("Hello Robin");
  });

  test("hbs template - with tagName", async function (assert) {
    const self = this;

    createWidget("hbs-test", {
      tagName: "div.test",
      template: widgetHbs`Hello {{attrs.name}}`,
    });

    this.set("args", { name: "Robin" });

    await render(
      <template>
        <MountWidget @widget="hbs-test" @args={{self.args}} />
      </template>
    );

    assert.dom("div.test").hasText("Hello Robin");
  });

  test("hbs template - with data attributes", async function (assert) {
    const self = this;

    createWidget("hbs-test", {
      template: widgetHbs`<div class='my-div' data-my-test='hello world'></div>`,
    });

    await render(
      <template>
        <MountWidget @widget="hbs-test" @args={{self.args}} />
      </template>
    );

    assert.dom("div.my-div").hasAttribute("data-my-test", "hello world");
  });

  test("buildClasses", async function (assert) {
    const self = this;

    createWidget("classname-test", {
      tagName: "div.test",

      buildClasses(attrs) {
        return ["static", attrs.dynamic];
      },
    });

    this.set("args", { dynamic: "cool-class" });

    await render(
      <template>
        <MountWidget @widget="classname-test" @args={{self.args}} />
      </template>
    );

    assert.dom(".test.static.cool-class").exists("has all the classes");
  });

  test("buildAttributes", async function (assert) {
    const self = this;

    createWidget("attributes-test", {
      tagName: "div.test",

      buildAttributes(attrs) {
        return { "data-evil": "trout", "aria-label": attrs.label };
      },
    });

    this.set("args", { label: "accessibility" });

    await render(
      <template>
        <MountWidget @widget="attributes-test" @args={{self.args}} />
      </template>
    );

    assert.dom('.test[data-evil="trout"]').exists();
    assert.dom('.test[aria-label="accessibility"]').exists();
  });

  test("buildId", async function (assert) {
    const self = this;

    createWidget("id-test", {
      buildId(attrs) {
        return `test-${attrs.id}`;
      },
    });

    this.set("args", { id: 1234 });

    await render(
      <template><MountWidget @widget="id-test" @args={{self.args}} /></template>
    );

    assert.dom("#test-1234").exists();
  });

  test("widget state", async function (assert) {
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

    await render(<template><MountWidget @widget="state-test" /></template>);

    assert.dom("button.test").exists("renders the button");
    assert.dom("button.test").hasText("0 clicks");

    await click("button");
    assert.dom("button.test").hasText("1 clicks");
  });

  test("widget update with promise", async function (assert) {
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

    await render(<template><MountWidget @widget="promise-test" /></template>);

    assert.dom("button.test").hasText("No name");

    await click("button");
    assert.dom("button.test").hasText("Robin");
  });

  test("widget attaching", async function (assert) {
    createWidget("test-embedded", { tagName: "div.embedded" });

    createWidget("attach-test", {
      tagName: "div.container",
      template: widgetHbs`{{attach widget="test-embedded" attrs=attrs}}`,
    });

    await render(<template><MountWidget @widget="attach-test" /></template>);

    assert.dom(".container").exists("renders container");
    assert.dom(".container .embedded").exists("renders attached");
  });

  test("magic attaching by name", async function (assert) {
    createWidget("test-embedded", { tagName: "div.embedded" });

    createWidget("attach-test", {
      tagName: "div.container",
      template: widgetHbs`{{test-embedded attrs=attrs}}`,
    });

    await render(<template><MountWidget @widget="attach-test" /></template>);

    assert.dom(".container").exists("renders container");
    assert.dom(".container .embedded").exists("renders attached");
  });

  test("custom attrs to a magic attached widget", async function (assert) {
    createWidget("testing", {
      tagName: "span.value",
      template: widgetHbs`{{attrs.value}}`,
    });

    createWidget("attach-test", {
      tagName: "div.container",
      template: widgetHbs`{{testing value=(concat "hello" " " "world")}}`,
    });

    await render(<template><MountWidget @widget="attach-test" /></template>);

    assert.dom(".container").exists("renders container");
    assert.dom(".container .value").hasText("hello world");
  });

  test("using transformed values in a sub-expression", async function (assert) {
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

    await render(<template><MountWidget @widget="attach-test" /></template>);

    assert.dom(".container").exists("renders container");
    assert.dom(".container .value").hasText("hello world");
  });

  test("handlebars d-icon", async function (assert) {
    const self = this;

    createWidget("hbs-icon-test", {
      template: widgetHbs`{{d-icon "arrow-down"}}`,
    });

    await render(
      <template>
        <MountWidget @widget="hbs-icon-test" @args={{self.args}} />
      </template>
    );

    assert.dom(".d-icon-arrow-down").exists();
  });

  test("handlebars i18n", async function (assert) {
    const self = this;

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

    await render(
      <template>
        <MountWidget @widget="hbs-i18n-test" @args={{self.args}} />
      </template>
    );

    // coming up
    assert.dom("span.string").hasText("evil");
    assert.dom("span.var").hasText("trout");
    assert.dom("a").hasAttribute("title", "evil");
  });

  test("handlebars #each", async function (assert) {
    const self = this;

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

    await render(
      <template>
        <MountWidget @widget="hbs-each-test" @args={{self.args}} />
      </template>
    );

    assert.dom("ul li").exists({ count: 3 });
    assert.dom("ul li:nth-of-type(1)").hasText("one");
  });

  test("widget decorating", async function (assert) {
    createWidget("decorate-test", {
      tagName: "div.decorate",
      template: widgetHbs`main content`,
    });

    withPluginApi((api) => {
      api.decorateWidget("decorate-test:before", (dec) => {
        return dec.h("b", "before");
      });

      api.decorateWidget("decorate-test:after", (dec) => {
        return dec.h("i", "after");
      });
    });

    await render(<template><MountWidget @widget="decorate-test" /></template>);

    assert.dom(".decorate").exists();
    assert.dom(".decorate b").hasText("before");
    assert.dom(".decorate i").hasText("after");
  });

  test("widget settings", async function (assert) {
    createWidget("settings-test", {
      tagName: "div.settings",
      template: widgetHbs`age is {{settings.age}}`,
      settings: { age: 36 },
    });

    await render(<template><MountWidget @widget="settings-test" /></template>);

    assert.dom(".settings").hasText("age is 36");
  });

  test("override settings", async function (assert) {
    createWidget("ov-settings-test", {
      tagName: "div.settings",
      template: widgetHbs`age is {{settings.age}}`,
      settings: { age: 36 },
    });

    withPluginApi((api) => {
      api.changeWidgetSetting("ov-settings-test", "age", 37);
    });

    await render(
      <template><MountWidget @widget="ov-settings-test" /></template>
    );

    assert.dom(".settings").hasText("age is 37");
  });

  test("get accessor", async function (assert) {
    createWidget("get-accessor-test", {
      tagName: "div.test",
      template: widgetHbs`Hello {{transformed.name}}`,
      transform() {
        return {
          name: this.get("currentUser.username"),
        };
      },
    });

    await render(
      <template><MountWidget @widget="get-accessor-test" /></template>
    );

    assert.dom("div.test").hasText("Hello eviltrout");
  });

  test("tagName", async function (assert) {
    createWidget("test-override", { tagName: "div.not-override" });

    createWidget("tag-name-override-test", {
      template: widgetHbs`{{attach widget="test-override" attrs=attrs otherOpts=(hash tagName="section.override")}}`,
    });

    await render(
      <template><MountWidget @widget="tag-name-override-test" /></template>
    );

    assert
      .dom("section.override")
      .exists("renders container with overridden tagName");
  });

  test("avoids rerendering on prepend", async function (assert) {
    const self = this;

    createWidget("prepend-test", {
      tagName: "div.test",
      html(attrs) {
        const result = [];
        result.push(
          this.attach("button", {
            label: "rerender",
            className: "rerender",
            action: "dummyAction",
          })
        );
        result.push(
          h(
            "div",
            attrs.array.map((val) => h(`span.val.${val}`, { key: val }, val))
          )
        );
        return result;
      },
      dummyAction() {},
    });

    const array = ["ElementOne", "ElementTwo"];
    this.set("args", { array });

    await render(
      <template>
        <MountWidget @widget="prepend-test" @args={{self.args}} />
      </template>
    );

    const startElements = Array.from(document.querySelectorAll("span.val"));
    assert.deepEqual(
      startElements.map((e) => e.innerText),
      ["ElementOne", "ElementTwo"]
    );
    const elementOneBefore = startElements[0];

    const parent = elementOneBefore.parentNode;
    const observer = new MutationObserver(function (mutations) {
      assert.false(
        mutations.some((m) =>
          Array.from(m.addedNodes).includes(elementOneBefore)
        )
      );
    });
    observer.observe(parent, { childList: true });

    array.unshift(
      "PrependedElementOne",
      "PrependedElementTwo",
      "PrependedElementThree"
    );

    await click(".rerender");

    const endElements = Array.from(document.querySelectorAll("span.val"));
    assert.deepEqual(
      endElements.map((e) => e.innerText),
      [
        "PrependedElementOne",
        "PrependedElementTwo",
        "PrependedElementThree",
        "ElementOne",
        "ElementTwo",
      ]
    );
    const elementOneAfter = endElements[3];

    assert.strictEqual(elementOneBefore, elementOneAfter);
  });
});
