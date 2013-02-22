/**
  This view handles the rendering of an archetype as an option

  @class ArchetypeOptionsView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ArchetypeOptionsView = Em.ContainerView.extend({
  metaDataBinding: 'parentView.metaData',

  init: function() {
    var metaData,
      _this = this;
    this._super();
    metaData = this.get('metaData');
    return this.get('archetype.options').forEach(function(a) {
      var checked;

      if (a.option_type === 1) {
        checked = _this.pushObject(Discourse.OptionBooleanView.create({
          content: a,
          checked: metaData.get(a.key) === 'true'
        }));
      }

    });
  }

});


