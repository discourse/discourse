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
  started: null,

  init: function() {
    this._super();
    $LAB.script(assetPath('defer/html-sanitizer-bundle'));
  },

  // If the buffer is cleared, clear out other state (post)
  bufferChanged: (function() {
    if (this.blank('buffer')) {
      return this.set('post', null);
    }
  }).observes('buffer'),

  mouseDown: function(e) {
    this.started = [e.pageX, e.pageY];
  },

  mouseUp: function(e) {
    if (this.started[1] > e.pageY) {
      this.started = [e.pageX, e.pageY];
    }
  },

  selectText: function(e) {
    var $quoteButton, left, selectedText, top;
    if (!Discourse.get('currentUser')) return;
    if (!this.get('controllers.topic.content.can_create_post')) return;

    selectedText = Discourse.Utilities.selectedText();
    if (this.get('buffer') === selectedText) return;
    if (this.get('lastSelected') === selectedText) return;

    this.set('post', e.context);
    this.set('buffer', selectedText);
    top = e.pageY + 5;
    left = e.pageX + 5;
    $quoteButton = $('.quote-button');
    if (this.started) {
      top = this.started[1] - 50;
      left = ((left - this.started[0]) / 2) + this.started[0] - ($quoteButton.width() / 2);
    }
    $quoteButton.css({ top: top, left: left });
    this.started = null;
    return false;
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
