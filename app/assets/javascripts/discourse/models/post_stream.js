/**
  We use this class to keep on top of streaming and filtering posts within a topic.

  @class PostStream
  @extends Ember.Object
  @namespace Discourse
  @module Discourse
**/
Discourse.PostStream = Em.Object.extend({

  /**
    Are we currently loading posts in any way?

    @property loading
  **/
  loading: Em.computed.or('loadingAbove', 'loadingBelow', 'loadingFilter', 'stagingPost'),

  notLoading: Em.computed.not('loading'),

  filteredPostsCount: Em.computed.alias("stream.length"),

  /**
    Have we loaded any posts?

    @property hasPosts
  **/
  hasPosts: function(){
    return this.get('posts.length') > 0;
  }.property("posts.@each"),

  /**
    Do we have a stream list of post ids?

    @property hasStream
  **/
  hasStream: Em.computed.gt('filteredPostsCount', 0),

  /**
    Can we append more posts to our current stream?

    @property canAppendMore
  **/
  canAppendMore: Em.computed.and('notLoading', 'hasPosts', 'lastPostNotLoaded'),

  /**
    Can we prepend more posts to our current stream?

    @property canPrependMore
  **/
  canPrependMore: Em.computed.and('notLoading', 'hasPosts', 'firstPostNotLoaded'),

  /**
    Have we loaded the first post in the stream?

    @property firstPostPresent
  **/
  firstPostPresent: function() {
    if (!this.get('hasLoadedData')) { return false; }
    return !!this.get('posts').findProperty('id', this.get('firstPostId'));
  }.property('hasLoadedData', 'posts.@each', 'firstPostId'),

  firstPostNotLoaded: Em.computed.not('firstPostPresent'),

  /**
    The first post that we have loaded. Useful for checking to see if we should scroll upwards

    @property firstLoadedPost
  **/
  firstLoadedPost: function() {
    return _.first(this.get('posts'));
  }.property('posts.@each'),

  /**
    The last post we have loaded. Useful for checking to see if we should load more

    @property lastLoadedPost
  **/
  lastLoadedPost: function() {
    return _.last(this.get('posts'));
  }.property('posts.@each'),

  /**
    Returns the id of the first post in the set

    @property firstPostId
  **/
  firstPostId: function() {
    return this.get('stream')[0];
  }.property('stream.@each'),

  /**
    Returns the id of the last post in the set

    @property lastPostId
  **/
  lastPostId: function() {
    return _.last(this.get('stream'));
  }.property('stream.@each'),

  /**
    Have we loaded the last post in the stream?

    @property loadedAllPosts
  **/
  loadedAllPosts: function() {
    if (!this.get('hasLoadedData')) { return false; }
    return !!this.get('posts').findProperty('id', this.get('lastPostId'));
  }.property('hasLoadedData', 'posts.@each.id', 'lastPostId'),

  lastPostNotLoaded: Em.computed.not('loadedAllPosts'),

  /**
    Returns a JS Object of current stream filter options. It should match the query
    params for the stream.

    @property streamFilters
  **/
  streamFilters: function() {
    var result = {};
    if (this.get('summary')) { result.filter = "summary"; }
    if (this.get('show_deleted')) { result.show_deleted = true; }

    var userFilters = this.get('userFilters');
    if (!Em.isEmpty(userFilters)) {
      result.username_filters = userFilters.join(",");
    }

    return result;
  }.property('userFilters.[]', 'summary', 'show_deleted'),

  hasNoFilters: function() {
    var streamFilters = this.get('streamFilters');
    return !(streamFilters && ((streamFilters.filter === 'summary') || streamFilters.userFilters));
  }.property('streamFilters.[]', 'topic.posts_count', 'posts.length'),

  /**
    Returns the window of posts above the current set in the stream, bound to the top of the stream.
    This is the collection we'll ask for when scrolling upwards.

    @property previousWindow
  **/
  previousWindow: function() {
    // If we can't find the last post loaded, bail
    var firstPost = _.first(this.get('posts'));
    if (!firstPost) { return []; }

    // Find the index of the last post loaded, if not found, bail
    var stream = this.get('stream');
    var firstIndex = this.indexOf(firstPost);
    if (firstIndex === -1) { return []; }

    var startIndex = firstIndex - Discourse.SiteSettings.posts_chunksize;
    if (startIndex < 0) { startIndex = 0; }
    return stream.slice(startIndex, firstIndex);

  }.property('posts.@each', 'stream.@each'),

  /**
    Returns the window of posts below the current set in the stream, bound by the bottom of the
    stream. This is the collection we use when scrolling downwards.

    @property nextWindow
  **/
  nextWindow: function() {
    // If we can't find the last post loaded, bail
    var lastLoadedPost = this.get('lastLoadedPost');
    if (!lastLoadedPost) { return []; }

    // Find the index of the last post loaded, if not found, bail
    var stream = this.get('stream');
    var lastIndex = this.indexOf(lastLoadedPost);
    if (lastIndex === -1) { return []; }
    if ((lastIndex + 1) >= this.get('highest_post_number')) { return []; }

    // find our window of posts
    return stream.slice(lastIndex+1, lastIndex+Discourse.SiteSettings.posts_chunksize+1);
  }.property('lastLoadedPost', 'stream.@each'),


  /**
    Cancel any active filters on the stream.

    @method cancelFilter
  **/
  cancelFilter: function() {
    this.set('summary', false);
    this.set('show_deleted', false);
    this.get('userFilters').clear();
  },

  /**
    Toggle summary mode for the stream.

    @method toggleSummary
  **/
  toggleSummary: function() {
    this.get('userFilters').clear();
    this.toggleProperty('summary');
    return this.refresh();
  },

  toggleDeleted: function() {
    this.toggleProperty('show_deleted');
    return this.refresh();
  },

  /**
    Filter the stream to a particular user.

    @method toggleParticipant
  **/
  toggleParticipant: function(username) {
    var userFilters = this.get('userFilters');
    this.set('summary', false);
    this.set('show_deleted', true);
    if (userFilters.contains(username)) {
      userFilters.removeObject(username);
    } else {
      userFilters.addObject(username);
    }
    return this.refresh();
  },

  /**
    Loads a new set of posts into the stream. If you provide a `nearPost` option and the post
    is already loaded, it will simply scroll there and load nothing.

    @method refresh
    @param {Object} opts Options for loading the stream
      @param {Integer} opts.nearPost The post we want to find other posts near to.
      @param {Boolean} opts.track_visit Whether or not to track this as a visit to a topic.
    @returns {Promise} a promise that is resolved when the posts have been inserted into the stream.
  **/
  refresh: function(opts) {
    opts = opts || {};
    opts.nearPost = parseInt(opts.nearPost, 10);

    var topic = this.get('topic'),
        self = this;

    // Do we already have the post in our list of posts? Jump there.
    var postWeWant = this.get('posts').findProperty('post_number', opts.nearPost);
    if (postWeWant) { return Ember.RSVP.resolve(); }

    // TODO: if we have all the posts in the filter, don't go to the server for them.
    self.set('loadingFilter', true);

    opts = _.merge(opts, self.get('streamFilters'));

    // Request a topicView
    return Discourse.PostStream.loadTopicView(topic.get('id'), opts).then(function (json) {
      topic.updateFromJson(json);
      self.updateFromJson(json.post_stream);
      self.setProperties({ loadingFilter: false, loaded: true });
    }).catch(function(result) {
      self.errorLoading(result);
      throw result;
    });
  },
  hasLoadedData: Em.computed.and('hasPosts', 'hasStream'),

  collapsePosts: function(from, to){
    var posts = this.get('posts');
    var remove = posts.filter(function(post){
      var postNumber = post.get('post_number');
      return postNumber >= from && postNumber <= to;
    });

    posts.removeObjects(remove);

    // make gap
    this.set('gaps', this.get('gaps') || {before: {}, after: {}});
    var before = this.get('gaps.before');

    var post = posts.find(function(post){
      return post.get('post_number') > to;
    });

    before[post.get('id')] = remove.map(function(post){
      return post.get('id');
    });
    post.set('hasGap', true);

    this.get('stream').enumerableContentDidChange();
  },


  /**
    Fill in a gap of posts before a particular post

    @method fillGapBefore
    @paaram {Discourse.Post} post beside gap
    @paaram {Array} gap array of post ids to load
    @returns {Promise} a promise that's resolved when the posts have been added.
  **/
  fillGapBefore: function(post, gap) {
    var postId = post.get('id'),
        stream = this.get('stream'),
        idx = stream.indexOf(postId),
        currentPosts = this.get('posts'),
        self = this;

    if (idx !== -1) {
      // Insert the gap at the appropriate place
      stream.splice.apply(stream, [idx, 0].concat(gap));

      var postIdx = currentPosts.indexOf(post);
      if (postIdx !== -1) {
        return this.findPostsByIds(gap).then(function(posts) {
          posts.forEach(function(p) {
            var stored = self.storePost(p);
            if (!currentPosts.contains(stored)) {
              currentPosts.insertAt(postIdx++, stored);
            }
          });

          delete self.get('gaps.before')[postId];
          self.get('stream').enumerableContentDidChange();
          post.set('hasGap', false);
        });
      }
    }
    return Ember.RSVP.resolve();
  },

  /**
    Fill in a gap of posts after a particular post

    @method fillGapAfter
    @paaram {Discourse.Post} post beside gap
    @paaram {Array} gap array of post ids to load
    @returns {Promise} a promise that's resolved when the posts have been added.
  **/
  fillGapAfter: function(post, gap) {
    var postId = post.get('id'),
        stream = this.get('stream'),
        idx = stream.indexOf(postId),
        self = this;

    if (idx !== -1) {
      stream.pushObjects(gap);
      return this.appendMore().then(function() {
        self.get('stream').enumerableContentDidChange();
      });
    }
    return Ember.RSVP.resolve();
  },

  /**
    Appends the next window of posts to the stream. Call it when scrolling downwards.

    @method appendMore
    @returns {Promise} a promise that's resolved when the posts have been added.
  **/
  appendMore: function() {
    var self = this;

    // Make sure we can append more posts
    if (!self.get('canAppendMore')) { return Ember.RSVP.resolve(); }

    var postIds = self.get('nextWindow');
    if (Ember.isEmpty(postIds)) { return Ember.RSVP.resolve(); }

    self.set('loadingBelow', true);

    var stopLoading = function() {
      self.set('loadingBelow', false);
    };

    return self.findPostsByIds(postIds).then(function(posts) {
      posts.forEach(function(p) {
        self.appendPost(p);
      });
      stopLoading();
    }, stopLoading);
  },

  /**
    Prepend the previous window of posts to the stream. Call it when scrolling upwards.

    @method prependMore
    @returns {Promise} a promise that's resolved when the posts have been added.
  **/
  prependMore: function() {
    var postStream = this;

    // Make sure we can append more posts
    if (!postStream.get('canPrependMore')) { return Ember.RSVP.resolve(); }

    var postIds = postStream.get('previousWindow');
    if (Ember.isEmpty(postIds)) { return Ember.RSVP.resolve(); }

    postStream.set('loadingAbove', true);
    return postStream.findPostsByIds(postIds.reverse()).then(function(posts) {
      posts.forEach(function(p) {
        postStream.prependPost(p);
      });
      postStream.set('loadingAbove', false);
    });
  },

  /**
    Stage a post for insertion in the stream. It should be rendered right away under the
    assumption that the post will succeed. We can then `commitPost` when it succeeds or
    `undoPost` when it fails.

    @method stagePost
    @param {Discourse.Post} post the post to stage in the stream
    @param {Discourse.User} user the user creating the post
  **/
  stagePost: function(post, user) {

    // We can't stage two posts simultaneously
    if (this.get('stagingPost')) { return false; }
    this.set('stagingPost', true);

    var topic = this.get('topic');
    topic.setProperties({
      posts_count: (topic.get('posts_count') || 0) + 1,
      last_posted_at: new Date(),
      'details.last_poster': user,
      highest_post_number: (topic.get('highest_post_number') || 0) + 1
    });

    post.setProperties({
      post_number: topic.get('highest_post_number'),
      topic: topic,
      created_at: new Date(),
      id: -1
    });

    // If we're at the end of the stream, add the post
    if (this.get('loadedAllPosts')) {
      this.appendPost(post);
      this.get('stream').addObject(post.get('id'));
    }

    return true;
  },

  /**
    Commit the post we staged. Call this after a save succeeds.

    @method commitPost
    @param {Discourse.Post} the post we saved in the stream.
  **/
  commitPost: function(post) {
    if (this.get('loadedAllPosts')) {
      this.appendPost(post);
    }
    // Correct for a dangling deleted post, if needed
    // compensating for message bus pumping in new posts while
    // your post is in transit
    if(this.get('topic.highest_post_number') < post.get('post_number')){
      this.set('topic.highest_post_number', post.get('post_number'));
    }
    this.get('stream').removeObject(-1);
    this.get('postIdentityMap').set(-1, null);
    this.get('postIdentityMap').set(post.get('id'), post);

    this.get('stream').addObject(post.get('id'));
    this.set('stagingPost', false);
  },

  /**
    Undo a post we've staged in the stream. Remove it from being rendered and revert the
    state we changed.

    @method undoPost
    @param {Discourse.Post} the post to undo from the stream
  **/
  undoPost: function(post) {
    this.get('stream').removeObject(-1);
    this.posts.removeObject(post);
    this.get('postIdentityMap').set(-1, null);

    var topic = this.get('topic');
    this.set('stagingPost', false);

    topic.setProperties({
      highest_post_number: (topic.get('highest_post_number') || 0) - 1,
      posts_count: (topic.get('posts_count') || 0) - 1
    });

    // TODO unfudge reply count on parent post
  },

  /**
    Prepends a single post to the stream.

    @method prependPost
    @param {Discourse.Post} post The post we're prepending
    @returns {Discourse.Post} the post that was inserted.
  **/
  prependPost: function(post) {
    this.get('posts').unshiftObject(this.storePost(post));
    return post;
  },

  /**
    Appends a single post into the stream.

    @method appendPost
    @param {Discourse.Post} post The post we're appending
    @returns {Discourse.Post} the post that was inserted.
  **/
  appendPost: function(post) {
    var stored = this.storePost(post);
    if (stored) {
      this.get('posts').addObject(stored);
    }
    return post;
  },

  /**
    Removes posts from the stream.

    @method removePosts
    @param {Array} posts the collection of posts to remove
  **/
  removePosts: function(posts) {
    if (Em.isEmpty(posts)) { return; }

    var postIds = posts.map(function (p) { return p.get('id'); });
    var identityMap = this.get('postIdentityMap');

    this.get('stream').removeObjects(postIds);
    this.get('posts').removeObjects(posts);
    postIds.forEach(function(id){
      identityMap.remove(id);
    });
  },

  /**
    Returns a post from the identity map if it's been inserted.

    @method findLoadedPost
    @param {Integer} id The post we want from the identity map.
    @returns {Discourse.Post} the post that was inserted.
  **/
  findLoadedPost: function(id) {
    return this.get('postIdentityMap').get(id);
  },

  /**
    Finds and adds a post to the stream by id. Typically this would happen if we receive a message
    from the message bus indicating there's a new post. We'll only insert it if we currently
    have no filters.

    @method triggerNewPostInStream
    @param {Integer} postId The id of the new post to be inserted into the stream
  **/
  triggerNewPostInStream: function(postId) {
    if (!postId) { return; }

    // We only trigger if there are no filters active
    if (!this.get('hasNoFilters')) { return; }

    var loadedAllPosts = this.get('loadedAllPosts');

    if (this.get('stream').indexOf(postId) === -1) {
      this.get('stream').addObject(postId);
      if (loadedAllPosts) { this.appendMore(); }
    }
  },

  triggerRecoveredPost: function(postId){
    var self = this,
        postIdentityMap = this.get('postIdentityMap'),
        existing = postIdentityMap.get(postId);

    if(existing){
      this.triggerChangedPost(postId, new Date());
    } else {
      // need to insert into stream
      var url = "/posts/" + postId;
      Discourse.ajax(url).then(function(p){
        var post = Discourse.Post.create(p);
        var stream = self.get("stream");
        var posts = self.get("posts");
        self.storePost(post);

        // we need to zip this into the stream
        var index = 0;
        stream.forEach(function(postId){
          if(postId < p.id){
            index+= 1;
          }
        });

        stream.insertAt(index, p.id);

        index = 0;
        posts.forEach(function(_post){
          if(_post.id < p.id){
            index+= 1;
          }
        });

        if(index < posts.length){
          posts.insertAt(index, post);
        } else {
          if(post.post_number < posts[posts.length-1].post_number + 5){
            self.appendMore();
          }
        }
      });
    }
  },

  triggerDeletedPost: function(postId){
    var self = this,
        postIdentityMap = this.get('postIdentityMap'),
        existing = postIdentityMap.get(postId);

    if(existing){
      var url = "/posts/" + postId;
      Discourse.ajax(url).then(
        function(p){
          self.storePost(Discourse.Post.create(p));
        },
        function(){
          self.removePosts([existing]);
        });
    }
  },

  triggerChangedPost: function(postId, updatedAt) {
    if (!postId) { return; }

    var postIdentityMap = this.get('postIdentityMap'),
        existing = postIdentityMap.get(postId),
        self = this;

    if (existing && existing.updated_at !== updatedAt) {
      var url = "/posts/" + postId;
      Discourse.ajax(url).then(function(p){
        self.storePost(Discourse.Post.create(p));
      });
    }
  },

  /**
    Returns the "thread" of posts in the history of a post.

    @method findReplyHistory
    @param {Discourse.Post} post the post whose history we want
    @returns {Array} the posts in the history.
  **/
  findReplyHistory: function(post) {
    var postStream = this,
        url = "/posts/" + post.get('id') + "/reply-history.json?max_replies=" + Discourse.SiteSettings.max_reply_history;

    return Discourse.ajax(url).then(function(result) {
      return result.map(function (p) {
        return postStream.storePost(Discourse.Post.create(p));
      });
    }).then(function (replyHistory) {
      post.set('replyHistory', replyHistory);
    });
  },

  /**
    Returns the closest post given a postNumber that may not exist in the stream.
    For example, if the user asks for a post that's deleted or otherwise outside the range.
    This allows us to set the progress bar with the correct number.

    @method closestPostForPostNumber
    @param {Number} postNumber the post number we're looking for
    @return {Post} the closest post
    @see PostStream.closestPostNumberFor
  **/
  closestPostForPostNumber: function(postNumber) {
    if (!this.get('hasPosts')) { return; }

    var closest = null;
    this.get('posts').forEach(function (p) {
      if (!closest) {
        closest = p;
        return;
      }

      if (Math.abs(postNumber - p.get('post_number')) < Math.abs(closest.get('post_number') - postNumber)) {
        closest = p;
      }
    });

    return closest;
  },

  /**
    Get the index of a post in the stream. (Use this for the topic progress bar.)

    @param post the post to get the index of
    @returns {Number} 1-starting index of the post, or 0 if not found
    @see PostStream.progressIndexOfPostId
  **/
  progressIndexOfPost: function(post) {
    return this.progressIndexOfPostId(post.get('id'));
  },

  /**
    Get the index in the stream of a post id. (Use this for the topic progress bar.)

    @param post_id - post id to search for
    @returns {Number} 1-starting index of the post, or 0 if not found
  **/
  progressIndexOfPostId: function(post_id) {
    return this.get('stream').indexOf(post_id) + 1;
  },

  /**
    Returns the closest post number given a postNumber that may not exist in the stream.
    For example, if the user asks for a post that's deleted or otherwise outside the range.
    This allows us to set the progress bar with the correct number.

    @method closestPostNumberFor
    @param {Number} postNumber the post number we're looking for
    @return {Number} a close post number
  **/
  closestPostNumberFor: function(postNumber) {
    if (!this.get('hasPosts')) { return; }

    var closest = null;
    this.get('posts').forEach(function (p) {
      if (closest === postNumber) { return; }
      if (!closest) { closest = p.get('post_number'); }

      if (Math.abs(postNumber - p.get('post_number')) < Math.abs(closest - postNumber)) {
        closest = p.get('post_number');
      }
    });

    return closest;
  },

  /**
    @private

    Given a JSON packet, update this stream and the posts that exist in it.

    @param {Object} postStreamData The JSON data we want to update from.
    @method updateFromJson
  **/
  updateFromJson: function(postStreamData) {
    var postStream = this,
        posts = this.get('posts');

    posts.clear();
    this.set('gaps', null);
    if (postStreamData) {
      // Load posts if present
      postStreamData.posts.forEach(function(p) {
        postStream.appendPost(Discourse.Post.create(p));
      });
      delete postStreamData.posts;

      // Update our attributes
      postStream.setProperties(postStreamData);
    }
  },

  /**
    @private

    Stores a post in our identity map, and sets up the references it needs to
    find associated objects like the topic. It might return a different reference
    than you supplied if the post has already been loaded.

    @method storePost
    @param {Discourse.Post} post The post we're storing in the identity map
    @returns {Discourse.Post} the post from the identity map
  **/
  storePost: function(post) {
    // Calling `Em.get(undefined` raises an error
    if (!post) { return; }

    var postId = Em.get(post, 'id');
    if (postId) {
      var postIdentityMap = this.get('postIdentityMap'),
          existing = postIdentityMap.get(post.get('id'));

      if (existing) {
        // If the post is in the identity map, update it and return the old reference.
        existing.updateFromPost(post);
        return existing;
      }

      // Update the auto_close_at value of the topic
      this.set("topic.details.auto_close_at", post.get("topic_auto_close_at"));

      post.set('topic', this.get('topic'));
      postIdentityMap.set(post.get('id'), post);

      // Update the `highest_post_number` if this post is higher.
      var postNumber = post.get('post_number');
      if (postNumber && postNumber > (this.get('topic.highest_post_number') || 0)) {
        this.set('topic.highest_post_number', postNumber);
      }
    }
    return post;
  },

  /**
    @private

    Given a list of postIds, returns a list of the posts we don't have in our
    identity map and need to load.

    @method listUnloadedIds
    @param {Array} postIds The post Ids we want to load from the server
    @returns {Array} the array of postIds we don't have loaded.
  **/
  listUnloadedIds: function(postIds) {
    var unloaded = Em.A(),
        postIdentityMap = this.get('postIdentityMap');
    postIds.forEach(function(p) {
      if (!postIdentityMap.has(p)) { unloaded.pushObject(p); }
    });
    return unloaded;
  },

  /**
    @private

    Returns a list of posts in order requested, by id.

    @method findPostsByIds
    @param {Array} postIds The post Ids we want to retrieve, in order.
    @returns {Promise} a promise that will resolve to the posts in the order requested.
  **/
  findPostsByIds: function(postIds) {
    var unloaded = this.listUnloadedIds(postIds),
        postIdentityMap = this.get('postIdentityMap');

    // Load our unloaded posts by id
    return this.loadIntoIdentityMap(unloaded).then(function() {
      return postIds.map(function (p) {
        return postIdentityMap.get(p);
      }).compact();
    });
  },

  /**
    @private

    Loads a list of posts from the server and inserts them into our identity map.

    @method loadIntoIdentityMap
    @param {Array} postIds The post Ids we want to insert into the identity map.
    @returns {Promise} a promise that will resolve to the posts in the order requested.
  **/
  loadIntoIdentityMap: function(postIds) {
    // If we don't want any posts, return a promise that resolves right away
    if (Em.isEmpty(postIds)) {
      return Ember.RSVP.resolve();
    }

    var url = "/t/" + this.get('topic.id') + "/posts.json",
        data = { post_ids: postIds },
        postStream = this;

    return Discourse.ajax(url, {data: data}).then(function(result) {
      var posts = Em.get(result, "post_stream.posts");
      if (posts) {
        posts.forEach(function (p) {
          postStream.storePost(Discourse.Post.create(p));
        });
      }
    });
  },


  /**
    @private

    Returns the index of a particular post in the stream

    @method indexOf
    @param {Discourse.Post} post The post we're looking for
  **/
  indexOf: function(post) {
    return this.get('stream').indexOf(post.get('id'));
  },


  /**
    @private

    Handles an error loading a topic based on a HTTP status code. Updates
    the text to the correct values.

    @method errorLoading
    @param {Integer} status the HTTP status code
    @param {Discourse.Topic} topic The topic instance we were trying to load
  **/
  errorLoading: function(result) {
    var status = result.status;

    var topic = this.get('topic');
    topic.set('loadingFilter', false);
    topic.set('errorLoading', true);

    // If the result was 404 the post is not found
    if (status === 404) {
      topic.set('errorTitle', I18n.t('topic.not_found.title'));
      topic.set('notFoundHtml', result.responseText);
      return;
    }

    // If the result is 403 it means invalid access
    if (status === 403) {
      topic.set('errorTitle', I18n.t('topic.invalid_access.title'));
      topic.set('noRetry', true);
      if (Discourse.User.current()) {
        topic.set('message', I18n.t('topic.invalid_access.description'));
      } else {
        topic.set('message', I18n.t('topic.invalid_access.login_required'));
      }
      return;
    }

    // Otherwise supply a generic error message
    topic.set('errorTitle', I18n.t('topic.server_error.title'));
    topic.set('message', I18n.t('topic.server_error.description'));
  }

});


Discourse.PostStream.reopenClass({

  create: function() {
    var postStream = this._super.apply(this, arguments);
    postStream.setProperties({
      posts: [],
      stream: [],
      userFilters: [],
      postIdentityMap: Em.Map.create(),
      summary: false,
      loaded: false,
      loadingAbove: false,
      loadingBelow: false,
      loadingFilter: false,
      stagingPost: false
    });
    return postStream;
  },

  loadTopicView: function(topicId, args) {
    var opts = _.merge({}, args),
        url = Discourse.getURL("/t/") + topicId;
    if (opts.nearPost) {
      url += "/" + opts.nearPost;
    }
    delete opts.nearPost;

    return PreloadStore.getAndRemove("topic_" + topicId, function() {
      return Discourse.ajax(url + ".json", {data: opts});
    });

  }

});
