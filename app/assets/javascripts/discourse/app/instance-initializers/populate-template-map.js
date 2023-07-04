import discourseTemplateMap from "discourse-common/lib/discourse-template-map";

export default {
  initialize() {
    discourseTemplateMap.setModuleNames(Object.keys(requirejs.entries));
  },
};
