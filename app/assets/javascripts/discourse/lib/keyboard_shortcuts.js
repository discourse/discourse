var PATH_BINDINGS = {
      'g h': '/',
      'g l': '/latest',
      'g n': '/new',
      'g u': '/unread',
      'g c': '/categories',
      'g t': '/top',
      'g b': '/bookmarks'
    },

    SELECTED_POST_BINDINGS = {
      'd': 'deletePost',
      'e': 'editPost',
      'l': 'toggleLike',
      'r': 'replyToPost',
      '!': 'showFlags',
      't': 'replyAsNewTopic'
    },

    CLICK_BINDINGS = {
      'm m': 'div.notification-options li[data-id="0"] a',                      // mark topic as muted
      'm r': 'div.notification-options li[data-id="1"] a',                      // mark topic as regular
      'm t': 'div.notification-options li[data-id="2"] a',                      // mark topic as tracking
      'm w': 'div.notification-options li[data-id="3"] a',                      // mark topic as watching
      'x r': '#dismiss-new,#dismiss-new-top,#dismiss-posts,#dismiss-posts-top', // dismiss new/posts
      'x t': '#dismiss-topics,#dismiss-topics-top',                             // dismiss topics
      '.': '.alert.alert-info.clickable',                                       // show incoming/updated topics
      'n': '#user-notifications',                                               // open notifications menu
      'o,enter': '.topic-list tr.selected a.title',                             // open selected topic
      'shift+s': '#topic-footer-buttons button.share',                          // share topic
      's': '.topic-post.selected a.post-date'                                   // share post
    },

    FUNCTION_BINDINGS = {
      'c': 'createTopic',                                                       // create new topic
      'home': 'goToFirstPost',
      '#': 'toggleProgress',
      'end': 'goToLastPost',
      'shift+j': 'nextSection',
      'j': 'selectDown',
      'shift+k': 'prevSection',
      'shift+p': 'pinUnpinTopic',
      'k': 'selectUp',
      'u': 'goBack',
      '/': 'showSearch',
      '=': 'showSiteMap',                                                       // open site map menu
      'p': 'showCurrentUser',                                                   // open current user menu
      'ctrl+f': 'showBuiltinSearch',
      'command+f': 'showBuiltinSearch',
      '?': 'showHelpModal',                                                     // open keyboard shortcut help
      'q': 'quoteReply',
      'b': 'toggleBookmark',
      'f': 'toggleBookmarkTopic',
      'shift+r': 'replyToTopic'
    };


