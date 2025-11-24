import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import DFloatPortal from "discourse/float-kit/components/d-float-portal";
import { getScrollParent } from "discourse/float-kit/lib/get-scroll-parent";
import FloatKitApplyFloatingUi from "discourse/float-kit/modifiers/apply-floating-ui";
import FloatKitCloseOnEscape from "discourse/float-kit/modifiers/close-on-escape";
import concatClass from "discourse/helpers/concat-class";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import TrapTab from "discourse/modifiers/trap-tab";
import { and } from "discourse/truth-helpers";

export default class DFloatBody extends Component {
  closeOnScroll = modifierFn(() => {
    const firstScrollParent = getScrollParent(this.trigger);

    const handler = () => {
      // This is where the close logic for the floating body is triggered.
      // See: float-kit/lib/d-menu-instance.js (or d-menu-instance.ts) for the `close` method implementation.
      // If you want to add a `closing` class for exit animation, consider calling a new instance method
      // that sets a state for "closing", triggers the class, then closes after animation.

      // Example: this.args.instance.beginCloseWithAnimation?.() or similar.
      this.args.instance.close();
    };

    firstScrollParent.addEventListener("scroll", handler, { passive: true });

    return () => {
      firstScrollParent.removeEventListener("scroll", handler);
    };
  });

  trapPointerDown = modifierFn((element) => {
    const handler = (event) => {
      event.stopPropagation();
    };

    element.addEventListener("pointerdown", handler);

    return () => {
      element.removeEventListener("pointerdown", handler);
    };
  });

  get supportsCloseOnClickOutside() {
    return this.args.instance.expanded && this.options.closeOnClickOutside;
  }

  get supportsCloseOnEscape() {
    return this.args.instance.expanded && this.options.closeOnEscape;
  }

  get supportsCloseOnScroll() {
    return this.args.instance.expanded && this.options.closeOnScroll;
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

  <template>
    {{~! strip whitespace ~}}<DFloatPortal
      @inline={{@inline}}
      @portalOutletElement={{@instance.portalOutletElement}}
    >
      <div
        class={{concatClass
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
        {{this.trapPointerDown}}
        {{(if @trapTab (modifier TrapTab autofocus=this.options.autofocus))}}
        {{(if
          (and @instance.expanded this.supportsCloseOnClickOutside)
          (modifier
            closeOnClickOutside
            (fn @instance.close (hash focusTrigger=false))
            (hash target=this.content)
          )
        )}}
        {{(if
          this.supportsCloseOnEscape
          (modifier FloatKitCloseOnEscape @instance.close)
        )}}
        {{(if this.supportsCloseOnScroll (modifier this.closeOnScroll))}}
        style={{htmlSafe (concat "max-width: " this.options.maxWidth "px")}}
        ...attributes
      >
        <div class={{@innerClass}}>
          {{yield}}
        </div>
      </div>
    </DFloatPortal>{{~! strip whitespace ~}}
  </template>
}
