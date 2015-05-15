import LoadMore from "discourse/mixins/load-more";

export default Discourse.View.extend(LoadMore, {
  classNames: ['paginated-topics-list'],
  eyelineSelector: '.paginated-topics-list .topic-list tr',
});
