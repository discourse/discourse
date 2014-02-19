/**
  This view handles the modal for flagging posts

  @class FlagView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.FlagView = Discourse.ModalBodyView.extend({
  templateName: 'modal/flag',

  title: function() {
    return this.get('controller.flagTopic') ? I18n.t('flagging_topic.title') : I18n.t('flagging.title');
  }.property('controller.flagTopic'),

  selectedChanged: function() {
    var flagView = this;
    Em.run.next(function() {
      flagView.$("input[type='radio']").prop('checked', false);

      var nameKey = flagView.get('controller.selected.name_key');
      if (!nameKey) return;

      flagView.$('#radio_' + nameKey).prop('checked', 'true');
    });
  }.observes('controller.selected.name_key')

});
