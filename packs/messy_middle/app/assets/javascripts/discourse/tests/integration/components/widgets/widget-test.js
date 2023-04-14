import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { count, exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import widgetHbs from "discourse/widgets/hbs-compiler";
import I18n from "I18n";
import { Promise } from "rsvp";
import { createWidget } from "discourse/widgets/widget";
import { next } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";
import { h } from "virtual-dom";

module("Integration | Component | Widget | base", function (hooks) {
  setupRenderingTest(hooks);

  let _translations = I18n.translations;

  hooks.afterEach(function () {
    I18n.translations = _translations;
  });

  test("widget attributes are passed in via args", async function (assert) {
    createWidget("hello-test", {
      tagName: "div.test",
      template: widgetHbs`Hello {{attrs.name}}`,
    });

    this.set("args", { name: "Robin" });

    await render(hbs`<MountWidget @widget="hello-test" @args={{this.args}} />`);

    assert.strictEqual(query(".test").innerText, "Hello Robin");
  });

  test("widget services", async function (assert) {
    createWidget("service-test", {
      tagName: "div.base-url-test",
      services: ["router"],
      html() {
        return this.router.rootURL;
      },
    });

    await render(hbs`<MountWidget @widget="service-test" />`);

    assert.strictEqual(query(".base-url-test").innerText, "/");
  });

  test("hbs template - no tagName", async function (assert) {
    createWidget("hbs-test", {
      template: widgetHbs`<div class='test'>Hello {{attrs.name}}</div>`,
    });

    this.set("args", { name: "Robin" });

    await render(hbs`<MountWidget @widget="hbs-test" @args={{this.args}} />`);

    assert.strictEqual(query("div.test").innerText, "Hello Robin");
  });

  test("hbs template - with tagName", async function (assert) {
    createWidget("hbs-test", {
      tagName: "div.test",
      template: widgetHbs`Hello {{attrs.name}}`,
    });

    this.set("args", { name: "Robin" });

    await render(hbs`<MountWidget @widget="hbs-test" @args={{this.args}} />`);

    assert.strictEqual(query("div.test").innerText, "Hello Robin");
  });

  test("hbs template - with data attributes", async function (assert) {
    createWidget("hbs-test", {
      template: widgetHbs`<div class='my-div' data-my-test='hello world'></div>`,
    });

    await render(hbs`<MountWidget @widget="hbs-test" @args={{this.args}} />`);

    assert.strictEqual(query("div.my-div").dataset.myTest, "hello world");
  });

  test("buildClasses", async function (assert) {
    createWidget("classname-test", {
      tagName: "div.test",

      buildClasses(attrs) {
        return ["static", attrs.dynamic];
      },
    });

    this.set("args", { dynamic: "cool-class" });

    await render(
      hbs`<MountWidget @widget="classname-test" @args={{this.args}} />`
    );

    assert.ok(exists(".test.static.cool-class"), "it has all the classes");
  });

  test("buildAttributes", async function (assert) {
    createWidget("attributes-test", {
      tagName: "div.test",

      buildAttributes(attrs) {
        return { "data-evil": "trout", "aria-label": attrs.label };
      },
    });

    this.set("args", { label: "accessibility" });

    await render(
      hbs`<MountWidget @widget="attributes-test" @args={{this.args}} />`
    );

    assert.ok(exists('.test[data-evil="trout"]'));
    assert.ok(exists('.test[aria-label="accessibility"]'));
  });

  test("buildId", async function (assert) {
    createWidget("id-test", {
      buildId(attrs) {
        return `test-${attrs.id}`;
      },
    });

    this.set("args", { id: 1234 });

    await render(hbs`<MountWidget @widget="id-test" @args={{this.args}} />`);

    assert.ok(exists("#test-1234"));
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

    await render(hbs`<MountWidget @widget="state-test" />`);

    assert.ok(exists("button.test"), "it renders the button");
    assert.strictEqual(query("button.test").innerText, "0 clicks");

    await click(query("button"));
    assert.strictEqual(query("button.test").innerText, "1 clicks");
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

    await render(hbs`<MountWidget @widget="promise-test" />`);

    assert.strictEqual(query("button.test").innerText.trim(), "No name");

    await click(query("button"));
    assert.strictEqual(query("button.test").innerText.trim(), "Robin");
  });

  test("widget attaching", async function (assert) {
    createWidget("test-embedded", { tagName: "div.embedded" });

    createWidget("attach-test", {
      tagName: "div.container",
      template: widgetHbs`{{attach widget="test-embedded" attrs=attrs}}`,
    });

    await render(hbs`<MountWidget @widget="attach-test" />`);

    assert.ok(exists(".container"), "renders container");
    assert.ok(exists(".container .embedded"), "renders attached");
  });

  test("magic attaching by name", async function (assert) {
    createWidget("test-embedded", { tagName: "div.embedded" });

    createWidget("attach-test", {
      tagName: "div.container",
      template: widgetHbs`{{test-embedded attrs=attrs}}`,
    });

    await render(hbs`<MountWidget @widget="attach-test" />`);

    assert.ok(exists(".container"), "renders container");
    assert.ok(exists(".container .embedded"), "renders attached");
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

    await render(hbs`<MountWidget @widget="attach-test" />`);

    assert.ok(exists(".container"), "renders container");
    assert.strictEqual(query(".container .value").innerText, "hello world");
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

    await render(hbs`<MountWidget @widget="attach-test" />`);

    assert.ok(count(".container"), "renders container");
    assert.strictEqual(query(".container .value").innerText, "hello world");
  });

  test("handlebars d-icon", async function (assert) {
    createWidget("hbs-icon-test", {
      template: widgetHbs`{{d-icon "arrow-down"}}`,
    });

    await render(
      hbs`<MountWidget @widget="hbs-icon-test" @args={{this.args}} />`
    );

    assert.strictEqual(count(".d-icon-arrow-down"), 1);
  });

  test("handlebars i18n", async function (assert) {
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
      hbs`<MountWidget @widget="hbs-i18n-test" @args={{this.args}} />`
    );

    // coming up
    assert.strictEqual(query("span.string").innerText, "evil");
    assert.strictEqual(query("span.var").innerText, "trout");
    assert.strictEqual(query("a").title, "evil");
  });

  test("handlebars #each", async function (assert) {
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
      hbs`<MountWidget @widget="hbs-each-test" @args={{this.args}} />`
    );

    assert.strictEqual(count("ul li"), 3);
    assert.strictEqual(query("ul li:nth-of-type(1)").innerText, "one");
  });

  test("widget decorating", async function (assert) {
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

    await render(hbs`<MountWidget @widget="decorate-test" />`);

    assert.ok(exists(".decorate"));
    assert.strictEqual(query(".decorate b").innerText, "before");
    assert.strictEqual(query(".decorate i").innerText, "after");
  });

  test("widget settings", async function (assert) {
    createWidget("settings-test", {
      tagName: "div.settings",
      template: widgetHbs`age is {{settings.age}}`,
      settings: { age: 36 },
    });

    await render(hbs`<MountWidget @widget="settings-test" />`);

    assert.strictEqual(query(".settings").innerText, "age is 36");
  });

  test("override settings", async function (assert) {
    createWidget("ov-settings-test", {
      tagName: "div.settings",
      template: widgetHbs`age is {{settings.age}}`,
      settings: { age: 36 },
    });

    withPluginApi("0.1", (api) => {
      api.changeWidgetSetting("ov-settings-test", "age", 37);
    });

    await render(hbs`<MountWidget @widget="ov-settings-test" />`);

    assert.strictEqual(query(".settings").innerText, "age is 37");
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

    await render(hbs`<MountWidget @widget="get-accessor-test" />`);

    assert.strictEqual(query("div.test").innerText, "Hello eviltrout");
  });

  test("tagName", async function (assert) {
    createWidget("test-override", { tagName: "div.not-override" });

    createWidget("tag-name-override-test", {
      template: widgetHbs`{{attach widget="test-override" attrs=attrs otherOpts=(hash tagName="section.override")}}`,
    });

    await render(hbs`<MountWidget @widget="tag-name-override-test" />`);

    assert.ok(
      exists("section.override"),
      "renders container with overridden tagName"
    );
  });

  test("avoids rerendering on prepend", async function (assert) {
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
      hbs`<MountWidget @widget="prepend-test" @args={{this.args}} />`
    );

    const startElements = Array.from(document.querySelectorAll("span.val"));
    assert.deepEqual(
      startElements.map((e) => e.innerText),
      ["ElementOne", "ElementTwo"]
    );
    const elementOneBefore = startElements[0];

    const parent = elementOneBefore.parentNode;
    const observer = new MutationObserver(function (mutations) {
      assert.notOk(
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
