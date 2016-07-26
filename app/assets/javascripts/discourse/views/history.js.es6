import ModalBodyView from "discourse/views/modal-body";
import ClickTrack from 'discourse/lib/click-track';
import { selectedText } from 'discourse/lib/utilities';

export default ModalBodyView.extend({
  templateName: 'modal/history',
  title: I18n.t('history'),

  resizeModal: function(){
    const viewPortHeight = $(window).height();
    this.$(".modal-body").css("max-height", Math.floor(0.8 * viewPortHeight) + "px");
  }.on("didInsertElement"),

  _inserted: function() {
    this.$().on('mouseup.discourse-redirect', '#revisions a', function(e) {
      // bypass if we are selecting stuff
      const selection = window.getSelection && window.getSelection();
      if (selection.type === "Range" || selection.rangeCount > 0) {
        if (selectedText() !== "") {
          return true;
        }
      }

      const $target = $(e.target);
      if ($target.hasClass('mention') || $target.parents('.expanded-embed').length) { return false; }

      return ClickTrack.trackClick(e);
    });

  }.on('didInsertElement'),

  // This view is being removed. Shut down operations
  _destroyed: function() {
    this.$().off('mouseup.discourse-redirect', '#revisions a');
  }.on('willDestroyElement')
});
