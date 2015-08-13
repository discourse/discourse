import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  tagName: 'ul',
  classNameBindings: [':nav', ':nav-pills'],
  id: 'navigation-bar',
  selectedNavItem: function(){
    const filterMode = this.get('filterMode'),
          navItems = this.get('navItems');

    var item = navItems.find(function(i){
      return i.get('filterMode').indexOf(filterMode) === 0;
    });

    return item || navItems[0];
  }.property('filterMode'),

  closedNav: function(){
    if (!this.get('expanded')) {
      this.ensureDropClosed();
    }
  }.observes('expanded'),

  ensureDropClosed: function(){
    if (!this.get('expanded')) {
      this.set('expanded',false);
    }
    $(window).off('click.navigation-bar');
    DiscourseURL.appEvents.off('dom:clean', this, this.ensureDropClosed);
  },

  actions: {
    toggleDrop: function(){
      this.set('expanded', !this.get('expanded'));
      var self = this;
      if (this.get('expanded')) {

        DiscourseURL.appEvents.on('dom:clean', this, this.ensureDropClosed);

        Em.run.next(function() {

          if (!self.get('expanded')) { return; }

          self.$('.drop a').on('click', function(){
            self.$('.drop').hide();
            self.set('expanded', false);
            return true;
          });

          $(window).on('click.navigation-bar', function() {
            self.set('expanded', false);
            return true;
          });
        });
      }
    }
  }
});
