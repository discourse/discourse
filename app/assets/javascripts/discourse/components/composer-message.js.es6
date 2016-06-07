import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNameBindings: [':composer-popup', ':hidden', 'message.extraClass'],

  @computed('message.templateName')
  defaultLayout(templateName) {
    return this.container.lookup(`template:composer/${templateName}`);
  },

  didInsertElement() {
    this._super();
    this.$().show();
  },

  actions: {
    closeMessage() {
      this.sendAction('closeMessage', this.get('message'));
    }
  }
});
