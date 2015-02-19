import ObjectController from 'discourse/controllers/object';

// The basic controller for a group
export default ObjectController.extend({
  counts: null,

  // It would be nice if bootstrap marked action lists as selected when their links
  // were 'active' not the `li` tags.
  showingIndex: Em.computed.equal('showing', 'index'),
  showingMembers: Em.computed.equal('showing', 'members')
});

