import ColorSchemeColor from 'admin/models/color-scheme-color';

const ColorScheme = Discourse.Model.extend(Ember.Copyable, {

  init: function() {
    this._super();
    this.startTrackingChanges();
  },

  description: function() {
    return "" + this.name + (this.enabled ? ' (*)' : '');
  }.property(),

  startTrackingChanges: function() {
    this.set('originals', {
      name: this.get('name'),
      enabled: this.get('enabled')
    });
  },

  copy: function() {
    var newScheme = ColorScheme.create({name: this.get('name'), enabled: false, can_edit: true, colors: Em.A()});
    _.each(this.get('colors'), function(c){
      newScheme.colors.pushObject(ColorSchemeColor.create({name: c.get('name'), hex: c.get('hex'), default_hex: c.get('default_hex')}));
    });
    return newScheme;
  },

  changed: function() {
    if (!this.originals) return false;
    if (this.originals['name'] !== this.get('name') || this.originals['enabled'] !== this.get('enabled')) return true;
    if (_.any(this.get('colors'), function(c){ return c.get('changed'); })) return true;
    return false;
  }.property('name', 'enabled', 'colors.@each.changed', 'saving'),

  disableSave: function() {
    return !this.get('changed') || this.get('saving') || _.any(this.get('colors'), function(c) { return !c.get('valid'); });
  }.property('changed'),

  disableEnable: function() {
    return !this.get('id') || this.get('saving');
  }.property('id', 'saving'),

  newRecord: function() {
    return (!this.get('id'));
  }.property('id'),

  save: function(opts) {
    if (this.get('is_base') || this.get('disableSave')) return;

    var self = this;
    this.set('savingStatus', I18n.t('saving'));
    this.set('saving',true);

    var data = { enabled: this.enabled };

    if (!opts || !opts.enabledOnly) {
      data.name = this.name;

      data.colors = [];
      _.each(this.get('colors'), function(c) {
        if (!self.id || c.get('changed')) {
          data.colors.pushObject({name: c.get('name'), hex: c.get('hex')});
        }
      });
    }

    return Discourse.ajax("/admin/color_schemes" + (this.id ? '/' + this.id : '') + '.json', {
      data: JSON.stringify({"color_scheme": data}),
      type: this.id ? 'PUT' : 'POST',
      dataType: 'json',
      contentType: 'application/json'
    }).then(function(result) {
      if(result.id) { self.set('id', result.id); }
      if (!opts || !opts.enabledOnly) {
        self.startTrackingChanges();
        _.each(self.get('colors'), function(c) {
          c.startTrackingChanges();
        });
      } else {
        self.set('originals.enabled', data.enabled);
      }
      self.set('savingStatus', I18n.t('saved'));
      self.set('saving', false);
      self.notifyPropertyChange('description');
    });
  },

  destroy: function() {
    if (this.id) {
      return Discourse.ajax("/admin/color_schemes/" + this.id, { type: 'DELETE' });
    }
  }

});

var ColorSchemes = Ember.ArrayProxy.extend({
  selectedItemChanged: function() {
    var selected = this.get('selectedItem');
    _.each(this.get('content'),function(i) {
      return i.set('selected', selected === i);
    });
  }.observes('selectedItem')
});

ColorScheme.reopenClass({
  findAll: function() {
    var colorSchemes = ColorSchemes.create({ content: [], loading: true });
    Discourse.ajax('/admin/color_schemes').then(function(all) {
      _.each(all, function(colorScheme){
        colorSchemes.pushObject(ColorScheme.create({
          id: colorScheme.id,
          name: colorScheme.name,
          enabled: colorScheme.enabled,
          is_base: colorScheme.is_base,
          colors: colorScheme.colors.map(function(c) { return ColorSchemeColor.create({name: c.name, hex: c.hex, default_hex: c.default_hex}); })
        }));
      });
      colorSchemes.set('loading', false);
    });
    return colorSchemes;
  }
});

export default ColorScheme;
