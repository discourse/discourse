(function() {

  window.Discourse.UserAction = Discourse.Model.extend({
    postUrl: (function() {
      return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('post_number'));
    }).property(),
    replyUrl: (function() {
      return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('reply_to_post_number'));
    }).property(),
    isPM: (function() {
      var a;
      a = this.get('action_type');
      return a === Discourse.UserAction.NEW_PRIVATE_MESSAGE || a === Discourse.UserAction.GOT_PRIVATE_MESSAGE;
    }).property(),
    isPostAction: (function() {
      var a;
      a = this.get('action_type');
      return a === Discourse.UserAction.RESPONSE || a === Discourse.UserAction.POST || a === Discourse.UserAction.NEW_TOPIC;
    }).property(),
    addChild: function(action) {
      var bucket, current, groups, ua;
      groups = this.get("childGroups");
      if (!groups) {
        groups = {
          likes: Discourse.UserActionGroup.create({
            icon: "icon-heart"
          }),
          stars: Discourse.UserActionGroup.create({
            icon: "icon-star"
          }),
          edits: Discourse.UserActionGroup.create({
            icon: "icon-pencil"
          }),
          bookmarks: Discourse.UserActionGroup.create({
            icon: "icon-bookmark"
          })
        };
      }
      this.set("childGroups", groups);
      ua = Discourse.UserAction;
      bucket = (function() {
        switch (action.action_type) {
          case ua.LIKE:
          case ua.WAS_LIKED:
            return "likes";
          case ua.STAR:
            return "stars";
          case ua.EDIT:
            return "edits";
          case ua.BOOKMARK:
            return "bookmarks";
        }
      })();
      current = groups[bucket];
      if (current) {
        current.push(action);
      }
    },
    children: (function() {
      var g, rval;
      g = this.get("childGroups");
      rval = [];
      if (g) {
        rval = [g.likes, g.stars, g.edits, g.bookmarks].filter(function(i) {
          return i.get("items") && i.get("items").length > 0;
        });
      }
      return rval;
    }).property("childGroups"),
    switchToActing: function() {
      this.set('username', this.get('acting_username'));
      this.set('avatar_template', this.get('acting_avatar_template'));
      return this.set('name', this.get('acting_name'));
    }
  });

  window.Discourse.UserAction.reopenClass({
    collapseStream: function(stream) {
      var collapse, collapsed, pos, uniq;
      collapse = [this.LIKE, this.WAS_LIKED, this.STAR, this.EDIT, this.BOOKMARK];
      uniq = {};
      collapsed = Em.A();
      pos = 0;
      stream.each(function(item) {
        var current, found, key;
        key = "" + item.topic_id + "-" + item.post_number;
        found = uniq[key];
        if (found === void 0) {
          if (collapse.indexOf(item.action_type) >= 0) {
            current = Discourse.UserAction.create(item);
            current.set('action_type', null);
            current.set('description', null);
            item.switchToActing();
            current.addChild(item);
          } else {
            current = item;
          }
          uniq[key] = pos;
          collapsed[pos] = current;
          pos += 1;
        } else {
          if (collapse.indexOf(item.action_type) >= 0) {
            item.switchToActing();
            return collapsed[found].addChild(item);
          } else {
            collapsed[found].set('action_type', item.get('action_type'));
            return collapsed[found].set('description', item.get('description'));
          }
        }
      });
      return collapsed;
    },
    /* in future we should be sending this through from the server
    */

    LIKE: 1,
    WAS_LIKED: 2,
    BOOKMARK: 3,
    NEW_TOPIC: 4,
    POST: 5,
    RESPONSE: 6,
    MENTION: 7,
    QUOTE: 9,
    STAR: 10,
    EDIT: 11,
    NEW_PRIVATE_MESSAGE: 12,
    GOT_PRIVATE_MESSAGE: 13
  });

  window.Discourse.UserAction.reopenClass({
    statGroups: (function() {
      var g;
      g = {};
      g[Discourse.UserAction.RESPONSE] = [Discourse.UserAction.RESPONSE, Discourse.UserAction.MENTION, Discourse.UserAction.QUOTE];
      return g;
    })()
  });

}).call(this);
