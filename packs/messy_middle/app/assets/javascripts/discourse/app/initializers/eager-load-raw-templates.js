import { eagerLoadRawTemplateModules } from "discourse-common/lib/raw-templates";

export default {
  name: "eager-load-raw-templates",

  initialize() {
    eagerLoadRawTemplateModules();
  },
};
