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

  CLICK_BINDINGS: {
    'b': 'article.selected button.bookmark',                      // bookmark current post
    'c': '#create-topic',                                         // create new topic
    'd': 'article.selected button.delete',                        // delete selected post
    'e': 'article.selected button.edit',                          // edit selected post

    // star topic
    'f': '#topic-footer-buttons button.star, #topic-list tr.topic-list-item.selected a.star',

    'l': 'article.selected button.like',                          // like selected post
    'm m': 'div.notification-options li[data-id="0"] a',          // mark topic as muted
    'm r': 'div.notification-options li[data-id="1"] a',          // mark topic as regular
    'm t': 'div.notification-options li[data-id="2"] a',          // mark topic as tracking
    'm w': 'div.notification-options li[data-id="3"] a',          // mark topic as watching
    'n': '#user-notifications',                                   // open notifictions menu
    'o,enter': '#topic-list tr.topic-list-item.selected a.title', // open selected topic
    'r': '#topic-footer-buttons button.create',                   // reply to topic
    'R': 'article.selected button.create',                        // reply to selected post
    's': '#topic-footer-buttons button.share',                    // share topic
    'S': 'article.selected button.share',                         // share selected post
    '/': '#search-button',                                        // focus search
    '!': 'article.selected button.flag'                           // flag selected post
  },

  FUNCTION_BINDINGS: {
    'j': 'selectDown',
    'k': 'selectUp',
    'u': 'goBack',
    '`': 'nextSection',
    '~': 'prevSection',
    '?': 'showHelpModal'                                          // open keyboard shortcut help
  },

  bindEvents: function(keyTrapper) {
    this.keyTrapper = keyTrapper;
    _.each(this.PATH_BINDINGS, this._bindToPath, this);
    _.each(this.CLICK_BINDINGS, this._bindToClick, this);
    _.each(this.FUNCTION_BINDINGS, this._bindToFunction, this);
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

  showHelpModal: function() {
    Discourse.__container__.lookup('controller:application').send("showKeyboardShortcutsHelp");
  },

  _bindToPath: function(path, binding) {
    this.keyTrapper.bind(binding, function() {
      Discourse.URL.routeTo(path);
    });
  },

  _bindToClick: function(selector, binding) {
    binding = binding.split(',');
    this.keyTrapper.bind(binding, function(e) {
      if (!_.isUndefined(e) && _.isFunction(e.preventDefault)) {
        e.preventDefault();
      }

      $(selector).click();
    });
  },

  _bindToFunction: function(func, binding) {
    if (typeof this[func] === 'function') {
      this.keyTrapper.bind(binding, _.bind(this[func], this));
    }
  },

  _moveSelection: function(num) {
    var $articles = this._findArticles();

    if (typeof $articles === 'undefined') {
      return;
    }

    var $selected = $articles.filter('.selected'),
        index = $articles.index($selected),
        $article = $articles.eq(index + num);

    if ($article.size() > 0) {
      $articles.removeClass('selected');
      $article.addClass('selected');
      this._scrollList($article);
    }
  },

  _scrollList: function($article) {
    var $body = $('body'),
        distToElement = $article.position().top + $article.height() - $(window).height() - $body.scrollTop();

    $('html, body').scrollTop($body.scrollTop() + distToElement);
  },

  _findArticles: function() {
    var $topicList = $('#topic-list'),
        $topicArea = $('.posts-wrapper');

    if ($topicArea.size() > 0) {
      return $topicArea.find('.topic-post');
    }
    else if ($topicList.size() > 0) {
      return $topicList.find('.topic-list-item');
    }
  },

  _changeSection: function(num) {
    var $sections = $('#navigation-bar').find('li'),
        index = $sections.index('.active');

    $sections.eq(index + num).find('a').click();
  }
});
