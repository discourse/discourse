/**
  A data model representing a Topic

  @class Topic
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Topic = Discourse.Model.extend({
  categoriesBinding: 'Discourse.site.categories',

  fewParticipants: (function() {
    if (!this.present('participants')) return null;
    return this.get('participants').slice(0, 3);
  }).property('participants'),

  canConvertToRegular: (function() {
    var a = this.get('archetype');
    return a !== 'regular' && a !== 'private_message';
  }).property('archetype'),

  convertArchetype: function(archetype) {
    var a = this.get('archetype');
    if (a !== 'regular' && a !== 'private_message') {
      this.set('archetype', 'regular');
      return Discourse.ajax(this.get('url'), {
        type: 'PUT',
        data: {archetype: 'regular'}
      });
    }
  },

  category: function() {
    if (this.get('categories')) {
      return this.get('categories').findProperty('name', this.get('categoryName'));
    }
  }.property('categoryName', 'categories'),

  shareUrl: function(){
    var user = Discourse.get('currentUser');
    return this.get('url') + (user ? '?u=' + user.get('username_lower') : '');
  }.property('url'),

  url: function() {
    var slug = this.get('slug');
    if (slug.isBlank()) {
      slug = "topic";
    }
    return Discourse.getURL("/t/") + slug + "/" + (this.get('id'));
  }.property('id', 'slug'),

  // Helper to build a Url with a post number
  urlForPostNumber: function(postNumber) {
    var url = this.get('url');
    if (postNumber && (postNumber > 1)) {
      url += "/" + postNumber;
    }
    return url;
  },

  lastReadUrl: function() {
    return this.urlForPostNumber(this.get('last_read_post_number'));
  }.property('url', 'last_read_post_number'),

  lastPostUrl: function() {
    return this.urlForPostNumber(this.get('highest_post_number'));
  }.property('url', 'highest_post_number'),

  // The last post in the topic
  lastPost: function() {
    return this.get('posts').last();
  },

  postsChanged: function() {
    var last, posts;
    posts = this.get('posts');
    last = posts.last();
    if (!(last && last.set && !last.lastPost)) return;
    posts.each(function(p) {
      if (p.lastPost) return p.set('lastPost', false);
    });
    last.set('lastPost', true);
    return true;
  }.observes('posts.@each', 'posts'),

  // The amount of new posts to display. It might be different than what the server
  // tells us if we are still asynchronously flushing our "recently read" data.
  // So take what the browser has seen into consideration.
  displayNewPosts: function() {
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
  }.property('new_posts', 'id'),

  // The coldmap class for the age of the topic
  ageCold: function() {
    var createdAt, createdAtDays, daysSinceEpoch, lastPost, nowDays;
    if (!(lastPost = this.get('last_posted_at'))) return;
    if (!(createdAt = this.get('created_at'))) return;
    daysSinceEpoch = function(dt) {
      // 1000 * 60 * 60 * 24 = days since epoch
      return dt.getTime() / 86400000;
    };

    // Show heat on age
    nowDays = daysSinceEpoch(new Date());
    createdAtDays = daysSinceEpoch(new Date(createdAt));
    if (daysSinceEpoch(new Date(lastPost)) > nowDays - 90) {
      if (createdAtDays < nowDays - 60) return 'coldmap-high';
      if (createdAtDays < nowDays - 30) return 'coldmap-med';
      if (createdAtDays < nowDays - 14) return 'coldmap-low';
    }
    return null;
  }.property('age', 'created_at'),

  viewsHeat: function() {
    var v = this.get('views');
    if( v >= Discourse.SiteSettings.topic_views_heat_high )   return 'heatmap-high';
    if( v >= Discourse.SiteSettings.topic_views_heat_medium ) return 'heatmap-med';
    if( v >= Discourse.SiteSettings.topic_views_heat_low )    return 'heatmap-low';
    return null;
  }.property('views'),

  archetypeObject: (function() {
    return Discourse.get('site.archetypes').findProperty('id', this.get('archetype'));
  }).property('archetype'),

  isPrivateMessage: (function() {
    return this.get('archetype') === 'private_message';
  }).property('archetype'),

  toggleStatus: function(property) {
    this.toggleProperty(property);
    return Discourse.ajax(this.get('url') + "/status", {
      type: 'PUT',
      data: {status: property, enabled: this.get(property) ? 'true' : 'false' }
    });
  },

  favoriteTooltipKey: (function() {
    return this.get('starred') ? 'favorite.help.unstar' : 'favorite.help.star';
  }).property('starred'),

  favoriteTooltip: (function() {
    return Em.String.i18n(this.get('favoriteTooltipKey'));
  }).property('favoriteTooltipKey'),

  toggleStar: function() {
    var topic = this;
    topic.toggleProperty('starred');
    return Discourse.ajax({
      url: "" + (this.get('url')) + "/star",
      type: 'PUT',
      data: { starred: topic.get('starred') ? true : false }
    }).then(null, function (error) {
      topic.toggleProperty('starred');

      if (error && error.responseText) {
        bootbox.alert($.parseJSON(error.responseText).errors);
      } else {
        bootbox.alert(Em.String.i18n('generic_error'));
      }
    });
  },

  // Save any changes we've made to the model
  save: function() {
    // Don't save unless we can
    if (!this.get('can_edit')) return;

    return Discourse.ajax(this.get('url'), {
      type: 'PUT',
      data: { title: this.get('title'), category: this.get('category.name') }
    });
  },

  // Reset our read data for this topic
  resetRead: function() {
    return Discourse.ajax("/t/" + (this.get('id')) + "/timings", {
      type: 'DELETE'
    });
  },

  // Invite a user to this topic
  inviteUser: function(user) {
    return Discourse.ajax("/t/" + (this.get('id')) + "/invite", {
      type: 'POST',
      data: { user: user }
    });
  },

  // Delete this topic
  destroy: function() {
    return Discourse.ajax("/t/" + (this.get('id')), { type: 'DELETE' });
  },

  // Load the posts for this topic
  loadPosts: function(opts) {
    var topic = this;

    if (!opts) opts = {};

    // Load the first post by default
    if ((!opts.bestOf) && (!opts.nearPost)) opts.nearPost = 1;

    // If we already have that post in the DOM, jump to it. Return a promise
    // that's already complete.
    if (Discourse.TopicView.scrollTo(this.get('id'), opts.nearPost)) {
      return Ember.Deferred.promise(function(promise) { promise.resolve(); });
    }

    // If loading the topic succeeded...
    var afterTopicLoaded = function(result) {
      var closestPostNumber, lastPost, postDiff;

      // Update the slug if different
      if (result.slug) topic.set('slug', result.slug);

      // If we want to scroll to a post that doesn't exist, just pop them to the closest
      // one instead. This is likely happening due to a deleted post.
      opts.nearPost = parseInt(opts.nearPost, 10);
      closestPostNumber = 0;
      postDiff = Number.MAX_VALUE;
      result.posts.each(function(p) {
        var diff = Math.abs(p.post_number - opts.nearPost);
        if (diff < postDiff) {
          postDiff = diff;
          closestPostNumber = p.post_number;
          if (diff === 0) return false;
        }
      });

      opts.nearPost = closestPostNumber;
      if (topic.get('participants')) {
        topic.get('participants').clear();
      }
      if (result.suggested_topics) {
        topic.set('suggested_topics', Em.A());
      }
      topic.mergeAttributes(result, { suggested_topics: Discourse.Topic });
      topic.set('posts', Em.A());
      if (opts.trackVisit && result.draft && result.draft.length > 0) {
        Discourse.openComposer({
          draft: Discourse.Draft.getLocal(result.draft_key, result.draft),
          draftKey: result.draft_key,
          draftSequence: result.draft_sequence,
          topic: topic,
          ignoreIfChanged: true
        });
      }

      // Okay this is weird, but let's store the length of the next post when there
      lastPost = null;
      result.posts.each(function(p) {
        var post;
        p.scrollToAfterInsert = opts.nearPost;
        post = Discourse.Post.create(p);
        post.set('topic', topic);
        topic.get('posts').pushObject(post);
        lastPost = post;
      });
      topic.set('loaded', true);
    }

    var errorLoadingTopic = function(result) {
      topic.set('errorLoading', true);

      // If the result was 404 the post is not found
      if (result.status === 404) {
        topic.set('errorTitle', Em.String.i18n('topic.not_found.title'))
        topic.set('message', Em.String.i18n('topic.not_found.description'));
        return;
      }

      // If the result is 403 it means invalid access
      if (result.status === 403) {
        topic.set('errorTitle', Em.String.i18n('topic.invalid_access.title'))
        topic.set('message', Em.String.i18n('topic.invalid_access.description'));
        return;
      }

      // Otherwise supply a generic error message
      topic.set('errorTitle', Em.String.i18n('topic.server_error.title'))
      topic.set('message', Em.String.i18n('topic.server_error.description'));
    }

    // Finally, call our find method
    return Discourse.Topic.find(this.get('id'), {
      nearPost: opts.nearPost,
      bestOf: opts.bestOf,
      trackVisit: opts.trackVisit
    }).then(afterTopicLoaded, errorLoadingTopic);
  },

  notificationReasonText: function() {
    var locale_string = "topic.notifications.reasons." + this.get('notification_level');
    if (typeof this.get('notifications_reason_id') === 'number') {
      locale_string += "_" + this.get('notifications_reason_id');
    }
    return Em.String.i18n(locale_string, { username: Discourse.currentUser.username.toLowerCase() });
  }.property('notification_level', 'notifications_reason_id'),

  updateNotifications: function(v) {
    this.set('notification_level', v);
    this.set('notifications_reason_id', null);
    return Discourse.ajax("/t/" + (this.get('id')) + "/notifications", {
      type: 'POST',
      data: { notification_level: v }
    });
  },

  // use to add post to topics protecting from dupes
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

  /**
    Clears the pin from a topic for the currentUser

    @method clearPin
  **/
  clearPin: function() {

    var topic = this;

    // Clear the pin optimistically from the object
    topic.set('pinned', false);

    Discourse.ajax("/t/" + this.get('id') + "/clear-pin", {
      type: 'PUT'
    }).then(null, function() {
      // On error, put the pin back
      topic.set('pinned', true);
    });
  },

  // Is the reply to a post directly below it?
  isReplyDirectlyBelow: function(post) {
    var postBelow, posts;
    posts = this.get('posts');
    if (!posts) return;

    postBelow = posts[posts.indexOf(post) + 1];

    // If the post directly below's reply_to_post_number is our post number, it's
    // considered directly below.
    return (postBelow ? postBelow.get('reply_to_post_number') : void 0) === post.get('post_number');
  },

  hasExcerpt: function() {
    return this.get('pinned') && this.get('excerpt') && this.get('excerpt').length > 0;
  }.property('pinned', 'excerpt'),

  excerptTruncated: function() {
    var e = this.get('excerpt');
    return( e && e.substr(e.length - 8,8) === '&hellip;' );
  }.property('excerpt'),

  canClearPin: function() {
    return this.get('pinned') && (this.get('last_read_post_number') === this.get('highest_post_number'));
  }.property('pinned', 'last_read_post_number', 'highest_post_number')
});

