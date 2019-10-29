import EmberObject from "@ember/object";
import computed from "ember-addons/ember-computed-decorators";

export default EmberObject.extend({
  showDefault: null,

  @computed("defaultIcon")
  renderDiv(defaultIcon) {
    return (defaultIcon || this.statuses.length > 0) && !this.noDiv;
  },

  @computed
  statuses() {
    const topic = this.topic;
    const results = [];

    // TODO, custom statuses? via override?
    if (topic.get("is_warning")) {
      results.push({ icon: "envelope", key: "warning" });
    }

    if (topic.get("bookmarked")) {
      const postNumbers = topic.get("bookmarked_post_numbers");
      let url = topic.get("url");
      let extraClasses = "";
      if (postNumbers && postNumbers[0] > 1) {
        url += "/" + postNumbers[0];
      } else {
        extraClasses = "op-bookmark";
      }

      results.push({
        extraClasses,
        icon: "bookmark",
        key: "bookmarked",
        href: url
      });
    }

    if (topic.get("closed") && topic.get("archived")) {
      results.push({ icon: "lock", key: "locked_and_archived" });
    } else if (topic.get("closed")) {
      results.push({ icon: "lock", key: "locked" });
    } else if (topic.get("archived")) {
      results.push({ icon: "lock", key: "archived" });
    }

    if (topic.get("pinned")) {
      results.push({ icon: "thumbtack", key: "pinned" });
    }

    if (topic.get("unpinned")) {
      results.push({ icon: "thumbtack", key: "unpinned" });
    }

    if (topic.get("invisible")) {
      results.push({ icon: "far-eye-slash", key: "unlisted" });
    }

    results.forEach(result => {
      result.title = I18n.t(`topic_statuses.${result.key}.help`);
      if (
        this.currentUser &&
        (result.key === "pinned" || result.key === "unpinned")
      ) {
        result.openTag = "a href";
        result.closeTag = "a";
      } else {
        result.openTag = "span";
        result.closeTag = "span";
      }
    });

    let defaultIcon = this.defaultIcon;
    if (results.length === 0 && defaultIcon) {
      this.set("showDefault", defaultIcon);
    }
    return results;
  }
});
