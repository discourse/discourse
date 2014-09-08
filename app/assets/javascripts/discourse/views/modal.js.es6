export default Ember.View.extend({
  elementId: 'discourse-modal',
  templateName: 'modal/modal',
  classNameBindings: [':modal', ':hidden', 'controller.modalClass'],

  click: function(e) {
    // Delegate click to modal backdrop if clicked outside. We do this
    // because some CSS of ours seems to cover the backdrop and makes it
    // unclickable.
    if ($(e.target).closest('.modal-inner-container').length === 0) {
      $('.modal-backdrop').click();
    }
  }
});
