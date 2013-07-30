// used to render a div with unescaped contents

Discourse.RawDivView = Ember.View.extend({

  shouldRerender: Discourse.View.renderIfChanged('content'),

  render: function(buffer) {
    buffer.push(this.get('content'));
  }

});
