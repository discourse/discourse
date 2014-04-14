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

test('findByIds', function(){
  var categories =  [
        Discourse.Category.create({id: 1}),
        Discourse.Category.create({id: 2})];

  this.stub(Discourse.Category, 'list').returns(categories);
  deepEqual(Discourse.Category.findByIds([1,2,3]), categories);
});

test('postCountStats', function() {
  var category1 = Discourse.Category.create({id: 1, slug: 'unloved', posts_year: 2, posts_month: 0, posts_week: 0, posts_day: 0}),
      category2 = Discourse.Category.create({id: 2, slug: 'hasbeen', posts_year: 50, posts_month: 4, posts_week: 0, posts_day: 0}),
      category3 = Discourse.Category.create({id: 3, slug: 'solastweek', posts_year: 250, posts_month: 200, posts_week: 50, posts_day: 0}),
      category4 = Discourse.Category.create({id: 4, slug: 'hotstuff', posts_year: 500, posts_month: 280, posts_week: 100, posts_day: 22}),
      category5 = Discourse.Category.create({id: 6, slug: 'empty', posts_year: 0, posts_month: 0, posts_week: 0, posts_day: 0});

  var result = category1.get('postCountStats');
  equal(result.length, 1, "should only show year");
  equal(result[0].value, 2);
  equal(result[0].unit, 'year');

  result = category2.get('postCountStats');
  equal(result.length, 2, "should show month and year");
  equal(result[0].value, 4);
  equal(result[0].unit, 'month');
  equal(result[1].value, 50);
  equal(result[1].unit, 'year');

  result = category3.get('postCountStats');
  equal(result.length, 2, "should show week and month");
  equal(result[0].value, 50);
  equal(result[0].unit, 'week');
  equal(result[1].value, 200);
  equal(result[1].unit, 'month');

  result = category4.get('postCountStats');
  equal(result.length, 2, "should show day and week");
  equal(result[0].value, 22);
  equal(result[0].unit, 'day');
  equal(result[1].value, 100);
  equal(result[1].unit, 'week');

  result = category5.get('postCountStats');
  equal(result.length, 0, "should show nothing");
});
