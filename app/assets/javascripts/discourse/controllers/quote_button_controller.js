/*global assetPath:true */

/**
  This controller supports the pop up quote button

  @class QuoteButtonController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.QuoteButtonController = Discourse.Controller.extend({
  needs: ['topic', 'composer'],

  init: function() {
    this._super();
    $LAB.script(assetPath('defer/html-sanitizer-bundle'));
  },

  /**
    If the buffer is cleared, clear out other state (post)
  **/
  bufferChanged: function() {
    if (this.blank('buffer')) this.set('post', null);
  }.observes('buffer'),

  /**
    Save the currently selected text and displays the
    "quote reply" button

    @method selectText
  **/
  selectText: function(postId) {
    // anonymous users cannot "quote-reply"
    if (!Discourse.get('currentUser')) return;
    // don't display the "quote-reply" button if we can't create a post
    if (!this.get('controllers.topic.content.can_create_post')) return;

    var selection = window.getSelection();
    // no selections
    if (selection.rangeCount === 0) return;
    // retrieve the selected range
    var range = selection.getRangeAt(0),
        cloned = range.cloneRange(),
        $ancestor = $(range.commonAncestorContainer);

    // don't display the "quote reply" button if you select text spanning two posts
    // note: the ".contents" is here to prevent selection of the topic summary
    if ($ancestor.closest('.topic-body > .contents').length === 0) {
      this.set('buffer', '');
      return;
    }

    var selectedText = Discourse.Utilities.selectedText();
    if (this.get('buffer') === selectedText) return;

    // we need to retrieve the post data from the posts collection in the topic controller
    var posts = this.get('controllers.topic.posts'),
        length = posts.length,
        post;

    for (var p = 0; p < length; p++) {
      if (posts[p].id === postId) { post = posts[p]; break; }
    }

    this.set('post', post);
    this.set('buffer', selectedText);

    // collapse the range at the beginning of the selection
    // (ie. moves the end point to the start point)
    range.collapse(true);

    // create a marker element containing a single invisible character
    var markerElement = document.createElement("span");
    markerElement.appendChild(document.createTextNode("\ufeff"));
    // insert it at the beginning of our range
    range.insertNode(markerElement);

    // work around chrome that would sometimes lose the selection
    var sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(cloned);

    // move the quote button at the beginning of the selection
    var markerOffset = $(markerElement).offset(),
        $quoteButton = $('.quote-button');

    Em.run.next(function(){
      $quoteButton.offset({
        top: markerOffset.top - $quoteButton.outerHeight() - 5,
        left: markerOffset.left
      });
    });

    // remove the marker
    markerElement.parentNode.removeChild(markerElement);
  },

  /**
    Quote the currently selected text

    @method quoteText
  **/
  quoteText: function() {
    var post = this.get('post');
    var composerController = this.get('controllers.composer');
    var composerOpts = {
      post: post,
      action: Discourse.Composer.REPLY,
      draftKey: this.get('post.topic.draft_key')
    };

    // If the composer is associated with a different post, we don't change it.
    var composerPost = composerController.get('content.post');
    if (composerPost && (composerPost.get('id') !== this.get('post.id'))) {
      composerOpts.post = composerPost;
    }

    var buffer = this.get('buffer');
    var quotedText = Discourse.BBCode.buildQuoteBBCode(post, buffer);
    if (composerController.wouldLoseChanges()) {
      composerController.appendText(quotedText);
    } else {
      composerController.open(composerOpts).then(function() {
        return composerController.appendText(quotedText);
      });
    }
    this.set('buffer', '');
    return false;
  },

  /**
    Deselect the currently selected text

    @method deselectText
  **/
  deselectText: function() {
    // clear selected text
    window.getSelection().removeAllRanges();
    // clean up the buffer
    this.set('buffer', '');
  }

});
