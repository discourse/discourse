/**
  A modal view for displaying Keyboard Shortcut Help

  @class KeyboardShortcutsHelpView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.KeyboardShortcutsHelpView = Discourse.ModalBodyView.extend({
  templateName: 'modal/keyboard_shortcuts_help',
  title: I18n.t('keyboard_shortcuts_help.title')
});
