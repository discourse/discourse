module("Discourse.HTML");

var html = Discourse.HTML;

test("categoryLink without a category", function() {
  blank(Discourse.HTML.categoryLink(), "it returns no HTML");
});

test("Regular categoryLink", function() {
  var category = Discourse.Category.create({
        name: 'hello',
        id: 123,
        description: 'cool description',
        color: 'ff0',
        text_color: 'f00'
      }),
      tag = parseHTML(Discourse.HTML.categoryLink(category))[0];

  equal(tag.name, 'a', 'it creates an `a` tag');
  equal(tag.attributes['class'], 'badge-category', 'it has the correct class');
  equal(tag.attributes.title, 'cool description', 'it has the correct title');

  ok(tag.attributes.style.indexOf('#ff0') !== -1, "it has the color style");
  ok(tag.attributes.style.indexOf('#f00') !== -1, "it has the textColor style");

  equal(tag.children[0].data, 'hello', 'it has the category name');
});

test("undefined color", function() {
  var noColor = Discourse.Category.create({ name: 'hello', id: 123 }),
      tag = parseHTML(Discourse.HTML.categoryLink(noColor))[0];

  blank(tag.attributes.style, "it has no color style because there are no colors");
});

test("allowUncategorized", function() {
  var uncategorized = Discourse.Category.create({name: 'uncategorized', id: 345});
  this.stub(Discourse.Site, 'currentProp').withArgs('uncategorized_category_id').returns(345);

  blank(Discourse.HTML.categoryLink(uncategorized), "it doesn't return HTML for uncategorized by default");
  present(Discourse.HTML.categoryLink(uncategorized, {allowUncategorized: true}), "it returns HTML");
});

