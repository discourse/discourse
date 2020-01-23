import TopicListItem from "discourse/components/topic-list-item";
import Bookmark from "discourse/models/bookmark";
import discourseComputed from "discourse-common/utils/decorators";

export default TopicListItem.extend({
  @discourseComputed("topic.bookmarked_post_numbers")
  bookmakedPostNumber(bookmarked_post_numbers) {
    return bookmarked_post_numbers[0];
  },
  actions: {
    removeBookmark(id) {
      let bookmark = new Bookmark({ id: id });
      bookmark.destroy().then(this.refreshList);
    }
  }
});
