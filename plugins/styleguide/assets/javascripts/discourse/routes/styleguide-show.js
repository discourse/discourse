import Route from "@ember/routing/route";
import {
  findNote,
  sectionById,
} from "discourse/plugins/styleguide/discourse/lib/styleguide";
import { createData } from "discourse/plugins/styleguide/discourse/lib/dummy-data";

export default class StyleguideShow extends Route {
  model(params) {
    return sectionById(params.section);
  }

  setupController(controller, section) {
    controller.setProperties({
      section,
      note: findNote(section),
      dummy: createData(this.store),
    });
  }
}