Discourse.Topic.reopenClass({
  NotificationLevel: {
    WATCHING: 3,
    TRACKING: 2,
    REGULAR: 1,
    MUTE: 0
  },

  /**
    Find similar topics to a given title and body

    @method findSimilar
    @param {String} title The current title
    @param {String} body The current body
    @returns A promise that will resolve to the topics
  **/
  findSimilarTo: function(title, body) {
    return Discourse.ajax("/topics/similar_to", { data: {title: title, raw: body} }).then(function (results) {
      return results.map(function(topic) { return Discourse.Topic.create(topic) });
    });
  },

  // Load a topic, but accepts a set of filters
  //  options:
  //    onLoad - the callback after the topic is loaded
  find: function(topicId, opts) {
    var data, promise, url;
    url = Discourse.getURL("/t/") + topicId;

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

    // Add username filters if we have them
    if (opts.userFilters && opts.userFilters.length > 0) {
      data.username_filters = [];
      opts.userFilters.forEach(function(username) {
        data.username_filters.push(username);
      });
    }

    // Add the best of filter if we have it
    if (opts.bestOf === true) {
      data.best_of = true;
    }

    // Check the preload store. If not, load it via JSON
    return PreloadStore.getAndRemove("topic_" + topicId, function() {
      return Discourse.ajax(url + ".json", {data: data});
    }).then(function(result) {
      var first = result.posts.first();
      if (first && opts && opts.bestOf) {
        first.bestOfFirst = true;
      }
      return result;
    });
  },

  movePosts: function(topicId, opts) {
    var promise = Discourse.ajax("/t/" + topicId + "/move-posts", {
      type: 'POST',
      data: opts
    }).then(function (result) {
      if (result.success) return result;
      promise.reject();
    });
    return promise;
  },

  create: function(obj, topicView) {
    return Object.tap(this._super(obj), function(result) {
      if (result.participants) {
        result.participants = result.participants.map(function(u) {
          return Discourse.User.create(u);
        });
        result.fewParticipants = Em.A();
        return result.participants.each(function(p) {
          if (result.fewParticipants.length >= 8) return false;
          result.fewParticipants.pushObject(p);
          return true;
        });
      }
    });
  }

});


