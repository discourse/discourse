import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { fn, hash } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import DFloatPortal from "discourse/float-kit/components/d-float-portal";
import type FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import { getScrollParent } from "discourse/float-kit/lib/get-scroll-parent";
import { horizontalViewportInset } from "discourse/float-kit/lib/update-position";
import FloatKitApplyFloatingUi from "discourse/float-kit/modifiers/apply-floating-ui";
import FloatKitCloseOnEscape from "discourse/float-kit/modifiers/close-on-escape";
import FloatKitTabOrderInline from "discourse/float-kit/modifiers/tab-order-inline";
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
     * Whether the content should take part in the tab sequence as if it were rendered inline
     * after the trigger, rather than at the portal's position in the document: Tab leads into its
     * controls from the trigger, and off the end of them it dismisses the float and continues
     * from the trigger.
     *
     * The non-containing alternative to `trapTab`, for a float that is dismissable but whose
     * content holds focus. See `FloatKitTabOrderInline`.
     */
    inlineTabOrder?: boolean;

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

  /**
   * Extends the trigger's grace period across the content itself, so hovering onto the
   * float keeps it open and leaving it starts the close. Focus moving within the
   * content is not a departure, so it holds the lock rather than scheduling a close.
   */
  hoverGrace = modifierFn((element: HTMLElement) => {
    const instance = this.args.instance;

    const onPointerEnter = () => instance.cancelHoverClose();
    const onPointerLeave = () => instance.scheduleHoverClose();
    const onFocusIn = () => instance.lockHoverCloseForFocus();
    const onFocusOut = (event: FocusEvent) => {
      const nextFocused = event.relatedTarget;
      if (nextFocused instanceof Node && element.contains(nextFocused)) {
        return;
      }
      instance.unlockHoverCloseForFocus();
      instance.scheduleHoverClose();
    };

    element.addEventListener("pointerenter", onPointerEnter, { passive: true });
    element.addEventListener("pointerleave", onPointerLeave, { passive: true });
    element.addEventListener("focusin", onFocusIn, { passive: true });
    element.addEventListener("focusout", onFocusOut, { passive: true });

    return () => {
      element.removeEventListener("pointerenter", onPointerEnter);
      element.removeEventListener("pointerleave", onPointerLeave);
      element.removeEventListener("focusin", onFocusIn);
      element.removeEventListener("focusout", onFocusOut);
    };
  });

  /**
   * Whether to install the grace-period listeners on the content. Only meaningful while
   * the float is open, and only when a grace period is configured.
   *
   * @returns `true` when the content should participate in the grace period.
   */
  get supportsHoverGrace(): boolean {
    return this.args.instance.expanded && this.options.hoverGracePeriod > 0;
  }

  get contentAriaLabelledby(): string | null | undefined {
    if (this.#hasPresentationalRole) {
      return;
    }

    return this.args.instance.id;
  }

  /**
   * `presentation` prohibits an accessible name outright, and `none` is its synonym, so a
   * container in either role must not be labelled by its trigger.
   */
  get #hasPresentationalRole() {
    return this.args.role === "none" || this.args.role === "presentation";
  }

  /**
   * Whether to repair the tab order, asserting first that containment was not ALSO asked for.
   *
   * The two are alternatives, and the conflict is otherwise silent and one-sided: `dTrapTab` is
   * applied first below, so its `preventDefault` lands before the tab-order handler runs, and the
   * float traps focus while its author believes they configured the opposite.
   */
  get inlineTabOrder() {
    assert(
      "float-kit: `trapTab` and `inlineTabOrder` are alternatives — the first contains focus, the second deliberately lets it leave. Setting both keeps the trap and silently ignores the tab-order repair.",
      !(this.args.trapTab && this.args.inlineTabOrder)
    );

    return this.args.inlineTabOrder;
  }

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
    const { maxWidth } = this.options;

    // Only a number is clamped: a keyword like `none` or `unset` is invalid inside `min()`,
    // which would drop the declaration and hand the float to whatever CSS sets `max-width`.
    const value =
      typeof maxWidth === "number"
        ? `min(${maxWidth}px, calc(100dvw - ${horizontalViewportInset(this.options)}px))`
        : maxWidth;

    return trustHTML(`max-width: ${value}`);
  }

  <template>
    {{~! strip whitespace ~}}<DFloatPortal
      @inline={{@inline}}
      @portalOutletElement={{@instance.portalOutletElement}}
    >
      {{~! strip whitespace ~}}
      <div
        class={{dConcatClass
          @mainClass
          (if this.options.animated "-animated")
          (if @instance.expanded "-expanded")
        }}
        data-identifier={{this.options.identifier}}
        data-content
        aria-labelledby={{this.contentAriaLabelledby}}
        role={{@role}}
        {{FloatKitApplyFloatingUi this.trigger this.options @instance}}
        {{this.trapInteractionPropagation}}
        {{(if @trapTab (modifier dTrapTab autofocus=this.options.autofocus))}}
        {{(if
          this.inlineTabOrder
          (modifier
            FloatKitTabOrderInline
            @instance.triggerElement
            (fn @instance.close (hash focusTrigger=false))
          )
        )}}
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
        {{(if this.supportsHoverGrace (modifier this.hoverGrace))}}
        style={{this.style}}
        ...attributes
      >
        <div class={{@innerClass}}>
          {{yield}}
        </div>
      </div>
      {{~! strip whitespace ~}}
    </DFloatPortal>{{~! strip whitespace ~}}
  </template>
}
