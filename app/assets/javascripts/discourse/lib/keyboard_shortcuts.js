/**
  Keyboard Shortcut related functions.

  @class KeyboardShortcuts
  @namespace Discourse
  @module Discourse
**/
Discourse.KeyboardShortcuts = Ember.Object.createWithMixins({
  PATH_BINDINGS: {
    'g h': '/',
    'g l': '/latest',
    'g n': '/new',
    'g u': '/unread',
    'g f': '/starred',
    'g c': '/categories',
    'g t': '/top'
  },

  SELECTED_POST_BINDINGS: {
    'b': 'toggleBookmark',
    'd': 'deletePost',
    'e': 'editPost',
    'l': 'toggleLike',
    'r': 'replyToPost',
    '!': 'showFlags',
    't': 'replyAsNewTopic'
  },

  CLICK_BINDINGS: {
    // star topic
    'f': '#topic-footer-buttons button.star, .topic-list tr.topic-list-item.selected a.star',

    'm m': 'div.notification-options li[data-id="0"] a',                      // mark topic as muted
    'm r': 'div.notification-options li[data-id="1"] a',                      // mark topic as regular
    'm t': 'div.notification-options li[data-id="2"] a',                      // mark topic as tracking
    'm w': 'div.notification-options li[data-id="3"] a',                      // mark topic as watching
    'x r': '#dismiss-new,#dismiss-new-top,#dismiss-posts,#dismiss-posts-top', // dismiss new/posts
    'x t': '#dismiss-topics,#dismiss-topics-top',                             //dismiss topics
    '.': '.alert.alert-info.clickable',                                       // show incoming/updated topics
    'n': '#user-notifications',                                               // open notifications menu
    'o,enter': '.topic-list tr.selected a.title',                             // open selected topic
    'shift+r': '#topic-footer-buttons button.create',                         // reply to topic
    'shift+s': '#topic-footer-buttons button.share',                          // share topic
    's': '.topic-post.selected a.post-date'                                   // share post
  },

  FUNCTION_BINDINGS: {
    'c': 'createTopic',                                         // create new topic
    'home': 'goToFirstPost',
    '#': 'toggleProgress',
    'end': 'goToLastPost',
    'shift+j': 'nextSection',
    'j': 'selectDown',
    'shift+k': 'prevSection',
    'k': 'selectUp',
    'u': 'goBack',
    '/': 'showSearch',
    '=': 'showSiteMap',                                             // open site map menu
    'p': 'showCurrentUser',                                         // open current user menu
    'ctrl+f': 'showBuiltinSearch',
    'command+f': 'showBuiltinSearch',
    '?': 'showHelpModal',                                          // open keyboard shortcut help
    'q': 'quoteReply'
  },

  bindEvents: function(keyTrapper, container) {
    this.keyTrapper = keyTrapper;
    this.container = container;
    _.each(this.PATH_BINDINGS, this._bindToPath, this);
    _.each(this.CLICK_BINDINGS, this._bindToClick, this);
    _.each(this.SELECTED_POST_BINDINGS, this._bindToSelectedPost, this);
    _.each(this.FUNCTION_BINDINGS, this._bindToFunction, this);
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
    var currentPath = this.container.lookup('controller:application').get('currentPath'),
        blacklist = [ /^discovery\.categories/ ],
        whitelist = [ /^topic\./ ],
        check = function(regex) { return !!currentPath.match(regex); },
        showSearch = whitelist.any(check) && !blacklist.any(check);

    // If we're viewing a topic, only intercept search if there are cloaked posts
    if (showSearch && currentPath.match(/^topic\./)) {
      showSearch = $('.cooked').length < this.container.lookup('controller:topic').get('postStream.stream.length');

    }

    return showSearch ? this.showSearch(true) : true;
  },

  createTopic: function() {
    Discourse.__container__.lookup('controller:composer').open({action: Discourse.Composer.CREATE_TOPIC, draftKey: Discourse.Composer.DRAFT});
  },

  toggleProgress: function() {
    Discourse.__container__.lookup('controller:topic-progress').send('toggleExpansion', {highlight: true});
  },

  showSearch: function(selectContext) {
    $('#search-button').click();
    if(selectContext) {
      Discourse.__container__.lookup('controller:search').set('searchContextEnabled', true);
    }
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

  _bindToSelectedPost: function(action, binding) {
    var container = this.container;

    this.keyTrapper.bind(binding, function() {
      // TODO: We should keep track of the post without a CSS class
      var selectedPostId = parseInt($('.topic-post.selected article.boxed').data('post-id'), 10);
      if (selectedPostId) {
        var topicController = container.lookup('controller:topic'),
            post = topicController.get('postStream.posts').findBy('id', selectedPostId);
        if (post) {
          topicController.send(action, post);
        }
      }
    });
  },

  _bindToPath: function(path, binding) {
    this.keyTrapper.bind(binding, function() {
      Discourse.URL.routeTo(path);
    });
  },

  _bindToClick: function(selector, binding) {
    binding = binding.split(',');
    this.keyTrapper.bind(binding, function() {
      $(selector).click();
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
      if (direction === 1 && index === ($articles.size()-1) ) { return;}  
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

      if ($article.is('.topic-post')) {
        var tabLoc = $article.find('a.tabLoc');
        if (tabLoc.length === 0) {
          tabLoc = $('<a href="#" class="tabLoc"></a>');
          $article.prepend(tabLoc);
        }
        tabLoc.focus();
      }
      
      var rgx = new RegExp("post-cloak-(\\d+)").exec($article.parent()[0].id);
      if (rgx === null || typeof rgx[1] === 'undefined') {
          this._scrollList($article, direction);
      } else {
          Discourse.URL.jumpToPost(rgx[1]);
      }
    }
  },

  _scrollList: function($article, direction) {
    var $document = $(document),
        distToElement = $article.position().top + $article.height() - $(window).height() - $document.scrollTop();

    // cut some bottom slack
    distToElement += 40;

    // don't scroll backwards, its silly
    if((direction > 0 && distToElement < 0) || (direction < 0 && distToElement > 0)) {
      return;
    }

    $('html, body').scrollTop($document.scrollTop() + distToElement);
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
  }
});
