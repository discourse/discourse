/**
  Display a list of cloaked items

  @class CloakedContainerView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.CloakedCollectionView = Ember.CollectionView.extend(Discourse.Scrolling, {
  topVisible: null,
  bottomVisible: null,

  init: function() {
    var cloakView = this.get('cloakView'),
        idProperty = this.get('idProperty') || 'id';

    this.set('slackRatio', Discourse.Capabilities.currentProp('slackRatio'));
    this.set('itemViewClass', Discourse.CloakedView.extend({
      classNames: [cloakView + '-cloak'],
      cloaks: Em.String.classify(cloakView) + 'View',
      defaultHeight: this.get('defaultHeight') || 100,

      init: function() {
        this._super();
        this.set('elementId', cloakView + '-cloak-' + this.get('content.' + idProperty));
      }
    }));

    this._super();
    Ember.run.next(this, 'scrolled');
  },

  /**
    If the topmost visible view changed, we will notify the controller if it has an appropriate hook.

    @method _topVisibleChanged
    @observes topVisible
  **/
  _topVisibleChanged: function() {
    var controller = this.get('controller');
    if (controller.topVisibleChanged) { controller.topVisibleChanged(this.get('topVisible')); }
  }.observes('topVisible'),

  /**
    If the bottommost visible view changed, we will notify the controller if it has an appropriate hook.

    @method _bottomVisible
    @observes bottomVisible
  **/
  _bottomVisible: function() {
    var controller = this.get('controller');
    if (controller.bottomVisibleChanged) { controller.bottomVisibleChanged(this.get('bottomVisible')); }
  }.observes('bottomVisible'),

  /**
    Binary search for finding the topmost view on screen.

    @method findTopView
    @param {Array} childViews the childViews to search through
    @param {Number} windowTop The top of the viewport to search against
    @param {Number} min The minimum index to search through of the child views
    @param {Number} max The max index to search through of the child views
    @returns {Number} the index into childViews of the topmost view
  **/
  findTopView: function(childViews, viewportTop, min, max) {
    if (max < min) { return min; }

    var mid = Math.floor((min + max) / 2),
        $view = childViews[mid].$(),
        viewBottom = $view.offset().top + $view.height();

    if (viewBottom > viewportTop) {
      return this.findTopView(childViews, viewportTop, min, mid-1);
    } else {
      return this.findTopView(childViews, viewportTop, mid+1, max);
    }
  },

  /**
    Determine what views are onscreen and cloak/uncloak them as necessary.

    @method scrolled
  **/
  scrolled: function() {
    var childViews = this.get('childViews'),
        toUncloak = [],
        $w = $(window),
        windowHeight = $w.height(),
        windowTop = $w.scrollTop(),
        slack = Math.round(windowHeight * this.get('slackRatio')),
        viewportTop = windowTop - slack,
        windowBottom = windowTop + windowHeight,
        viewportBottom = windowBottom + slack,
        topView = this.findTopView(childViews, viewportTop, 0, childViews.length-1),
        bodyHeight = $('body').height(),
        bottomView = topView,
        onscreen = [];

    if (windowBottom > bodyHeight) { windowBottom = bodyHeight; }
    if (viewportBottom > bodyHeight) { viewportBottom = bodyHeight; }

    // Find the bottom view and what's onscreen
    while (bottomView < childViews.length) {
      var view = childViews[bottomView],
        $view = view.$(),
        viewTop = $view.offset().top,
        viewBottom = viewTop + $view.height();

      if (viewTop > viewportBottom) { break; }
      toUncloak.push(view);

      if (viewBottom > windowTop && viewTop <= windowBottom) {
        onscreen.push(view.get('content'));
      }

      bottomView++;
    }
    if (bottomView >= childViews.length) { bottomView = childViews.length - 1; }

    // If our controller has a `sawObjects` method, pass the on screen objects to it.
    var controller = this.get('controller');
    if (onscreen.length) {
      this.setProperties({topVisible: onscreen[0], bottomVisible: onscreen[onscreen.length-1]});
      if (controller && controller.sawObjects) {
        Em.run.schedule('afterRender', function() {
          controller.sawObjects(onscreen);
        });
      }
    } else {
      this.setProperties({topVisible: null, bottomVisible: null});
    }

    var toCloak = childViews.slice(0, topView).concat(childViews.slice(bottomView+1)),
        loadingView = childViews[bottomView + 1];

    Em.run.schedule('afterRender', function() {
      toUncloak.forEach(function (v) { v.uncloak(); });
      toCloak.forEach(function (v) { v.cloak(); });
    });

    for (var j=bottomView; j<childViews.length; j++) {
      var checkView = childViews[j];
      if (!checkView.get('containedView')) {
        if (!checkView.get('loading')) {
          checkView.$().html("<div class='spinner'>" + I18n.t('loading') + "</div>");
        }
        return;
      }
    }

  },

  didInsertElement: function() {
    this.bindScrolling({debounce: 10});
  },

  willDestroyElement: function() {
    this.unbindScrolling();
  }

});


Discourse.View.registerHelper('cloaked-collection', Discourse.CloakedCollectionView);