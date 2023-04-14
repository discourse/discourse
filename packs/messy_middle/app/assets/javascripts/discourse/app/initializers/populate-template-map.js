import discourseTemplateMap from "discourse-common/lib/discourse-template-map";

export default {
  name: "populate-template-map",
  initialize() {
    discourseTemplateMap.setModuleNames(Object.keys(requirejs.entries));
  },
};
