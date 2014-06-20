/**
  This view handles rendering of a link to share something on a
  third-party site.

  @class ShareLinkView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
export default Ember.View.extend({
  templateName: 'share_link',
  tagName: 'div',
  classNameBindings: [':social-link']
});
