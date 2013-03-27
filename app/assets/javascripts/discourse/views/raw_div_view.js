// used to render a div with unescaped contents

Discourse.RawDivView = Ember.View.extend({

  render: function(buffer) {
    buffer.push(this.get('content'));
  },

  contentChanged: function() {
    this.rerender();
  }.observes('content')
  
});
