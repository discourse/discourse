import Application from "@ember/application";
import { buildResolver } from "discourse-common/resolver";

export default Application.extend({
  rootElement: "#wizard-main",
  Resolver: buildResolver("wizard"),

  start() {
    // required for select kit to work without Ember CLI
    // eslint-disable-next-line no-undef
    Object.keys(Ember.TEMPLATES).forEach((k) => {
      if (k.indexOf("select-kit") === 0) {
        // eslint-disable-next-line no-undef
        let template = Ember.TEMPLATES[k];
        define(k, () => template);
      }
    });

    Object.keys(requirejs._eak_seen).forEach((key) => {
      if (/\/initializers\//.test(key)) {
        const module = requirejs(key, null, null, true);
        if (!module) {
          throw new Error(key + " must export an initializer.");
        }
        this.initializer(module.default);
      }
    });
  },
});
