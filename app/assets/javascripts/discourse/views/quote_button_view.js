/**
  This view is used for rendering the pop-up quote button

  @class QuoteButtonView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.QuoteButtonView = Discourse.View.extend({
  classNames: ['quote-button'],
  classNameBindings: ['visible'],
  isMouseDown: false,

  /**
    Determines whether the pop-up quote button should be visible.
    The button is visible whenever there is something in the buffer
    (ie. something has been selected)

    @property visible
  **/
  visible: function() {
    return this.present('controller.buffer');
  }.property('controller.buffer'),

  /**
    Renders the pop-up quote button.

    @method render
  **/
  render: function(buffer) {
    buffer.push('<i class="icon-quote-right"></i>&nbsp;&nbsp;');
    buffer.push(Em.String.i18n("post.quote_reply"));
  },

  /**
    Binds to the following global events:
      - `mousedown` to clear the quote button if they click elsewhere.
      - `mouseup` to trigger the display of the quote button.
      - `selectionchange` to make the selection work under iOS

    @method didInsertElement
  **/
  didInsertElement: function() {
    var controller = this.get('controller'),
        view = this;

    $(document)
    .on("mousedown.quote-button", function(e) {
      view.set('isMouseDown', true);
      if ($(e.target).hasClass('quote-button') || $(e.target).hasClass('create')) return;
      // deselects only when the user left-click
      // this also allow anyone to `extend` their selection using a shift+click
      if (e.which === 1 && !e.shiftKey) controller.deselectText();
    })
    .on('mouseup.quote-button', function(e) {
      view.selectText(e.target, controller);
      view.set('isMouseDown', false);
    })
    .on('selectionchange', function() {
      // there is no need to handle this event when the mouse is down
      if (view.get('isMouseDown')) return;
      // `selection.anchorNode` is used as a target
      view.selectText(window.getSelection().anchorNode, controller);
    });
  },

  /**
    Selects the text

    @method selectText
  **/
  selectText: function(target, controller) {
    var $target = $(target);
    // quoting as been disabled by the user
    if (!Discourse.get('currentUser.enable_quoting')) return;
    // retrieve the post id from the DOM
    var postId = $target.closest('.boxed').data('post-id');
    // select the text
    if (postId) controller.selectText(postId);
  },

  /**
    Unbinds from global `mouseup, mousedown, selectionchange` events

    @method willDestroyElement
  **/
  willDestroyElement: function() {
    $(document)
    .off("mousedown.quote-button")
    .off("mouseup.quote-button")
    .off("selectionchange");
  },

  /**
    Quote the selected text when clicking on the quote button.

    @method click
  **/
  click: function(e) {
    e.stopPropagation();
    return this.get('controller').quoteText(e);
  }

});
