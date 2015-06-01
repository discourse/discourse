
module('emoji');

test("Emoji.search", function(){

  // able to find an alias
  equal(Discourse.Emoji.search("coll").length, 1);

});

