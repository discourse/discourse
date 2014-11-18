import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend({

  actions: {
    refresh: function() {
      var model = this.get('model'),
          self = this;

      self.set('loading', true);
      Discourse.EmailPreview.findDigest(this.get('lastSeen')).then(function (email) {
        model.setProperties(email.getProperties('html_content', 'text_content'));
        self.set('loading', false);
      });
    },

    toggleShowHtml: function() {
      this.toggleProperty('showHtml');
    }
  }

});
