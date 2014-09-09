export default Ember.View.extend({
  elementId: 'discourse-modal',
  templateName: 'modal/modal',
  classNameBindings: [':modal', ':hidden', 'controller.modalClass'],

  click: function(e) {
    var $target = $(e.target);
    // some buttons get removed from the DOM when you click on them.
    // we don't want to close the modal when we click on those...
    if ($target.parent().length > 0 &&
        $target.closest('.modal-inner-container').length === 0) {
      // Delegate click to modal backdrop if clicked outside. We do this
      // because some CSS of ours seems to cover the backdrop and makes it
      // unclickable.
      $('.modal-backdrop').click();
    }
  }
});
