import RestModel from 'discourse/models/rest';

const trackedProperties = [
  'enabled', 'name', 'stylesheet', 'header', 'top', 'footer', 'mobile_stylesheet',
  'mobile_header', 'mobile_top', 'mobile_footer', 'head_tag', 'body_tag', 'embedded_css'
];

function changed() {
  const originals = this.get('originals');
  if (!originals) { return false; }
  return _.some(trackedProperties, (p) => originals[p] !== this.get(p));
}

const SiteCustomization = RestModel.extend({
  description: function() {
    return "" + this.name + (this.enabled ? ' (*)' : '');
  }.property('selected', 'name', 'enabled'),

  changed: changed.property.apply(changed, trackedProperties.concat('originals')),

  startTrackingChanges: function() {
    this.set('originals', this.getProperties(trackedProperties));
  }.on('init'),

  saveChanges() {
    return this.save(this.getProperties(trackedProperties)).then(() => this.startTrackingChanges());
  },

});

export default SiteCustomization;
