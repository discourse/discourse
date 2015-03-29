import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/edit-category',

  _initializePanels: function() {
    this.set('panels', []);
  }.on('init')
});
