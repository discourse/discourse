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

test('postCountStatsStrings', function() {
  var category1 = Discourse.Category.create({id: 1, slug: 'unloved', posts_year: 2, posts_month: 0, posts_week: 0, posts_day: 0}),
      category2 = Discourse.Category.create({id: 2, slug: 'hasbeen', posts_year: 50, posts_month: 4, posts_week: 0, posts_day: 0}),
      category3 = Discourse.Category.create({id: 3, slug: 'solastweek', posts_year: 250, posts_month: 200, posts_week: 50, posts_day: 0}),
      category4 = Discourse.Category.create({id: 4, slug: 'hotstuff', posts_year: 500, posts_month: 280, posts_week: 100, posts_day: 22});

  var result = category1.get('postCountStatsStrings');
  equal(result.length, 2, "should show month and year");
  equal(result[0], '0 / month', "should show month and year");
  equal(result[1], '2 / year', "should show month and year");

  result = category2.get('postCountStatsStrings');
  equal(result.length, 2, "should show month and year");
  equal(result[0], '4 / month', "should show month and year");
  equal(result[1], '50 / year', "should show month and year");

  result = category3.get('postCountStatsStrings');
  equal(result.length, 2, "should show week and month");
  equal(result[0], '50 / week', "should show week and month");
  equal(result[1], '200 / month', "should show week and month");

  result = category4.get('postCountStatsStrings');
  equal(result.length, 2, "should show day and week");
  equal(result[0], '22 / day', "should show day and week");
  equal(result[1], '100 / week', "should show day and week");
});
