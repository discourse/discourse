module("Discourse.Computed");

var testClass = Em.Object.extend({
  same: Discourse.computed.propertyEqual('cookies', 'biscuits'),
  diff: Discourse.computed.propertyNotEqual('cookies', 'biscuits'),
  exclaimyUsername: Discourse.computed.fmt('username', "!!! %@ !!!"),
  multiple: Discourse.computed.fmt('username', 'mood', "%@ is %@"),
  userUrl: Discourse.computed.url('username', "/users/%@")
});

test("propertyEqual", function() {
  var t = testClass.create({
    cookies: 10,
    biscuits: 10
  });

  ok(t.get('same'), "it is true when the properties are the same");
  t.set('biscuits', 9);
  ok(!t.get('same'), "it isn't true when one property is different");
});

test("propertyNotEqual", function() {
  var t = testClass.create({
    cookies: 10,
    biscuits: 10
  });

  ok(!t.get('diff'), "it isn't true when the properties are the same");
  t.set('biscuits', 9);
  ok(t.get('diff'), "it is true when one property is different");
});


test("fmt", function() {
  var t = testClass.create({
    username: 'eviltrout',
    mood: "happy"
  });

  equal(t.get('exclaimyUsername'), '!!! eviltrout !!!', "it inserts the string");
  equal(t.get('multiple'), "eviltrout is happy");

  t.set('username', 'codinghorror');
  equal(t.get('multiple'), "codinghorror is happy", "supports changing proerties");
  t.set('mood', 'ecstatic');
  equal(t.get('multiple'), "codinghorror is ecstatic", "supports changing another property");
});


test("url without a prefix", function() {
  var t = testClass.create({ username: 'eviltrout' });
  equal(t.get('userUrl'), "/users/eviltrout");

});

test("url with a prefix", function() {
  Discourse.BaseUri = "/prefixed/";
  var t = testClass.create({ username: 'eviltrout' });
  equal(t.get('userUrl'), "/prefixed/users/eviltrout");

});