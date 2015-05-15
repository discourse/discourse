import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/history',
  title: I18n.t('history'),

  resizeModal: function(){
    const viewPortHeight = $(window).height();
    this.$(".modal-body").css("max-height", Math.floor(0.8 * viewPortHeight) + "px");
  }.on("didInsertElement")
});
