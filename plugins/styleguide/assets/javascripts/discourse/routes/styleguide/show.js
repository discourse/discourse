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

  // Query-param stickiness is model-scoped, so `?group=` cannot leak from one section to
  // another. What it does do is survive leaving and returning to the SAME section, which would
  // silently reopen a group the reader had navigated away from. Clearing on exit keeps the bare
  // nav link meaning "the first group".
  resetController(controller, isExiting) {
    if (isExiting) {
      controller.set("group", null);
    }
  }
}
