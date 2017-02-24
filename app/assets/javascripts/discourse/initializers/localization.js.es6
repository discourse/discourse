import PreloadStore from 'preload-store';

export default {
  name: 'localization',
  after: 'inject-objects',

  enableVerboseLocalization() {
    let counter = 0;
    let keys = {};
    let t = I18n.t;

    I18n.noFallbacks = true;

    I18n.t = I18n.translate = function(scope, value){
      let current = keys[scope];
      if (!current) {
        current = keys[scope] = ++counter;
        let message = "Translation #" + current + ": " + scope;
        if (!_.isEmpty(value)) {
          message += ", parameters: " + JSON.stringify(value);
        }
        Em.Logger.info(message);
      }
      return t.apply(I18n, [scope, value]) + " (#" + current + ")";
    };
  },

  initialize(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.verbose_localization) {
      this.enableVerboseLocalization();
    }

    // Merge any overrides into our object
    const overrides = PreloadStore.get('translationOverrides') || {};
    Object.keys(overrides).forEach(k => {
      const v = overrides[k];

      // Special case: Message format keys are functions
      if (/_MF$/.test(k)) {
        k = k.replace(/^[a-z_]*js\./, '');
        I18n._compiledMFs[k] = new Function('transKey', `return (${v})(transKey);`);
        return;
      }

      k = k.replace('admin_js', 'js');

      const segs = k.split('.');

      let node = I18n.translations[I18n.locale];
      let i = 0;

      for (; i < segs.length - 1; i++) {
        if (!(segs[i] in node)) node[segs[i]] = {};
        node = node[segs[i]];
      }

      node[segs[segs.length-1]] = v;

    });
  }
};
