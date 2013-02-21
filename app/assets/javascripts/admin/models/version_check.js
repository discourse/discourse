(function() {

  window.Discourse.VersionCheck = Discourse.Model.extend({
    hasInstalledSha: function() {
      console.log( 'hello??' );
      return( this.get('installed_sha') && this.get('installed_sha') != 'unknown' );
    }.property('installed_sha')
  });

  Discourse.VersionCheck.reopenClass({
    find: function() {
      var promise = new RSVP.Promise()
      jQuery.ajax({
        url: '/admin/version_check',
        dataType: 'json',
        success: function(json) {
          promise.resolve(Discourse.VersionCheck.create(json));
        }
      });
      return promise;
    }
  });

}).call(this);
