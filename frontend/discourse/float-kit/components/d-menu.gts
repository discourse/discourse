import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import type { AutoUpdateOptions } from "@floating-ui/dom";
import { type ComponentLike } from "@glint/template";
import curryComponent from "ember-curry-component";
import { modifier } from "ember-modifier";
import DFloatBody from "discourse/float-kit/components/d-float-body";
import {
  type FloatCallback,
  type FloatUiPlacement,
  MENU,
  type MenuOptions,
  type VisibilityOptimizer,
} from "discourse/float-kit/lib/constants";
import DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import { isTesting } from "discourse/lib/environment";
import type Site from "discourse/models/site";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModalUntyped from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

// TODO(devxp-typescript-pending): drop this cast once DModal is authored in .gts with a
// real Signature, then import it directly. Untyped .gjs today gives it no arg/attr types.
const DModal = DModalUntyped as unknown as ComponentLike<{
  Element: HTMLElement;
  Args: {
    closeModal?: FloatCallback;
    hideHeader?: boolean;
    autofocus?: boolean;
    inline?: boolean;
  };
  Blocks: { default: [] };
}>;

/** The object yielded to each of the menu's blocks and passed to a rendered component. */
export interface DMenuComponentArgs<Data = unknown> {
  close: FloatCallback;
  show: FloatCallback;
  data?: Data;
}

interface DMenuSignature<Data = unknown> {
  Element: HTMLElement;
  Args: {
    /* Explicitly-read arguments (not part of the options bag). */
    onKeydown?: (event: KeyboardEvent) => unknown;
    triggerComponent?: ComponentLike;
    icon?: string;
    label?: string;
    ariaLabel?: string;
    title?: string;
    disabled?: boolean;
    isLoading?: boolean;

    /* Every key of `MENU.options` (see `constants.ts` — the source of truth). */
    animated?: boolean;
    arrow?: boolean;
    autofocus?: boolean;
    beforeTrigger?: FloatCallback;
    closeOnEscape?: boolean;
    closeOnClickOutside?: boolean;
    closeOnScroll?: boolean;
    component?: ComponentLike<{ Args: { data?: Data; close?: FloatCallback } }>;
    content?: string;
    identifier?: string;
    interactive?: boolean;
    listeners?: boolean;
    maxWidth?: number;
    data?: Data;
    offset?: number;
    triggers?: string[];
    untriggers?: string[];
    placement?: FloatUiPlacement;
    shiftBeforeVisibilityOptimizer?: boolean;
    visibilityOptimizer?: VisibilityOptimizer;
    fallbackPlacements?: readonly FloatUiPlacement[];
    autoUpdate?: boolean | AutoUpdateOptions;
    trapTab?: boolean;
    onClose?: FloatCallback;
    onShow?: FloatCallback;
    onRegisterApi?: (instance: DMenuInstance) => void;
    modalForMobile?: boolean;
    inline?: boolean | null;
    groupIdentifier?: string;
    parentIdentifier?: string;
    triggerClass?: string;
    contentClass?: string;
    class?: string;
    matchTriggerMinWidth?: boolean;
    matchTriggerWidth?: boolean;
    portalOutletElement?: HTMLElement;
  };
  Blocks: {
    default: [DMenuComponentArgs<Data>];
    trigger: [DMenuComponentArgs<Data>];
    content: [DMenuComponentArgs<Data>];
  };
}

export default class DMenu<Data = unknown> extends Component<
  DMenuSignature<Data>
