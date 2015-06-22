import TextField from 'discourse/components/text-field';

export default TextField.extend({
  placeholder: function() {
    return this.get('searchContextEnabled') ? "" : I18n.t('search.title');
  }.property('searchContextEnabled')
});
