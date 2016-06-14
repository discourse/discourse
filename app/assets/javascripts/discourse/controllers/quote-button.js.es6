import Quote from 'discourse/lib/quote';
import computed from 'ember-addons/ember-computed-decorators';
import { selectedText } from 'discourse/lib/utilities';

export default Ember.Controller.extend({
  needs: ['topic', 'composer'],

  @computed('buffer', 'postId')
  post(buffer, postId) {
    if (!postId || Ember.isEmpty(buffer)) { return null; }

    const postStream = this.get('controllers.topic.model.postStream');
    const post = postStream.findLoadedPost(postId);

    return post;
  },

  // Save the currently selected text and displays the
  //  "quote reply" button
  selectText(postId) {
    // anonymous users cannot "quote-reply"
    if (!this.currentUser) return;

    // don't display the "quote-reply" button if we can't reply
    const topicDetails = this.get('controllers.topic.model.details');
    if (!(topicDetails.get('can_reply_as_new_topic') || topicDetails.get('can_create_post'))) {
      return;
    }

    const selection = window.getSelection();

     // no selections
    if (selection.isCollapsed) {
      this.set('buffer', '');
      return;
    }

    // retrieve the selected range
    const range = selection.getRangeAt(0),
          cloned = range.cloneRange(),
          $ancestor = $(range.commonAncestorContainer);

    if ($ancestor.closest('.cooked').length === 0) {
      this.set('buffer', '');
      return;
    }

    const selVal = selectedText();
    if (this.get('buffer') === selVal) return;

    // we need to retrieve the post data from the posts collection in the topic controller
    this.set('postId', postId);
    this.set('buffer', selVal);

    // create a marker element
    const markerElement = document.createElement("span");
    // containing a single invisible character
    markerElement.appendChild(document.createTextNode("\ufeff"));

    const isMobileDevice = this.site.isMobileDevice;
    const capabilities = this.capabilities,
          isIOS = capabilities.isIOS,
          isAndroid = capabilities.isAndroid;

    // collapse the range at the beginning/end of the selection
    range.collapse(!isMobileDevice);
    // and insert it at the start of our selection range
    range.insertNode(markerElement);

    // retrieve the position of the marker
    const markerOffset = $(markerElement).offset(),
          $quoteButton = $('.quote-button');

    // remove the marker
    markerElement.parentNode.removeChild(markerElement);

    // work around Chrome that would sometimes lose the selection
    const sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(cloned);

    // move the quote button above the marker
    Em.run.schedule('afterRender', function() {
      let topOff = markerOffset.top;
      let leftOff = markerOffset.left;

      if (isMobileDevice || isIOS || isAndroid) {
        topOff = topOff + 20;
        leftOff = Math.min(leftOff + 10, $(window).width() - $quoteButton.outerWidth());
      } else {
        topOff = topOff - $quoteButton.outerHeight() - 5;
      }

      $quoteButton.offset({ top: topOff, left: leftOff });
    });
  },

  quoteText() {
    const Composer = require('discourse/models/composer').default;
    const postId = this.get('postId');
    const post = this.get('post');

    // defer load if needed, if in an expanded replies section
    if (!post) {
      const postStream = this.get('controllers.topic.model.postStream');
      return postStream.loadPost(postId).then(p => {
        this.set('post', p);
        return this.quoteText();
      });
    }

    // If we can't create a post, delegate to reply as new topic
    if (!this.get('controllers.topic.model.details.can_create_post')) {
      this.get('controllers.topic').send('replyAsNewTopic', post);
      return;
    }

    const composerController = this.get('controllers.composer');
    const composerOpts = {
      action: Composer.REPLY,
      draftKey: post.get('topic.draft_key')
    };

    if (post.get('post_number') === 1) {
      composerOpts.topic = post.get("topic");
    } else {
      composerOpts.post = post;
    }

    // If the composer is associated with a different post, we don't change it.
    const composerPost = composerController.get('content.post');
    if (composerPost && (composerPost.get('id') !== this.get('post.id'))) {
      composerOpts.post = composerPost;
    }

    const buffer = this.get('buffer');
    const quotedText = Quote.build(post, buffer);
    composerOpts.quote = quotedText;
    if (composerController.get('content.viewOpen') || composerController.get('content.viewDraft')) {
      this.appEvents.trigger('composer:insert-text', quotedText);
    } else {
      composerController.open(composerOpts);
    }
    this.set('buffer', '');
    return false;
  },

  deselectText() {
    // clear selected text
    window.getSelection().removeAllRanges();
    // clean up the buffer
    this.set('buffer', '');
  }

});
