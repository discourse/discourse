import LoadMore from "discourse/mixins/load-more";

export default Ember.View.extend(LoadMore, {
  classNames: ['paginated-topics-list'],
  eyelineSelector: '.paginated-topics-list .user-invite-list tr',
  templateName: 'user-invited-show'
});
