import { eagerLoadRawTemplateModules } from "discourse/lib/raw-templates";

export default {
  initialize() {
    eagerLoadRawTemplateModules();
  },
};
