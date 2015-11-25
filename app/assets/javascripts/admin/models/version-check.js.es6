const VersionCheck = Discourse.Model.extend({

  noCheckPerformed: function() {
    return this.get('updated_at') === null;
  }.property('updated_at'),

  dataIsOld: function() {
    return this.get('version_check_pending') || moment().diff(moment(this.get('updated_at')), 'hours') >= 48;
  }.property('updated_at'),

  staleData: function() {
    return ( this.get('dataIsOld') ||
             (this.get('installed_version') !== this.get('latest_version') && this.get('missing_versions_count') === 0) ||
             (this.get('installed_version') === this.get('latest_version') && this.get('missing_versions_count') !== 0) );
  }.property('dataIsOld', 'missing_versions_count', 'installed_version', 'latest_version'),

  upToDate: function() {
    return this.get('missing_versions_count') === 0 || this.get('missing_versions_count') === null;
  }.property('missing_versions_count'),

  behindByOneVersion: function() {
    return this.get('missing_versions_count') === 1;
  }.property('missing_versions_count'),

  gitLink: function() {
    return "https://github.com/discourse/discourse/tree/" + this.get('installed_sha');
  }.property('installed_sha'),

  shortSha: function() {
    return this.get('installed_sha').substr(0,10);
  }.property('installed_sha')
});

VersionCheck.reopenClass({
  find: function() {
    return Discourse.ajax('/admin/version_check').then(function(json) {
      return VersionCheck.create(json);
    });
  }
});

export default VersionCheck;
