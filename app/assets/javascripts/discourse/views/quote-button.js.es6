// we don't want to deselect when we click on buttons that use it
function ignoreElements(e) {
  const $target = $(e.target);
  return $target.hasClass('quote-button') ||
         $target.closest('.create').length ||
         $target.closest('.reply-new').length;
}

export default Ember.View.extend({
  classNames: ['quote-button'],
  classNameBindings: ['visible'],
  isMouseDown: false,
  isTouchInProgress: false,

  /**
    The button is visible whenever there is something in the buffer
    (ie. something has been selected)
  **/
  visible: Em.computed.notEmpty('controller.buffer'),

  render(buffer) {
    buffer.push(I18n.t("post.quote_reply"));
  },

  /**
    Binds to the following global events:
      - `mousedown` to clear the quote button if they click elsewhere.
      - `mouseup` to trigger the display of the quote button.
      - `selectionchange` to make the selection work under iOS

    @method didInsertElement
  **/
  didInsertElement() {
    const controller = this.get('controller'),
          view = this;

    var onSelectionChanged = function() {
      view.selectText(window.getSelection().anchorNode, controller);
    };

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

    $(document)
      .on("mousedown.quote-button", function(e) {
        view.set('isMouseDown', true);

        if (ignoreElements(e)) { return; }

        // deselects only when the user left click
        // (allows anyone to `extend` their selection using shift+click)
        if (!window.getSelection().isCollapsed &&
            e.which === 1 &&
            !e.shiftKey) controller.deselectText();
      })
      .on('mouseup.quote-button', function(e) {
        if (ignoreElements(e)) { return; }

        view.selectText(e.target, controller);
        view.set('isMouseDown', false);
      })
      .on('selectionchange', function() {
        // there is no need to handle this event when the mouse is down
        // or if there a touch in progress
        if (view.get('isMouseDown') || view.get('isTouchInProgress')) return;
        // `selection.anchorNode` is used as a target
        onSelectionChanged();
      });

      // Android is dodgy, touchend often will not fire
      // https://code.google.com/p/android/issues/detail?id=19827
      if (!isAndroid) {
        $(document)
          .on('touchstart.quote-button', function(){
            view.set('isTouchInProgress', true);
          })
          .on('touchend.quote-button', function(){
            view.set('isTouchInProgress', false);
          });
      }
  },

  selectText(target, controller) {
    const $target = $(target);
    // breaks if quoting has been disabled by the user
    if (!Discourse.User.currentProp('enable_quoting')) return;
    // retrieve the post id from the DOM
    const postId = $target.closest('.boxed, .reply').data('post-id');
    // select the text
    if (postId) controller.selectText(postId);
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
    return this.get('controller').quoteText(e);
  }

});
