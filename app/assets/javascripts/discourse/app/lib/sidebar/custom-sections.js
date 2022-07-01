import BaseSectionHeader from "discourse/lib/sidebar/base-section-header";
import { A } from "@ember/array";
import { tracked } from "@glimmer/tracking";

export const customSections = [];

export function addSidebarSection(arg) {
  customSections.push(
    class extends BaseSectionHeader {
      @tracked sectionLinks = A([]);

      constructor() {
        super(...arguments);

        arg.chatService.getChannels().then((channels) => {
          channels.publicChannels.forEach((channel) => {
            this.sectionLinks.pushObject(
              new (class {
                get text() {
                  return channel.title;
                }
              })()
            );
          });
        });
      }

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

      get links() {
        return this.sectionLinks;
      }
    }
  );
}
