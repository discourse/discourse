/**
  A modal view for displaying the options for a topic archetype

  @class OptionBooleanView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.OptionBooleanView = Discourse.GroupedView.extend({
  classNames: ['archetype-option'],
  composerControllerBinding: 'Discourse.router.composerController',
  templateName: "modal/option_boolean",

  checkedChanged: (function() {
    var metaData;
    metaData = this.get('parentView.metaData');
    metaData.set(this.get('content.key'), this.get('checked') ? 'true' : 'false');
    return this.get('controller.controllers.composer').saveDraft();
  }).observes('checked')

});


