module("Discourse.Site");

test('create', function() {
  ok(Discourse.Site.create(), 'it can create with no parameters');
});

test('instance', function() {

  var site = Discourse.Site.current();

  present(site, "We have a current site singleton");
  present(site.get('categories'), "The instance has a list of categories");
  present(site.get('flagTypes'), "The instance has a list of flag types");
  present(site.get('trustLevels'), "The instance has a list of trust levels");

});

test('create categories', function() {

  var site = Discourse.Site.create({
    categories: [{ id: 1234, name: 'Test'},
                 { id: 3456, name: 'Test Subcategory', parent_category_id: 1234},
                 { id: 3456, name: 'Invalid Subcategory', parent_category_id: 6666}]
  });

  var categories = site.get('categories');
  site.get('sortedCategories');

  present(categories, "The categories are present");
  equal(categories.length, 3, "it loaded all three categories");

  var parent = categories.findBy('id', 1234);
  present(parent, "it loaded the parent category");
  blank(parent.get('parentCategory'), 'it has no parent category');

  var subcategory = categories.findBy('id', 3456);
  present(subcategory, "it loaded the subcategory");
  equal(subcategory.get('parentCategory'), parent, "it has associated the child with the parent");

  // remove invalid category and child
  categories.removeObject(categories[2]);
  categories.removeObject(categories[1]);

  equal(categories.length, site.get('categoriesByCount').length, "categories by count should change on removal");
  equal(categories.length, site.get('sortedCategories').length, "sorted categories should change on removal");

});
