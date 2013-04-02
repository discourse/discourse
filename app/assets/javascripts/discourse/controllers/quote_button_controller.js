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

  // If the buffer is cleared, clear out other state (post)
  bufferChanged: (function() {
    if (this.blank('buffer')) this.set('post', null);
  }).observes('buffer'),

  selectText: function(e) {
    // anonymous users cannot "quote-reply"
    if (!Discourse.get('currentUser')) return;
    // there is no need to display the "quote-reply" button if we can't create a post
    if (!this.get('controllers.topic.content.can_create_post')) return;

    // retrieve the selected range
    var range = window.getSelection().getRangeAt(0).cloneRange();

    // do not be present the "quote reply" button if you select text spanning two posts
    // this basically look for the first "DIV" container...
    var commonDivAncestorContainer = range.commonAncestorContainer;
    while (commonDivAncestorContainer.nodeName !== 'DIV') commonDivAncestorContainer = commonDivAncestorContainer.parentNode;
    // ... and check it has the 'cooked' class (which indicates we're in a post)
    if (commonDivAncestorContainer.className.indexOf('cooked') === -1) return;

    var selectedText = Discourse.Utilities.selectedText();
    if (this.get('buffer') === selectedText) return;
    if (this.get('lastSelected') === selectedText) return;

    this.set('post', e.context);
    this.set('buffer', selectedText);

    // collapse the range at the beginning of the selection
    // (ie. moves the end point to the start point)
    range.collapse(true);

    // create a marker element containing a single invisible character
    var markerElement = document.createElement("span");
    markerElement.appendChild(document.createTextNode("\ufeff"));
    // insert it at the beginning of our range
    range.insertNode(markerElement);

    // find marker position (cf. http://www.quirksmode.org/js/findpos.html)
    var obj = markerElement, left = 0, top = 0;
    do {
      left += obj.offsetLeft;
      top += obj.offsetTop;
      obj = obj.offsetParent;
    } while (obj.offsetParent);

    // move the quote button at the beginning of the selection
    var $quoteButton = $('.quote-button');
    $quoteButton.css({ top: top - $quoteButton.outerHeight(), left: left });

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
  }

});
