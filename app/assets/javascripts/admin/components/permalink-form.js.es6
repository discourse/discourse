export default Ember.Component.extend({
  classNames: ['permalink-form'],
  formSubmitted: false,
  permalinkType: 'topic_id',

  permalinkTypes: function() {
    return [
      {id: 'topic_id',       name: I18n.t('admin.permalink.topic_id')},
      {id: 'post_id',  name: I18n.t('admin.permalink.post_id')},
      {id: 'category_id', name: I18n.t('admin.permalink.category_id')},
      {id: 'external_url', name: I18n.t('admin.permalink.external_url')}
    ];
  }.property(),

  permalinkTypePlaceholder: function() {
    return 'admin.permalink.' + this.get('permalinkType');
  }.property('permalinkType'),

  actions: {
    submit: function() {
      if (!this.get('formSubmitted')) {
        const self = this;
        self.set('formSubmitted', true);
        const permalink = Discourse.Permalink.create({url: self.get('url'), permalink_type: self.get('permalinkType'), permalink_type_value: self.get('permalink_type_value')});
        permalink.save().then(function(result) {
          self.set('url', '');
          self.set('permalink_type_value', '');
          self.set('formSubmitted', false);
          self.sendAction('action', Discourse.Permalink.create(result.permalink));
          Em.run.schedule('afterRender', function() { self.$('.permalink-url').focus(); });
        }, function(e) {
          self.set('formSubmitted', false);
          let error;
          if (e.responseJSON && e.responseJSON.errors) {
            error = I18n.t("generic_error_with_reason", {error: e.responseJSON.errors.join('. ')});
          } else {
            error = I18n.t("generic_error");
          }
          bootbox.alert(error, function() { self.$('.permalink-url').focus(); });
        });
      }
    }
  },

  didInsertElement: function() {
    var self = this;
    self._super();
    Em.run.schedule('afterRender', function() {
      self.$('.external-url').keydown(function(e) {
        if (e.keyCode === 13) { // enter key
          self.send('submit');
        }
      });
    });
  }
});
