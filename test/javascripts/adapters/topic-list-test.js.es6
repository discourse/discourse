module("adapter:topic-list");

import { finderFor } from 'discourse/adapters/topic-list';

test("finderFor", function() {
  // Mocking instead of using a pretender which decodes the path and thus does
  // not reflect the behavior of an actual web server.
  var mock = sandbox.mock(Discourse);
  mock.expects("ajax").withArgs("/search.json?q=test%25%25");
  var finderForFunction = finderFor('search', { q: "test%%" });
  finderForFunction();
  mock.verify();
});
