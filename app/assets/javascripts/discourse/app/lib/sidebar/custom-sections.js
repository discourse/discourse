import BaseSectionHeader from "discourse/lib/sidebar/base-section-header";
import BaseSectionLink from "discourse/lib/sidebar/topics-section/base-section-link";
import { A } from "@ember/array";

export const customSections = A([]);

export function addSidebarSection(arg) {
  let header,
    links = A([]);

  if (typeof arg.header === "function") {
    header = arg.header.call(this, BaseSectionHeader);
  } else {
    header = class extends BaseSectionHeader {
      get name() {
        return arg.header.name;
      }

      get route() {
        return arg.header.route;
      }

      get title() {
        return arg.header.title;
      }

      get text() {
        return arg.header.text;
      }

      get action() {
        return arg.header.action;
      }

      get actionIcon() {
        return arg.header.actionIcon;
      }

      get actionTitle() {
        return arg.header.actionTitle;
      }
    };
  }

  if (typeof arg.links === "function") {
    links = arg.links.call(this, BaseSectionLink);
  } else {
    arg.links?.forEach((link) => {
      const klass = class extends BaseSectionLink {
        get name() {
          return link.name;
        }

        get route() {
          return link.route;
        }

        get text() {
          return link.text;
        }

        get title() {
          return link.title;
        }
      };
      links.pushObject(klass);
    });
  }

  customSections.push({ header, links });
}
