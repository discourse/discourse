export default {
  resource: 'admin',

  map() {
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

      this.resource('adminCustomizeCssHtml', { path: 'css_html' }, function() {
        this.route('show', {path: '/:site_customization_id/:section'});
      });

      this.resource('adminSiteText', { path: '/site_texts' }, function() {
        this.route('edit', {path: '/:text_type'});
      });
      this.resource('adminUserFields', { path: '/user_fields' });
      this.resource('adminEmojis', { path: '/emojis' });
      this.resource('adminPermalinks', { path: '/permalinks' });
      this.resource('adminEmbedding', { path: '/embedding' });
    });
    this.route('api');

    this.resource('admin.backups', { path: '/backups' }, function() {
      this.route('logs');
    });

    this.resource('adminReports', { path: '/reports/:type' });

    this.resource('adminFlags', { path: '/flags' }, function() {
      this.route('list', { path: '/:filter' });
    });

    this.resource('adminLogs', { path: '/logs' }, function() {
      this.route('staffActionLogs', { path: '/staff_action_logs' });
      this.route('screenedEmails', { path: '/screened_emails' });
      this.route('screenedIpAddresses', { path: '/screened_ip_addresses' });
      this.route('screenedUrls', { path: '/screened_urls' });
    });

    this.resource('adminGroups', { path: '/groups' }, function() {
      this.resource('adminGroupsType', { path: '/:type' }, function() {
        this.resource('adminGroup', { path: '/:name' });
      });
    });

    this.resource('adminUsers', { path: '/users' }, function() {
      this.resource('adminUser', { path: '/:username' }, function() {
        this.route('badges');
        this.route('tl3Requirements', { path: '/tl3_requirements' });
      });

      this.resource('adminUsersList', { path: '/list' }, function() {
        this.route('show', { path: '/:filter' });
      });
    });

    this.resource('adminBadges', { path: '/badges' }, function() {
      this.route('show', { path: '/:badge_id' });
    });
  }
};
