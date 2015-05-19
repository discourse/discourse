// TODO: remove unused: false
/* jshint unused: false*/
import Ember from 'ember';
import ReusableListItemView from './reusable-list-item-view';

var get     = Ember.get;
var set     = Ember.set;
var min     = Math.min;
var max     = Math.max;
var floor   = Math.floor;
var ceil    = Math.ceil;
var forEach = Ember.ArrayPolyfills.forEach;

function addContentArrayObserver() {
  var content = get(this, 'content');
  if (content) {
    content.addArrayObserver(this);
  }
}

function removeAndDestroy(object) {
  this.removeObject(object);
  object.destroy();
}

function syncChildViews() {
  Ember.run.once(this, '_syncChildViews');
}

function sortByContentIndex (viewOne, viewTwo) {
  return get(viewOne, 'contentIndex') - get(viewTwo, 'contentIndex');
}

function removeEmptyView() {
  var emptyView = get(this, 'emptyView');
  if (emptyView && emptyView instanceof Ember.View) {
    emptyView.removeFromParent();
    if (this.totalHeightDidChange !== undefined) {
        this.totalHeightDidChange();
    }
  }
}

function addEmptyView() {
  var emptyView = get(this, 'emptyView');

  if (!emptyView) {
    return;
  }

  if ('string' === typeof emptyView) {
    emptyView = get(emptyView) || emptyView;
  }

  emptyView = this.createChildView(emptyView);
  set(this, 'emptyView', emptyView);

  if (Ember.CoreView.detect(emptyView)) {
    this._createdEmptyView = emptyView;
  }

  this.unshiftObject(emptyView);
}

function enableProfilingOutput() {
  function before(name, time/*, payload*/) {
    console.time(name);
  }

  function after (name, time/*, payload*/) {
    console.timeEnd(name);
  }

  if (Ember.ENABLE_PROFILING) {
    Ember.subscribe('view._scrollContentTo', {
      before: before,
      after: after
    });
    Ember.subscribe('view.updateContext', {
      before: before,
      after: after
    });
  }
}

