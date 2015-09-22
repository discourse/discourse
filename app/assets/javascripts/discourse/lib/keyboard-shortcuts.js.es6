import DiscourseURL from 'discourse/lib/url';

const bindings = {
  '!':               {postAction: 'showFlags'},
  '#':               {handler: 'toggleProgress', anonymous: true},
  '/':               {handler: 'showSearch', anonymous: true},
  '=':               {handler: 'toggleHamburgerMenu', anonymous: true},
  '?':               {handler: 'showHelpModal', anonymous: true},
  '.':               {click: '.alert.alert-info.clickable', anonymous: true}, // show incoming/updated topics
  'b':               {handler: 'toggleBookmark'},
  'c':               {handler: 'createTopic'},
  'ctrl+f':          {handler: 'showBuiltinSearch', anonymous: true},
  'command+f':       {handler: 'showBuiltinSearch', anonymous: true},
  'd':               {postAction: 'deletePost'},
  'e':               {postAction: 'editPost'},
  'end':             {handler: 'goToLastPost', anonymous: true},
  'f':               {handler: 'toggleBookmarkTopic'},
  'g h':             {path: '/', anonymous: true},
  'g l':             {path: '/latest', anonymous: true},
  'g n':             {path: '/new'},
  'g u':             {path: '/unread'},
  'g c':             {path: '/categories', anonymous: true},
  'g t':             {path: '/top', anonymous: true},
  'g b':             {path: '/bookmarks'},
  'g p':             {path: '/my/activity'},
  'g m':             {path: '/my/messages'},
  'home':            {handler: 'goToFirstPost', anonymous: true},
  'j':               {handler: 'selectDown', anonymous: true},
  'k':               {handler: 'selectUp', anonymous: true},
  'l':               {click: '.topic-post.selected button[data-action="like"]'},
  'm m':             {click: 'div.notification-options li[data-id="0"] a'}, // mark topic as muted
  'm r':             {click: 'div.notification-options li[data-id="1"] a'}, // mark topic as regular
  'm t':             {click: 'div.notification-options li[data-id="2"] a'}, // mark topic as tracking
  'm w':             {click: 'div.notification-options li[data-id="3"] a'}, // mark topic as watching
  'o,enter':         {click: '.topic-list tr.selected a.title', anonymous: true}, // open selected topic
  'p':               {handler: 'showCurrentUser'},
  'q':               {handler: 'quoteReply'},
  'r':               {postAction: 'replyToPost'},
  's':               {click: '.topic-post.selected a.post-date', anonymous: true}, // share post
  'shift+j':         {handler: 'nextSection', anonymous: true},
  'shift+k':         {handler: 'prevSection', anonymous: true},
  'shift+p':         {handler: 'pinUnpinTopic'},
  'shift+r':         {handler: 'replyToTopic'},
  'shift+s':         {click: '#topic-footer-buttons button.share', anonymous: true}, // share topic
  'shift+z shift+z': {handler: 'logout'},
  't':               {postAction: 'replyAsNewTopic'},
  'u':               {handler: 'goBack', anonymous: true},
  'x r':             {click: '#dismiss-new,#dismiss-new-top,#dismiss-posts,#dismiss-posts-top'}, // dismiss new/posts
  'x t':             {click: '#dismiss-topics,#dismiss-topics-top'} // dismiss topics
};


