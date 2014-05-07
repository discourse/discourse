/**
  This controller is used to display the Keyboard Shortcuts Help Modal

  @class KeyboardShortcutsHelpController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
export default Discourse.Controller.extend(Discourse.ModalFunctionality, {
  needs: ['modal'],

  onShow: function() {
    this.set('controllers.modal.modalClass', 'keyboard-shortcuts-modal');
  }
});
