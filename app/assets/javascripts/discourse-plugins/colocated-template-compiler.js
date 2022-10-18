const ColocatedTemplateProcessor = require("ember-cli-htmlbars/lib/colocated-broccoli-plugin");

module.exports = class DiscoursePluginColocatedTemplateProcessor extends (
  ColocatedTemplateProcessor
) {
  detectRootName() {
    const entries = this.currentEntries().filter((e) => !e.isDirectory());

    const path = entries[0]?.relativePath;

    const match = path?.match(
      /^discourse\/plugins\/(?<name>[^/]+)\/discourse\//
    );

    if (match) {
      return `discourse/plugins/${match.groups.name}/discourse`;
    }
  }
};
