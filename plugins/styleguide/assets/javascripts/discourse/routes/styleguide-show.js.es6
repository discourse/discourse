import {
  findNote,
  sectionById,
} from "discourse/plugins/styleguide/discourse/lib/styleguide";
import { createData } from "discourse/plugins/styleguide/discourse/lib/dummy-data";

export default Ember.Route.extend({
  model(params) {
    return sectionById(params.section);
  },

  setupController(controller, section) {
    let note = findNote(section);

    controller.setProperties({
      section,
      note,
      dummy: createData(this.store),
    });
  },

  renderTemplate(controller, section) {
    this.render("styleguide.show");
    this.render(`styleguide/${section.templateName}`, {
      into: "styleguide.show",
    });
  },
});
