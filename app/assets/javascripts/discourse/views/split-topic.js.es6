export default Discourse.ModalBodyView.extend(Discourse.SelectedPostsCount, {
  templateName: 'modal/split_topic',
  title: I18n.t('topic.split_topic.title')
});
