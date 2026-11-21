import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import type { TrustedHTML } from "@ember/template";
import type {
  AnnouncementType,
  default as A11y,
} from "discourse/services/a11y";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const FLASH_TYPES = ["success", "error", "warning", "info"] as const;

export type FlashType = (typeof FLASH_TYPES)[number];

/** How a screen reader announces a message when it appears. */
export type FlashAnnounce = AnnouncementType | false;

interface DFlashMessageSignature {
  Args: {
    /** The message to display. Accepts a plain string or trusted HTML. */
    flash?: string | TrustedHTML;

    /** The severity of the message. */
    type?: FlashType;

    /**
     * How a screen reader announces the message when it appears:
     * `"assertive"` interrupts, `"polite"` waits for a pause, and `false`
     * stays silent. Errors default to `"assertive"` and everything else to
     * `"polite"`.
     */
    announce?: FlashAnnounce;
  };

  Element: HTMLDivElement;
}

export default class DFlashMessage extends Component<DFlashMessageSignature> {
  @service declare a11y: A11y;

  get flashClass() {
    if (this.args.type && !FLASH_TYPES.includes(this.args.type)) {
      throw `@type must be one of ${FLASH_TYPES.join(", ")}`;
    }
    return this.args.type ? `alert-${this.args.type}` : null;
  }

  @action
  announceFlash(element: HTMLElement) {
    const { announce, type } = this.args;
    const text = element.textContent?.trim();

    if (announce === false || !text) {
      return;
    }

    this.a11y.announce(
      text,
      announce ?? (type === "error" ? "assertive" : "polite")
    );
  }

  <template>
    {{#if @flash}}
      <div
        class={{dConcatClass "alert" this.flashClass}}
        ...attributes
        {{didInsert this.announceFlash}}
        {{didUpdate this.announceFlash @flash}}
      >
        {{~@flash~}}
      </div>
    {{/if}}
  </template>
}
