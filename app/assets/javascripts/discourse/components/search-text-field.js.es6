import computed from 'ember-addons/ember-computed-decorators';
import { on } from 'ember-addons/ember-computed-decorators';
import TextField from 'discourse/components/text-field';

export default TextField.extend({
  @computed('searchService.searchContextEnabled')
  placeholder(searchContextEnabled) {
    return searchContextEnabled ? "" : I18n.t('search.title');
  },

  focusIn() {
    Em.run.later(() => this.$().select());
  },

  @on("didInsertElement")
  becomeFocused() {
    if (this.get('hasAutofocus')) this.$().focus();
  }
});
