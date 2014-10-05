/**
  A helper view to display a preview of the pagedown content

  @class PagedownPreviewView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
export default Discourse.View.extend({
  elementId: 'wmd-preview',
  classNameBindings: [':preview', 'hidden'],
  hidden: Em.computed.empty('parentView.value')
});
