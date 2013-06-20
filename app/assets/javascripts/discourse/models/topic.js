/**
  A data model representing a Topic

  @class Topic
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Topic = Discourse.Model.extend({

  postStream: function() {
    return Discourse.PostStream.create({topic: this});
  }.property(),

  details: function() {
    return Discourse.TopicDetails.create({topic: this});
  }.property(),

  canConvertToRegular: function() {
    var a = this.get('archetype');
    return a !== 'regular' && a !== 'private_message';
  }.property('archetype'),

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

  searchContext: function() {
    return ({ type: 'topic', id: this.get('id') });
  }.property('id'),

  category: function() {
    var categoryId = this.get('category_id');
    if (categoryId) {
      return Discourse.Category.list().findProperty('id', categoryId);
    }

    var categoryName = this.get('categoryName');
    if (categoryName) {
      return Discourse.Category.list().findProperty('name', categoryName);
    }
    return null;
  }.property('category_id', 'categoryName'),

  shareUrl: function(){
    var user = Discourse.User.current();
    return this.get('url') + (user ? '?u=' + user.get('username_lower') : '');
  }.property('url'),

  url: function() {
    var slug = this.get('slug');
    if (slug.trim().length === 0) {
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
    var posts = this.get('posts');
    return posts[posts.length-1];
  },

  postsChanged: function() {
    var last, posts;
    posts = this.get('posts');
    last = posts[posts.length - 1];
    if (!(last && last.set && !last.lastPost)) return;
    _.each(posts,function(p) {
      if (p.lastPost) {
        p.set('lastPost', false);
      }
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

  archetypeObject: function() {
    return Discourse.Site.instance().get('archetypes').findProperty('id', this.get('archetype'));
  }.property('archetype'),

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
    if (!this.get('details.can_edit')) return;

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

  // Update our attributes from a JSON result
  updateFromJson: function(json) {
    this.get('details').updateFromJson(json.details);

    var keys = Object.keys(json);
    keys.removeObject('details');
    keys.removeObject('post_stream');

    var topic = this;
    keys.forEach(function (key) {
      topic.set(key, json[key]);
    });

  },

  /**
    Clears the pin from a topic for the currently logged in user

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
    return Discourse.ajax(url + ".json", {data: data});
  },

  mergeTopic: function(topicId, destinationTopicId) {
    var promise = Discourse.ajax("/t/" + topicId + "/merge-topic", {
      type: 'POST',
      data: {destination_topic_id: destinationTopicId}
    }).then(function (result) {
      if (result.success) return result;
      promise.reject();
    });
    return promise;
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
  }

});


