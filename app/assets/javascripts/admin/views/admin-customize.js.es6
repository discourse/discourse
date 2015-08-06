/*global Mousetrap:true */

export default Ember.View.extend({
  classNames: ['customize'],

  _init: function() {
    var controller = this.get('controller');
    Mousetrap.bindGlobal('mod+s', function() {
      controller.send("save");
      return false;
    });
  }.on("didInsertElement"),

  _cleanUp: function() {
    Mousetrap.unbindGlobal('mod+s');
  }.on("willDestroyElement")

});
