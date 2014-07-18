export default Discourse.GroupedView.extend({
  classNames: ['archetype-option'],
  composerControllerBinding: 'Discourse.router.composerController',
  templateName: "modal/option_boolean",

  _checkedChanged: function() {
    var metaData = this.get('parentView.metaData');
    metaData.set(this.get('content.key'), this.get('checked') ? 'true' : 'false');
    this.get('controller.controllers.composer').saveDraft();
  }.observes('checked')
});
