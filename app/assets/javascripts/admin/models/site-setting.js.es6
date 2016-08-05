import { ajax } from 'discourse/lib/ajax';
const SiteSetting = Discourse.Model.extend({
  overridden: function() {
    let val = this.get('value'),
        defaultVal = this.get('default');

    if (val === null) val = '';
    if (defaultVal === null) defaultVal = '';

    return val.toString() !== defaultVal.toString();
  }.property('value', 'default'),

  validValues: function() {
    const vals = [],
          translateNames = this.get('translate_names');

    this.get('valid_values').forEach(function(v) {
      if (v.name && v.name.length > 0) {
        vals.addObject(translateNames ? {name: I18n.t(v.name), value: v.value} : v);
      }
    });
    return vals;
  }.property('valid_values'),

  allowsNone: function() {
    if ( _.indexOf(this.get('valid_values'), '') >= 0 ) return 'admin.site_settings.none';
  }.property('valid_values')
});

SiteSetting.reopenClass({
  findAll() {
    return ajax("/admin/site_settings").then(function (settings) {
      // Group the results by category
      const categories = {};
      settings.site_settings.forEach(function(s) {
        if (!categories[s.category]) {
          categories[s.category] = [];
        }
        categories[s.category].pushObject(SiteSetting.create(s));
      });

      return Object.keys(categories).map(function(n) {
        return {nameKey: n, name: I18n.t('admin.site_settings.categories.' + n), siteSettings: categories[n]};
      });
    });
  },

  update(key, value) {
    const data = {};
    data[key] = value;
    return ajax("/admin/site_settings/" + key, { type: 'PUT', data });
  }
});

export default SiteSetting;
