import Group from 'discourse/models/group';
import createPMRoute from "discourse/routes/build-private-messages-route";

export default createPMRoute('groups', 'private-messages-groups').extend({
    model(params) {
      const username = this.modelFor("user").get("username_lower");
      return this.store.findFiltered("topicList", {
        filter: `topics/private-messages-group/${username}/${params.name}`
      });
    },

    afterModel(model) {
      const groupName = _.last(model.get("filter").split('/'));
      Group.findAll().then(groups => {
        const group = _.first(groups.filterBy("name", groupName));
        this.controllerFor("user-private-messages").set("group", group);
      });
    },

    setupController(controller, model) {
      this._super.apply(this, arguments);
      const group = _.last(model.get("filter").split('/'));
      this.controllerFor("userPrivateMessages").set("groupFilter", group);
    }
});
