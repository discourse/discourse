import EmberObject from "@ember/object";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  computedI18n,
  fmt,
  htmlSafe,
  propertyEqual,
  propertyNotEqual,
  setting,
  url,
} from "discourse/lib/computed";
import { setPrefix } from "discourse-common/lib/get-url";

module("Unit | Utility | computed", function (hooks) {
  setupTest(hooks);

  test("setting", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");

    // eslint-disable-next-line ember/no-classic-classes
    let t = EmberObject.extend({
      siteSettings,
      vehicle: setting("vehicle"),
      missingProp: setting("madeUpThing"),
    }).create();

    siteSettings.vehicle = "airplane";
    assert.strictEqual(
      t.vehicle,
      "airplane",
      "it has the value of the site setting"
    );
    assert.strictEqual(
      t.missingProp,
      undefined,
      "is falsy when the site setting is not defined"
    );
  });

  test("propertyEqual", function (assert) {
    // eslint-disable-next-line ember/no-classic-classes
    let t = EmberObject.extend({
      same: propertyEqual("cookies", "biscuits"),
    }).create({
      cookies: 10,
      biscuits: 10,
    });

    assert.true(t.same, "is true when the properties are the same");
    t.set("biscuits", 9);
    assert.false(t.same, "isn't true when one property is different");
  });

  test("propertyNotEqual", function (assert) {
    // eslint-disable-next-line ember/no-classic-classes
    let t = EmberObject.extend({
      diff: propertyNotEqual("cookies", "biscuits"),
    }).create({
      cookies: 10,
      biscuits: 10,
    });

    assert.false(t.diff, "isn't true when the properties are the same");
    t.set("biscuits", 9);
    assert.true(t.diff, "is true when one property is different");
  });

  test("fmt", function (assert) {
    // eslint-disable-next-line ember/no-classic-classes
    let t = EmberObject.extend({
      exclaimyUsername: fmt("username", "!!! %@ !!!"),
      multiple: fmt("username", "mood", "%@ is %@"),
    }).create({
      username: "eviltrout",
      mood: "happy",
    });

    assert.strictEqual(
      t.exclaimyUsername,
      "!!! eviltrout !!!",
      "it inserts the string"
    );
    assert.strictEqual(
      t.multiple,
      "eviltrout is happy",
      "it inserts multiple strings"
    );

    t.set("username", "codinghorror");
    assert.strictEqual(
      t.multiple,
      "codinghorror is happy",
      "it supports changing properties"
    );
    t.set("mood", "ecstatic");
    assert.strictEqual(
      t.multiple,
      "codinghorror is ecstatic",
      "it supports changing another property"
    );
  });

  test("i18n", function (assert) {
    // eslint-disable-next-line ember/no-classic-classes
    let t = EmberObject.extend({
      exclaimyUsername: computedI18n("username", "!!! %@ !!!"),
      multiple: computedI18n("username", "mood", "%@ is %@"),
    }).create({
      username: "eviltrout",
      mood: "happy",
    });

    assert.strictEqual(
      t.exclaimyUsername,
      "[en.!!! eviltrout !!!]",
      "it inserts the string and then translates"
    );
    assert.strictEqual(
      t.multiple,
      "[en.eviltrout is happy]",
      "it inserts multiple strings and then translates"
    );

    t.set("username", "codinghorror");
    assert.strictEqual(
      t.multiple,
      "[en.codinghorror is happy]",
      "it supports changing properties"
    );
    t.set("mood", "ecstatic");
    assert.strictEqual(
      t.multiple,
      "[en.codinghorror is ecstatic]",
      "it supports changing another property"
    );
  });

  test("url", function (assert) {
    let t, testClass;

    // eslint-disable-next-line ember/no-classic-classes
    testClass = EmberObject.extend({
      userUrl: url("username", "/u/%@"),
    });

    t = testClass.create({ username: "eviltrout" });
    assert.strictEqual(
      t.userUrl,
      "/u/eviltrout",
      "it supports urls without a prefix"
    );

    setPrefix("/prefixed");
    t = testClass.create({ username: "eviltrout" });
    assert.strictEqual(
      t.userUrl,
      "/prefixed/u/eviltrout",
      "it supports urls with a prefix"
    );
  });

  test("htmlSafe", function (assert) {
    const cookies = "<p>cookies and <b>biscuits</b></p>";
    // eslint-disable-next-line ember/no-classic-classes
    const t = EmberObject.extend({
      desc: htmlSafe("cookies"),
    }).create({ cookies });

    assert.strictEqual(t.desc.toString(), cookies);
  });
});
