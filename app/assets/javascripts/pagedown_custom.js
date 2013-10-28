/*global Markdown:true*/

window.PagedownCustom = {
  insertButtons: [
    {
      id: 'wmd-quote-post',
      description: I18n.t("composer.quote_post_title"),
      execute: function() {
        // AWFUL but I can't figure out how to call a controller method from outside our app
        return Discourse.__container__.lookup('controller:composer').send('importQuote');
      }
    }
  ],

  customActions: {
    "doBlockquote": function(chunk, postProcessing, oldDoBlockquote) {

      // When traditional linebreaks are set, use the default Pagedown implementation
      if (Discourse.SiteSettings.traditional_markdown_linebreaks) {
        return oldDoBlockquote.call(this, chunk, postProcessing);
      }

      // Our custom blockquote for non-traditional markdown linebreaks
      var result = [];
      chunk.selection.split(/\n/).forEach(function (line) {
        var newLine = "";
        if (line.indexOf("> ") === 0) {
          newLine += line.substr(2);
        } else {
          if (/\S/.test(line)) { newLine += "> " + line; }
        }
        result.push(newLine);
      });
      chunk.selection = result.join("\n");

    }
  }
};
