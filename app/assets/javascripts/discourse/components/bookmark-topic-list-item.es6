import TopicListItem from "discourse/components/topic-list-item";
import Bookmark from "discourse/models/bookmark";
import { readOnly } from "@ember/object/computed";

export default TopicListItem.extend({
  bookmakedPostNumber: readOnly("topic.bookmarked_post_numbers.firstObject"),
  actions: {
    removeBookmark(id) {
      let bookmark = Bookmark.create({ id });
      bookmark.destroy().then(this.refreshList);
    }
  }
});
