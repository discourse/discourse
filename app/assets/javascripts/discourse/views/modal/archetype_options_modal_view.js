/**
  This view handles rendering of options for an archetype

  @class ArchetypeOptionsModalView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
window.Discourse.ArchetypeOptionsModalView = window.Discourse.ModalBodyView.extend({
  templateName: 'modal/archetype_options',
  title: Em.String.i18n('topic.options')
});


