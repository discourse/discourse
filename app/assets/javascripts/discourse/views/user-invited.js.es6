export default Ember.View.extend(Discourse.LoadMore, {
  classNames: ['paginated-topics-list'],
  eyelineSelector: '.paginated-topics-list .invite-list tr',
  templateName: 'user/invited'
});
