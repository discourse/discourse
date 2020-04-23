/* global BreakString:true */

QUnit.module("lib:breakString", {});

QUnit.test("breakString", assert => {
  var b = function(s, hint) {
    return new BreakString(s).break(hint);
  };

  assert.equal(b("hello"), "hello");
  assert.equal(b("helloworld"), "helloworld");
  assert.equal(b("HeMans11"), "He<wbr>&#8203;Mans<wbr>&#8203;11");
  assert.equal(b("he_man"), "he_<wbr>&#8203;man");
  assert.equal(b("he11111"), "he<wbr>&#8203;11111");
  assert.equal(b("HRCBob"), "HRC<wbr>&#8203;Bob");
  assert.equal(
    b("bobmarleytoo", "Bob Marley Too"),
    "bob<wbr>&#8203;marley<wbr>&#8203;too"
  );
});
