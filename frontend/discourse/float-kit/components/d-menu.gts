import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { type ComponentLike } from "@glint/template";
import curryComponent from "ember-curry-component";
import { modifier } from "ember-modifier";
import DFloatBody from "discourse/float-kit/components/d-float-body";
import {
  type FloatCallback,
  MENU,
  type MenuOptions,
} from "discourse/float-kit/lib/constants";
import DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import { isTesting } from "discourse/lib/environment";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/** The object yielded to each of the menu's blocks and passed to a rendered component. */
export interface DMenuComponentArgs<Data = unknown> {
  /** Closes the menu. */
  close: FloatCallback;

  /** Opens the menu. */
  show: FloatCallback;

  /** The `@data` passed to the menu. */
  data?: Data;
  /** Whether the menu is currently open — reflects the live instance state. */
  expanded: boolean;
}

// The subset of arguments that mirror a menu's option bag. Built as a
// `Partial<Omit<…>>` over `MenuOptions` (defined in `constants.ts`), so the
// arguments track the options automatically: a field added there is accepted here
// for free, with no second list to keep in sync. The three omitted fields are
// re-declared to narrow their generic `MenuOptions` types (`data: unknown`, a
// `Data`-agnostic `component`, `onRegisterApi: FloatCallback | null`) to the
// component's `Data` and the concrete `DMenuInstance`.
type DMenuOptionArgs<Data> = Partial<
  Omit<MenuOptions, "data" | "component" | "onRegisterApi">
> & {
  /** The data passed to the content block and rendered component. */
  data?: Data;

  /** A component rendered as the content; it receives the `@data` and `@close` arguments. */
  component?: ComponentLike<{ Args: { data?: Data; close?: FloatCallback } }>;

  /** Called with the menu instance when it is created, so callers can control it programmatically. */
  onRegisterApi?: (instance: DMenuInstance) => void;
};

interface DMenuSignature<Data = unknown> {
  Element: HTMLElement;
  Args: DMenuOptionArgs<Data> & {
    // Arguments the component reads directly and forwards to the trigger button;
    // these are not keys of `MENU.options`.

    /** Called on keydown on the default trigger button. */
    onKeydown?: (event: KeyboardEvent) => unknown;

    /** A component rendered as the trigger, instead of the default button. */
    triggerComponent?: ComponentLike;

    /** The icon ID for the default trigger button. */
    icon?: string;

    /** The label for the default trigger button. */
    label?: string;

    /** The aria-label for the default trigger button. */
    ariaLabel?: string;

    /** The title for the default trigger button. */
    title?: string;

    /**
     * Disables the menu: the default trigger button renders disabled, and — for any trigger,
     * including a custom `@triggerComponent` — a trigger event (click/focus/hover/hold) no longer
     * opens the menu. It does not touch the trigger's focusability or ARIA; that stays the
     * caller's concern.
     */
    disabled?: boolean;

    /** Whether the default trigger button shows a loading state. */
    isLoading?: boolean;
  };
  Blocks: {
    /** The menu content; takes precedence over the `content` block. Yields the menu api. */
    default: [DMenuComponentArgs<Data>];

    /** Rendered as the trigger, replacing the default button. Yields the menu api. */
    trigger: [DMenuComponentArgs<Data>];

    /** The menu content, used when no default block is given. Yields the menu api. */
    content: [DMenuComponentArgs<Data>];
  };
}

/**
 * The declarative menu component: it renders a trigger (the default button, a
 * supplied `triggerComponent`, or a `trigger` block) and, while open, the menu
 * content in a positioned float. It creates and owns its own `DMenuInstance`,
 * populating the instance options from its arguments, so a template can drop in
 * a menu without touching the `menu` service. For a menu whose trigger is
 * managed separately through that service, see `DHeadlessMenu`.
 */
export default class DMenu<Data = unknown> extends Component<
  DMenuSignature<Data>
> {
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

  // Keeps the instance's open-veto in sync with `@disabled` reactively. The instance wires its
  // trigger listeners once (at registration), so the disabled state cannot ride in through the
  // one-time options snapshot; this re-runs whenever `@disabled` changes and gates the open.
  // Becoming disabled while open also closes the menu — a disabled control must not keep an
  // already-open overlay live (its content would stay interactive).
  syncDisabled = modifier((_element: HTMLElement, [disabled]: [boolean?]) => {
    const value = disabled ?? false;
    this.menuInstance.disabled = value;
    if (value && this.menuInstance.expanded) {
      this.menuInstance.close();
    }
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
    const instance = this.menuInstance;
    return {
      close: instance.close,
      show: instance.show,
      data: this.options.data as Data,
      // A getter (not a snapshot) so a consumer reading `expanded` subscribes to the
      // live tracked state and re-renders on open/close, without churning this object.
      get expanded() {
        return instance.expanded;
      },
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

    // The template forwards `@componentArgs` plus element attributes and a modifier that
    // the concrete trigger component (the default `DButton`, or a consumer-supplied one)
    // does not declare but honors at runtime, so the result is cast to a component type
    // describing that passthrough.
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
      {{this.syncDisabled @disabled}}
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
      {{#if this.menuInstance.renderInModal}}
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
