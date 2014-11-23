import ModalFunctionality from 'discourse/mixins/modal-functionality';
import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend(ModalFunctionality, {
  needs: ['modal'],

  onShow: function() {
    this.set('controllers.modal.modalClass', 'keyboard-shortcuts-modal');
  }
});
