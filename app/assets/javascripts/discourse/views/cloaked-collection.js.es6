/*eslint no-bitwise:0 */
const CloakedCollectionView = Ember.CollectionView.extend({
  cloakView: Ember.computed.alias('itemViewClass'),
  topVisible: null,
  bottomVisible: null,
  offsetFixedTopElement: null,
  offsetFixedBottomElement: null,
  loadingHTML: 'Loading...',
  scrollDebounce: 10,

  init() {
    const cloakView = this.get('cloakView'),
          idProperty = this.get('idProperty'),
          uncloakDefault = !!this.get('uncloakDefault');

    // Set the slack ratio differently to allow for more or less slack in preloading
    const slackRatio = parseFloat(this.get('slackRatio'));
    if (!slackRatio) { this.set('slackRatio', 1.0); }

    const CloakedView = this.container.lookupFactory('view:cloaked');
    this.set('itemViewClass', CloakedView.extend({
      classNames: [cloakView + '-cloak'],
      cloaks: cloakView,
      preservesContext: this.get('preservesContext') === 'true',
      cloaksController: this.get('itemController'),
      defaultHeight: this.get('defaultHeight'),

      init() {
        this._super();

        if (idProperty) {
          this.set('elementId', cloakView + '-cloak-' + this.get('content.' + idProperty));
        }
        if (uncloakDefault) {
          this.uncloak();
        } else {
          this.cloak();
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
    const controller = this.get('controller');
    if (controller.topVisibleChanged) { controller.topVisibleChanged(this.get('topVisible')); }
  }.observes('topVisible'),

  /**
    If the bottommost visible view changed, we will notify the controller if it has an appropriate hook.

    @method _bottomVisible
    @observes bottomVisible
  **/
  _bottomVisible: function() {
    const controller = this.get('controller');
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
  findTopView(childViews, viewportTop, min, max) {
    if (max < min) { return min; }

    const wrapperTop = this.get('wrapperTop')>>0;

    while(max>min){
      const mid = Math.floor((min + max) / 2),
          // in case of not full-window scrolling
          $view = childViews[mid].$(),
          viewBottom = $view.position().top + wrapperTop + $view.height();

      if (viewBottom > viewportTop) {
        max = mid-1;
      } else {
        min = mid+1;
      }
    }

    return min;
  },


  /**
    Determine what views are onscreen and cloak/uncloak them as necessary.

    @method scrolled
  **/
  scrolled() {
    if (!this.get('scrollingEnabled')) { return; }

    const childViews = this.get('childViews');
    if ((!childViews) || (childViews.length === 0)) { return; }

    const self = this,
          toUncloak = [],
          onscreen = [],
          onscreenCloaks = [],
          $w = $(window),
          windowHeight = this.get('wrapperHeight') || ( window.innerHeight ? window.innerHeight : $w.height() ),
          slack = Math.round(windowHeight * this.get('slackRatio')),
          offsetFixedTopElement = this.get('offsetFixedTopElement'),
          offsetFixedBottomElement = this.get('offsetFixedBottomElement'),
          bodyHeight = this.get('wrapperHeight') ? this.$().height() : $('body').height();

    let windowTop = this.get('wrapperTop') || $w.scrollTop();

    const viewportTop = windowTop - slack,
          topView = this.findTopView(childViews, viewportTop, 0, childViews.length-1);

    let windowBottom = windowTop + windowHeight,
        viewportBottom = windowBottom + slack;
    if (windowBottom > bodyHeight) { windowBottom = bodyHeight; }
    if (viewportBottom > bodyHeight) { viewportBottom = bodyHeight; }

    if (offsetFixedTopElement) {
      windowTop += (offsetFixedTopElement.outerHeight(true) || 0);
    }

    if (offsetFixedBottomElement) {
      windowBottom -= (offsetFixedBottomElement.outerHeight(true) || 0);
    }

    // Find the bottom view and what's onscreen
    let bottomView = topView;
    while (bottomView < childViews.length) {
      const view = childViews[bottomView],
          $view = view.$();

      if (!$view) { break; }

      // in case of not full-window scrolling
      const scrollOffset = this.get('wrapperTop') || 0,
          viewTop = $view.offset().top + scrollOffset,
          viewBottom = viewTop + $view.height();

      if (viewTop > viewportBottom) { break; }
      toUncloak.push(view);

      if (viewBottom > windowTop && viewTop <= windowBottom) {
        onscreen.push(view.get('content'));
        onscreenCloaks.push(view);
      }

      bottomView++;
    }
    if (bottomView >= childViews.length) { bottomView = childViews.length - 1; }

    // If our controller has a `sawObjects` method, pass the on screen objects to it.
    const controller = this.get('controller');
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

    const toCloak = childViews.slice(0, topView).concat(childViews.slice(bottomView+1));

    this._uncloak = toUncloak;
    if(this._nextUncloak){
      Em.run.cancel(this._nextUncloak);
      this._nextUncloak = null;
    }

    Em.run.schedule('afterRender', this, function() {
      onscreenCloaks.forEach(function (v) {
        if(v && v.uncloak) {
          v.uncloak();
        }
      });
      toCloak.forEach(function (v) { v.cloak(); });
      if (self._nextUncloak) { Em.run.cancel(self._nextUncloak); }
      self._nextUncloak = Em.run.later(self, self.uncloakQueue,50);
    });

    for (let j=bottomView; j<childViews.length; j++) {
      const checkView = childViews[j];
      if (!checkView._containedView) {
        const loadingHTML = this.get('loadingHTML');
        if (!Em.isEmpty(loadingHTML) && !checkView.get('loading')) {
          checkView.$().html(loadingHTML);
        }
        return;
      }
    }
  },

  uncloakQueue() {
    const maxPerRun = 3, delay = 50, self = this;
    let processed = 0;

    if(this._uncloak){
      while(processed < maxPerRun && this._uncloak.length>0){
        const view = this._uncloak.shift();
        if(view && view.uncloak && !view._containedView){
          Em.run.schedule('afterRender', view, view.uncloak);
          processed++;
        }
      }
      if(this._uncloak.length === 0){
        this._uncloak = null;
      } else {
        Em.run.schedule('afterRender', self, function(){
          if(self._nextUncloak){
            Em.run.cancel(self._nextUncloak);
          }
          self._nextUncloak = Em.run.next(self, function(){
            if(self._nextUncloak){
              Em.run.cancel(self._nextUncloak);
            }
            self._nextUncloak = Em.run.later(self,self.uncloakQueue,delay);
          });
        });
      }
    }
  },

  scrollTriggered() {
    if ($('body').data('disable-cloaked-view')) {
      return;
    }
    Em.run.scheduleOnce('afterRender', this, 'scrolled');
  },

  _startEvents: function() {
    if (this.get('offsetFixed')) {
      Em.warn("Cloaked-collection's `offsetFixed` is deprecated. Use `offsetFixedTop` instead.");
    }

    const self = this,
        offsetFixedTop = this.get('offsetFixedTop') || this.get('offsetFixed'),
        offsetFixedBottom = this.get('offsetFixedBottom'),
        scrollDebounce = this.get('scrollDebounce'),
        onScrollMethod = function() {
          Ember.run.debounce(self, 'scrollTriggered', scrollDebounce);
        };

    if (offsetFixedTop) {
      this.set('offsetFixedTopElement', $(offsetFixedTop));
    }

    if (offsetFixedBottom) {
      this.set('offsetFixedBottomElement', $(offsetFixedBottom));
    }

    $(document).bind('touchmove.ember-cloak', onScrollMethod);
    $(window).bind('scroll.ember-cloak', onScrollMethod);
    this.addObserver('wrapperTop', self, onScrollMethod);
    this.addObserver('wrapperHeight', self, onScrollMethod);
    this.addObserver('content.@each', self, onScrollMethod);
    this.scrollTriggered();

    this.set('scrollingEnabled', true);
  }.on('didInsertElement'),

  cleanUp() {
    $(document).unbind('touchmove.ember-cloak');
    $(window).unbind('scroll.ember-cloak');
    this.set('scrollingEnabled', false);
  },

  _endEvents: function() {
    this.cleanUp();
  }.on('willDestroyElement')
});

Ember.Handlebars.helper('cloaked-collection', Ember.testing ? Ember.CollectionView : CloakedCollectionView);
export default CloakedCollectionView;
