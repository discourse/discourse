import computed from 'ember-addons/ember-computed-decorators';
import { selectedText } from 'discourse/lib/utilities';

// we don't want to deselect when we click on buttons that use it
function willQuote(e) {
  const $target = $(e.target);
  return $target.hasClass('quote-button') || $target.closest('.create, .share, .reply-new').length;
}

export default Ember.Component.extend({
  classNames: ['quote-button'],
  classNameBindings: ['visible'],

  @computed('quoteState.buffer')
  visible: buffer => buffer && buffer.length > 0,

  _isMouseDown: false,

  _selectionChanged() {
    const selection = window.getSelection();
    if (selection.isCollapsed) {
      if (this.get("visible")) this.sendAction("deselectText");
      return;
    }

    // ensure we selected content inside 1 post *only*
    let firstRange, postId;
    for (let r = 0; r < selection.rangeCount; r++) {
      const range = selection.getRangeAt(r);
      const $ancestor = $(range.commonAncestorContainer);

      firstRange = firstRange || range;
      postId = postId || $ancestor.closest('.boxed, .reply').data('post-id');

      if ($ancestor.closest(".contents").length === 0 || !postId) {
        if (this.get("visible")) this.sendAction("deselectText");
        return;
      }
    }

    this.get("quoteState").setProperties({ postId, buffer: selectedText() });

    // on Desktop, shows the button at the beginning of the selection
    // on Mobile, shows the button at the end of the selection
    const isMobileDevice = this.site.isMobileDevice;
    const { isIOS, isAndroid } = this.capabilities;
    const showAtEnd = isMobileDevice || isIOS || isAndroid;

    // create a marker element containing a single invisible character
    const markerElement = document.createElement("span");
    markerElement.appendChild(document.createTextNode("\ufeff"));

    // on mobile, collapse the range at the end of the selection
    if (showAtEnd) { firstRange.collapse(); }
    // insert the marker
    firstRange.insertNode(markerElement);

    // retrieve the position of the marker
    const $markerElement = $(markerElement);
    const markerOffset = $markerElement.offset();
    const parentScrollLeft = $markerElement.parent().scrollLeft();
    const $quoteButton = this.$();

    // remove the marker
    markerElement.parentNode.removeChild(markerElement);

    // change the position of the button
    Ember.run.scheduleOnce("afterRender", () => {
      let top = markerOffset.top;
      let left = markerOffset.left + Math.max(0, parentScrollLeft);

      if (showAtEnd) {
        top = top + 20;
        left = Math.min(left + 10, $(window).width() - $quoteButton.outerWidth());
      } else {
        top = top - $quoteButton.outerHeight() - 5;
      }

      $quoteButton.offset({ top, left });
    });

  },

  didInsertElement() {
    const { isWinphone, isAndroid } = this.capabilities;
    const wait = (isWinphone || isAndroid) ? 250 : 25;
    const onSelectionChanged = _.debounce(() => this._selectionChanged(), wait);

    $(document).on("mousedown.quote-button", (e) => {
      this._isMouseDown = true;
      if (!willQuote(e)) {
        this.sendAction("deselectText");
      }
    }).on("mouseup.quote-button", () => {
      this._isMouseDown = false;
      onSelectionChanged();
    }).on("selectionchange.quote-button", () => {
      if (!this._isMouseDown) {
        onSelectionChanged();
      }
    });
  },

  willDestroyElement() {
    $(document).off("mousedown.quote-button")
               .off("mouseup.quote-button")
               .off("selectionchange.quote-button");
  },

  click() {
    this.sendAction("selectText");
    return false;
  }
});
