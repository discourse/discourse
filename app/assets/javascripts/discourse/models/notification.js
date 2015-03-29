Discourse.NotificationContainer = Ember.ArrayProxy.extend({

});

Discourse.NotificationContainer.reopenClass({

  createFromJson: function(json_array) {
    return Discourse.NotificationContainer.create({content: json_array});
  },

  createFromError: function(error) {
    return Discourse.NotificationContainer.create({
      content: [],
      error: true,
      forbidden: error.status === 403
    });
  },

  loadRecent: function() {
    // TODO - add .json (breaks tests atm)
    return Discourse.ajax('/notifications').then(function(result) {
      return Discourse.NotificationContainer.createFromJson(result);
    }).catch(function(error) {
      // TODO HeaderController can't handle a createFromError
      // just throw for now
      throw error;
    });
  },

  loadHistory: function(beforeDate, username) {
    var url = '/notifications/history.json',
        params = [
          beforeDate ? ('before=' + beforeDate) : null,
          username ? ('user=' + username) : null
        ];

    // Remove nulls
    params = params.filter(function(param) { return !!param; });
    // Build URL
    params.forEach(function(param, idx) {
      url = url + (idx === 0 ? '?' : '&') + param;
    });

    return Discourse.ajax(url).then(function(result) {
      return Discourse.NotificationContainer.createFromJson(result);
    }).catch(function(error) {
      return Discourse.NotificationContainer.createFromError(error);
    });
  },

  resetNew: function() {
    return Discourse.ajax("/notifications/reset-new", {type: 'PUT'});
  }
});
