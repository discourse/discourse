module("Discourse.NavItem", {
  setup: function() {
    this.site = Discourse.Site.current();
    this.asianCategory = Discourse.Category.create({name: '确实是这样', id: 343434});
    this.site.get('categories').addObject(this.asianCategory);
  },

  teardown: function() {
    this.site.get('categories').removeObject(this.asianCategory);
  }
});

test('href', function(){
  expect(4);

  function href(text, expected, label) {
    equal(Discourse.NavItem.fromText(text, {}).get('href'), expected, label);
  }

  href('latest', '/latest', 'latest');
  href('categories', '/categories', 'categories');
  href('category/bug', '/category/bug', 'English category name');
  href('category/确实是这样', '/category/343434-category', 'Chinese category name');
});
