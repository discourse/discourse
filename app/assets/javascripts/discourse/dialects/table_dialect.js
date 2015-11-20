var tableFlattenBlocks = function(blocks) {
  var result = "";
  blocks.forEach(function(b) {
    result += b;
    if (b.trailing) { result += b.trailing; }
  });

  // bypass newline insertion
  return result.replace(/[\n\r]/g, " ");
};

var emitter = function(contents) {
  // TODO event should be fired when sanitizer loads
  if (window.html4 && window.html4.ELEMENTS.td !== 1) {
     window.html4.ELEMENTS.table = 0;
     window.html4.ELEMENTS.tbody = 1;
     window.html4.ELEMENTS.td = 1;
     window.html4.ELEMENTS.thead = 1;
     window.html4.ELEMENTS.th = 1;
     window.html4.ELEMENTS.tr = 1;
  }
  return ['table', {"class": "md-table"}, tableFlattenBlocks.apply(this, [contents])];
};

var tableBlock = {
  start: /(<table[^>]*>)([\S\s]*)/igm,
  stop: /<\/table>/igm,
  rawContents: true,
  emitter: emitter,
  priority: 1
};

var init = function(){
  if (Discourse.SiteSettings.allow_html_tables) {
    Discourse.Markdown.whiteListTag("table");
    Discourse.Markdown.whiteListTag("table", "class", "md-table");
    Discourse.Markdown.whiteListTag("tbody");
    Discourse.Markdown.whiteListTag("thead");
    Discourse.Markdown.whiteListTag("tr");
    Discourse.Markdown.whiteListTag("th");
    Discourse.Markdown.whiteListTag("td");
    Discourse.Dialect.replaceBlock(tableBlock);

  }
};

if (Discourse.SiteSettings) {
  init();
} else {
  Discourse.initializer({initialize: init, name: 'enable-html-tables'});
}