Discourse.KeyboardShortcuts = Ember.Object.createWithMixins({
  bindEvents: function(keyTrapper, container) {
    this.keyTrapper = keyTrapper;
    this.container = container;
    this._stopCallback();

    _.each(PATH_BINDINGS, this._bindToPath, this);
    _.each(CLICK_BINDINGS, this._bindToClick, this);
    _.each(SELECTED_POST_BINDINGS, this._bindToSelectedPost, this);
    _.each(FUNCTION_BINDINGS, this._bindToFunction, this);
  },

  toggleBookmark: function(){
    this.sendToSelectedPost('toggleBookmark');
    this.sendToTopicListItemView('toggleBookmark');
  },

  toggleBookmarkTopic: function(){
    var topic = this.currentTopic();
    // BIG hack, need a cleaner way
    if(topic && $('.posts-wrapper').length > 0) {
      topic.toggleBookmark();
    } else {
      this.sendToTopicListItemView('toggleBookmark');
    }
  },

  quoteReply: function(){
    $('.topic-post.selected button.create').click();
    // lazy but should work for now
    setTimeout(function(){
      $('#wmd-quote-post').click();
    }, 500);
  },

  goToFirstPost: function() {
    this._jumpTo('jumpTop');
  },

  goToLastPost: function() {
    this._jumpTo('jumpBottom');
  },

  _jumpTo: function(direction) {
    if ($('.container.posts').length) {
      this.container.lookup('controller:topic-progress').send(direction);
    }
  },

  replyToTopic: function() {
    this.container.lookup('controller:topic').send('replyToPost');
  },

  selectDown: function() {
    this._moveSelection(1);
  },

  selectUp: function() {
    this._moveSelection(-1);
  },

  goBack: function() {
    history.back();
  },

  nextSection: function() {
    this._changeSection(1);
  },

  prevSection: function() {
    this._changeSection(-1);
  },

  showBuiltinSearch: function() {
    if ($('#search-dropdown').is(':visible')) {
      this._toggleSearch(false);
      return true;
    }

    var currentPath = this.container.lookup('controller:application').get('currentPath'),
        blacklist = [ /^discovery\.categories/ ],
        whitelist = [ /^topic\./ ],
        check = function(regex) { return !!currentPath.match(regex); },
        showSearch = whitelist.any(check) && !blacklist.any(check);

    // If we're viewing a topic, only intercept search if there are cloaked posts
    if (showSearch && currentPath.match(/^topic\./)) {
      showSearch = $('.cooked').length < this.container.lookup('controller:topic').get('postStream.stream.length');
    }

    if (showSearch) {
      this._toggleSearch(true);
      return false;
    }

    return true;
  },

  createTopic: function() {
    Discourse.__container__.lookup('controller:composer').open({action: Discourse.Composer.CREATE_TOPIC, draftKey: Discourse.Composer.CREATE_TOPIC});
  },

  pinUnpinTopic: function() {
    Discourse.__container__.lookup('controller:topic').togglePinnedState();
  },

  toggleProgress: function() {
    Discourse.__container__.lookup('controller:topic-progress').send('toggleExpansion', {highlight: true});
  },

  showSearch: function() {
    this._toggleSearch(false);
    return false;
  },

  showSiteMap: function() {
    $('#site-map').click();
    $('#site-map-dropdown a:first').focus();
  },

  showCurrentUser: function() {
    $('#current-user').click();
    $('#user-dropdown a:first').focus();
  },

  showHelpModal: function() {
    Discourse.__container__.lookup('controller:application').send('showKeyboardShortcutsHelp');
  },

  sendToTopicListItemView: function(action){
    var elem = $('tr.selected.topic-list-item.ember-view')[0];
    if(elem){
      var view = Ember.View.views[elem.id];
      view.send(action);
    }
  },

  currentTopic: function(){
    var topicController = this.container.lookup('controller:topic');
    if(topicController) {
      var topic = topicController.get('model');
      if(topic){
        return topic;
      }
    }
  },

  sendToSelectedPost: function(action){
    var container = this.container;
    // TODO: We should keep track of the post without a CSS class
    var selectedPostId = parseInt($('.topic-post.selected article.boxed').data('post-id'), 10);
    if (selectedPostId) {
      var topicController = container.lookup('controller:topic'),
          post = topicController.get('model.postStream.posts').findBy('id', selectedPostId);
      if (post) {
        topicController.send(action, post);
      }
    }
  },

  _bindToSelectedPost: function(action, binding) {
    var self = this;

    this.keyTrapper.bind(binding, function() {
      self.sendToSelectedPost(action);
    });
  },

  _bindToPath: function(path, binding) {
    this.keyTrapper.bind(binding, function() {
      Discourse.URL.routeTo(path);
    });
  },

  _bindToClick: function(selector, binding) {
    binding = binding.split(',');
    this.keyTrapper.bind(binding, function(e) {
      var $sel = $(selector);

      // Special case: We're binding to enter.
      if (e && e.keyCode === 13) {
        // Binding to enter should only be effective when there is something
        // to select.
        if ($sel.length === 0) {
          return;
        }

        // If effective, prevent default.
        e.preventDefault();
      }
      $sel.click();
    });
  },

  _bindToFunction: function(func, binding) {
    if (typeof this[func] === 'function') {
      this.keyTrapper.bind(binding, _.bind(this[func], this));
    }
  },

  _moveSelection: function(direction) {
    var $articles = this._findArticles();

    if (typeof $articles === 'undefined') {
      return;
    }

    var $selected = $articles.filter('.selected'),
        index = $articles.index($selected);

    if($selected.length !== 0){ //boundries check
      // loop is not allowed
      if (direction === -1 && index === 0) { return; }
      if (direction === 1 && index === ($articles.size()-1) ) { return; }
    }

    // if nothing is selected go to the first post on screen
    if ($selected.length === 0) {
      var scrollTop = $(document).scrollTop();

      index = 0;
      $articles.each(function(){
        var top = $(this).position().top;
        if(top > scrollTop) {
          return false;
        }
        index += 1;
      });

      if(index >= $articles.length){
        index = $articles.length - 1;
      }

      direction = 0;
    }

    var $article = $articles.eq(index + direction);

    if ($article.size() > 0) {

      $articles.removeClass('selected');
      $article.addClass('selected');

      if($article.is('.topic-list-item')){
        this.sendToTopicListItemView('select');
      }

      if ($article.is('.topic-post')) {
        var tabLoc = $article.find('a.tabLoc');
        if (tabLoc.length === 0) {
          tabLoc = $('<a href class="tabLoc"></a>');
          $article.prepend(tabLoc);
        }
        tabLoc.focus();
      }

      this._scrollList($article, direction);
    }
  },

  _scrollList: function($article) {
    // Try to keep the article on screen
    var pos = $article.offset();
    var height = $article.height();
    var scrollTop = $(window).scrollTop();
    var windowHeight = $(window).height();

    // skip if completely on screen
    if (pos.top > scrollTop && (pos.top + height) < (scrollTop + windowHeight)) {
      return;
    }

    var scrollPos = (pos.top + (height/2)) - (windowHeight * 0.5);
    if (scrollPos < 0) { scrollPos = 0; }

    if (this._scrollAnimation) {
      this._scrollAnimation.stop();
    }
    this._scrollAnimation = $("html, body").animate({ scrollTop: scrollPos + "px"}, 100);
  },


  _findArticles: function() {
    var $topicList = $('.topic-list'),
        $topicArea = $('.posts-wrapper');

    if ($topicArea.size() > 0) {
      return $('.posts-wrapper .topic-post, .topic-list tbody tr');
    }
    else if ($topicList.size() > 0) {
      return $topicList.find('.topic-list-item');
    }
  },

  _changeSection: function(direction) {
    var $sections = $('#navigation-bar li'),
        active = $('#navigation-bar li.active'),
        index = $sections.index(active) + direction;

    if(index >= 0 && index < $sections.length){
      $sections.eq(index).find('a').click();
    }
  },

  _stopCallback: function() {
    var oldStopCallback = this.keyTrapper.stopCallback;

    this.keyTrapper.stopCallback = function(e, element, combo) {
      if ((combo === 'ctrl+f' || combo === 'command+f') && element.id === 'search-term') {
        return false;
      }

      return oldStopCallback(e, element, combo);
    };
  },

  _toggleSearch: function(selectContext) {
    $('#search-button').click();
    if (selectContext) {
      Discourse.__container__.lookup('controller:search').set('searchContextEnabled', true);
    }
  },
});
