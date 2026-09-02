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

  /** The list element; consumers yield its `li` children. */
  Element: HTMLUListElement;

  Blocks: {
    /** The `li` items of the list. */
    default: [];
  };
}

/**
 * A navigation bar whose pills scroll sideways when they outgrow it, built
 * on `DOverflowControls`: edge fades, chevrons that scroll a viewport per
 * click or continuously while held, and the active item brought into view
 * on mount. Consumers yield bare `li` elements; the list keeps the
 * `nav-pills` styling contract and receives every attribute.
 */
export default class DHorizontalOverflowNav extends Component<DHorizontalOverflowNavSignature> {
  /**
   * Reveals the active item once, centred in the strip. When the list is
   * still empty on mount, which a portal-filled list is, it waits for the
   * first children and reveals then.
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
