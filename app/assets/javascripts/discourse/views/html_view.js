Discourse.HtmlView = Ember.View.extend({

  render: function(buffer) {
    var key = this.get("key"),
        htmlContent = PreloadStore.get("htmlContent");

    if (htmlContent && htmlContent[key] && htmlContent[key].length) {
      buffer.push(htmlContent[key]);
    }
  }

});
