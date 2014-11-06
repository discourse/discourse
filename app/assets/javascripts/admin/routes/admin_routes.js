Discourse.Route.buildRoutes(function() {
  this.resource('admin', function() {
    this.route('dashboard', { path: '/' });
    this.resource('adminSiteSettings', { path: '/site_settings' }, function() {
      this.resource('adminSiteSettingsCategory', { path: 'category/:category_id'} );
    });

    this.resource('adminEmail', { path: '/email'}, function() {
      this.route('all');
      this.route('sent');
      this.route('skipped');
      this.route('previewDigest', { path: '/preview-digest' });
    });

    this.resource('adminCustomize', { path: '/customize' } ,function() {
      this.route('colors');
      this.route('css_html');
      this.resource('adminSiteText', { path: '/site_text' }, function() {
        this.route('edit', {path: '/:text_type'});
      });
      this.resource('adminUserFields', { path: '/user_fields' }, function() {
      });
    });
    this.route('api');

    this.resource('admin.backups', { path: '/backups' }, function() {
      this.route('logs');
    });

    this.resource('adminReports', { path: '/reports/:type' });

    this.resource('adminFlags', { path: '/flags' }, function() {
      this.route('active');
      this.route('old');
    });

    this.resource('adminLogs', { path: '/logs' }, function() {
      this.route('staffActionLogs', { path: '/staff_action_logs' });
      this.route('screenedEmails', { path: '/screened_emails' });
      this.route('screenedIpAddresses', { path: '/screened_ip_addresses' });
      this.route('screenedUrls', { path: '/screened_urls' });
    });

    this.resource('adminGroups', { path: '/groups'}, function() {
      this.resource('adminGroup', { path: '/:name' });
    });

    this.resource('adminUsers', { path: '/users' }, function() {
      this.resource('adminUser', { path: '/:username' }, function() {
        this.route('badges');
        this.route('tl3Requirements', { path: '/tl3_requirements' });
      });
      this.resource('adminUsersList', { path: '/list' }, function() {
        _.each(['active', 'new', 'pending', 'admins', 'moderators', 'blocked', 'suspended',
                'newuser', 'basicuser', 'regular', 'leaders', 'elders'], function(x) {
          this.route(x, { path: '/' + x });
        }, this);
      });
    });

    this.resource('adminBadges', { path: '/badges' }, function() {
      this.route('show', { path: '/:badge_id' });
    });

  });
});
