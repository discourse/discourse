import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["hook-event"],
  typeName: Ember.computed.alias("type.name"),

  @computed("typeName")
  name(typeName) {
    return I18n.t(`admin.web_hooks.${typeName}_event.name`);
  },

  @computed("typeName")
  details(typeName) {
    return I18n.t(`admin.web_hooks.${typeName}_event.details`);
  },

  @computed("model.[]", "typeName")
  eventTypeExists(eventTypes, typeName) {
    return eventTypes.any(event => event.name === typeName);
  },

  @computed("eventTypeExists")
  enabled: {
    get(eventTypeExists) {
      return eventTypeExists;
    },
    set(value, eventTypeExists) {
      const type = this.get("type");
      const model = this.get("model");
      // add an association when not exists
      if (value !== eventTypeExists) {
        if (value) {
          model.addObject(type);
        } else {
          model.removeObjects(
            model.filter(eventType => eventType.name === type.name)
          );
        }
      }

      return value;
    }
  }
});
