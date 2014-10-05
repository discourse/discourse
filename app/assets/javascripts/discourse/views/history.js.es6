export default Discourse.ModalBodyView.extend({
  templateName: 'modal/history',
  title: I18n.t('history'),

  resizeModal: function(){
    var viewPortHeight = $(window).height();
    this.$(".modal-body").css("max-height", Math.floor(0.8 * viewPortHeight) + "px");
  }.on("didInsertElement")
});
