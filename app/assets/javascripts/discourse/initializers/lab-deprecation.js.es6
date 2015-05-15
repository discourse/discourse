import loadScript from 'discourse/lib/load-script';

export default {
  name: 'lab-deprecation',

  initialize() {
    if (window.$LAB) { return; }

    window.$LAB = {
      script(path) {
        Ember.warn('$LAB is not included with Discouse anymore. Use `loadScript` instead.');

        const promise = loadScript(path);
        promise.wait = promise.then;
        return promise;
      }
    };
  }
};
