import {
  acceptance,
  count,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { action } from "@ember/object";
import { extraConnectorClass } from "discourse/lib/plugin-connectors";
import { hbs } from "ember-cli-htmlbars";
import { test } from "qunit";
import Ember from "ember";

const PREFIX = "javascripts/single-test/connectors";

acceptance("Plugin Outlet - Connector Class", function (needs) {
  needs.hooks.beforeEach(() => {
    extraConnectorClass("user-profile-primary/hello", {
      actions: {
        sayHello() {
          this.set("hello", `${this.hello || ""}hello!`);
        },
      },
    });

    extraConnectorClass("user-profile-primary/hi", {
      setupComponent() {
        this.appEvents.on("hi:sayHi", this, this.say);
      },

      teardownComponent() {
        this.appEvents.off("hi:sayHi", this, this.say);
      },

      @action
      say() {
        this.set("hi", "hi!");
      },

      @action
      sayHi() {
        this.appEvents.trigger("hi:sayHi");
      },
    });

    extraConnectorClass("user-profile-primary/dont-render", {
      shouldRender(args) {
        return args.model.get("username") !== "eviltrout";
      },
    });

    Ember.TEMPLATES[
      `${PREFIX}/user-profile-primary/hello`
    ] = hbs`<span class='hello-username'>{{model.username}}</span>
        <button class='say-hello' {{on "click" (action "sayHello")}}></button>
        <button class='say-hello-using-this' {{on "click" this.sayHello}}></button>
        <span class='hello-result'>{{hello}}</span>`;
    Ember.TEMPLATES[
      `${PREFIX}/user-profile-primary/hi`
    ] = hbs`<button class='say-hi' {{on "click" (action "sayHi")}}></button>
        <span class='hi-result'>{{hi}}</span>`;
    Ember.TEMPLATES[
      `${PREFIX}/user-profile-primary/dont-render`
    ] = hbs`I'm not rendered!`;
  });

  needs.hooks.afterEach(() => {
    delete Ember.TEMPLATES[`${PREFIX}/user-profile-primary/hello`];
    delete Ember.TEMPLATES[`${PREFIX}/user-profile-primary/hi`];
    delete Ember.TEMPLATES[`${PREFIX}/user-profile-primary/dont-render`];
  });

  test("Renders a template into the outlet", async function (assert) {
    await visit("/u/eviltrout");
    assert.strictEqual(
      count(".user-profile-primary-outlet.hello"),
      1,
      "it has class names"
    );
    assert.ok(
      !exists(".user-profile-primary-outlet.dont-render"),
      "doesn't render"
    );

    await click(".say-hello");
    assert.strictEqual(
      query(".hello-result").innerText,
      "hello!",
      "actions delegate properly"
    );
    await click(".say-hello-using-this");
    assert.strictEqual(
      query(".hello-result").innerText,
      "hello!hello!",
      "actions are made available on `this` and are bound correctly"
    );

    await click(".say-hi");
    assert.strictEqual(
      query(".hi-result").innerText,
      "hi!",
      "actions delegate properly"
    );
  });
});
