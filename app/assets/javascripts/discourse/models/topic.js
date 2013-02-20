(function() {

  Discourse.Topic = Discourse.Model.extend(Discourse.Presence, {
    categoriesBinding: 'Discourse.site.categories',
    fewParticipants: (function() {
      if (!this.present('participants')) {
        return null;
      }
      return this.get('participants').slice(0, 3);
    }).property('participants'),
    canConvertToRegular: (function() {
      var a;
      a = this.get('archetype');
      return a !== 'regular' && a !== 'private_message';
    }).property('archetype'),
    convertArchetype: function(archetype) {
      var a;
      a = this.get('archetype');
      if (a !== 'regular' && a !== 'private_message') {
        this.set('archetype', 'regular');
        return jQuery.post(this.get('url'), {
          _method: 'put',
          archetype: 'regular'
        });
      }
    },
    category: (function() {
      if (this.get('categories')) {
        return this.get('categories').findProperty('name', this.get('categoryName'));
      }
    }).property('categoryName', 'categories'),
    url: (function() {
      var slug;
      slug = this.get('slug');
      if (slug.isBlank()) {
        slug = "topic";
      }
      return "/t/" + slug + "/" + (this.get('id'));
    }).property('id', 'slug'),
    /* Helper to build a Url with a post number
    */

    urlForPostNumber: function(postNumber) {
      var url;
      url = this.get('url');
      if (postNumber && (postNumber > 1)) {
        url += "/" + postNumber;
      }
      return url;
    },
    lastReadUrl: (function() {
      return this.urlForPostNumber(this.get('last_read_post_number'));
    }).property('url', 'last_read_post_number'),
    lastPostUrl: (function() {
      return this.urlForPostNumber(this.get('highest_post_number'));
    }).property('url', 'highest_post_number'),
    /* The last post in the topic
    */

    lastPost: function() {
      return this.get('posts').last();
    },
    postsChanged: (function() {
      var last, posts;
      posts = this.get('posts');
      last = posts.last();
      if (!(last && last.set && !last.lastPost)) {
        return;
      }
      posts.each(function(p) {
        if (p.lastPost) {
          return p.set('lastPost', false);
        }
      });
      last.set('lastPost', true);
      return true;
    }).observes('posts.@each', 'posts'),
    /* The amount of new posts to display. It might be different than what the server
    */

    /* tells us if we are still asynchronously flushing our "recently read" data.
    */

    /* So take what the browser has seen into consideration.
    */

    displayNewPosts: (function() {
      var delta, highestSeen, result;
      if (highestSeen = Discourse.get('highestSeenByTopic')[this.get('id')]) {
        delta = highestSeen - this.get('last_read_post_number');
        if (delta > 0) {
          result = this.get('new_posts') - delta;
          if (result < 0) {
            result = 0;
          }
          return result;
        }
      }
      return this.get('new_posts');
    }).property('new_posts', 'id'),
    /* The coldmap class for the age of the topic
    */

    ageCold: (function() {
      var createdAt, createdAtDays, daysSinceEpoch, lastPost, nowDays;
      if (!(lastPost = this.get('last_posted_at'))) {
        return;
      }
      if (!(createdAt = this.get('created_at'))) {
        return;
      }
      daysSinceEpoch = function(dt) {
        /* 1000 * 60 * 60 * 24 = days since epoch
        */
        return dt.getTime() / 86400000;
      };
      /* Show heat on age
      */

      nowDays = daysSinceEpoch(new Date());
      createdAtDays = daysSinceEpoch(new Date(createdAt));
      if (daysSinceEpoch(new Date(lastPost)) > nowDays - 90) {
        if (createdAtDays < nowDays - 60) {
          return 'coldmap-high';
        }
        if (createdAtDays < nowDays - 30) {
          return 'coldmap-med';
        }
        if (createdAtDays < nowDays - 14) {
          return 'coldmap-low';
        }
      }
      return null;
    }).property('age', 'created_at'),
    archetypeObject: (function() {
      return Discourse.get('site.archetypes').findProperty('id', this.get('archetype'));
    }).property('archetype'),
    isPrivateMessage: (function() {
      return this.get('archetype') === 'private_message';
    }).property('archetype'),
    /* Does this topic only have a single post?
    */

    singlePost: (function() {
      return this.get('posts_count') === 1;
    }).property('posts_count'),
    toggleStatus: function(property) {
      this.toggleProperty(property);
      return jQuery.post("" + (this.get('url')) + "/status", {
        _method: 'put',
        status: property,
        enabled: this.get(property) ? 'true' : 'false'
      });
    },
    toggleStar: function() {
      var _this = this;
      this.toggleProperty('starred');
      return jQuery.ajax({
        url: "" + (this.get('url')) + "/star",
        type: 'PUT',
        data: {
          starred: this.get('starred') ? true : false
        },
        error: function(error) {
          var errors;
          _this.toggleProperty('starred');
          errors = jQuery.parseJSON(error.responseText).errors;
          return bootbox.alert(errors[0]);
        }
      });
    },
    /* Save any changes we've made to the model
    */

    save: function() {
      /* Don't save unless we can
      */
      if (!this.get('can_edit')) {
        return;
      }
      return jQuery.post(this.get('url'), {
        _method: 'put',
        title: this.get('title'),
        category: this.get('category.name')
      });
    },
    /* Reset our read data for this topic
    */

    resetRead: function(callback) {
      return jQuery.ajax("/t/" + (this.get('id')) + "/timings", {
        type: 'DELETE',
        success: function() {
          return typeof callback === "function" ? callback() : void 0;
        }
      });
    },
    /* Invite a user to this topic
    */

    inviteUser: function(user) {
      return jQuery.ajax({
        type: 'POST',
        url: "/t/" + (this.get('id')) + "/invite",
        data: {
          user: user
        }
      });
    },
    /* Delete this topic
    */

    "delete": function(callback) {
      return jQuery.ajax("/t/" + (this.get('id')), {
        type: 'DELETE',
        success: function() {
          return typeof callback === "function" ? callback() : void 0;
        }
      });
    },
    /* Load the posts for this topic
    */

    loadPosts: function(opts) {
      var _this = this;
      if (!opts) {
        opts = {};
      }
      /* Load the first post by default
      */

      if (!opts.bestOf) {
        if (!opts.nearPost) opts.nearPost = 1
      }
      /* If we already have that post in the DOM, jump to it
      */

      if (Discourse.TopicView.scrollTo(this.get('id'), opts.nearPost)) {
        return;
      }
      return Discourse.Topic.find(this.get('id'), {
        nearPost: opts.nearPost,
        bestOf: opts.bestOf,
        trackVisit: opts.trackVisit
      }).then(function(result) {
        /* If loading the topic succeeded...
        */

        /* Update the slug if different
        */

        var closestPostNumber, lastPost, postDiff;
        if (result.slug) {
          _this.set('slug', result.slug);
        }
        /* If we want to scroll to a post that doesn't exist, just pop them to the closest
        */

        /* one instead. This is likely happening due to a deleted post.
        */

        opts.nearPost = parseInt(opts.nearPost, 10);
        closestPostNumber = 0;
        postDiff = Number.MAX_VALUE;
        result.posts.each(function(p) {
          var diff;
          diff = Math.abs(p.post_number - opts.nearPost);
          if (diff < postDiff) {
            postDiff = diff;
            closestPostNumber = p.post_number;
            if (diff === 0) {
              return false;
            }
          }
        });
        opts.nearPost = closestPostNumber;
        if (_this.get('participants')) {
          _this.get('participants').clear();
        }
        if (result.suggested_topics) {
          _this.set('suggested_topics', Em.A());
        }
        _this.mergeAttributes(result, {
          suggested_topics: Discourse.Topic
        });
        _this.set('posts', Em.A());
        if (opts.trackVisit && result.draft && result.draft.length > 0) {
          Discourse.openComposer({
            draft: Discourse.Draft.getLocal(result.draft_key, result.draft),
            draftKey: result.draft_key,
            draftSequence: result.draft_sequence,
            topic: _this,
            ignoreIfChanged: true
          });
        }
        /* Okay this is weird, but let's store the length of the next post
        */

        /* when there
        */

        lastPost = null;
        result.posts.each(function(p) {
          var post;
          p.scrollToAfterInsert = opts.nearPost;
          post = Discourse.Post.create(p);
          post.set('topic', _this);
          _this.get('posts').pushObject(post);
          lastPost = post;
        });
        return _this.set('loaded', true);
      }, function(result) {
        _this.set('missing', true);
        return _this.set('message', Em.String.i18n('topic.not_found.description'));
      });
    },
    notificationReasonText: (function() {
      var locale_string;
      locale_string = "topic.notifications.reasons." + this.notification_level;
      if (typeof this.notifications_reason_id === 'number') {
        locale_string += "_" + this.notifications_reason_id;
      }
      return Em.String.i18n(locale_string, {
        username: Discourse.currentUser.username.toLowerCase()
      });
    }).property('notifications_reason_id'),
    updateNotifications: function(v) {
      this.set('notification_level', v);
      this.set('notifications_reason_id', null);
      return jQuery.ajax({
        url: "/t/" + (this.get('id')) + "/notifications",
        type: 'POST',
        data: {
          notification_level: v
        }
      });
    },
    /* use to add post to topics protecting from dupes
    */

    pushPosts: function(newPosts) {
      var map, posts;
      map = {};
      posts = this.get('posts');
      posts.each(function(p) {
        map["" + p.post_number] = true;
      });
      return newPosts.each(function(p) {
        if (!map[p.get('post_number')]) {
          return posts.pushObject(p);
        }
      });
    },
    /* Is the reply to a post directly below it?
    */

    isReplyDirectlyBelow: function(post) {
      var postBelow, posts;
      posts = this.get('posts');
      if (!posts) {
        return;
      }
      postBelow = posts[posts.indexOf(post) + 1];
      /* If the post directly below's reply_to_post_number is our post number, it's
         considered directly below. */
      return (postBelow ? postBelow.get('reply_to_post_number') : void 0) === post.get('post_number');
    }
  });

  window.Discourse.Topic.reopenClass({
    NotificationLevel: {
      WATCHING: 3,
      TRACKING: 2,
      REGULAR: 1,
      MUTE: 0
    },
    /* Load a topic, but accepts a set of filters
    */

    /*  options:
    */

    /*    onLoad - the callback after the topic is loaded
    */

    find: function(topicId, opts) {
      var data, promise, url,
        _this = this;
      url = "/t/" + topicId;
      if (opts.nearPost) {
        url += "/" + opts.nearPost;
      }
      data = {};
      if (opts.postsAfter) {
        data.posts_after = opts.postsAfter;
      }
      if (opts.postsBefore) {
        data.posts_before = opts.postsBefore;
      }
      if (opts.trackVisit) {
        data.track_visit = true;
      }
      /* Add username filters if we have them
      */

      if (opts.userFilters && opts.userFilters.length > 0) {
        data.username_filters = [];
        opts.userFilters.forEach(function(username) {
          return data.username_filters.push(username);
        });
      }
      /* Add the best of filter if we have it
      */

      if (opts.bestOf === true) {
        data.best_of = true;
      }
      /* Check the preload store. If not, load it via JSON
      */

      promise = new RSVP.Promise();
      PreloadStore.get("topic_" + topicId, function() {
        return jQuery.getJSON(url + ".json", data);
      }).then(function(result) {
        var first;
        first = result.posts.first();
        if (first && opts && opts.bestOf) {
          first.bestOfFirst = true;
        }
        return promise.resolve(result);
      }, function(result) {
        return promise.reject(result);
      });
      return promise;
    },
    /* Create a topic from posts
    */

    movePosts: function(topicId, title, postIds) {
      return jQuery.ajax("/t/" + topicId + "/move-posts", {
        type: 'POST',
        data: {
          title: title,
          post_ids: postIds
        }
      });
    },
    create: function(obj, topicView) {
      var _this = this;
      return Object.tap(this._super(obj), function(result) {
        if (result.participants) {
          result.participants = result.participants.map(function(u) {
            return Discourse.User.create(u);
          });
          result.fewParticipants = Em.A();
          return result.participants.each(function(p) {
            if (result.fewParticipants.length >= 8) {
              return false;
            }
            result.fewParticipants.pushObject(p);
            return true;
          });
        }
      });
    }
  });

}).call(this);
