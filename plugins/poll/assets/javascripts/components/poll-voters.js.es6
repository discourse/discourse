export default Ember.Component.extend({
  layoutName: "components/poll-voters",
  tagName: 'ul',
  classNames: ["poll-voters-list"],
  isExpanded: false,
  numOfVotersToShow: 20,

  actions: {
    toggleExpand() {
      this.toggleProperty("isExpanded");
    }
  }
});
