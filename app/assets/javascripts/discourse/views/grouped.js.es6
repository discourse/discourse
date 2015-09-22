export default Ember.View.extend({
  _groupInit: function() {
    this.set('context', this.get('content'));

    const templateData = this.get('templateData');
    if (templateData) {
      this.set('templateData.insideGroup', true);
    }
  }.on('init')
});