/**
  @class Ember.ListViewMixin
  @namespace Ember
*/
export default Ember.Mixin.create({
  itemViewClass: ReusableListItemView,
  emptyViewClass: Ember.View,
  classNames: ['ember-list-view'],
  attributeBindings: ['style'],
  classNameBindings: ['_isGrid:ember-list-view-grid:ember-list-view-list'],
  scrollTop: 0,
  bottomPadding: 0, // TODO: maybe this can go away
  _lastEndingIndex: 0,
  paddingCount: 1,
  _cachedPos: 0,

  _isGrid: Ember.computed.gt('columnCount', 1).readOnly(),

  /**
    @private

    Setup a mixin.
    - adding observer to content array
    - creating child views based on height and length of the content array

    @method init
  */
  init: function() {
    this._super();
    this._cachedHeights = [0];
    this.on('didInsertElement', this._syncListContainerWidth);
    this.columnCountDidChange();
    this._syncChildViews();
    this._addContentArrayObserver();
  },

  _addContentArrayObserver: Ember.beforeObserver(function() {
    addContentArrayObserver.call(this);
  }, 'content'),

  /**
    Called on your view when it should push strings of HTML into a
    `Ember.RenderBuffer`.

    Adds a [div](https://developer.mozilla.org/en-US/docs/HTML/Element/div)
    with a required `ember-list-container` class.

    @method render
    @param {Ember.RenderBuffer} buffer The render buffer
  */
  render: function (buffer) {
    var element          = buffer.element();
    var dom              = buffer.dom;
    var container        = dom.createElement('div');
    container.className  = 'ember-list-container';
    element.appendChild(container);

    this._childViewsMorph = dom.appendMorph(container, container, null);

    return container;
  },

  createChildViewsMorph: function (element) {
    this._childViewsMorph = this._renderer._dom.createMorph(element.lastChild, element.lastChild, null);
    return element;
  },

  willInsertElement: function() {
    if (!this.get('height') || !this.get('rowHeight')) {
      throw new Error('A ListView must be created with a height and a rowHeight.');
    }
    this._super();
  },

  /**
    @private

    Sets inline styles of the view:
    - height
    - width
    - position
    - overflow
    - -webkit-overflow
    - overflow-scrolling

    Called while attributes binding.

    @property {Ember.ComputedProperty} style
  */
  style: Ember.computed('height', 'width', function() {
    var height, width, style, css;

    height = get(this, 'height');
    width = get(this, 'width');
    css = get(this, 'css');

    style = '';

    if (height) {
      style += 'height:' + height + 'px;';
    }

    if (width)  {
      style += 'width:' + width  + 'px;';
    }

    for ( var rule in css ) {
      if (css.hasOwnProperty(rule)) {
        style += rule + ':' + css[rule] + ';';
      }
    }

    return Ember.String.htmlSafe(style);
  }),

  /**
    @private

    Performs visual scrolling. Is overridden in Ember.ListView.

    @method scrollTo
  */
  scrollTo: function(y) {
    throw new Error('must override to perform the visual scroll and effectively delegate to _scrollContentTo');
  },

  /**
    @private

    Internal method used to force scroll position

    @method scrollTo
  */
  _scrollTo: Ember.K,

  /**
    @private
    @method _scrollContentTo
  */
  _scrollContentTo: function(y) {
    var startingIndex, endingIndex,
        contentIndex, visibleEndingIndex, maxContentIndex,
        contentIndexEnd, contentLength, scrollTop, content;

    scrollTop = max(0, y);

    if (this.scrollTop === scrollTop) {
      return;
    }

    // allow a visual overscroll, but don't scroll the content. As we are doing needless
    // recycyling, and adding unexpected nodes to the DOM.
    var maxScrollTop = max(0, get(this, 'totalHeight') - get(this, 'height'));
    scrollTop = min(scrollTop, maxScrollTop);

    content = get(this, 'content');
    contentLength = get(content, 'length');
    startingIndex = this._startingIndex(contentLength);

    Ember.instrument('view._scrollContentTo', {
      scrollTop: scrollTop,
      content: content,
      startingIndex: startingIndex,
      endingIndex: min(max(contentLength - 1, 0), startingIndex + this._numChildViewsForViewport())
    }, function () {
      this.scrollTop = scrollTop;

      maxContentIndex = max(contentLength - 1, 0);

      startingIndex = this._startingIndex();
      visibleEndingIndex = startingIndex + this._numChildViewsForViewport();

      endingIndex = min(maxContentIndex, visibleEndingIndex);

      if (startingIndex === this._lastStartingIndex &&
          endingIndex === this._lastEndingIndex) {

        this.trigger('scrollYChanged', y);
        return;
      } else {

        Ember.run(this, function() {
          this._reuseChildren();

          this._lastStartingIndex = startingIndex;
          this._lastEndingIndex = endingIndex;
          this.trigger('scrollYChanged', y);
        });
      }
    }, this);

  },

  /**
    @private

    Computes the height for a `Ember.ListView` scrollable container div.
    You must specify `rowHeight` parameter for the height to be computed properly.

    @property {Ember.ComputedProperty} totalHeight
  */
  totalHeight: Ember.computed('content.length',
                              'rowHeight',
                              'columnCount',
                              'bottomPadding', function() {
    if (typeof this.heightForIndex === 'function') {
      return this._totalHeightWithHeightForIndex();
    } else {
      return this._totalHeightWithStaticRowHeight();
   }
  }),

  _doRowHeightDidChange: function() {
    this._cachedHeights = [0];
    this._cachedPos = 0;
    this._syncChildViews();
  },

  _rowHeightDidChange: Ember.observer('rowHeight', function() {
    Ember.run.once(this, this._doRowHeightDidChange);
  }),

  _totalHeightWithHeightForIndex: function() {
    var length = this.get('content.length');
    return this._cachedHeightLookup(length);
  },

  _totalHeightWithStaticRowHeight: function() {
    var contentLength, rowHeight, columnCount, bottomPadding;

    contentLength = get(this, 'content.length');
    rowHeight = get(this, 'rowHeight');
    columnCount = get(this, 'columnCount');
    bottomPadding = get(this, 'bottomPadding');

    return ((ceil(contentLength / columnCount)) * rowHeight) + bottomPadding;
  },

  /**
    @private
    @method _prepareChildForReuse
  */
  _prepareChildForReuse: function(childView) {
    childView.prepareForReuse();
  },

  createChildView: function (_view) {
    return this._super(_view, this._itemViewProps || {});
  },

  /**
    @private
    @method _reuseChildForContentIndex
  */
  _reuseChildForContentIndex: function(childView, contentIndex) {
    var content, context, newContext, childsCurrentContentIndex, position, enableProfiling, oldChildView;

    var contentViewClass = this.itemViewForIndex(contentIndex);

    if (childView.constructor !== contentViewClass) {
      // rather then associative arrays, lets move childView + contentEntry maping to a Map
      var i = this._childViews.indexOf(childView);
      childView.destroy();
      childView = this.createChildView(contentViewClass);
      this.insertAt(i, childView);
    }

    content         = get(this, 'content');
    enableProfiling = get(this, 'enableProfiling');
    position        = this.positionForIndex(contentIndex);
    childView.updatePosition(position);

    set(childView, 'contentIndex', contentIndex);

    if (enableProfiling) {
      Ember.instrument('view._reuseChildForContentIndex', position, function() {

      }, this);
    }

    newContext = content.objectAt(contentIndex);
    childView.updateContext(newContext);
  },

  /**
    @private
    @method positionForIndex
  */
  positionForIndex: function(index) {
    if (typeof this.heightForIndex !== 'function') {
      return this._singleHeightPosForIndex(index);
    }
    else {
      return this._multiHeightPosForIndex(index);
    }
  },

  _singleHeightPosForIndex: function(index) {
    var elementWidth, width, columnCount, rowHeight, y, x;

    elementWidth = get(this, 'elementWidth') || 1;
    width = get(this, 'width') || 1;
    columnCount = get(this, 'columnCount');
    rowHeight = get(this, 'rowHeight');

    y = (rowHeight * floor(index/columnCount));
    x = (index % columnCount) * elementWidth;

    return {
      y: y,
      x: x
    };
  },

  // 0 maps to 0, 1 maps to heightForIndex(i)
  _multiHeightPosForIndex: function(index) {
    var elementWidth, width, columnCount, rowHeight, y, x;

    elementWidth = get(this, 'elementWidth') || 1;
    width = get(this, 'width') || 1;
    columnCount = get(this, 'columnCount');

    x = (index % columnCount) * elementWidth;
    y = this._cachedHeightLookup(index);

    return {
      x: x,
      y: y
    };
  },

  _cachedHeightLookup: function(index) {
    for (var i = this._cachedPos; i < index; i++) {
      this._cachedHeights[i + 1] = this._cachedHeights[i] + this.heightForIndex(i);
    }
    this._cachedPos = i;
    return this._cachedHeights[index];
  },

  /**
    @private
    @method _childViewCount
  */
  _childViewCount: function() {
    var contentLength, childViewCountForHeight;

    contentLength = get(this, 'content.length');
    childViewCountForHeight = this._numChildViewsForViewport();

    return min(contentLength, childViewCountForHeight);
  },

  /**
    @private

    Returns a number of columns in the Ember.ListView (for grid layout).

    If you want to have a multi column layout, you need to specify both
    `width` and `elementWidth`.

    If no `elementWidth` is specified, it returns `1`. Otherwise, it will
    try to fit as many columns as possible for a given `width`.

    @property {Ember.ComputedProperty} columnCount
  */
  columnCount: Ember.computed('width', 'elementWidth', function() {
    var elementWidth, width, count;

    elementWidth = get(this, 'elementWidth');
    width = get(this, 'width');

    if (elementWidth && width > elementWidth) {
      count = floor(width / elementWidth);
    } else {
      count = 1;
    }

    return count;
  }),

  /**
    @private

    Fires every time column count is changed.

    @event columnCountDidChange
  */
  columnCountDidChange: Ember.observer(function() {
    var ratio, currentScrollTop, proposedScrollTop, maxScrollTop,
        scrollTop, lastColumnCount, newColumnCount, element;

    lastColumnCount = this._lastColumnCount;

    currentScrollTop = this.scrollTop;
    newColumnCount = get(this, 'columnCount');
    maxScrollTop = get(this, 'maxScrollTop');
    element = this.element;

    this._lastColumnCount = newColumnCount;

    if (lastColumnCount) {
      ratio = (lastColumnCount / newColumnCount);
      proposedScrollTop = currentScrollTop * ratio;
      scrollTop = min(maxScrollTop, proposedScrollTop);

      this._scrollTo(scrollTop);
      this.scrollTop = scrollTop;
    }

    if (arguments.length > 0) {
      // invoked by observer
      Ember.run.schedule('afterRender', this, this._syncListContainerWidth);
    }
  }, 'columnCount'),

  /**
    @private

    Computes max possible scrollTop value given the visible viewport
    and scrollable container div height.

    @property {Ember.ComputedProperty} maxScrollTop
  */
  maxScrollTop: Ember.computed('height', 'totalHeight', function(){
    var totalHeight, viewportHeight;

    totalHeight = get(this, 'totalHeight');
    viewportHeight = get(this, 'height');

    return max(0, totalHeight - viewportHeight);
  }),

  /**
    @private

    Determines whether the emptyView is the current childView.

    @method _isChildEmptyView
  */
  _isChildEmptyView: function() {
    var emptyView = get(this, 'emptyView');

    return emptyView && emptyView instanceof Ember.View &&
           this._childViews.length === 1 && this._childViews.indexOf(emptyView) === 0;
  },

  /**
    @private

    Computes the number of views that would fit in the viewport area.
    You must specify `height` and `rowHeight` parameters for the number of
    views to be computed properly.

    @method _numChildViewsForViewport
  */
  _numChildViewsForViewport: function() {

    if (this.heightForIndex) {
      return this._numChildViewsForViewportWithMultiHeight();
    } else {
      return this._numChildViewsForViewportWithoutMultiHeight();
    }
  },

  _numChildViewsForViewportWithoutMultiHeight:  function() {
    var height, rowHeight, paddingCount, columnCount;

    height = get(this, 'height');
    rowHeight = get(this, 'rowHeight');
    paddingCount = get(this, 'paddingCount');
    columnCount = get(this, 'columnCount');

    return (ceil(height / rowHeight) * columnCount) + (paddingCount * columnCount);
  },

  _numChildViewsForViewportWithMultiHeight:  function() {
    var rowHeight, paddingCount, columnCount;
    var scrollTop = this.scrollTop;
    var viewportHeight = this.get('height');
    var length = this.get('content.length');
    var heightfromTop = 0;
    var padding = get(this, 'paddingCount');

    var startingIndex = this._calculatedStartingIndex();
    var currentHeight = 0;

    var offsetHeight = this._cachedHeightLookup(startingIndex);
    for (var i = 0; i < length; i++) {
      if (this._cachedHeightLookup(startingIndex + i + 1) - offsetHeight > viewportHeight) {
        break;
      }
    }

    return i + padding + 1;
  },


  /**
    @private

    Computes the starting index of the item views array.
    Takes `scrollTop` property of the element into account.

    Is used in `_syncChildViews`.

    @method _startingIndex
  */
  _startingIndex: function(_contentLength) {
    var scrollTop, rowHeight, columnCount, calculatedStartingIndex,
        contentLength;

    if (_contentLength === undefined) {
      contentLength = get(this, 'content.length');
    } else {
      contentLength = _contentLength;
    }

    scrollTop = this.scrollTop;
    rowHeight = get(this, 'rowHeight');
    columnCount = get(this, 'columnCount');

    if (this.heightForIndex) {
      calculatedStartingIndex = this._calculatedStartingIndex();
    } else {
      calculatedStartingIndex = floor(scrollTop / rowHeight) * columnCount;
    }

    var viewsNeededForViewport = this._numChildViewsForViewport();
    var paddingCount = (1 * columnCount);
    var largestStartingIndex = max(contentLength - viewsNeededForViewport, 0);

    return min(calculatedStartingIndex, largestStartingIndex);
  },

  _calculatedStartingIndex: function() {
    var rowHeight, paddingCount, columnCount;
    var scrollTop = this.scrollTop;
    var viewportHeight = this.get('height');
    var length = this.get('content.length');
    var heightfromTop = 0;
    var padding = get(this, 'paddingCount');

    for (var i = 0; i < length; i++) {
      if (this._cachedHeightLookup(i + 1) >= scrollTop) {
        break;
      }
    }

    return i;
  },

  /**
    @private
    @event contentWillChange
  */
  contentWillChange: Ember.beforeObserver(function() {
    var content = get(this, 'content');

    if (content) {
      content.removeArrayObserver(this);
    }
  }, 'content'),

  /**),
    @private
    @event contentDidChange
  */
  contentDidChange: Ember.observer(function() {
    addContentArrayObserver.call(this);
    syncChildViews.call(this);
  }, 'content'),

  /**
    @private
    @property {Function} needsSyncChildViews
  */
  needsSyncChildViews: Ember.observer(syncChildViews, 'height', 'width', 'columnCount'),

  /**
    @private

    Returns a new item view. Takes `contentIndex` to set the context
    of the returned view properly.

    @param {Number} contentIndex item index in the content array
    @method _addItemView
  */
  _addItemView: function (contentIndex) {
    var itemViewClass, childView;

    itemViewClass = this.itemViewForIndex(contentIndex);
    childView = this.createChildView(itemViewClass);
    this.pushObject(childView);
  },

  /**
    @public

    Returns a view class for the provided contentIndex. If the view is
    different then the one currently present it will remove the existing view
    and replace it with an instance of the class provided

    @param {Number} contentIndex item index in the content array
    @method _addItemView
    @returns {Ember.View} ember view class for this index
  */
  itemViewForIndex: function(contentIndex) {
    return get(this, 'itemViewClass');
  },

  /**
    @public

    Returns a view class for the provided contentIndex. If the view is
    different then the one currently present it will remove the existing view
    and replace it with an instance of the class provided

    @param {Number} contentIndex item index in the content array
    @method _addItemView
    @returns {Ember.View} ember view class for this index
  */
  heightForIndex: null,

  /**
    @private

    Intelligently manages the number of childviews.

    @method _syncChildViews
   **/
  _syncChildViews: function () {
    var childViews, childViewCount,
        numberOfChildViews, numberOfChildViewsNeeded,
        contentIndex, startingIndex, endingIndex,
        contentLength, emptyView, count, delta;

    if (this.isDestroyed || this.isDestroying) {
      return;
    }

    contentLength = get(this, 'content.length');
    emptyView = get(this, 'emptyView');

    childViewCount = this._childViewCount();
    childViews = this.positionOrderedChildViews();

    if (this._isChildEmptyView()) {
      removeEmptyView.call(this);
    }

    startingIndex = this._startingIndex();
    endingIndex = startingIndex + childViewCount;

    numberOfChildViewsNeeded = childViewCount;
    numberOfChildViews = childViews.length;

    delta = numberOfChildViewsNeeded - numberOfChildViews;

    if (delta === 0) {
      // no change
    } else if (delta > 0) {
      // more views are needed
      contentIndex = this._lastEndingIndex;

      for (count = 0; count < delta; count++, contentIndex++) {
        this._addItemView(contentIndex);
      }
    } else {
      // less views are needed
      forEach.call(
        childViews.splice(numberOfChildViewsNeeded, numberOfChildViews),
        removeAndDestroy,
        this
      );
    }

    this._reuseChildren();

    this._lastStartingIndex = startingIndex;
    this._lastEndingIndex   = this._lastEndingIndex + delta;

    if (contentLength === 0 || contentLength === undefined) {
      addEmptyView.call(this);
    }
  },

  /**
    @private

    Applies an inline width style to the list container.

    @method _syncListContainerWidth
   **/
  _syncListContainerWidth: function() {
    var elementWidth, columnCount, containerWidth, element;

    elementWidth = get(this, 'elementWidth');
    columnCount = get(this, 'columnCount');
    containerWidth = elementWidth * columnCount;
    element = this.$('.ember-list-container');

    if (containerWidth && element) {
      element.css('width', containerWidth);
    }
  },

  /**
    @private
    @method _reuseChildren
  */
  _reuseChildren: function(){
    var contentLength, childViews, childViewsLength,
        startingIndex, endingIndex, childView, attrs,
        contentIndex, visibleEndingIndex, maxContentIndex,
        contentIndexEnd, scrollTop;

    scrollTop          = this.scrollTop;
    contentLength      = get(this, 'content.length');
    maxContentIndex    = max(contentLength - 1, 0);
    childViews         = this.getReusableChildViews();
    childViewsLength   =  childViews.length;

    startingIndex      = this._startingIndex();
    visibleEndingIndex = startingIndex + this._numChildViewsForViewport();

    endingIndex        = min(maxContentIndex, visibleEndingIndex);

    contentIndexEnd    = min(visibleEndingIndex, startingIndex + childViewsLength);

    for (contentIndex = startingIndex; contentIndex < contentIndexEnd; contentIndex++) {
      childView = childViews[contentIndex % childViewsLength];
      this._reuseChildForContentIndex(childView, contentIndex);
    }
  },

  /**
    @private
    @method getReusableChildViews
  */
  getReusableChildViews: function() {
    return this._childViews;
  },

  /**
    @private
    @method positionOrderedChildViews
  */
  positionOrderedChildViews: function() {
    return this.getReusableChildViews().sort(sortByContentIndex);
  },

  arrayWillChange: Ember.K,

  /**
    @private
    @event arrayDidChange
  */
  // TODO: refactor
  arrayDidChange: function(content, start, removedCount, addedCount) {
    var index, contentIndex, state;

    if (this._isChildEmptyView()) {
      removeEmptyView.call(this);
    }

    // Support old and new Ember versions
    state = this._state || this.state;

    if (state === 'inDOM') {
      // ignore if all changes are out of the visible change
      if (start >= this._lastStartingIndex || start < this._lastEndingIndex) {
        index = 0;
        // ignore all changes not in the visible range
        // this can re-position many, rather then causing a cascade of re-renders
        forEach.call(
          this.positionOrderedChildViews(),
          function(childView) {
            contentIndex = this._lastStartingIndex + index;
            this._reuseChildForContentIndex(childView, contentIndex);
            index++;
          },
          this
        );
      }

      syncChildViews.call(this);
    }
  },

  destroy: function () {
    if (!this._super()) {
      return;
    }

    if (this._createdEmptyView) {
      this._createdEmptyView.destroy();
    }

    return this;
  }
});
