module("Discourse.Category");

test('slugFor', function(){

  var slugFor = function(cat, val, text) {
    equal(Discourse.Category.slugFor(cat), val, text);
  };

  slugFor(Discourse.Category.create({slug: 'hello'}), "hello", "It calculates the proper slug for hello");
  slugFor(Discourse.Category.create({id: 123, slug: ''}), "123-category", "It returns id-category for empty strings");
  slugFor(Discourse.Category.create({id: 456}), "456-category", "It returns id-category for undefined slugs");

  var parentCategory = Discourse.Category.create({id: 345, slug: 'darth'});
  slugFor(Discourse.Category.create({slug: 'luke', parentCategory: parentCategory}),
          "darth/luke",
          "it uses the parent slug before the child");

  slugFor(Discourse.Category.create({id: 555, parentCategory: parentCategory}),
          "darth/555-category",
          "it uses the parent slug before the child and then uses id");

  parentCategory.set('slug', null);
  slugFor(Discourse.Category.create({id: 555, parentCategory: parentCategory}),
        "345-category/555-category",
        "it uses the parent before the child and uses ids for both");
});


test('findBySlug', function() {
  var darth = Discourse.Category.create({id: 1, slug: 'darth'}),
      luke = Discourse.Category.create({id: 2, slug: 'luke', parentCategory: darth}),
      categoryList = [darth, luke];

  this.stub(Discourse.Category, 'list').returns(categoryList);

  equal(Discourse.Category.findBySlug('darth'), darth, 'we can find a parent category');
  equal(Discourse.Category.findBySlug('luke', 'darth'), luke, 'we can find a child with parent');
  blank(Discourse.Category.findBySlug('luke'), 'luke is blank without the parent');
  blank(Discourse.Category.findBySlug('luke', 'leia'), 'luke is blank with an incorrect parent');
});