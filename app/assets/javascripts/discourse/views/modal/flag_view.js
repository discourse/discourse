/**
  This view handles the modal for flagging posts

  @class FlagView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.FlagView = Discourse.ModalBodyView.extend({
  templateName: 'modal/flag',
  title: I18n.t('flagging.title'),

  selectedChanged: function() {
    var nameKey = this.get('controller.selected.name_key');
    if (!nameKey) return;
    Em.run.next(function() {
      $('#radio_' + nameKey).prop('checked', 'true');
    });
  }.observes('controller.selected.name_key'),

  didInsertElement: function() {
    this._super();

    // Would be nice if there were an EmberJs radio button to do this for us. Oh well, one should be coming
    // in an upcoming release.
    this.$("input[type='radio']").prop('checked', false);
  }
});
