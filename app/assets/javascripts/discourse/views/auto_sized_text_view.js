(function() {

  Discourse.AutoSizedTextView = Ember.View.extend({
    render: function(buffer) {
      return null;
    },
    didInsertElement: function(e) {
      var fontSize, lh, lineHeight, me, _results;
      me = this.$();
      me.text(this.get('content'));
      lh = lineHeight = parseInt(me.css("line-height"), 10);
      fontSize = parseInt(me.css("font-size"), 10);
      _results = [];
      while (me.height() > lineHeight && fontSize > 12) {
        fontSize -= 1;
        lh -= 1;
        me.css("font-size", "" + fontSize + "px");
        _results.push(me.css("line-height", "" + lh + "px"));
      }
      return _results;
    }
  });

}).call(this);
