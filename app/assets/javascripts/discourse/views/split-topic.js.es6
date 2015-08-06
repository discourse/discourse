import SelectedPostsCount from 'discourse/mixins/selected-posts-count';
import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend(SelectedPostsCount, {
  templateName: 'modal/split-topic',
  title: I18n.t('topic.split_topic.title')
});
