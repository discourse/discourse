import Resolver from 'wizard/resolver';
import Router from 'wizard/router';

export default Ember.Application.extend({
  rootElement: '#wizard-main',
  Resolver,
  Router,

  start() {
    Object.keys(requirejs._eak_seen).forEach(key => {
      if (/\/initializers\//.test(key)) {
        const module = require(key, null, null, true);
        if (!module) { throw new Error(key + ' must export an initializer.'); }
        this.instanceInitializer(module.default);
      }
    });
  }
});
