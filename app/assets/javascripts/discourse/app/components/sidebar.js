import GlimmerComponent from "discourse/components/glimmer";
import { tracked } from "@glimmer/tracking";
import { customSections } from "discourse/lib/sidebar/custom-sections";
import { A } from "@ember/array";

export default class Sidebar extends GlimmerComponent {
  @tracked customSections;

  get computedCustomSections() {
    return customSections.map((sectionClass) => {
      const links = A([]);
      sectionClass.links?.forEach((linkClass) => {
        links.push(
          new linkClass({
            currentUser: this.currentUser,
            appEvents: this.appEvents,
          })
        );
      });

      return {
        header: new sectionClass.header({
          currentUser: this.currentUser,
          appEvents: this.appEvents,
        }),
        links,
      };
    });
  }
}
