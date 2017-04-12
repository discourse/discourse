import ModalFunctionality from 'discourse/mixins/modal-functionality';
import { ajax } from 'discourse/lib/ajax';

export default Ember.Controller.extend(ModalFunctionality, {
  loadDiff() {
    this.set('loading', true);
    ajax('/admin/logs/staff_action_logs/' + this.get('model.id') + '/diff')
      .then(diff=>{
        this.set('loading', false);
        this.set('diff', diff.side_by_side);
      });
  }
});
