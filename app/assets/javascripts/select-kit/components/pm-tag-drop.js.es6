import TagDropComponent from "select-kit/components/tag-drop";
import DiscourseURL from "discourse/lib/url";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default TagDropComponent.extend({
  @computed
  allTagsUrl() {
    return `/u/${this.currentUser.username}/messages/`;
  },

  content: Ember.computed.alias("pmTags"),

  actions: {
    onSelect(tagId) {
      const url = `/u/${this.currentUser.username}/messages/tag/${tagId}`;
      DiscourseURL.routeTo(url);
    }
  }
});
