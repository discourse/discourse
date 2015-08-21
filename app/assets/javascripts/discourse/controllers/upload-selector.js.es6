import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  showMore: false,
  local: true,
  remote: Ember.computed.not("local"),

  actions: {
    useLocal() { this.setProperties({ local: true, showMore: false}); },
    useRemote() { this.set("local", false); },
    toggleShowMore() { this.toggleProperty("showMore"); }
  }

});
