(function () {

  /**
    Display a list of cloaked items

    @class CloakedCollectionView
    @extends Ember.CollectionView
    @namespace Ember
  **/
  Ember.CloakedCollectionView = Ember.CollectionView.extend({
    topVisible: null,
    bottomVisible: null,
    offsetFixedElement: null,

    init: function() {
      var cloakView = this.get('cloakView'),
          idProperty = this.get('idProperty');

      // Set the slack ratio differently to allow for more or less slack in preloading
      var slackRatio = parseFloat(this.get('slackRatio'));
      if (!slackRatio) { this.set('slackRatio', 1.0); }

      this.set('itemViewClass', Ember.CloakedView.extend({
        classNames: [cloakView + '-cloak'],
        cloaks: cloakView,
        preservesContext: this.get('preservesContext') === "true",
        cloaksController: this.get('itemController'),
        defaultHeight: this.get('defaultHeight'),

        init: function() {
          this._super();

          if (idProperty) {
            this.set('elementId', cloakView + '-cloak-' + this.get('content.' + idProperty));
          }
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
          // in case of not full-window scrolling
          scrollOffset = this.get('wrapperTop') >> 0,
          $view = childViews[mid].$(),
          viewBottom = $view.position().top + scrollOffset + $view.height();

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
      if (!this.get('scrollingEnabled')) { return; }

      var childViews = this.get('childViews');
      if ((!childViews) || (childViews.length === 0)) { return; }

      var toUncloak = [],
          onscreen = [],
          // calculating viewport edges
          $w = $(window),
          windowHeight = this.get('wrapperHeight') || ( window.innerHeight ? window.innerHeight : $w.height() ),
          windowTop = this.get('wrapperTop') || $w.scrollTop(),
          slack = Math.round(windowHeight * this.get('slackRatio')),
          viewportTop = windowTop - slack,
          windowBottom = windowTop + windowHeight,
          viewportBottom = windowBottom + slack,
          topView = this.findTopView(childViews, viewportTop, 0, childViews.length-1),
          bodyHeight = this.get('wrapperHeight') ? this.$().height() : $('body').height(),
          bottomView = topView,
          offsetFixedElement = this.get('offsetFixedElement');

      if (windowBottom > bodyHeight) { windowBottom = bodyHeight; }
      if (viewportBottom > bodyHeight) { viewportBottom = bodyHeight; }

      if (offsetFixedElement) {
        windowTop += (offsetFixedElement.outerHeight(true) || 0);
      }
      // Find the bottom view and what's onscreen
      while (bottomView < childViews.length) {
        var view = childViews[bottomView],
          $view = view.$(),
          // in case of not full-window scrolling
          scrollOffset = this.get('wrapperTop') >> 0,
          viewTop = $view.position().top + scrollOffset,
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

      var toCloak = childViews.slice(0, topView).concat(childViews.slice(bottomView+1));
      Em.run.schedule('afterRender', function() {
        toUncloak.forEach(function (v) { v.uncloak(); });
        toCloak.forEach(function (v) { v.cloak(); });
      });

      for (var j=bottomView; j<childViews.length; j++) {
        var checkView = childViews[j];
        if (!checkView.get('containedView')) {
          if (!checkView.get('loading')) {
            checkView.$().html(this.get('loadingHTML') || "Loading...");
          }
          return;
        }
      }

    },

    scrollTriggered: function() {
      Em.run.scheduleOnce('afterRender', this, 'scrolled');
    },

    _startEvents: function() {
      var self = this,
          offsetFixed = this.get('offsetFixed'),
          onScrollMethod = function() {
            Ember.run.debounce(self, 'scrollTriggered', 10);
          };

      if (offsetFixed) {
        this.set('offsetFixedElement', $(offsetFixed));
      }

      $(document).bind('touchmove.ember-cloak', onScrollMethod);
      $(window).bind('scroll.ember-cloak', onScrollMethod);
      this.addObserver('wrapperTop', self, onScrollMethod);
      this.addObserver('wrapperHeight', self, onScrollMethod);
      this.addObserver('content.@each', self, onScrollMethod);
      this.scrollTriggered();

      this.set('scrollingEnabled', true);
    }.on('didInsertElement'),

    cleanUp: function() {
      $(document).unbind('touchmove.ember-cloak');
      $(window).unbind('scroll.ember-cloak');
      this.set('scrollingEnabled', false);
    },

    _endEvents: function() {
      this.cleanUp();
    }.on('willDestroyElement')
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
      this.cloak();
    },

    /**
      Triggers the set up for rendering a view that is cloaked.

      @method uncloak
    */
    uncloak: function() {
      var containedView = this.get('containedView');
      if (!containedView) {
        var model = this.get('content'),
            controller = null,
            container = this.get('container');

        // Wire up the itemController if necessary
        var controllerName = this.get('cloaksController');
        if (controllerName) {
          var controllerFullName = 'controller:' + controllerName,
              factory = container.lookupFactory(controllerFullName),
              parentController = this.get('controller');

          // let ember generate controller if needed
          if (factory === undefined) {
            factory = Ember.generateControllerFactory(container, controllerName, model);

            // inform developer about typo
            Ember.Logger.warn('ember-cloaking: can\'t lookup controller by name "' + controllerFullName + '".');
            Ember.Logger.warn('ember-cloaking: using ' + factory.toString() + '.');
          }

          controller = factory.create({
            model: model,
            parentController: parentController,
            target: parentController
          });
        }

        var createArgs = {},
            target = controller || model;

        if (this.get('preservesContext')) {
          createArgs.content = target;
        } else {
          createArgs.context = target;
        }
        if (controller) { createArgs.controller = controller; }
        this.setProperties({
          style: null,
          loading: false,
          containedView: this.createChildView(this.get('cloaks'), createArgs)
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


    didInsertElement: function(){
      if (!this.get('containedView')) {
        // setting default height
        // but do not touch if height already defined
        if(!this.$().height()){
          var defaultHeight = 100;
          if(this.get('defaultHeight')) {
            defaultHeight = this.get('defaultHeight');
          }

          this.$().css('height', defaultHeight);
        }
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
