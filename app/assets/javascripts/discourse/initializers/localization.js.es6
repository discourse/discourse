export default {
  name: 'localization',
  after: 'inject-objects',

  initialize: function(container) {
    const siteSettings = container.lookup('site-settings:main');
    if (siteSettings.verbose_localization) {
      I18n.enable_verbose_localization();
    }

    // Merge any overrides into our object
    const overrides = PreloadStore.get('translationOverrides') || {};
    Object.keys(overrides).forEach(k => {
      const v = overrides[k];

      // Special case: Message format keys are functions
      if (/\_MF$/.test(k)) {
        k = k.replace(/^[a-z_]*js\./, '');
        I18n._compiledMFs[k] = new Function('transKey', `return (${v})(transKey);`);

        return;
      }

      k = k.replace('admin_js', 'js');
      const segs = k.split('.');
      let node = I18n.translations[I18n.locale];
      let i = 0;
      for (; node && i<segs.length-1; i++) {
        node = node[segs[i]];
      }

      if (node && i === segs.length-1) {
        node[segs[segs.length-1]] = v;
      }
    });
  }
};
