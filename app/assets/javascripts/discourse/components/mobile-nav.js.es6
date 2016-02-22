import { on, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({

  @on('init')
  _init() {
    if (!this.get('site.mobileView')) {
      var classes = this.get('desktopClass');
      if (classes) {
        classes = classes.split(' ');
        this.set('classNames', classes);
      }
    }
  },

  tagName: 'ul',

  classNames: ['mobile-nav'],

  @observes('currentPath')
  currentPathChanged() {
    this.set('expanded', false);
    Em.run.next(() => this._updateSelectedHtml());
  },

  _updateSelectedHtml(){
    const active = this.$('.active');
    if (active && active.html) {
      this.set('selectedHtml', active.html());
    }
  },

  didInsertElement() {
    this._updateSelectedHtml();
  },

  @on('didInsertElement')
  _bindClick() {
    this.$().on("click.mobile-nav", 'ul li', () => {
      this.set('expanded', false);
    });
  },

  @on('willDestroyElement')
  _unbindClick() {
    this.$().off("click.mobile-nav", 'ul li');
  },

  actions: {
    toggleExpanded(){
      this.toggleProperty('expanded');
    }
  }
});
