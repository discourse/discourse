import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { createData } from "discourse/plugins/styleguide/discourse/lib/dummy-data";
import { sectionById } from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default class StyleguideShow extends Route {
  @service router;

  model(params) {
    const section = sectionById(params.section);

    if (!section) {
      this.router.replaceWith("/404");
      return;
    }

    return section;
  }

  setupController(controller, section) {
    controller.setProperties({
      section,
      dummy: createData(this.store),
    });
  }
}
