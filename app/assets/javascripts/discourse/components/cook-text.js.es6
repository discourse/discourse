import { cookAsync } from 'discourse/lib/text';

const CookText = Ember.Component.extend({
  tagName: '',
  cooked: null,

  didReceiveAttrs() {
    this._super(...arguments);
    cookAsync(this.get('rawText')).then(cooked => this.set('cooked', cooked));
  }
});

CookText.reopenClass({ positionalParams: ['rawText'] });

export default CookText;
