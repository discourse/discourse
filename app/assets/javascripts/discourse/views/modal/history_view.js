/**
  This view handles rendering of the history of a post

  @class HistoryView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.HistoryView = Discourse.ModalBodyView.extend({
  templateName: 'modal/history',
  title: I18n.t('history'),

  resizeModal: function(){
    var viewPortHeight = $(window).height();
    this.$(".modal-body").css("max-height", Math.floor(0.8 * viewPortHeight) + "px");
  }.on("didInsertElement")

});
