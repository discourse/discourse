const ColocatedTemplateProcessor = require("ember-cli-htmlbars/lib/colocated-broccoli-plugin");

module.exports = class DiscoursePluginColocatedTemplateProcessor extends (
  ColocatedTemplateProcessor
) {
  constructor(tree, rootName) {
    super(tree);
    this.rootName = rootName;
  }

  detectRootName() {
    return this.rootName;
  }
};
