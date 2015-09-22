import { on } from "ember-addons/ember-computed-decorators";

export default Ember.View.extend({
  elementId: 'discourse-modal',
  templateName: 'modal/modal',
  classNameBindings: [':modal', ':hidden', 'controller.modalClass'],
  attributeBindings: ['data-keyboard'],

  // We handle ESC ourselves
  'data-keyboard': 'false',

  @on("didInsertElement")
  setUp() {
    $('html').on('keydown.discourse-modal', e => {
      if (e.which === 27) {
        Em.run.next(() => $('.modal-header a.close').click());
      }
    });
  },

  @on("willDestroyElement")
  cleanUp() {
    $('html').off('keydown.discourse-modal');
  },

  click(e) {
    const $target = $(e.target);
    if ($target.hasClass("modal-middle-container") ||
        $target.hasClass("modal-outer-container")) {
      // Delegate click to modal close if clicked outside.
      // We do this because some CSS of ours seems to cover
      // the backdrop and makes it unclickable.
      $('.modal-header a.close').click();
    }
  }
});
