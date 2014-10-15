export default Ember.TextField.extend({
  becomeFocused: function() {
    var input = this.get("element");
    input.focus();
    input.selectionStart = input.selectionEnd = input.value.length;
  }.on('didInsertElement')
});
