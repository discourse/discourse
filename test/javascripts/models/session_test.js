module("Discourse.Session");

test('current', function(){
  var session = Discourse.Session.current();

  present(session, "We have a current site session");
  equal(session, Discourse.Session.current(), "Calling it a second time returns the same instance");

  blank(Discourse.Session.current('orange'), "by default properties are nil");
  session.set('orange', 'newBlack');
  equal(Discourse.Session.current('orange'), "newBlack", "it remembers values");

  Discourse.Session.current('orange', 'juice');
  equal(session.get('orange'), "juice", "it can be updated");

});