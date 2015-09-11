import { on, observes } from "ember-addons/ember-computed-decorators";
import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/avatar_selector',
  classNames: ['avatar-selector'],
  title: I18n.t('user.change_avatar.title'),

  // *HACK* used to select the proper radio button, because {{action}} stops the default behavior
  @on("didInsertElement")
  @observes("controller.selected")
  selectedChanged() {
    Em.run.next(() => $('input:radio[name="avatar"]').val([this.get('controller.selected')]));
  },

  @on("didInsertElement")
  _focusSelectedButton() {
    Em.run.next(() => $('input:radio[value="' + this.get('controller.selected') + '"]').focus());
  }
});
