Discourse.HtmlView = Ember.View.extend({

  render: function(buffer) {
    var key = this.get("key"),
        noscript = $("noscript").text();

    if (noscript.length) {
      var regexp = new RegExp("<!-- " +  key + ": -->((?:.|[\\n\\r])*)<!-- :" + key + " -->"),
          content = noscript.match(regexp)[1];

      buffer.push(content);
    }
  }

});
