import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import DOverflowControls, {
  type DOverflowControlsBag,
} from "discourse/ui-kit/d-overflow-controls";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const ACTIVE_ITEM = "a.active, button.active";

const EDGE_CLASSES = {
  left: "horizontal-overflow-nav__scroll-left",
  right: "horizontal-overflow-nav__scroll-right",
};

interface DHorizontalOverflowNavSignature {
  Args: {
    /** The accessible name of the navigation landmark, already translated. */
    ariaLabel?: string;

    /** Extra class(es) added to the list element. */
    className?: string;
  };

  /** The list element. Consumers yield its `li` children. */
  Element: HTMLUListElement;

  Blocks: {
    /** The `li` items of the list. */
    default: [];
  };
}

/**
 * A navigation bar whose pills scroll sideways when they outgrow it, built
 * on `DOverflowControls`: edge fades, chevrons, press-and-hold, and the
 * active item revealed on mount.
 *
 * Consumers yield bare `li` elements. The list keeps the `nav-pills`
 * styling contract and receives every attribute.
 */
export default class DHorizontalOverflowNav extends Component<DHorizontalOverflowNavSignature> {
  /**
   * Reveals the active item once, centered in the strip. When no active
   * item exists on mount, as in a portal-filled list, it watches the list
   * and reveals the first one that appears.
   */
  revealActive = modifier(
    (list: HTMLElement, [strip]: [strip: DOverflowControlsBag]) => {
      const reveal = () => {
        const active = list.querySelector<HTMLElement>(ACTIVE_ITEM);
        if (!active) {
          return false;
        }
        strip.reveal(active, { align: "center" });
        return true;
      };

      if (reveal()) {
        return;
      }

      const observer = new MutationObserver(() => {
        if (reveal()) {
          observer.disconnect();
        }
      });
      observer.observe(list, { childList: true, subtree: true });

      return () => observer.disconnect();
    }
  );

  <template>
    <nav class="horizontal-overflow-nav" aria-label={{@ariaLabel}}>
      <DOverflowControls
        @axis="horizontal"
        @edgeButtonClasses={{EDGE_CLASSES}}
        @ownedScroller={{true}}
        @wrapperClass="horizontal-overflow-nav__controls"
        as |strip|
      >
        <ul
          class={{dConcatClass "nav-pills action-list" @className}}
          ...attributes
          {{strip.scroller}}
          {{this.revealActive strip}}
        >
          {{yield}}
        </ul>
      </DOverflowControls>
    </nav>
  </template>
}
