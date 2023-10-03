import { eagerLoadRawTemplateModules } from "discourse-common/lib/raw-templates";

export default {
  initialize() {
    eagerLoadRawTemplateModules();
  },
};
