/*global module:true test:true ok:true visit:true expect:true exists:true count:true equal:true */

module("Discourse.Category");

test('slugFor', function(){

  var slugFor = function(args, val, text) {
    equal(Discourse.Category.slugFor(args), val, text);
  }

  slugFor({slug: 'hello'}, "hello", "It calculates the proper slug for hello");
  slugFor({id: 123, slug: ''}, "123-category", "It returns id-category for empty strings");
  slugFor({id: 456}, "456-category", "It returns id-category for undefined slugs");

});