import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";

export default Component.extend({
  classNames: ["hook-event"],
  typeName: alias("type.name"),

  @discourseComputed("typeName")
  name(typeName) {
    return I18n.t(`admin.web_hooks.${typeName}_event.name`);
  },

  @discourseComputed("typeName")
  details(typeName) {
    return I18n.t(`admin.web_hooks.${typeName}_event.details`);
  },

  @discourseComputed("model.[]", "typeName")
  eventTypeExists(eventTypes, typeName) {
    return eventTypes.any(event => event.name === typeName);
  },

  @discourseComputed("eventTypeExists")
  enabled: {
    get(eventTypeExists) {
      return eventTypeExists;
    },
    set(value, eventTypeExists) {
      const type = this.type;
      const model = this.model;
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
