import ModalFunctionality from 'discourse/mixins/modal-functionality';

export default Ember.Controller.extend(ModalFunctionality, {
  previousSelected: Ember.computed.equal('selectedTab', 'previous'),
  newSelected:      Ember.computed.equal('selectedTab', 'new'),

  onShow: function() {
    this.send("selectNew");
  },

  actions: {
    selectNew: function() {
      this.set('selectedTab', 'new');
    },

    selectPrevious: function() {
      this.set('selectedTab', 'previous');
    }
  }
});
