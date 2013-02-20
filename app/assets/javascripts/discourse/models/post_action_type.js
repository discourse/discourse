(function() {

  window.Discourse.PostActionType = Em.Object.extend({
    alsoName: (function() {
      if (this.get('is_flag')) {
        return Em.String.i18n('post.actions.flag');
      }
      return this.get('name');
    }).property('is_flag', 'name'),
    alsoNameLower: (function() {
      var _ref;
      return (_ref = this.get('alsoName')) ? _ref.toLowerCase() : void 0;
    }).property('alsoName')
  });

}).call(this);
