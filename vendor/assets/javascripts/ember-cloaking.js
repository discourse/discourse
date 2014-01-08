(function () {

  /**
    Display a list of cloaked items

    @class CloakedContainerView
    @extends Ember.View
    @namespace Ember
  **/
  Ember.CloakedCollectionView = Ember.CollectionView.extend({
    topVisible: null,
    bottomVisible: null,

    init: function() {
      var cloakView = this.get('cloakView'),
          idProperty = this.get('idProperty') || 'id';

      // Set the slack ratio differently to allow for more or less slack in preloading
      var slackRatio = parseFloat(this.get('slackRatio'));
      if (!slackRatio) { this.set('slackRatio', 1.0); }

      this.set('itemViewClass', Ember.CloakedView.extend({
        classNames: [cloakView + '-cloak'],
        cloaks: cloakView,
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
      var childViews = this.get('childViews');
      if ((!childViews) || (childViews.length === 0)) { return; }

      var toUncloak = [],
          $w = $(window),
          windowHeight = window.innerHeight ? window.innerHeight : $w.height(),
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

    scrollTriggered: function() {
      Em.run.scheduleOnce('afterRender', this, 'scrolled');
    },

    didInsertElement: function() {
      var self = this,
          onScrollMethod = function() {
            Ember.run.debounce(self, 'scrollTriggered', 10);
          };

      $(document).bind('touchmove.ember-cloak', onScrollMethod);
      $(window).bind('scroll.ember-cloak', onScrollMethod);
    },

    willDestroyElement: function() {
      $(document).bind('touchmove.ember-cloak');
      $(window).bind('scroll.ember-cloak');
    }

  });


  /**
    A cloaked view is one that removes its content when scrolled off the screen

    @class CloakedView
    @extends Ember.View
    @namespace Ember
  **/
  Ember.CloakedView = Ember.View.extend({
    attributeBindings: ['style'],

    init: function() {
      this._super();
      this.uncloak();
    },

    /**
      Triggers the set up for rendering a view that is cloaked.

      @method uncloak
    */
    uncloak: function() {
      var containedView = this.get('containedView');
      if (!containedView) {

        this.setProperties({
          style: null,
          loading: false,
          containedView: this.createChildView(this.get('cloaks'), {content: this.get('content') })
        });

        this.rerender();
      }
    },

    /**
      Removes the view from the DOM and tears down all observers.

      @method cloak
    */
    cloak: function() {
      var containedView = this.get('containedView'),
          self = this;

      if (containedView && this.get('state') === 'inDOM') {
        var style = 'height: ' + this.$().height() + 'px;';
        this.set('style', style);
        this.$().prop('style', style);

        // We need to remove the container after the height of the element has taken
        // effect.
        Ember.run.schedule('afterRender', function() {
          self.set('containedView', null);
          containedView.willDestroyElement();
          containedView.remove();
        });
      }
    },


    /**
      Render the cloaked view if applicable.

      @method render
    */
    render: function(buffer) {
      var containedView = this.get('containedView');
      if (containedView && containedView.get('state') !== 'inDOM') {
        containedView.renderToBuffer(buffer);
        containedView.transitionTo('inDOM');
        Em.run.schedule('afterRender', function() {
          containedView.didInsertElement();
        });
      }
    }

  });



  Ember.Handlebars.registerHelper('cloaked-collection', function(options) {
    var hash = options.hash,
        types = options.hashTypes;

    for (var prop in hash) {
      if (types[prop] === 'ID') {
        hash[prop + 'Binding'] = hash[prop];
        delete hash[prop];
      }
    }
    return Ember.Handlebars.helpers.view.call(this, Ember.CloakedCollectionView, options);
  });

})();
