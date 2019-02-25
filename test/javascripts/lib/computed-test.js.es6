import {
  setting,
  propertyEqual,
  propertyNotEqual,
  fmt,
  i18n,
  url
} from "discourse/lib/computed";

QUnit.module("lib:computed", {
  beforeEach() {
    sandbox.stub(I18n, "t").callsFake(function(scope) {
      return "%@ translated: " + scope;
    });
  },

  afterEach() {
    I18n.t.restore();
  }
});

QUnit.test("setting", assert => {
  var t = Ember.Object.extend({
    vehicle: setting("vehicle"),
    missingProp: setting("madeUpThing")
  }).create();

  Discourse.SiteSettings.vehicle = "airplane";
  assert.equal(
    t.get("vehicle"),
    "airplane",
    "it has the value of the site setting"
  );
  assert.ok(
    !t.get("missingProp"),
    "it is falsy when the site setting is not defined"
  );
});

QUnit.test("propertyEqual", assert => {
  var t = Ember.Object.extend({
    same: propertyEqual("cookies", "biscuits")
  }).create({
    cookies: 10,
    biscuits: 10
  });

  assert.ok(t.get("same"), "it is true when the properties are the same");
  t.set("biscuits", 9);
  assert.ok(!t.get("same"), "it isn't true when one property is different");
});

QUnit.test("propertyNotEqual", assert => {
  var t = Ember.Object.extend({
    diff: propertyNotEqual("cookies", "biscuits")
  }).create({
    cookies: 10,
    biscuits: 10
  });

  assert.ok(!t.get("diff"), "it isn't true when the properties are the same");
  t.set("biscuits", 9);
  assert.ok(t.get("diff"), "it is true when one property is different");
});

QUnit.test("fmt", assert => {
  var t = Ember.Object.extend({
    exclaimyUsername: fmt("username", "!!! %@ !!!"),
    multiple: fmt("username", "mood", "%@ is %@")
  }).create({
    username: "eviltrout",
    mood: "happy"
  });

  assert.equal(
    t.get("exclaimyUsername"),
    "!!! eviltrout !!!",
    "it inserts the string"
  );
  assert.equal(
    t.get("multiple"),
    "eviltrout is happy",
    "it inserts multiple strings"
  );

  t.set("username", "codinghorror");
  assert.equal(
    t.get("multiple"),
    "codinghorror is happy",
    "it supports changing properties"
  );
  t.set("mood", "ecstatic");
  assert.equal(
    t.get("multiple"),
    "codinghorror is ecstatic",
    "it supports changing another property"
  );
});

QUnit.test("i18n", assert => {
  var t = Ember.Object.extend({
    exclaimyUsername: i18n("username", "!!! %@ !!!"),
    multiple: i18n("username", "mood", "%@ is %@")
  }).create({
    username: "eviltrout",
    mood: "happy"
  });

  assert.equal(
    t.get("exclaimyUsername"),
    "%@ translated: !!! eviltrout !!!",
    "it inserts the string and then translates"
  );
  assert.equal(
    t.get("multiple"),
    "%@ translated: eviltrout is happy",
    "it inserts multiple strings and then translates"
  );

  t.set("username", "codinghorror");
  assert.equal(
    t.get("multiple"),
    "%@ translated: codinghorror is happy",
    "it supports changing properties"
  );
  t.set("mood", "ecstatic");
  assert.equal(
    t.get("multiple"),
    "%@ translated: codinghorror is ecstatic",
    "it supports changing another property"
  );
});

QUnit.test("url", assert => {
  var t, testClass;

  testClass = Ember.Object.extend({
    userUrl: url("username", "/u/%@")
  });

  t = testClass.create({ username: "eviltrout" });
  assert.equal(
    t.get("userUrl"),
    "/u/eviltrout",
    "it supports urls without a prefix"
  );

  Discourse.BaseUri = "/prefixed";
  t = testClass.create({ username: "eviltrout" });
  assert.equal(
    t.get("userUrl"),
    "/prefixed/u/eviltrout",
    "it supports urls with a prefix"
  );
});
