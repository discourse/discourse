import { buildResolver } from "discourse-common/resolver";

export default Ember.Application.extend({
  rootElement: "#wizard-main",
  Resolver: buildResolver("wizard"),

  start() {
    Object.keys(requirejs._eak_seen).forEach(key => {
      if (/\/initializers\//.test(key)) {
        const module = requirejs(key, null, null, true);
        if (!module) {
          throw new Error(key + " must export an initializer.");
        }
        this.initializer(module.default);
      }
    });
  }
});
