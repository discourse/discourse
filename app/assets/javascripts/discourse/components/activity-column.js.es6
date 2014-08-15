import { daysSinceEpoch } from "discourse/helpers/cold-age-class";

export default Ember.Component.extend({
  tagName: 'td',
  classNameBindings: [':activity', 'coldness'],
  attributeBindings: ['title'],

  // returns createdAt if there's no bumped date
  bumpedAt: function() {
    var bumpedAt = this.get('topic.bumped_at');
    if (bumpedAt) {
      return new Date(bumpedAt);
    } else {
      return this.get('createdAt');
    }
  }.property('topic.bumped_at', 'createdAt'),

  createdAt: function() {
    return new Date(this.get('topic.created_at'));
  }.property('topic.created_at'),

  coldness: function() {
    var bumpedAt = this.get('bumpedAt'),
        createdAt = this.get('createdAt');

    if (!bumpedAt) { return; }
    var delta = daysSinceEpoch(bumpedAt) - daysSinceEpoch(createdAt);

    if (delta > Discourse.SiteSettings.cold_age_days_high) { return 'coldmap-high'; }
    if (delta > Discourse.SiteSettings.cold_age_days_medium) { return 'coldmap-med'; }
    if (delta > Discourse.SiteSettings.cold_age_days_low) { return 'coldmap-low'; }
  }.property('bumpedAt', 'createdAt'),

  title: function() {
    // return {{i18n last_post}}: {{{raw-date topic.bumped_at}}}
    return I18n.t('first_post') + ": " + Discourse.Formatter.longDate(this.get('createdAt')) + "\n" +
           I18n.t('last_post') + ": " + Discourse.Formatter.longDate(this.get('bumpedAt'));
  }.property('bumpedAt', 'createdAt'),

  render: function(buffer) {
    buffer.push('<a href="' + this.get('topic.lastPostUrl') + '">');
    buffer.push(Discourse.Formatter.autoUpdatingRelativeAge(this.get('bumpedAt')));
    buffer.push("</a>");
  }
});
