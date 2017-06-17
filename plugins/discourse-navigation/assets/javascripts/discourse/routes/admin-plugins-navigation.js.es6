import MenuLink from 'discourse/plugins/navigation/discourse/models/menu-link';

export default Discourse.Route.extend({

  model() {
    return this.store.findAll('menu-link');
  }

});
