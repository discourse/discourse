import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { modifier as modifierFn } from "ember-modifier";
import concatClass from "discourse/helpers/concat-class";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import TrapTab from "discourse/modifiers/trap-tab";
import DFloatPortal from "float-kit/components/d-float-portal";
import { getScrollParent } from "float-kit/lib/get-scroll-parent";
import FloatKitApplyFloatingUi from "float-kit/modifiers/apply-floating-ui";
import FloatKitCloseOnEscape from "float-kit/modifiers/close-on-escape";

export default class DFloatBody extends Component {
  trapClick = modifierFn(() => {
    const trap = (event) => {
      event.stopPropagation();
    };

    this.content.addEventListener("click", trap);

    return () => this.content?.removeEventListener("click", trap);
  });

  closeOnScroll = modifierFn(() => {
    const firstScrollParent = getScrollParent(this.trigger);

    const handler = () => {
      this.args.instance.close();
    };

    firstScrollParent.addEventListener("scroll", handler, { passive: true });

    return () => {
      firstScrollParent.removeEventListener("scroll", handler);
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
    <DFloatPortal
      @inline={{@inline}}
      @portalOutletElement={{@instance.portalOutletElement}}
    >
      <div
        class={{concatClass
          @mainClass
          (if this.options.animated "-animated")
          (if @instance.expanded "-expanded")
          this.options.extraClassName
        }}
        data-identifier={{this.options.identifier}}
        data-content
        aria-labelledby={{@instance.id}}
        aria-expanded={{if @instance.expanded "true" "false"}}
        role={{@role}}
        {{FloatKitApplyFloatingUi this.trigger this.options @instance}}
        {{(if @trapTab (modifier TrapTab autofocus=this.options.autofocus))}}
        {{(if
          this.supportsCloseOnClickOutside
          (modifier
            closeOnClickOutside @instance.close (hash target=this.content)
          )
        )}}
        {{(if this.supportsCloseOnClickOutside (modifier this.trapClick))}}
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
    </DFloatPortal>
  </template>
}
