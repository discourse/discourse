export default Discourse.ModalBodyView.extend({
  templateName: 'modal/raw_email',
  title: I18n.t('raw_email.title'),

  resizeModal: function(){
    var viewPortHeight = $(window).height();
    this.$(".modal-body").css("max-height", Math.floor(0.8 * viewPortHeight) + "px");
  }.on("didInsertElement")
});
