import ArrayProxy from "@ember/array/proxy";

export default ArrayProxy.extend({
  render(topic, renderIcon) {
    const renderIconIf = (conditionProp, name, key) => {
      if (!topic.get(conditionProp)) {
        return;
      }
      renderIcon(name, key);
    };

    if (topic.get("closed") && topic.get("archived")) {
      renderIcon("discourse-no-entry", "locked_and_archived");
    } else {
      renderIconIf("closed", "discourse-no-entry", "locked");
      renderIconIf("archived", "discourse-no-entry", "archived");
    }

    this.forEach(args => renderIconIf(...args));
  }
}).create({
  content: [
    ["is_warning", "envelope", "warning"],
    ["pinned", "thumbtack", "pinned"],
    ["unpinned", "thumbtack", "unpinned"],
    ["invisible", "far-eye-slash", "unlisted"]
  ]
});
