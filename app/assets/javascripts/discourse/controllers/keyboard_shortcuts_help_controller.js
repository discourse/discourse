/**
  This controller is used to display the Keyboard Shortcuts Help Modal

  @class KeyboardShortcutsHelpController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.KeyboardShortcutsHelpController = Discourse.Controller.extend(Discourse.ModalFunctionality, {
  needs: ['modal']
});
