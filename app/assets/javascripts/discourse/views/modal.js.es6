export default Ember.View.extend({
  elementId: 'discourse-modal',
  templateName: 'modal/modal',
  classNameBindings: [':modal', ':hidden', 'controller.modalClass'],

  click(e) {
    const $target = $(e.target);
    if ($target.hasClass("modal-middle-container") ||
        $target.hasClass("modal-outer-container")) {
      // Delegate click to modal close if clicked outside.
      // We do this because some CSS of ours seems to cover
      // the backdrop and makes it unclickable.
      $('.modal-header a.close').click();
    }
  },

  keyDown(e) {
    // Delegate click to modal close when pressing ESC
    if (e.keyCode === 27) {
      Em.run.next(() => $('.modal-header a.close').click());
    }
  }
});
