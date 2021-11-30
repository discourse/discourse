import {
  fmt,
  htmlSafe,
  i18n,
  propertyEqual,
  propertyNotEqual,
  setting,
  url,
} from "discourse/lib/computed";
import EmberObject from "@ember/object";
import I18n from "I18n";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { setPrefix } from "discourse-common/lib/get-url";
import sinon from "sinon";
import { test } from "qunit";

discourseModule("Unit | Utility | computed", function (hooks) {
  hooks.beforeEach(function () {
    sinon.stub(I18n, "t").callsFake(function (scope) {
      return "%@ translated: " + scope;
    });
  });

  hooks.afterEach(function () {
    I18n.t.restore();
  });

  test("setting", function (assert) {
    let t = EmberObject.extend({
      siteSettings: this.siteSettings,
      vehicle: setting("vehicle"),
      missingProp: setting("madeUpThing"),
    }).create();

    this.siteSettings.vehicle = "airplane";
    assert.strictEqual(
      t.get("vehicle"),
      "airplane",
      "it has the value of the site setting"
    );
    assert.ok(
      !t.get("missingProp"),
      "it is falsy when the site setting is not defined"
    );
  });

  test("propertyEqual", function (assert) {
    let t = EmberObject.extend({
      same: propertyEqual("cookies", "biscuits"),
    }).create({
      cookies: 10,
      biscuits: 10,
    });

    assert.ok(t.get("same"), "it is true when the properties are the same");
    t.set("biscuits", 9);
    assert.ok(!t.get("same"), "it isn't true when one property is different");
  });

  test("propertyNotEqual", function (assert) {
    let t = EmberObject.extend({
      diff: propertyNotEqual("cookies", "biscuits"),
    }).create({
      cookies: 10,
      biscuits: 10,
    });

    assert.ok(!t.get("diff"), "it isn't true when the properties are the same");
    t.set("biscuits", 9);
    assert.ok(t.get("diff"), "it is true when one property is different");
  });

  test("fmt", function (assert) {
    let t = EmberObject.extend({
      exclaimyUsername: fmt("username", "!!! %@ !!!"),
      multiple: fmt("username", "mood", "%@ is %@"),
    }).create({
      username: "eviltrout",
      mood: "happy",
    });

    assert.strictEqual(
      t.get("exclaimyUsername"),
      "!!! eviltrout !!!",
      "it inserts the string"
    );
    assert.strictEqual(
      t.get("multiple"),
      "eviltrout is happy",
      "it inserts multiple strings"
    );

    t.set("username", "codinghorror");
    assert.strictEqual(
      t.get("multiple"),
      "codinghorror is happy",
      "it supports changing properties"
    );
    t.set("mood", "ecstatic");
    assert.strictEqual(
      t.get("multiple"),
      "codinghorror is ecstatic",
      "it supports changing another property"
    );
  });

  test("i18n", function (assert) {
    let t = EmberObject.extend({
      exclaimyUsername: i18n("username", "!!! %@ !!!"),
      multiple: i18n("username", "mood", "%@ is %@"),
    }).create({
      username: "eviltrout",
      mood: "happy",
    });

    assert.strictEqual(
      t.get("exclaimyUsername"),
      "%@ translated: !!! eviltrout !!!",
      "it inserts the string and then translates"
    );
    assert.strictEqual(
      t.get("multiple"),
      "%@ translated: eviltrout is happy",
      "it inserts multiple strings and then translates"
    );

    t.set("username", "codinghorror");
    assert.strictEqual(
      t.get("multiple"),
      "%@ translated: codinghorror is happy",
      "it supports changing properties"
    );
    t.set("mood", "ecstatic");
    assert.strictEqual(
      t.get("multiple"),
      "%@ translated: codinghorror is ecstatic",
      "it supports changing another property"
    );
  });

  test("url", function (assert) {
    let t, testClass;

    testClass = EmberObject.extend({
      userUrl: url("username", "/u/%@"),
    });

    t = testClass.create({ username: "eviltrout" });
    assert.strictEqual(
      t.get("userUrl"),
      "/u/eviltrout",
      "it supports urls without a prefix"
    );

    setPrefix("/prefixed");
    t = testClass.create({ username: "eviltrout" });
    assert.strictEqual(
      t.get("userUrl"),
      "/prefixed/u/eviltrout",
      "it supports urls with a prefix"
    );
  });

  test("htmlSafe", function (assert) {
    const cookies = "<p>cookies and <b>biscuits</b></p>";
    const t = EmberObject.extend({
      desc: htmlSafe("cookies"),
    }).create({ cookies });

    assert.strictEqual(t.get("desc").string, cookies);
  });
});
