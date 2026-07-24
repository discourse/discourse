import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import DFloatPortal from "discourse/float-kit/components/d-float-portal";
import type FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import { getScrollParent } from "discourse/float-kit/lib/get-scroll-parent";
import FloatKitApplyFloatingUi from "discourse/float-kit/modifiers/apply-floating-ui";
import FloatKitCloseOnEscape from "discourse/float-kit/modifiers/close-on-escape";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import dTrapTab from "discourse/ui-kit/modifiers/d-trap-tab";

interface DFloatBodySignature {
  Element: HTMLDivElement;
  Args: {
    /** The float instance this body renders. */
    instance: FloatKitInstance;

    /** Whether to render in place instead of into the portal outlet. */
    inline?: boolean | null;

    /** A class added to the outer float element. */
    mainClass?: string;

    /** A class added to the inner content element. */
    innerClass?: string;

    /** The ARIA role for the content. */
    role?: string;

    /** Whether to trap Tab focus within the content. */
    trapTab?: boolean;

    /**
     * The element to render into. Some callers forward this even though the body
     * reads `@instance.portalOutletElement`.
     */
    portalOutletElement?: HTMLElement | null;
  };
  Blocks: {
    /** The float content, rendered inside the positioned element. */
    default: [];
  };
}

/**
 * The shared content body that both menus and tooltips render through. It
 * portals the content (see `DFloatPortal`), positions it against the trigger
 * with floating-ui, and wires the dismissal and focus behaviors the instance
 * asks for in its options: close on click-outside, Escape, or scroll, and a Tab
 * focus trap. It reads all of that from `@instance`, so callers only supply the
 * instance plus a few presentational overrides.
 */
export default class DFloatBody extends Component<DFloatBodySignature> {
  closeOnScroll = modifierFn(() => {
    const firstScrollParent = getScrollParent(this.trigger)!;

    const handler = () => {
      this.args.instance.close();
    };

    firstScrollParent.addEventListener("scroll", handler, { passive: true });

    return () => {
      firstScrollParent.removeEventListener("scroll", handler);
    };
  });

  trapInteractionPropagation = modifierFn((element: HTMLElement) => {
    const handler = (event: Event) => {
      event.stopPropagation();
    };

    const events = ["pointerdown", "mousedown", "touchend"];
    events.forEach((name) => element.addEventListener(name, handler));

    return () => {
      events.forEach((name) => element.removeEventListener(name, handler));
    };
  });

  get supportsCloseOnClickOutside() {
    return this.options.closeOnClickOutside;
  }

  get supportsCloseOnEscape() {
    return this.options.closeOnEscape;
  }

  get supportsCloseOnScroll() {
    return this.options.closeOnScroll;
  }

  get trigger() {
    return this.args.instance?.trigger;
  }

  get content() {
    return this.args.instance?.content;
  }

  get options() {
    return this.args.instance.options;
  }

  get style() {
    const maxWidth =
      typeof this.options.maxWidth === "number"
        ? `${this.options.maxWidth}px`
        : this.options.maxWidth;

    return trustHTML(`max-width: ${maxWidth}`);
  }

  <template>
    {{~! strip whitespace ~}}<DFloatPortal
      @inline={{@inline}}
      @portalOutletElement={{@instance.portalOutletElement}}
    >
      {{! eslint-disable-next-line ember/template-no-unsupported-role-attributes }}
      <div
        class={{dConcatClass
          @mainClass
          (if this.options.animated "-animated")
          (if @instance.expanded "-expanded")
        }}
        data-identifier={{this.options.identifier}}
        data-content
        aria-labelledby={{@instance.id}}
        aria-expanded={{if @instance.expanded "true" "false"}}
        role={{@role}}
        {{FloatKitApplyFloatingUi this.trigger this.options @instance}}
        {{this.trapInteractionPropagation}}
        {{(if @trapTab (modifier dTrapTab autofocus=this.options.autofocus))}}
        {{(if
          this.supportsCloseOnClickOutside
          (modifier
            dCloseOnClickOutside
            (fn @instance.close (hash focusTrigger=false))
            (hash target=this.content)
          )
        )}}
        {{(if
          this.supportsCloseOnEscape
          (modifier FloatKitCloseOnEscape @instance.close)
        )}}
        {{(if this.supportsCloseOnScroll (modifier this.closeOnScroll))}}
        style={{this.style}}
        ...attributes
      >
        <div class={{@innerClass}}>
          {{yield}}
        </div>
      </div>
    </DFloatPortal>{{~! strip whitespace ~}}
  </template>
}