export default {
  bindEvents(keyTrapper, container) {
    this.keyTrapper = keyTrapper;
    this.container = container;
    this._stopCallback();

    this.searchService = this.container.lookup('search-service:main');
    this.appEvents = this.container.lookup('app-events:main');
    this.currentUser = this.container.lookup('current-user:main');

    Object.keys(bindings).forEach(key => {
      const binding = bindings[key];
      if (!binding.anonymous && !this.currentUser) { return; }

      if (binding.path) {
        this._bindToPath(binding.path, key);
      } else if (binding.handler) {
        this._bindToFunction(binding.handler, key);
      } else if (binding.postAction) {
        this._bindToSelectedPost(binding.postAction, key);
      } else if (binding.click) {
        this._bindToClick(binding.click, key);
      }
    });
  },

  toggleBookmark() {
    this.sendToSelectedPost('toggleBookmark');
    this.sendToTopicListItemView('toggleBookmark');
  },

  toggleBookmarkTopic() {
    const topic = this.currentTopic();
    // BIG hack, need a cleaner way
    if (topic && $('.posts-wrapper').length > 0) {
      topic.toggleBookmark();
    } else {
      this.sendToTopicListItemView('toggleBookmark');
    }
  },

  logout() {
    this.container.lookup('route:application').send('logout');
  },

  quoteReply() {
    $('.topic-post.selected button.create').click();
    // lazy but should work for now
    setTimeout(function() {
      $('#wmd-quote-post').click();
    }, 500);
  },

  goToFirstPost() {
    this._jumpTo('jumpTop');
  },

  goToLastPost() {
    this._jumpTo('jumpBottom');
  },

  _jumpTo(direction) {
    if ($('.container.posts').length) {
      this.container.lookup('controller:topic-progress').send(direction);
    }
  },

  replyToTopic() {
    this.container.lookup('controller:topic').send('replyToPost');
  },

  selectDown() {
    this._moveSelection(1);
  },

  selectUp() {
    this._moveSelection(-1);
  },

  goBack() {
    history.back();
  },

  nextSection() {
    this._changeSection(1);
  },

  prevSection() {
    this._changeSection(-1);
  },

  showBuiltinSearch() {
    this.searchService.set('searchContextEnabled', false);

    const currentPath = this.container.lookup('controller:application').get('currentPath'),
          blacklist = [ /^discovery\.categories/ ],
          whitelist = [ /^topic\./ ],
          check = function(regex) { return !!currentPath.match(regex); };
    let showSearch = whitelist.any(check) && !blacklist.any(check);

    // If we're viewing a topic, only intercept search if there are cloaked posts
    if (showSearch && currentPath.match(/^topic\./)) {
      showSearch = $('.cooked').length < this.container.lookup('controller:topic').get('model.postStream.stream.length');
    }

    if (showSearch) {
      this.searchService.set('searchContextEnabled', true);
      this.showSearch();
      return false;
    }

    return true;
  },

  createTopic() {
    this.container.lookup('controller:composer').open({action: Discourse.Composer.CREATE_TOPIC, draftKey: Discourse.Composer.CREATE_TOPIC});
  },

  pinUnpinTopic() {
    this.container.lookup('controller:topic').togglePinnedState();
  },

  toggleProgress() {
    this.container.lookup('controller:topic-progress').send('toggleExpansion', {highlight: true});
  },

  showSearch() {
    this.container.lookup('controller:header').send('toggleSearch');
    return false;
  },

  toggleHamburgerMenu() {
    this.container.lookup('controller:header').send('toggleMenuPanel', 'hamburgerVisible');
  },

  showCurrentUser() {
    this.container.lookup('controller:header').send('toggleMenuPanel', 'userMenuVisible');
  },

  showHelpModal() {
    this.container.lookup('controller:application').send('showKeyboardShortcutsHelp');
  },

  sendToTopicListItemView(action) {
    const elem = $('tr.selected.topic-list-item.ember-view')[0];
    if (elem) {
      const view = Ember.View.views[elem.id];
      view.send(action);
    }
  },

  currentTopic() {
    const topicController = this.container.lookup('controller:topic');
    if (topicController) {
      const topic = topicController.get('model');
      if (topic) {
        return topic;
      }
    }
  },

  sendToSelectedPost(action) {
    const container = this.container;
    // TODO: We should keep track of the post without a CSS class
    const selectedPostId = parseInt($('.topic-post.selected article.boxed').data('post-id'), 10);
    if (selectedPostId) {
      const topicController = container.lookup('controller:topic'),
          post = topicController.get('model.postStream.posts').findBy('id', selectedPostId);
      if (post) {
        topicController.send(action, post);
      }
    }
  },

  _bindToSelectedPost(action, binding) {
    this.keyTrapper.bind(binding, () => this.sendToSelectedPost(action));
  },

  _bindToPath(path, key) {
    this.keyTrapper.bind(key, () => DiscourseURL.routeTo(path));
  },

  _bindToClick(selector, binding) {
    binding = binding.split(',');
    this.keyTrapper.bind(binding, function(e) {
      const $sel = $(selector);

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

  _bindToFunction(func, binding) {
    if (typeof this[func] === 'function') {
      this.keyTrapper.bind(binding, _.bind(this[func], this));
    }
  },

  _moveSelection(direction) {
    const $articles = this._findArticles();

    if (typeof $articles === 'undefined') {
      return;
    }

    const $selected = $articles.filter('.selected');
    let index = $articles.index($selected);

    if ($selected.length !== 0) { //boundries check
      // loop is not allowed
      if (direction === -1 && index === 0) { return; }
      if (direction === 1 && index === ($articles.size()-1) ) { return; }
    }

    // if nothing is selected go to the first post on screen
    if ($selected.length === 0) {
      const scrollTop = $(document).scrollTop();

      index = 0;
      $articles.each(function() {
        const top = $(this).position().top;
        if (top > scrollTop) {
          return false;
        }
        index += 1;
      });

      if (index >= $articles.length) {
        index = $articles.length - 1;
      }

      direction = 0;
    }

    const $article = $articles.eq(index + direction);

    if ($article.size() > 0) {

      $articles.removeClass('selected');
      $article.addClass('selected');

      if ($article.is('.topic-list-item')) {
        this.sendToTopicListItemView('select');
      }

      if ($article.is('.topic-post')) {
        let tabLoc = $article.find('a.tabLoc');
        if (tabLoc.length === 0) {
          tabLoc = $('<a href class="tabLoc"></a>');
          $article.prepend(tabLoc);
        }
        tabLoc.focus();
      }

      this._scrollList($article, direction);
    }
  },

  _scrollList($article) {
    // Try to keep the article on screen
    const pos = $article.offset();
    const height = $article.height();
    const scrollTop = $(window).scrollTop();
    const windowHeight = $(window).height();

    // skip if completely on screen
    if (pos.top > scrollTop && (pos.top + height) < (scrollTop + windowHeight)) {
      return;
    }

    let scrollPos = (pos.top + (height/2)) - (windowHeight * 0.5);
    if (scrollPos < 0) { scrollPos = 0; }

    if (this._scrollAnimation) {
      this._scrollAnimation.stop();
    }
    this._scrollAnimation = $("html, body").animate({ scrollTop: scrollPos + "px"}, 100);
  },


  _findArticles() {
    const $topicList = $('.topic-list'),
        $topicArea = $('.posts-wrapper');

    if ($topicArea.size() > 0) {
      return $('.posts-wrapper .topic-post, .topic-list tbody tr');
    }
    else if ($topicList.size() > 0) {
      return $topicList.find('.topic-list-item');
    }
  },

  _changeSection(direction) {
    const $sections = $('#navigation-bar li'),
        active = $('#navigation-bar li.active'),
        index = $sections.index(active) + direction;

    if (index >= 0 && index < $sections.length) {
      $sections.eq(index).find('a').click();
    }
  },

  _stopCallback() {
    const oldStopCallback = this.keyTrapper.stopCallback;

    this.keyTrapper.stopCallback = function(e, element, combo) {
      if ((combo === 'ctrl+f' || combo === 'command+f') && element.id === 'search-term') {
        return false;
      }

      return oldStopCallback(e, element, combo);
    };
  }
};
