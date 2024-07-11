import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import Service, { service } from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import deprecated from "discourse-common/lib/deprecated";

@disableImplicitInjections
export default class Header extends Service {
  @service siteSettings;

  /**
   * The topic currently viewed on the page.
   *
   * The information is updated as soon as the page is loaded.
   *
   * @type {Topic|null}
   */
  @tracked topicInfo = null;

  /**
   * Indicates whether the topic information is visible on the header.
   *
   * The information is updated when the user scrolls the page.
   *
   * @type {boolean}
   */
  @tracked topicInfoVisible = false;

  @tracked hamburgerVisible = false;
  @tracked userVisible = false;
  @tracked anyWidgetHeaderOverrides = false;

  #hiders = new TrackedMap();

  get topic() {
    deprecated(
      "`.topic` is deprecated in service:header. Use `.topicInfo` or `.topicInfoVisible` instead.",
      {
        id: "discourse.header-service-topic",
        since: "3.3.0.beta4-dev",
        dropFrom: "3.4.0",
      }
    );

    return this.topicInfoVisible ? this.topicInfo : null;
  }

  get useGlimmerHeader() {
    if (this.siteSettings.glimmer_header_mode === "disabled") {
      return false;
    } else if (this.siteSettings.glimmer_header_mode === "enabled") {
      return true;
    } else {
      // Auto
      if (this.anyWidgetHeaderOverrides) {
        // eslint-disable-next-line no-console
        console.warn(
          "Using legacy 'widget' header because themes and/or plugins are using deprecated APIs. https://meta.discourse.org/t/296544"
        );
        return false;
      } else {
        return true;
      }
    }
  }

  registerHider(ref, buttons) {
    this.#hiders.set(ref, buttons);

    registerDestructor(ref, () => {
      this.#hiders.delete(ref);
    });
  }

  get headerButtonsHidden() {
    const buttonsToHide = new Set();
    this.#hiders.forEach((buttons) => {
      buttons.forEach((button) => {
        buttonsToHide.add(button);
      });
    });
    return Array.from(buttonsToHide);
  }
}