> {
  @service declare site: Site;

  menuInstance = new DMenuInstance(getOwner(this)!, {
    ...this.allowedProperties,
    autoUpdate: true,
    listeners: true,
  } as Partial<MenuOptions>);

  registerTrigger = modifier((domElement: HTMLElement) => {
    this.menuInstance.trigger = domElement;
    this.options.onRegisterApi?.(this.menuInstance);

    return () => {
      this.menuInstance.destroy();
    };
  });

  registerFloatBody = modifier((domElement: HTMLElement) => {
    this.#body = domElement;

    return () => {
      this.#body = null;
    };
  });

  #body: HTMLElement | null = null;

  @action
  teardownFloatBody() {
    this.#body = null;
  }

  @action
  forwardTabToContent(event: KeyboardEvent) {
    // need to call the parent handler to allow arrow key navigation to siblings in toolbar contexts
    const parentHandlerResult = this.args.onKeydown?.(event);

    if (!this.#body) {
      return parentHandlerResult;
    }

    if (event.key === "Tab") {
      event.preventDefault();

      const firstFocusable = this.#body.querySelector<HTMLElement>(
        'button, a, input:not([type="hidden"]), select, textarea, [tabindex]:not([tabindex="-1"])'
      );

      firstFocusable?.focus();
      this.#body.focus();

      return true;
    }

    return parentHandlerResult;
  }

  get options(): MenuOptions {
    return this.menuInstance?.options ?? ({} as MenuOptions);
  }

  get componentArgs(): DMenuComponentArgs<Data> {
    return {
      close: this.menuInstance.close,
      show: this.menuInstance.show,
      data: this.options.data as Data,
    };
  }

  get triggerComponent() {
    const args = this.args;
    const baseArguments = {
      get icon() {
        return args.icon;
      },
      get translatedLabel() {
        return args.label;
      },
      get translatedAriaLabel() {
        return args.ariaLabel;
      },
      get translatedTitle() {
        return args.title;
      },
      get disabled() {
        return args.disabled;
      },
      get isLoading() {
        return args.isLoading;
      },
    };

    // `curryComponent` is untyped and the curried `DButton` honors the menu's
    // `@componentArgs` + modifier + splattributes + default block at runtime without
    // declaring them, so the result is cast to a permissive component type.
    return (this.args.triggerComponent ||
      curryComponent(DButton, baseArguments, getOwner(this))) as ComponentLike<{
      Element: HTMLElement;
      Args: { componentArgs?: DMenuComponentArgs<Data> };
      Blocks: { default: [] };
    }>;
  }

  get allowedProperties() {
    const properties: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(MENU.options)) {
      properties[key] = (this.args as Record<string, unknown>)[key] ?? value;
    }
    return properties;
  }

  <template>
    <this.triggerComponent
      {{this.registerTrigger}}
      class={{dConcatClass
        "fk-d-menu__trigger"
        (if this.menuInstance.expanded "-expanded")
        (concat this.options.identifier "-trigger")
        @triggerClass
        @class
      }}
      id={{this.menuInstance.id}}
      data-identifier={{this.options.identifier}}
      data-trigger
      aria-expanded={{if this.menuInstance.expanded "true" "false"}}
      {{on "keydown" this.forwardTabToContent}}
      @componentArgs={{this.componentArgs}}
      ...attributes
    >
      {{#if (has-block "trigger")}}
        {{yield this.componentArgs to="trigger"}}
      {{/if}}
    </this.triggerComponent>

    {{#if this.menuInstance.expanded}}
      {{#if (and this.site.mobileView this.options.modalForMobile)}}
        <DModal
          @closeModal={{this.menuInstance.close}}
          @hideHeader={{true}}
          @autofocus={{this.options.autofocus}}
          class={{dConcatClass
            "fk-d-menu-modal"
            (concat this.options.identifier "-content")
            @contentClass
            @class
          }}
          @inline={{(isTesting)}}
          data-identifier={{this.options.identifier}}
          data-content
        >
          <div class="fk-d-menu-modal__grip" aria-hidden="true"></div>
          {{#if (has-block)}}
            {{yield this.componentArgs}}
          {{else if (has-block "content")}}
            {{yield this.componentArgs to="content"}}
          {{else if this.options.component}}
            <this.options.component
              @data={{this.options.data}}
              @close={{this.menuInstance.close}}
            />
          {{else if this.options.content}}
            {{this.options.content}}
          {{/if}}
        </DModal>
      {{else}}
        <DFloatBody
          @instance={{this.menuInstance}}
          @trapTab={{this.options.trapTab}}
          @mainClass={{dConcatClass
            "fk-d-menu"
            (concat this.options.identifier "-content")
            @class
            @contentClass
          }}
          @innerClass="fk-d-menu__inner-content"
          @role="dialog"
          @inline={{this.options.inline}}
          {{this.registerFloatBody}}
        >
          {{#if (has-block)}}
            {{yield this.componentArgs}}
          {{else if (has-block "content")}}
            {{yield this.componentArgs to="content"}}
          {{else if this.options.component}}
            <this.options.component
              @data={{this.options.data}}
              @close={{this.menuInstance.close}}
            />
          {{else if this.options.content}}
            {{this.options.content}}
          {{/if}}
        </DFloatBody>
      {{/if}}
    {{/if}}
  </template>
}
