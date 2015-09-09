import { flushMap } from 'discourse/models/store';
import RestModel from 'discourse/models/rest';
import { propertyEqual } from 'discourse/lib/computed';
import { longDate } from 'discourse/lib/formatter';
import computed from 'ember-addons/ember-computed-decorators';

const Topic = RestModel.extend({
  message: null,
  errorLoading: false,

  @computed('fancy_title')
  fancyTitle(title) {
    title = title || "";
    title = Discourse.Emoji.unescape(title);
    return Discourse.CensoredWords.censor(title);
  },

  // returns createdAt if there's no bumped date
  bumpedAt: function() {
    const bumpedAt = this.get('bumped_at');
    if (bumpedAt) {
      return new Date(bumpedAt);
    } else {
      return this.get('createdAt');
    }
  }.property('bumped_at', 'createdAt'),

  bumpedAtTitle: function() {
    return I18n.t('first_post') + ": " + longDate(this.get('createdAt')) + "\n" +
           I18n.t('last_post') + ": " + longDate(this.get('bumpedAt'));
  }.property('bumpedAt'),

  createdAt: function() {
    return new Date(this.get('created_at'));
  }.property('created_at'),

  postStream: function() {
    return this.store.createRecord('postStream', {id: this.get('id'), topic: this});
  }.property(),

  replyCount: function() {
    return this.get('posts_count') - 1;
  }.property('posts_count'),

  details: function() {
    return this.store.createRecord('topicDetails', {id: this.get('id'), topic: this});
  }.property(),

  invisible: Em.computed.not('visible'),
  deleted: Em.computed.notEmpty('deleted_at'),

  searchContext: function() {
    return ({ type: 'topic', id: this.get('id') });
  }.property('id'),

  _categoryIdChanged: function() {
    this.set('category', Discourse.Category.findById(this.get('category_id')));
  }.observes('category_id').on('init'),

  _categoryNameChanged: function() {
    const categoryName = this.get('categoryName');
    let category;
    if (categoryName) {
      category = Discourse.Category.list().findProperty('name', categoryName);
    }
    this.set('category', category);
  }.observes('categoryName'),

  categoryClass: function() {
    return 'category-' + this.get('category.fullSlug');
  }.property('category.fullSlug'),

  shareUrl: function(){
    const user = Discourse.User.current();
    return this.get('url') + (user ? '?u=' + user.get('username_lower') : '');
  }.property('url'),

  url: function() {
    let slug = this.get('slug') || '';
    if (slug.trim().length === 0) {
      slug = "topic";
    }
    return Discourse.getURL("/t/") + slug + "/" + (this.get('id'));
  }.property('id', 'slug'),

  // Helper to build a Url with a post number
  urlForPostNumber(postNumber) {
    let url = this.get('url');
    if (postNumber && (postNumber > 0)) {
      url += "/" + postNumber;
    }
    return url;
  },

  totalUnread: function() {
    const count = (this.get('unread') || 0) + (this.get('new_posts') || 0);
    return count > 0 ? count : null;
  }.property('new_posts', 'unread'),

  lastReadUrl: function() {
    return this.urlForPostNumber(this.get('last_read_post_number'));
  }.property('url', 'last_read_post_number'),

  lastUnreadUrl: function() {
    const postNumber = Math.min(this.get('last_read_post_number') + 1, this.get('highest_post_number'));
    return this.urlForPostNumber(postNumber);
  }.property('url', 'last_read_post_number', 'highest_post_number'),

  lastPostUrl: function() {
    return this.urlForPostNumber(this.get('highest_post_number'));
  }.property('url', 'highest_post_number'),

  firstPostUrl: function () {
    return this.urlForPostNumber(1);
  }.property('url'),

  summaryUrl: function () {
    return this.urlForPostNumber(1) + (this.get('has_summary') ? "?filter=summary" : "");
  }.property('url'),

  lastPosterUrl: function() {
    return Discourse.getURL("/users/") + this.get("last_poster.username");
  }.property('last_poster'),

  // The amount of new posts to display. It might be different than what the server
  // tells us if we are still asynchronously flushing our "recently read" data.
  // So take what the browser has seen into consideration.
  displayNewPosts: function() {
    const highestSeen = Discourse.Session.currentProp('highestSeenByTopic')[this.get('id')];
    if (highestSeen) {
      let delta = highestSeen - this.get('last_read_post_number');
      if (delta > 0) {
        let result = this.get('new_posts') - delta;
        if (result < 0) {
          result = 0;
        }
        return result;
      }
    }
    return this.get('new_posts');
  }.property('new_posts', 'id'),

  viewsHeat: function() {
    const v = this.get('views');
    if( v >= Discourse.SiteSettings.topic_views_heat_high )   return 'heatmap-high';
    if( v >= Discourse.SiteSettings.topic_views_heat_medium ) return 'heatmap-med';
    if( v >= Discourse.SiteSettings.topic_views_heat_low )    return 'heatmap-low';
    return null;
  }.property('views'),

  archetypeObject: function() {
    return Discourse.Site.currentProp('archetypes').findProperty('id', this.get('archetype'));
  }.property('archetype'),

  isPrivateMessage: Em.computed.equal('archetype', 'private_message'),
  isBanner: Em.computed.equal('archetype', 'banner'),

  toggleStatus(property) {
    this.toggleProperty(property);
    this.saveStatus(property, !!this.get(property));
  },

  saveStatus(property, value, until) {
    if (property === 'closed') {
      this.incrementProperty('posts_count');

      if (value === true) {
        this.set('details.auto_close_at', null);
      }
    }
    return Discourse.ajax(this.get('url') + "/status", {
      type: 'PUT',
      data: {
        status: property,
        enabled: !!value,
        until: until
      }
    });
  },

  makeBanner() {
    const self = this;
    return Discourse.ajax('/t/' + this.get('id') + '/make-banner', { type: 'PUT' })
           .then(function () { self.set('archetype', 'banner'); });
  },

  removeBanner() {
    const self = this;
    return Discourse.ajax('/t/' + this.get('id') + '/remove-banner', { type: 'PUT' })
           .then(function () { self.set('archetype', 'regular'); });
  },

  estimatedReadingTime: function() {
    const wordCount = this.get('word_count');
    if (!wordCount) return;

    // Avg for 500 words per minute when you account for skimming
    return Math.floor(wordCount / 500.0);
  }.property('word_count'),

  toggleBookmark() {
    if (this.get("bookmarking")) { return; }
    this.set("bookmarking", true);

    const self = this,
          stream = this.get('postStream'),
          posts = Em.get(stream, 'posts'),
          firstPost = posts && posts[0] && posts[0].get('post_number') === 1 && posts[0],
          bookmark = !this.get('bookmarked'),
          path = bookmark ? '/bookmark' : '/remove_bookmarks';

    const toggleBookmarkOnServer = function() {
      return Discourse.ajax('/t/' + self.get('id') + path, {
        type: 'PUT',
      }).then(function() {
        self.toggleProperty('bookmarked');
        if (bookmark && firstPost) { firstPost.set('bookmarked', true); }
        if (!bookmark && posts) {
          posts.forEach((post) => post.get('bookmarked') && post.set('bookmarked', false));
        }
      }).catch(function(error) {
        let showGenericError = true;
        if (error && error.responseText) {
          try {
            bootbox.alert($.parseJSON(error.responseText).errors);
            showGenericError = false;
          } catch(e) { }
        }

        if (showGenericError) {
          bootbox.alert(I18n.t('generic_error'));
        }

        throw error;
      }).finally(function() {
        self.set("bookmarking", false);
      });
    };

    let unbookmarkedPosts = [];
    if (!bookmark && posts) {
      posts.forEach((post) => post.get('bookmarked') && unbookmarkedPosts.push(post));
    }

    if (unbookmarkedPosts.length > 1) {
      return bootbox.confirm(
        I18n.t("bookmarks.confirm_clear"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        function (confirmed) {
          if (confirmed) { return toggleBookmarkOnServer(); }
        }
      );
    } else {
      return toggleBookmarkOnServer();
    }
  },

  createInvite(emailOrUsername, groupNames) {
    return Discourse.ajax("/t/" + this.get('id') + "/invite", {
      type: 'POST',
      data: { user: emailOrUsername, group_names: groupNames }
    });
  },

  generateInviteLink: function(email, groupNames, topicId) {
    return Discourse.ajax('/invites/link', {
      type: 'POST',
      data: {email: email, group_names: groupNames, topic_id: topicId}
    });
  },

  // Delete this topic
  destroy(deleted_by) {
    this.setProperties({
      deleted_at: new Date(),
      deleted_by: deleted_by,
      'details.can_delete': false,
      'details.can_recover': true
    });
    return Discourse.ajax("/t/" + this.get('id'), {
      data: { context: window.location.pathname },
      type: 'DELETE'
    });
  },

  // Recover this topic if deleted
  recover() {
    this.setProperties({
      deleted_at: null,
      deleted_by: null,
      'details.can_delete': true,
      'details.can_recover': false
    });
    return Discourse.ajax("/t/" + this.get('id') + "/recover", { type: 'PUT' });
  },

  // Update our attributes from a JSON result
  updateFromJson(json) {
    this.get('details').updateFromJson(json.details);

    const keys = Object.keys(json);
    keys.removeObject('details');
    keys.removeObject('post_stream');

    const topic = this;
    keys.forEach(function (key) {
      topic.set(key, json[key]);
    });

  },

  isPinnedUncategorized: function() {
    return this.get('pinned') && this.get('category.isUncategorizedCategory');
  }.property('pinned', 'category.isUncategorizedCategory'),

  clearPin() {
    const topic = this;

    // Clear the pin optimistically from the object
    topic.set('pinned', false);
    topic.set('unpinned', true);

    Discourse.ajax("/t/" + this.get('id') + "/clear-pin", {
      type: 'PUT'
    }).then(null, function() {
      // On error, put the pin back
      topic.set('pinned', true);
      topic.set('unpinned', false);
    });
  },

  togglePinnedForUser() {
    if (this.get('pinned')) {
      this.clearPin();
    } else {
      this.rePin();
    }
  },

  rePin() {
    const topic = this;

    // Clear the pin optimistically from the object
    topic.set('pinned', true);
    topic.set('unpinned', false);

    Discourse.ajax("/t/" + this.get('id') + "/re-pin", {
      type: 'PUT'
    }).then(null, function() {
      // On error, put the pin back
      topic.set('pinned', true);
      topic.set('unpinned', false);
    });
  },

  // Is the reply to a post directly below it?
  isReplyDirectlyBelow(post) {
    const posts = this.get('postStream.posts');
    const postNumber = post.get('post_number');
    if (!posts) return;

    const postBelow = posts[posts.indexOf(post) + 1];

    // If the post directly below's reply_to_post_number is our post number or we are quoted,
    // it's considered directly below.
    //
    // TODO: we don't carry information about quoting, this leaves this code fairly fragile
    //  instead we should start shipping quote meta data with posts, but this will add at least
    //  1 query to the topics page
    //
    return postBelow && (postBelow.get('reply_to_post_number') === postNumber ||
        postBelow.get('cooked').indexOf('data-post="'+ postNumber + '"') >= 0
    );
  },

  hasExcerpt: Em.computed.notEmpty('excerpt'),

  excerptTruncated: function() {
    const e = this.get('excerpt');
    return( e && e.substr(e.length - 8,8) === '&hellip;' );
  }.property('excerpt'),

  readLastPost: propertyEqual('last_read_post_number', 'highest_post_number'),
  canClearPin: Em.computed.and('pinned', 'readLastPost')

});

Topic.reopenClass({
  NotificationLevel: {
    WATCHING: 3,
    TRACKING: 2,
    REGULAR: 1,
    MUTED: 0
  },

  createActionSummary(result) {
    if (result.actions_summary) {
      const lookup = Em.Object.create();
      result.actions_summary = result.actions_summary.map(function(a) {
        a.post = result;
        a.actionType = Discourse.Site.current().postActionTypeById(a.id);
        const actionSummary = Discourse.ActionSummary.create(a);
        lookup.set(a.actionType.get('name_key'), actionSummary);
        return actionSummary;
      });
      result.set('actionByName', lookup);
    }
  },

  update(topic, props) {
    props = JSON.parse(JSON.stringify(props)) || {};

    // We support `category_id` and `categoryId` for compatibility
    if (typeof props.categoryId !== "undefined") {
      props.category_id = props.categoryId;
      delete props.categoryId;
    }

    // Make sure we never change the category for private messages
    if (topic.get("isPrivateMessage")) { delete props.category_id; }

    // Annoyingly, empty arrays are not sent across the wire. This
    // allows us to make a distinction between arrays that were not
    // sent and arrays that we specifically want to be empty.
    Object.keys(props).forEach(function(k) {
      const v = props[k];
      if (v instanceof Array && v.length === 0) {
        props[k + '_empty_array'] = true;
      }
    });

    return Discourse.ajax(topic.get('url'), { type: 'PUT', data: props }).then(function(result) {
      // The title can be cleaned up server side
      props.title = result.basic_topic.title;
      props.fancy_title = result.basic_topic.fancy_title;
      topic.setProperties(props);
    });
  },

  create() {
    const result = this._super.apply(this, arguments);
    this.createActionSummary(result);
    return result;
  },

  // Load a topic, but accepts a set of filters
  find(topicId, opts) {
    let url = Discourse.getURL("/t/") + topicId;
    if (opts.nearPost) {
      url += "/" + opts.nearPost;
    }

    const data = {};
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
      data.show_deleted = true;
    }

    // Add the summary of filter if we have it
    if (opts.summary === true) {
      data.summary = true;
    }

    // Check the preload store. If not, load it via JSON
    return Discourse.ajax(url + ".json", {data: data});
  },

  changeOwners(topicId, opts) {
    const promise = Discourse.ajax("/t/" + topicId + "/change-owner", {
      type: 'POST',
      data: opts
    }).then(function (result) {
      if (result.success) return result;
      promise.reject(new Error("error changing ownership of posts"));
    });
    return promise;
  },

  changeTimestamp(topicId, timestamp) {
    const promise = Discourse.ajax("/t/" + topicId + '/change-timestamp', {
      type: 'PUT',
      data: { timestamp: timestamp },
    }).then(function(result) {
      if (result.success) return result;
      promise.reject(new Error("error updating timestamp of topic"));
    });
    return promise;
  },

  bulkOperation(topics, operation) {
    return Discourse.ajax("/topics/bulk", {
      type: 'PUT',
      data: {
        topic_ids: topics.map(function(t) { return t.get('id'); }),
        operation: operation
      }
    });
  },

  bulkOperationByFilter(filter, operation, categoryId) {
    const data = { filter: filter, operation: operation };
    if (categoryId) data['category_id'] = categoryId;
    return Discourse.ajax("/topics/bulk", {
      type: 'PUT',
      data: data
    });
  },

  resetNew() {
    return Discourse.ajax("/topics/reset-new", {type: 'PUT'});
  },

  idForSlug(slug) {
    return Discourse.ajax("/t/id_for/" + slug);
  }
});

function moveResult(result) {
  if (result.success) {
    // We should be hesitant to flush the map but moving ids is one rare case
    flushMap();
    return result;
  }
  throw "error moving posts topic";
}

export function movePosts(topicId, data) {
  return Discourse.ajax("/t/" + topicId + "/move-posts", { type: 'POST', data }).then(moveResult);
}

export function mergeTopic(topicId, destinationTopicId) {
  return Discourse.ajax("/t/" + topicId + "/merge-topic", {
    type: 'POST',
    data: {destination_topic_id: destinationTopicId}
  }).then(moveResult);
}

export default Topic;
