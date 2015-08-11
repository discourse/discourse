export default Ember.CollectionView.extend({
  classNameBindings: [':composer-popup-container', 'hidden'],
  content: Em.computed.alias('controller.content'),

  hidden: Em.computed.not('controller.controllers.composer.model.viewOpen'),

  itemViewClass: Ember.View.extend({
    classNames: ['composer-popup', 'hidden'],
    templateName: Em.computed.alias('content.templateName'),

    _setup: function() {
      this._super();
      this.set('context', this.get('content'));

      if (this.get('content.extraClass')) {
        this.get('classNames').pushObject(this.get('content.extraClass'));
      }
    }.on('init'),

    _initCss: function() {
      var composerHeight = $('#reply-control').height() || 0;
      this.$().css('bottom', composerHeight + "px").show();
    }.on('didInsertElement')
  })
});
