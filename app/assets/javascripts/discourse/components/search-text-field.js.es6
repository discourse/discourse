import computed from 'ember-addons/ember-computed-decorators';
import TextField from 'discourse/components/text-field';

export default TextField.extend({
  @computed('searchService.searchContextEnabled')
  placeholder: function(searchContextEnabled) {
    return searchContextEnabled ? "" : I18n.t('search.title');
  },

  focusIn: function() {
    Em.run.later(() => { this.$().select(); });
  },

  becomeFocused: function() {
    if (this.get('hasAutofocus')) this.$().focus();
  }.on('didInsertElement')
});
