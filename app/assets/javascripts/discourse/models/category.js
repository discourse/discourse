(function() {

  window.Discourse.Category = Discourse.Model.extend({
    url: (function() {
      return "/category/" + (this.get('slug'));
    }).property('name'),
    style: (function() {
      return "background-color: #" + (this.get('color'));
    }).property('color'),
    moreTopics: (function() {
      return this.get('topic_count') > Discourse.SiteSettings.category_featured_topics;
    }).property('topic_count'),
    save: function(args) {
      var url,
        _this = this;
      url = "/categories";
      if (this.get('id')) {
        url = "/categories/" + (this.get('id'));
      }
      return this.ajax(url, {
        data: {
          name: this.get('name'),
          color: this.get('color')
        },
        type: this.get('id') ? 'PUT' : 'POST',
        success: function(result) {
          return args.success(result);
        },
        error: function(errors) {
          return args.error(errors);
        }
      });
    },
    "delete": function(callback) {
      var _this = this;
      return jQuery.ajax("/categories/" + (this.get('slug')), {
        type: 'DELETE',
        success: function() {
          return callback();
        }
      });
    }
  });

}).call(this);
