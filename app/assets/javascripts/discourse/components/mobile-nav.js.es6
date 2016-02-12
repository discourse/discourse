export default Ember.Component.extend({

  _init: function(){
    if (!this.get('site.mobileView')) {
      var classes = this.get('desktopClass');
      if (classes) {
        classes = classes.split(' ');
        this.set('classNames', classes);
      }
    }
  }.on('init'),

  tagName: 'ul',

  classNames: ['mobile-nav'],

  currentPathChanged: function(){
    this.set('expanded', false);
    Em.run.next(() => this._updateSelectedHtml());
  }.observes('currentPath'),

  _updateSelectedHtml(){
    const active = this.$('.active');
    if (active && active.html) {
      this.set('selectedHtml', active.html());
    }
  },

  didInsertElement(){
    this._updateSelectedHtml();
  },

  actions: {
    toggleExpanded(){
      this.toggleProperty('expanded');
    }
  }
});
