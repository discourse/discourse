(function() {

  window.Discourse.PrependPostView = Em.ContainerView.extend({
    init: function() {
      this._super();
      return this.trigger('prependPostContent');
    }
  });

}).call(this);
