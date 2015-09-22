export default Ember.Controller.extend({

  actions: {
    refresh() {
      const model = this.get('model');

      this.set('loading', true);
      Discourse.EmailPreview.findDigest(this.get('lastSeen')).then(email => {
        model.setProperties(email.getProperties('html_content', 'text_content'));
        this.set('loading', false);
      });
    },

    toggleShowHtml() {
      this.toggleProperty('showHtml');
    }
  }

});
