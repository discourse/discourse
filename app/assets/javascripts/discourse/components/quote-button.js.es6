import computed from 'ember-addons/ember-computed-decorators';
import { selectedText } from 'discourse/lib/utilities';

// we don't want to deselect when we click on buttons that use it
function ignoreElements(e) {
  const $target = $(e.target);
  return $target.hasClass('quote-button') ||
         $target.closest('.create').length ||
         $target.closest('.reply-new').length ||
         $target.closest('.share').length;
}

export default Ember.Component.extend({
  classNames: ['quote-button'],
  classNameBindings: ['visible'],
  isMouseDown: false,
  _isTouchInProgress: false,

  @computed('quoteState.buffer')
  visible: buffer => buffer && buffer.length > 0,

  /**
    Binds to the following global events:
      - `mousedown` to clear the quote button if they click elsewhere.
      - `mouseup` to trigger the display of the quote button.
      - `selectionchange` to make the selection work under iOS

    @method didInsertElement
  **/
  didInsertElement() {
    let onSelectionChanged = () => this._selectText(window.getSelection().anchorNode);

    // Windows Phone hack, it is not firing the touch events
    // best we can do is debounce this so we dont keep locking up
    // the selection when we add the caret to measure where we place
    // the quote reply widget
    //
    // Same hack applied to Android cause it has unreliable touchend
    const isAndroid = this.capabilities.isAndroid;
    if (this.capabilities.isWinphone || isAndroid) {
      onSelectionChanged = _.debounce(onSelectionChanged, 500);
    }

    $(document).on("mousedown.quote-button", e => {
      this.set('isMouseDown', true);

      if (ignoreElements(e)) { return; }

      // deselects only when the user left click
      // (allows anyone to `extend` their selection using shift+click)
      if (!window.getSelection().isCollapsed &&
          e.which === 1 &&
          !e.shiftKey) {
        this.sendAction('deselectText');
      }
    }).on('mouseup.quote-button', e => {
      this.set('isMouseDown', false);
      if (ignoreElements(e)) { return; }

      this._selectText(e.target);
    }).on('selectionchange', () => {
      // there is no need to handle this event when the mouse is down
      // or if there a touch in progress
      if (this.get('isMouseDown') || this._isTouchInProgress) { return; }
      // `selection.anchorNode` is used as a target
      onSelectionChanged();
    });

    // Android is dodgy, touchend often will not fire
    // https://code.google.com/p/android/issues/detail?id=19827
    if (!isAndroid) {
      $(document).on('touchstart.quote-button', () => {
        this._isTouchInProgress = true;
        return true;
      });

      $(document).on('touchend.quote-button', () => {
        this._isTouchInProgress = false;
        return true;
      });
    }
  },

  _selectText(target) {
    // anonymous users cannot "quote-reply"
    if (!this.currentUser) return;

    const quoteState = this.get('quoteState');

    const $target = $(target);
    const postId = $target.closest('.boxed, .reply').data('post-id');

    const details = this.get('topic.details');
    if (!(details.get('can_reply_as_new_topic') || details.get('can_create_post'))) {
      return;
    }

    const selection = window.getSelection();
    if (selection.isCollapsed) {
      return;
    }

    const range = selection.getRangeAt(0),
          cloned = range.cloneRange(),
          $ancestor = $(range.commonAncestorContainer);

    if ($ancestor.closest('.cooked').length === 0) {
      return this.sendAction('deselectText');
    }

    const selVal = selectedText();
    if (quoteState.get('buffer') === selVal) { return; }
    quoteState.setProperties({ postId, buffer: selVal });

    // create a marker element containing a single invisible character
    const markerElement = document.createElement("span");
    markerElement.appendChild(document.createTextNode("\ufeff"));

    const isMobileDevice = this.site.isMobileDevice;
    const capabilities = this.capabilities;
    const isIOS = capabilities.isIOS;
    const isAndroid = capabilities.isAndroid;

    // collapse the range at the beginning/end of the selection
    // and insert it at the start of our selection range
    range.collapse(!isMobileDevice);
    range.insertNode(markerElement);

    // retrieve the position of the marker
    const $markerElement = $(markerElement);
    const markerOffset = $markerElement.offset();
    const parentScrollLeft = $markerElement.parent().scrollLeft();
    const $quoteButton = this.$();

    // remove the marker
    markerElement.parentNode.removeChild(markerElement);

    // work around Chrome that would sometimes lose the selection
    const sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(cloned);

    Ember.run.scheduleOnce('afterRender', function() {
      let topOff = markerOffset.top;
      let leftOff = markerOffset.left;

      if (parentScrollLeft > 0) leftOff += parentScrollLeft;

      if (isMobileDevice || isIOS || isAndroid) {
        topOff = topOff + 20;
        leftOff = Math.min(leftOff + 10, $(window).width() - $quoteButton.outerWidth());
      } else {
        topOff = topOff - $quoteButton.outerHeight() - 5;
      }

      $quoteButton.offset({ top: topOff, left: leftOff });
    });
  },

  willDestroyElement() {
    $(document)
      .off("mousedown.quote-button")
      .off("mouseup.quote-button")
      .off("touchstart.quote-button")
      .off("touchend.quote-button")
      .off("selectionchange");
  },

  click(e) {
    e.stopPropagation();
    this.sendAction('selectText');
  }
});
