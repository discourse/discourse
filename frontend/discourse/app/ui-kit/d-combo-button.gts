import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import type { WithBoundArgs } from "@glint/template";
import curryComponent from "ember-curry-component";
import DMenu, { DMenuSignature } from "discourse/float-kit/components/d-menu";
import { or } from "discourse/truth-helpers";
import DButton, { DButtonSignature } from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/** Arguments the group supplies to a half, which must not reach `DButton`/`DMenu`. */
const GROUP_ARGS = ["hasMenu", "btnTypeClass"];

function forwardedArgs(args: object): Record<string, unknown> {
  const forwarded: Record<string, unknown> = { ...args };
  GROUP_ARGS.forEach((name) => delete forwarded[name]);
  return forwarded;
}

interface GroupArgs {
  /** A `btn-*` class applied to both halves, so a call site states the variant once. */
  btnTypeClass?: string;
}

interface ButtonSignature {
  Element: HTMLButtonElement;
  Args: DButtonSignature["Args"] & GroupArgs;
  Blocks: { default: [] };
}

interface MenuSignature {
  Element: HTMLElement;
  Args: DMenuSignature["Args"] &
    GroupArgs & {
      /** Curried in by the group; the menu renders only when it is true. */
      hasMenu?: boolean;
    };
  Blocks: { default: [] };
}

class Button extends Component<ButtonSignature> {
  get buttonArgs() {
    return forwardedArgs(this.args);
  }

  <template>
    {{#let (curryComponent DButton this.buttonArgs) as |CurriedComponent|}}
      {{! A per-half class arrives as a splatted attribute, which Glimmer appends
          to this one rather than replacing it, so a call site can add to the
          group's variant without restating it. }}
      <CurriedComponent
        class={{dConcatClass "d-combo-button-button" @btnTypeClass}}
        ...attributes
      >
        {{yield}}
      </CurriedComponent>
    {{/let}}
  </template>
}

class Menu extends Component<MenuSignature> {
  get menuArgs() {
    return forwardedArgs(this.args);
  }

  <template>
    {{#if @hasMenu}}
      {{#let (curryComponent DMenu this.menuArgs) as |CurriedComponent|}}
        {{! The trigger sits at the group's trailing edge, so the float aligns
            there. Both defaults are written as fallbacks because invocation-site
            arguments beat curried ones, which would otherwise make them
            overrides. }}
        <CurriedComponent
          @icon={{or @icon "chevron-down"}}
          @placement={{or @placement "bottom-end"}}
          class={{dConcatClass "d-combo-button-menu" @btnTypeClass}}
          ...attributes
        >
          <:content>
            {{yield}}
          </:content>
        </CurriedComponent>
      {{/let}}
    {{/if}}
  </template>
}

/** The two halves yielded to the block, pre-bound to the group's own arguments. */
export interface DComboButtonParts {
  Button: WithBoundArgs<typeof Button, "btnTypeClass">;
  Menu: WithBoundArgs<typeof Menu, "hasMenu" | "btnTypeClass">;
}

interface DComboButtonSignature {
  Element: HTMLDivElement;
  Args: GroupArgs & {
    /**
     * Whether the group has a menu. Decides both whether `combo.Menu` renders and
     * whether `--has-menu` is published, so the two can never disagree.
     */
    hasMenu?: boolean;
  };
  Blocks: { default: [DComboButtonParts] };
}

/**
 * A button paired with an optional dropdown menu, rendered as one joined control.
 *
 * Pass `@hasMenu` rather than adding `--has-menu` by hand: the group publishes
 * that class itself and uses the same flag to decide whether the menu renders.
 *
 * @example
 * ```gjs
 * <DComboButton @hasMenu={{this.hasDrafts}} @btnTypeClass="btn-default" as |combo|>
 *   <combo.Button @label="topic.create" @action={{this.createTopic}} />
 *   <combo.Menu @identifier="drafts">
 *     <DDropdownMenu as |dropdown|>…</DDropdownMenu>
 *   </combo.Menu>
 * </DComboButton>
 * ```
 */
export default class DComboButton extends Component<DComboButtonSignature> {
  /**
   * The yielded halves, each bound to the arguments the group supplies. Cached so
   * a rerender hands the block the same component classes rather than freshly
   * curried ones, which would tear the control down and rebuild it.
   */
  @cached
  get parts(): DComboButtonParts {
    const owner = getOwner(this)!;
    const { hasMenu, btnTypeClass } = this.args;

    return {
      Button: curryComponent(Button, { btnTypeClass }, owner),
      Menu: curryComponent(Menu, { hasMenu, btnTypeClass }, owner),
    };
  }

  <template>
    {{! Themes select this modifier class, so it stays published even where core
        stops depending on it. }}
    <div
      class={{dConcatClass "d-combo-button" (if @hasMenu "--has-menu")}}
      role="group"
      ...attributes
    >
      {{yield (hash Button=this.parts.Button Menu=this.parts.Menu)}}
    </div>
  </template>
}
