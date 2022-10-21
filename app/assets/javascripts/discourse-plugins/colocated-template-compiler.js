const ColocatedTemplateProcessor = require("ember-cli-htmlbars/lib/colocated-broccoli-plugin");

module.exports = class DiscoursePluginColocatedTemplateProcessor extends (
  ColocatedTemplateProcessor
) {
  constructor(tree, discoursePluginName) {
    super(tree);
    this.discoursePluginName = discoursePluginName;
  }

  detectRootName() {
    return `discourse/plugins/${this.discoursePluginName}/discourse`;
  }
};
