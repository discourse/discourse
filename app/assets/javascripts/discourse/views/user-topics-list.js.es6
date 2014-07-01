export default Discourse.View.extend(Discourse.LoadMore, {
  classNames: ['paginated-topics-list'],
  eyelineSelector: '.paginated-topics-list #topic-list tr',
  templateName: 'list/user_topics_list'
});
