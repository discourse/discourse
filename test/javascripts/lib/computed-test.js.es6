import { setting, propertyEqual, propertyNotEqual, fmt, i18n, url } from 'discourse/lib/computed';

module("lib:computed", {
  setup: function() {
    sandbox.stub(I18n, "t", function(scope) {
      return "%@ translated: " + scope;
    });
  },

  teardown: function() {
    I18n.t.restore();
  }
});

test("setting", function() {
  var t = Em.Object.extend({
    vehicle: setting('vehicle'),
    missingProp: setting('madeUpThing')
  }).create();

  Discourse.SiteSettings.vehicle = "airplane";
  equal(t.get('vehicle'), "airplane", "it has the value of the site setting");
  ok(!t.get('missingProp'), "it is falsy when the site setting is not defined");
});

test("propertyEqual", function() {
  var t = Em.Object.extend({
    same: propertyEqual('cookies', 'biscuits')
  }).create({
    cookies: 10,
    biscuits: 10
  });

  ok(t.get('same'), "it is true when the properties are the same");
  t.set('biscuits', 9);
  ok(!t.get('same'), "it isn't true when one property is different");
});

test("propertyNotEqual", function() {
  var t = Em.Object.extend({
    diff: propertyNotEqual('cookies', 'biscuits')
  }).create({
    cookies: 10,
    biscuits: 10
  });

  ok(!t.get('diff'), "it isn't true when the properties are the same");
  t.set('biscuits', 9);
  ok(t.get('diff'), "it is true when one property is different");
});


test("fmt", function() {
  var t = Em.Object.extend({
    exclaimyUsername: fmt('username', "!!! %@ !!!"),
    multiple: fmt('username', 'mood', "%@ is %@")
  }).create({
    username: 'eviltrout',
    mood: "happy"
  });

  equal(t.get('exclaimyUsername'), '!!! eviltrout !!!', "it inserts the string");
  equal(t.get('multiple'), "eviltrout is happy", "it inserts multiple strings");

  t.set('username', 'codinghorror');
  equal(t.get('multiple'), "codinghorror is happy", "it supports changing properties");
  t.set('mood', 'ecstatic');
  equal(t.get('multiple'), "codinghorror is ecstatic", "it supports changing another property");
});


test("i18n", function() {
  var t = Em.Object.extend({
    exclaimyUsername: i18n('username', "!!! %@ !!!"),
    multiple: i18n('username', 'mood', "%@ is %@")
  }).create({
    username: 'eviltrout',
    mood: "happy"
  });

  equal(t.get('exclaimyUsername'), '%@ translated: !!! eviltrout !!!', "it inserts the string and then translates");
  equal(t.get('multiple'), "%@ translated: eviltrout is happy", "it inserts multiple strings and then translates");

  t.set('username', 'codinghorror');
  equal(t.get('multiple'), "%@ translated: codinghorror is happy", "it supports changing properties");
  t.set('mood', 'ecstatic');
  equal(t.get('multiple'), "%@ translated: codinghorror is ecstatic", "it supports changing another property");
});


test("url", function() {
  var t, testClass;
  
  testClass = Em.Object.extend({
    userUrl: url('username', "/users/%@")
  });

  t = testClass.create({ username: 'eviltrout' });
  equal(t.get('userUrl'), "/users/eviltrout", "it supports urls without a prefix");

  Discourse.BaseUri = "/prefixed/";
  t = testClass.create({ username: 'eviltrout' });
  equal(t.get('userUrl'), "/prefixed/users/eviltrout", "it supports urls with a prefix");
});
