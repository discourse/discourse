export default Ember.View.extend({
  elementId: 'discourse-modal',
  templateName: 'modal/modal',
  classNameBindings: [':modal', ':hidden', 'controller.modalClass']
});
