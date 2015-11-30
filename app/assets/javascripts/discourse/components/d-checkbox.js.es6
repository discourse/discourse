import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: 'label',

  @on('didInsertElement')
  _watchChanges() {
    // In Ember 13.3 we can use action on the checkbox `{{input}}` but not in 1.11
    this.$('input').on('click.d-checkbox', () => {
      Ember.run.scheduleOnce('afterRender', () => this.sendAction('change'));
    });
  },

  @on('willDestroyElement')
  _stopWatching() {
    this.$('input').off('click.d-checkbox');
  }
});
