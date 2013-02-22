(function() {

  window.Discourse.User = Discourse.Model.extend(Discourse.Presence, {
    avatarLarge: (function() {
      return Discourse.Utilities.avatarUrl(this.get('username'), 'large', this.get('avatar_template'));
    }).property('username'),
    avatarSmall: (function() {
      return Discourse.Utilities.avatarUrl(this.get('username'), 'small', this.get('avatar_template'));
    }).property('username'),
    websiteName: (function() {
      return this.get('website').split("/")[2];
    }).property('website'),
    path: (function() {
      return "/users/" + (this.get('username_lower'));
    }).property('username'),
    username_lower: (function() {
      return this.get('username').toLowerCase();
    }).property('username'),
    trustLevel: (function() {
      return Discourse.get('site.trust_levels').findProperty('id', this.get('trust_level'));
    }).property('trust_level'),
    changeUsername: function(newUsername) {
      return jQuery.ajax({
        url: "/users/" + (this.get('username_lower')) + "/preferences/username",
        type: 'PUT',
        data: {
          new_username: newUsername
        }
      });
    },
    changeEmail: function(email) {
      return jQuery.ajax({
        url: "/users/" + (this.get('username_lower')) + "/preferences/email",
        type: 'PUT',
        data: {
          email: email
        }
      });
    },
    copy: function(deep) {
      return Discourse.User.create(this.getProperties(Ember.keys(this)));
    },
    save: function(finished) {
      var _this = this;
      return jQuery.ajax("/users/" + this.get('username').toLowerCase(), {
        data: this.getProperties('auto_track_topics_after_msecs', 
                                 'bio_raw', 
                                 'website', 
                                 'name', 
                                 'email_digests', 
                                 'email_direct', 
                                 'email_private_messages', 
                                 'digest_after_days', 
                                 'new_topic_duration_minutes'),
        type: 'PUT',
        success: function() {
          return finished(true);
        },
        error: function() {
          return finished(false);
        }
      });
    },
    changePassword: function(callback) {
      var good;
      good = false;
      return jQuery.ajax({
        url: '/session/forgot_password',
        dataType: 'json',
        data: {
          username: this.get('username')
        },
        type: 'POST',
        success: function() {
          good = true;
        },
        complete: function() {
          var message;
          message = "error";
          if (good) {
            message = "email sent";
          }
          return callback(message);
        }
      });
    },
    filterStream: function(filter) {
      if (Discourse.UserAction.statGroups[filter]) {
        filter = Discourse.UserAction.statGroups[filter].join(",");
      }
      this.set('streamFilter', filter);
      this.set('stream', Em.A());
      return this.loadMoreUserActions();
    },
    loadUserAction: function(id) {
      var stream,
        _this = this;
      stream = this.get('stream');
      return jQuery.ajax({
        url: "/user_actions/" + id + ".json",
        dataType: 'json',
        cache: 'false',
        success: function(result) {
          if (result) {
            var action;
          
            if ((_this.get('streamFilter') || result.action_type) !== result.action_type) {
              return;
            }
            
            action = Em.A();
            action.pushObject(Discourse.UserAction.create(result));
            action = Discourse.UserAction.collapseStream(action);
            
            return stream.insertAt(0, action[0]);
          }
        }
      });
    },
    loadMoreUserActions: function(callback) {
      var stream, url,
        _this = this;
      stream = this.get('stream');
      if (!stream) {
        return;
      }
      url = "/user_actions?offset=" + stream.length + "&user_id=" + (this.get("id"));
      if (this.get('streamFilter')) {
        url += "&filter=" + (this.get('streamFilter'));
      }
      return jQuery.ajax({
        url: url,
        dataType: 'json',
        cache: 'false',
        success: function(result) {
          var copy;
          if (result && result.user_actions && result.user_actions.each) {
            copy = Em.A();
            result.user_actions.each(function(i) {
              return copy.pushObject(Discourse.UserAction.create(i));
            });
            copy = Discourse.UserAction.collapseStream(copy);
            stream.pushObjects(copy);
            _this.set('stream', stream);
          }
          if (callback) {
            return callback();
          }
        }
      });
    },
    statsCountNonPM: (function() {
      var stats, total;
      total = 0;
      if (!(stats = this.get('stats'))) {
        return 0;
      }
      this.get('stats').each(function(s) {
        if (!s.get("isPM")) {
          total += parseInt(s.count, 10);
        }
      });
      return total;
    }).property('stats.@each'),
    statsExcludingPms: (function() {
      var r;
      r = [];
      if (this.blank('stats')) {
        return r;
      }
      this.get('stats').each(function(s) {
        if (!s.get('isPM')) {
          return r.push(s);
        }
      });
      return r;
    }).property('stats.@each'),
    statsPmsOnly: (function() {
      var r;
      r = [];
      if (this.blank('stats')) {
        return r;
      }
      this.get('stats').each(function(s) {
        if (s.get('isPM')) {
          return r.push(s);
        }
      });
      return r;
    }).property('stats.@each'),
    inboxCount: (function() {
      var r;
      r = 0;
      this.get('stats').each(function(s) {
        if (s.action_type === Discourse.UserAction.GOT_PRIVATE_MESSAGE) {
          r = s.count;
          return false;
        }
      });
      return r;
    }).property('stats.@each'),
    sentItemsCount: (function() {
      var r;
      r = 0;
      this.get('stats').each(function(s) {
        if (s.action_type === Discourse.UserAction.NEW_PRIVATE_MESSAGE) {
          r = s.count;
          return false;
        }
      });
      return r;
    }).property('stats.@each')
  });

  window.Discourse.User.reopenClass({
    checkUsername: function(username, email) {
      return jQuery.ajax({
        url: '/users/check_username',
        type: 'GET',
        data: {
          username: username,
          email: email
        }
      });
    },
    groupStats: function(stats) {
      var g,
        _this = this;
      g = {};
      stats.each(function(s) {
        var c, found, k, v, _ref;
        found = false;
        _ref = Discourse.UserAction.statGroups;
        for (k in _ref) {
          v = _ref[k];
          if (v.contains(s.action_type)) {
            found = true;
            if (!g[k]) {
              g[k] = Em.Object.create({
                description: Em.String.i18n("user_action_descriptions." + k),
                count: 0,
                action_type: parseInt(k, 10)
              });
            }
            g[k].count += parseInt(s.count, 10);
            c = g[k].count;
            if (s.action_type === k) {
              g[k] = s;
              s.count = c;
            }
          }
        }
        if (!found) {
          g[s.action_type] = s;
        }
      });
      return stats.map(function(s) {
        return g[s.action_type];
      }).exclude(function(s) {
        return !s;
      });
    },
    find: function(username) {
      var promise,
        _this = this;
      promise = new RSVP.Promise();
      jQuery.ajax({
        url: "/users/" + username + '.json',
        success: function(json) {
          /* todo: decompose to object
          */

          var user;
          json.user.stats = _this.groupStats(json.user.stats.map(function(s) {
            var obj;
            obj = Em.Object.create(s);
            obj.isPM = obj.action_type === Discourse.UserAction.NEW_PRIVATE_MESSAGE || obj.action_type === Discourse.UserAction.GOT_PRIVATE_MESSAGE;
            return obj;
          }));
          if (json.user.stream) {
            json.user.stream = Discourse.UserAction.collapseStream(json.user.stream.map(function(ua) {
              return Discourse.UserAction.create(ua);
            }));
          }
          user = Discourse.User.create(json.user);
          return promise.resolve(user);
        },
        error: function(xhr) {
          return promise.reject(xhr);
        }
      });
      return promise;
    },
    createAccount: function(name, email, password, username, passwordConfirm, challenge) {
      return jQuery.ajax({
        url: '/users',
        dataType: 'json',
        data: {
          name: name,
          email: email,
          password: password,
          username: username,
          password_confirmation: passwordConfirm,
          challenge: challenge
        },
        type: 'POST'
      });
    }
  });

}).call(this);
