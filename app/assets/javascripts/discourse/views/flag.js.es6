export default Discourse.ModalBodyView.extend({
  templateName: 'modal/flag',

  title: function() {
    return this.get('controller.flagTopic') ? I18n.t('flagging_topic.title') : I18n.t('flagging.title');
  }.property('controller.flagTopic'),

  selectedChanged: function() {
    var self = this;
    Em.run.next(function() {
      self.$("input[type='radio']").prop('checked', false);

      var nameKey = self.get('controller.selected.name_key');
      if (!nameKey) return;

      self.$('#radio_' + nameKey).prop('checked', 'true');
    });
  }.observes('controller.selected.name_key')
});
