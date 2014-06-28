export default Discourse.ModalBodyView.extend({
  templateName: 'modal/edit-category',

  _initializePanels: function() {
    this.set('panels', []);
  }.on('init')
});
