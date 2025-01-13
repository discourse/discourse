import discourseTemplateMap from "discourse/lib/discourse-template-map";

export default {
  initialize() {
    discourseTemplateMap.setModuleNames(Object.keys(requirejs.entries));
  },
};
