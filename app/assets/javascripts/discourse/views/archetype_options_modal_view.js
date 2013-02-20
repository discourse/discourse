(function() {

  window.Discourse.ArchetypeOptionsModalView = window.Discourse.ModalBodyView.extend({
    templateName: 'modal/archetype_options',
    title: Em.String.i18n('topic.options')
  });

}).call(this);
