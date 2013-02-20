(function() {

  window.Discourse.OptionBooleanView = Em.View.extend({
    classNames: ['archetype-option'],
    composerControllerBinding: 'Discourse.router.composerController',
    templateName: "modal/option_boolean",
    checkedChanged: (function() {
      var metaData;
      metaData = this.get('parentView.metaData');
      metaData.set(this.get('content.key'), this.get('checked') ? 'true' : 'false');
      return this.get('controller.controllers.composer').saveDraft();
    }).observes('checked'),
    init: function() {
      this._super();
      return this.set('context', this.get('content'));
    }
  });

}).call(this);
