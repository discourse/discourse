module("Discourse.HTML");

var html = Discourse.HTML;

test("customHTML", function() {
  blank(html.getCustomHTML('evil'), "there is no custom HTML for a key by default");

  html.setCustomHTML('evil', 'trout');
  equal(html.getCustomHTML('evil'), 'trout', 'it retrieves the custom html');

  PreloadStore.store('customHTML', {cookie: 'monster'});
  equal(html.getCustomHTML('cookie'), 'monster', 'it returns HTML fragments from the PreloadStore');

});
