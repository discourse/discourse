export default Ember.View.extend({
  elementId: 'discourse-modal',
  templateName: 'modal/modal',
  classNameBindings: [':modal', ':hidden', 'controller.modalClass'],
  attributeBindings: ['data-keyboard'],

  // We handle ESC ourselves
  'data-keyboard': 'false',

  _bindOnInsert: function() {
    $('html').on('keydown.discourse-modal', e => {
      if (e.which === 27) {
        Em.run.next(() => $('.modal-header a.close').click());
      }
    });
  }.on('didInsertElement'),

  _bindOnDestroy: function() {
    $('html').off('keydown.discourse-modal');
  }.on('willDestroyElement'),

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
