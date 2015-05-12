import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/flag',

  title: function() {
    return this.get('controller.flagTopic') ? I18n.t('flagging_topic.title') : I18n.t('flagging.title');
  }.property('controller.flagTopic'),

  _selectRadio: function() {
    this.$("input[type='radio']").prop('checked', false);

    const nameKey = this.get('controller.selected.name_key');
    if (!nameKey) { return; }

    this.$('#radio_' + nameKey).prop('checked', 'true');
  },

  selectedChanged: function() {
    Ember.run.next(this, this._selectRadio);
  }.observes('controller.selected.name_key'),

  // See: https://github.com/emberjs/ember.js/issues/10869
  _selectedHack: function() {
    this.removeObserver('controller.selected.name_key');
  }.on('willDestroyElement')
});
