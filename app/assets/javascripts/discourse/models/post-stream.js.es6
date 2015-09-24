import DiscourseURL from 'discourse/lib/url';
import RestModel from 'discourse/models/rest';

function calcDayDiff(p1, p2) {
  if (!p1) { return; }

  const date = p1.get('created_at');
  if (date && p2) {
    const lastDate = p2.get('created_at');
    if (lastDate) {
      const delta = new Date(date).getTime() - new Date(lastDate).getTime();
      const days = Math.round(delta / (1000 * 60 * 60 * 24));

      p1.set('daysSincePrevious', days);
    }
  }
}

const PostStream = RestModel.extend({
  loading: Em.computed.or('loadingAbove', 'loadingBelow', 'loadingFilter', 'stagingPost'),
  notLoading: Em.computed.not('loading'),
  filteredPostsCount: Em.computed.alias("stream.length"),

  hasPosts: function() {
    return this.get('posts.length') > 0;
  }.property("posts.@each"),

  hasStream: Em.computed.gt('filteredPostsCount', 0),
  canAppendMore: Em.computed.and('notLoading', 'hasPosts', 'lastPostNotLoaded'),
  canPrependMore: Em.computed.and('notLoading', 'hasPosts', 'firstPostNotLoaded'),

  firstPostPresent: function() {
    if (!this.get('hasLoadedData')) { return false; }
    return !!this.get('posts').findProperty('id', this.get('firstPostId'));
  }.property('hasLoadedData', 'posts.@each', 'firstPostId'),

  firstPostNotLoaded: Em.computed.not('firstPostPresent'),

  firstLoadedPost: function() {
    return _.first(this.get('posts'));
  }.property('posts.@each'),

  lastLoadedPost: function() {
    return _.last(this.get('posts'));
  }.property('posts.@each'),

  firstPostId: function() {
    return this.get('stream')[0];
  }.property('stream.@each'),

  lastPostId: function() {
    return _.last(this.get('stream'));
  }.property('stream.@each'),

  loadedAllPosts: function() {
    if (!this.get('hasLoadedData')) {
      return false;
    }

    // if we are staging a post assume all is loaded
    if (this.get('lastPostId') === -1) {
      return true;
    }

    return !!this.get('posts').findProperty('id', this.get('lastPostId'));
  }.property('hasLoadedData', 'posts.@each.id', 'lastPostId'),

  lastPostNotLoaded: Em.computed.not('loadedAllPosts'),

  /**
    Returns a JS Object of current stream filter options. It should match the query
    params for the stream.
  **/
  streamFilters: function() {
    const result = {};
    if (this.get('summary')) { result.filter = "summary"; }
    if (this.get('show_deleted')) { result.show_deleted = true; }

    const userFilters = this.get('userFilters');
    if (!Em.isEmpty(userFilters)) {
      result.username_filters = userFilters.join(",");
    }

    return result;
  }.property('userFilters.[]', 'summary', 'show_deleted'),

  hasNoFilters: function() {
    const streamFilters = this.get('streamFilters');
    return !(streamFilters && ((streamFilters.filter === 'summary') || streamFilters.username_filters));
  }.property('streamFilters.[]', 'topic.posts_count', 'posts.length'),

  /**
    Returns the window of posts above the current set in the stream, bound to the top of the stream.
    This is the collection we'll ask for when scrolling upwards.
  **/
  previousWindow: function() {
    // If we can't find the last post loaded, bail
    const firstPost = _.first(this.get('posts'));
    if (!firstPost) { return []; }

    // Find the index of the last post loaded, if not found, bail
    const stream = this.get('stream');
    const firstIndex = this.indexOf(firstPost);
    if (firstIndex === -1) { return []; }

    let startIndex = firstIndex - this.get('topic.chunk_size');
    if (startIndex < 0) { startIndex = 0; }
    return stream.slice(startIndex, firstIndex);

  }.property('posts.@each', 'stream.@each'),

  /**
    Returns the window of posts below the current set in the stream, bound by the bottom of the
    stream. This is the collection we use when scrolling downwards.
  **/
  nextWindow: function() {
    // If we can't find the last post loaded, bail
    const lastLoadedPost = this.get('lastLoadedPost');
    if (!lastLoadedPost) { return []; }

    // Find the index of the last post loaded, if not found, bail
    const stream = this.get('stream');
    const lastIndex = this.indexOf(lastLoadedPost);
    if (lastIndex === -1) { return []; }
    if ((lastIndex + 1) >= this.get('highest_post_number')) { return []; }

    // find our window of posts
    return stream.slice(lastIndex+1, lastIndex + this.get('topic.chunk_size') + 1);
  }.property('lastLoadedPost', 'stream.@each'),

  cancelFilter() {
    this.set('summary', false);
    this.set('show_deleted', false);
    this.get('userFilters').clear();
  },

  toggleSummary() {
    this.get('userFilters').clear();
    this.toggleProperty('summary');

    const self = this;
    return this.refresh().then(function() {
      if (self.get('summary')) {
        self.jumpToSecondVisible();
      }
    });
  },

  toggleDeleted() {
    this.toggleProperty('show_deleted');
    return this.refresh();
  },

  jumpToSecondVisible() {
    const posts = this.get('posts');
    if (posts.length > 1) {
      const secondPostNum = posts[1].get('post_number');
      DiscourseURL.jumpToPost(secondPostNum);
    }
  },

  // Filter the stream to a particular user.
  toggleParticipant(username) {
    const userFilters = this.get('userFilters');
    this.set('summary', false);
    this.set('show_deleted', true);

    let jump = false;
    if (userFilters.contains(username)) {
      userFilters.removeObject(username);
    } else {
      userFilters.addObject(username);
      jump = true;
    }
    const self = this;
    return this.refresh().then(function() {
      if (jump) {
        self.jumpToSecondVisible();
      }
    });
  },

  /**
    Loads a new set of posts into the stream. If you provide a `nearPost` option and the post
    is already loaded, it will simply scroll there and load nothing.
  **/
  refresh(opts) {
    opts = opts || {};
    opts.nearPost = parseInt(opts.nearPost, 10);

    const topic = this.get('topic');
    const self = this;

    // Do we already have the post in our list of posts? Jump there.
    if (opts.forceLoad) {
      this.set('loaded', false);
    } else {
      const postWeWant = this.get('posts').findProperty('post_number', opts.nearPost);
      if (postWeWant) { return Ember.RSVP.resolve(); }
    }

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

  collapsePosts(from, to){
    const posts = this.get('posts');
    const remove = posts.filter(function(post){
      const postNumber = post.get('post_number');
      return postNumber >= from && postNumber <= to;
    });

    posts.removeObjects(remove);

    // make gap
    this.set('gaps', this.get('gaps') || {before: {}, after: {}});
    const before = this.get('gaps.before');

    const post = posts.find(function(p){
      return p.get('post_number') > to;
    });

    before[post.get('id')] = remove.map(function(p){
      return p.get('id');
    });
    post.set('hasGap', true);

    this.get('stream').enumerableContentDidChange();
  },


  // Fill in a gap of posts before a particular post
  fillGapBefore(post, gap) {
    const postId = post.get('id'),
        stream = this.get('stream'),
        idx = stream.indexOf(postId),
        currentPosts = this.get('posts'),
        self = this;

    if (idx !== -1) {
      // Insert the gap at the appropriate place
      stream.splice.apply(stream, [idx, 0].concat(gap));

      let postIdx = currentPosts.indexOf(post);
      if (postIdx !== -1) {
        return this.findPostsByIds(gap).then(function(posts) {
          posts.forEach(function(p) {
            const stored = self.storePost(p);
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

  // Fill in a gap of posts after a particular post
  fillGapAfter(post, gap) {
    const postId = post.get('id'),
          stream = this.get('stream'),
          idx = stream.indexOf(postId);

    if (idx !== -1) {
      stream.pushObjects(gap);
      return this.appendMore().then(() => {
        this.get('stream').enumerableContentDidChange();
      });
    }
    return Ember.RSVP.resolve();
  },

  // Appends the next window of posts to the stream. Call it when scrolling downwards.
  appendMore() {
    // Make sure we can append more posts
    if (!this.get('canAppendMore')) { return Ember.RSVP.resolve(); }

    const postIds = this.get('nextWindow');
    if (Ember.isEmpty(postIds)) { return Ember.RSVP.resolve(); }

    this.set('loadingBelow', true);

    const stopLoading = () => this.set('loadingBelow', false);

    return this.findPostsByIds(postIds).then((posts) => {
      posts.forEach(p => this.appendPost(p));
      stopLoading();
    }, stopLoading);
  },

  // Prepend the previous window of posts to the stream. Call it when scrolling upwards.
  prependMore() {
    const postStream = this;

    // Make sure we can append more posts
    if (!postStream.get('canPrependMore')) { return Ember.RSVP.resolve(); }

    const postIds = postStream.get('previousWindow');
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
  **/
  stagePost(post, user) {
    // We can't stage two posts simultaneously
    if (this.get('stagingPost')) { return "alreadyStaging"; }

    this.set('stagingPost', true);

    const topic = this.get('topic');
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
      return "staged";
    }

    return "offScreen";
  },

  // Commit the post we staged. Call this after a save succeeds.
  commitPost(post) {

    if (this.get('topic.id') === post.get('topic_id')) {
      if (this.get('loadedAllPosts')) {
        this.appendPost(post);
        this.get('stream').addObject(post.get('id'));
      }
    }

    this.get('stream').removeObject(-1);
    this.get('postIdentityMap').set(-1, null);

    this.set('stagingPost', false);
  },

  /**
    Undo a post we've staged in the stream. Remove it from being rendered and revert the
    state we changed.
  **/
  undoPost(post) {
    this.get('stream').removeObject(-1);
    this.posts.removeObject(post);
    this.get('postIdentityMap').set(-1, null);

    const topic = this.get('topic');
    this.set('stagingPost', false);

    topic.setProperties({
      highest_post_number: (topic.get('highest_post_number') || 0) - 1,
      posts_count: (topic.get('posts_count') || 0) - 1
    });

    // TODO unfudge reply count on parent post
  },

  prependPost(post) {
    const stored = this.storePost(post);
    if (stored) {
      const posts = this.get('posts');
      calcDayDiff(posts.get('firstObject'), stored);
      posts.unshiftObject(stored);
    }

    return post;
  },

  appendPost(post) {
    const stored = this.storePost(post);
    if (stored) {
      const posts = this.get('posts');

      calcDayDiff(stored, this.get('lastAppended'));
      posts.addObject(stored);

      if (stored.get('id') !== -1) {
        this.set('lastAppended', stored);
      }
    }
    return post;
  },

  removePosts(posts) {
    if (Em.isEmpty(posts)) { return; }

    const postIds = posts.map(function (p) { return p.get('id'); });
    const identityMap = this.get('postIdentityMap');

    this.get('stream').removeObjects(postIds);
    this.get('posts').removeObjects(posts);
    postIds.forEach(function(id){
      identityMap.delete(id);
    });
  },

  // Returns a post from the identity map if it's been inserted.
  findLoadedPost(id) {
    return this.get('postIdentityMap').get(id);
  },

  loadPost(postId){
    const url = "/posts/" + postId;
    const store = this.store;

    return Discourse.ajax(url).then((p) =>
        this.storePost(store.createRecord('post', p)));
  },

  /**
    Finds and adds a post to the stream by id. Typically this would happen if we receive a message
    from the message bus indicating there's a new post. We'll only insert it if we currently
    have no filters.
  **/
  triggerNewPostInStream(postId) {
    if (!postId) { return; }

    // We only trigger if there are no filters active
    if (!this.get('hasNoFilters')) { return; }

    const loadedAllPosts = this.get('loadedAllPosts');

    if (this.get('stream').indexOf(postId) === -1) {
      this.get('stream').addObject(postId);
      if (loadedAllPosts) { this.appendMore(); }
    }
  },

  triggerRecoveredPost(postId){
    const self = this,
        postIdentityMap = this.get('postIdentityMap'),
        existing = postIdentityMap.get(postId);

    if(existing){
      this.triggerChangedPost(postId, new Date());
    } else {
      // need to insert into stream
      const url = "/posts/" + postId;
      const store = this.store;
      Discourse.ajax(url).then(function(p){
        const post = store.createRecord('post', p);
        const stream = self.get("stream");
        const posts = self.get("posts");
        self.storePost(post);

        // we need to zip this into the stream
        let index = 0;
        stream.forEach(function(pid){
          if (pid < p.id){
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

  triggerDeletedPost(postId){
    const self = this,
        postIdentityMap = this.get('postIdentityMap'),
        existing = postIdentityMap.get(postId);

    if(existing){
      const url = "/posts/" + postId;
      const store = this.store;
      Discourse.ajax(url).then(
        function(p){
          self.storePost(store.createRecord('post', p));
        },
        function(){
          self.removePosts([existing]);
        });
    }
  },

  triggerChangedPost(postId, updatedAt) {
    if (!postId) { return; }

    const postIdentityMap = this.get('postIdentityMap'),
        existing = postIdentityMap.get(postId),
        self = this;

    if (existing && existing.updated_at !== updatedAt) {
      const url = "/posts/" + postId;
      const store = this.store;
      Discourse.ajax(url).then(function(p){
        self.storePost(store.createRecord('post', p));
      });
    }
  },

  // Returns the "thread" of posts in the history of a post.
  findReplyHistory(post) {
    const postStream = this,
        url = "/posts/" + post.get('id') + "/reply-history.json?max_replies=" + Discourse.SiteSettings.max_reply_history;

    const store = this.store;
    return Discourse.ajax(url).then(function(result) {
      return result.map(function (p) {
        return postStream.storePost(store.createRecord('post', p));
      });
    }).then(function (replyHistory) {
      post.set('replyHistory', replyHistory);
    });
  },

  /**
    Returns the closest post given a postNumber that may not exist in the stream.
    For example, if the user asks for a post that's deleted or otherwise outside the range.
    This allows us to set the progress bar with the correct number.
  **/
  closestPostForPostNumber(postNumber) {
    if (!this.get('hasPosts')) { return; }

    let closest = null;
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
  progressIndexOfPost(post) {
    return this.progressIndexOfPostId(post.get('id'));
  },

  // Get the index in the stream of a post id. (Use this for the topic progress bar.)
  progressIndexOfPostId(post_id) {
    return this.get('stream').indexOf(post_id) + 1;
  },

  /**
    Returns the closest post number given a postNumber that may not exist in the stream.
    For example, if the user asks for a post that's deleted or otherwise outside the range.
    This allows us to set the progress bar with the correct number.
  **/
  closestPostNumberFor(postNumber) {
    if (!this.get('hasPosts')) { return; }

    let closest = null;
    this.get('posts').forEach(function (p) {
      if (closest === postNumber) { return; }
      if (!closest) { closest = p.get('post_number'); }

      if (Math.abs(postNumber - p.get('post_number')) < Math.abs(closest - postNumber)) {
        closest = p.get('post_number');
      }
    });

    return closest;
  },

  // Find a postId for a postNumber, respecting gaps
  findPostIdForPostNumber(postNumber) {
    const stream = this.get('stream'),
          beforeLookup = this.get('gaps.before'),
          streamLength = stream.length;

    let sum = 1;
    for (let i=0; i<streamLength; i++) {
      const pid = stream[i];

      // See if there are posts before this post
      if (beforeLookup) {
        const before = beforeLookup[pid];
        if (before) {
          for (let j=0; j<before.length; j++) {
            if (sum === postNumber) { return pid; }
            sum++;
          }
        }
      }

      if (sum === postNumber) { return pid; }
      sum++;
    }
  },

  updateFromJson(postStreamData) {
    const postStream = this,
        posts = this.get('posts');

    posts.clear();
    this.set('gaps', null);
    if (postStreamData) {
      // Load posts if present
      const store = this.store;
      postStreamData.posts.forEach(function(p) {
        postStream.appendPost(store.createRecord('post', p));
      });
      delete postStreamData.posts;

      // Update our attributes
      postStream.setProperties(postStreamData);
    }
  },

  /**
    Stores a post in our identity map, and sets up the references it needs to
    find associated objects like the topic. It might return a different reference
    than you supplied if the post has already been loaded.
  **/
  storePost(post) {
    // Calling `Em.get(undefined` raises an error
    if (!post) { return; }

    const postId = Em.get(post, 'id');
    if (postId) {
      const postIdentityMap = this.get('postIdentityMap'),
            existing = postIdentityMap.get(post.get('id'));

      // Update the `highest_post_number` if this post is higher.
      const postNumber = post.get('post_number');
      if (postNumber && postNumber > (this.get('topic.highest_post_number') || 0)) {
        this.set('topic.highest_post_number', postNumber);
      }

      if (existing) {
        // If the post is in the identity map, update it and return the old reference.
        existing.updateFromPost(post);
        return existing;
      }

      post.set('topic', this.get('topic'));
      postIdentityMap.set(post.get('id'), post);
    }
    return post;
  },

  /**
    Given a list of postIds, returns a list of the posts we don't have in our
    identity map and need to load.
  **/
  listUnloadedIds(postIds) {
    const unloaded = Em.A(),
        postIdentityMap = this.get('postIdentityMap');
    postIds.forEach(function(p) {
      if (!postIdentityMap.has(p)) { unloaded.pushObject(p); }
    });
    return unloaded;
  },

  findPostsByIds(postIds) {
    const unloaded = this.listUnloadedIds(postIds),
        postIdentityMap = this.get('postIdentityMap');

    // Load our unloaded posts by id
    return this.loadIntoIdentityMap(unloaded).then(function() {
      return postIds.map(function (p) {
        return postIdentityMap.get(p);
      }).compact();
    });
  },

  loadIntoIdentityMap(postIds) {
    // If we don't want any posts, return a promise that resolves right away
    if (Em.isEmpty(postIds)) {
      return Ember.RSVP.resolve();
    }

    const url = "/t/" + this.get('topic.id') + "/posts.json",
        data = { post_ids: postIds },
        postStream = this;

    const store = this.store;
    return Discourse.ajax(url, {data: data}).then(function(result) {
      const posts = Em.get(result, "post_stream.posts");
      if (posts) {
        posts.forEach(function (p) {
          postStream.storePost(store.createRecord('post', p));
        });
      }
    });
  },


  indexOf(post) {
    return this.get('stream').indexOf(post.get('id'));
  },


  /**
    Handles an error loading a topic based on a HTTP status code. Updates
    the text to the correct values.
  **/
  errorLoading(result) {
    const status = result.jqXHR.status;

    const topic = this.get('topic');
    this.set('loadingFilter', false);
    topic.set('errorLoading', true);

    // If the result was 404 the post is not found
    if (status === 404) {
      topic.set('notFoundHtml', result.jqXHR.responseText);
      return;
    }

    // If the result is 403 it means invalid access
    if (status === 403) {
      topic.set('noRetry', true);
      if (Discourse.User.current()) {
        topic.set('message', I18n.t('topic.invalid_access.description'));
      } else {
        topic.set('message', I18n.t('topic.invalid_access.login_required'));
      }
      return;
    }

    // Otherwise supply a generic error message
    topic.set('message', I18n.t('topic.server_error.description'));
  }

});


PostStream.reopenClass({

  create() {
    const postStream = this._super.apply(this, arguments);
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

  loadTopicView(topicId, args) {
    const opts = _.merge({}, args);
    let url = Discourse.getURL("/t/") + topicId;
    if (opts.nearPost) {
      url += "/" + opts.nearPost;
    }
    delete opts.nearPost;
    delete opts.__type;
    delete opts.store;

    return PreloadStore.getAndRemove("topic_" + topicId, function() {
      return Discourse.ajax(url + ".json", {data: opts});
    });

  }

});

export default PostStream;
