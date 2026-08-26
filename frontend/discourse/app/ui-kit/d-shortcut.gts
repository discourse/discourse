import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import type { TOC } from "@ember/component/template-only";
import { getOwner } from "@ember/owner";
import type { WithBoundArgs } from "@glint/template";
import curryComponent from "ember-curry-component";
import {
  formatShortcut,
  type FormattedShortcut,
  type ShortcutKey,
} from "discourse/lib/shortcut-format";
import { notEq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

interface KbdSignature {
  Args: {
    keys: ShortcutKey[];
    /** Hide from assistive technology, for a chip beside an element that announces the shortcut itself. */
    hidden?: boolean;
  };
  Element: HTMLElement;
}

/**
 * The drawn form: one `<kbd>` per key inside a `<kbd>` for the combination.
 * A key drawn as a glyph also carries its spelled-out name for assistive
 * technology, hidden visually, so `⌘` is read as "Command" rather than as a
 * symbol name or nothing.
 */
const Kbd: TOC<KbdSignature> = <template>
  {{#if @keys.length}}
    <kbd
      class="d-shortcut"
      dir="ltr"
      aria-hidden={{if @hidden "true"}}
      ...attributes
    >
      {{#each @keys key="key" as |key|}}
        <kbd
          class={{dConcatClass
            "d-shortcut__key"
            (if (notEq key.name key.label) "d-shortcut__key--glyph")
          }}
        >
          {{#if (notEq key.name key.label)}}
            <span aria-hidden="true">{{key.label}}</span>
            <span class="sr-only">{{key.name}}</span>
          {{else}}
            {{key.label}}
          {{/if}}
        </kbd>
      {{/each}}
    </kbd>
  {{/if}}
</template>;

/** What the block form yields: both forms of the shortcut, from one spelling. */
export interface DShortcutParts extends FormattedShortcut {
  /**
   * The drawn form, pre-bound to the same keys and hidden from assistive
   * technology, since the element carrying `aria` announces the shortcut.
   * Accepts `...attributes`.
   */
  Kbd: WithBoundArgs<typeof Kbd, "keys" | "hidden">;
}

interface DShortcutSignature {
  Args: {
    /**
     * The shortcut in binding spelling: `+`-joined, case-insensitive, with
     * `mod` for the platform's primary modifier (`mod+enter`, `ctrl+alt+f`).
     * With none, the block form yields `aria: undefined` and a `Kbd` that
     * renders nothing, so a wrapper can be unconditional.
     */
    keys?: string | null;
  };
  Blocks: {
    default: [DShortcutParts];
  };
  Element: HTMLElement;
}

/**
 * Displays a keyboard shortcut, and announces it, from one spelling.
 *
 * Without a block it draws the shortcut as keycaps:
 *
 * ```gjs
 * <DShortcut @keys="mod+/" class="sidebar-search__shortcut-hint" />
 * ```
 *
 * With a block it renders no element of its own and instead yields both forms
 * (`aria`, `label`, `keys`, and a bound `Kbd` component), so the element the
 * shortcut activates and the drawn keycaps beside it cannot disagree:
 *
 * ```gjs
 * <DShortcut @keys="mod+enter" as |shortcut|>
 *   <DButton @action={{@save}} aria-keyshortcuts={{shortcut.aria}}>
 *     {{i18n "composer.save"}}
 *     <shortcut.Kbd />
 *   </DButton>
 * </DShortcut>
 * ```
 *
 * `aria-keyshortcuts` is never set by the component itself: it belongs on the
 * element that reacts to the keys, which only the caller knows. The yielded
 * `Kbd` is hidden from assistive technology for the same reason: the activator
 * announces the shortcut, and a readable chip inside it would fold the key
 * names into its accessible name. Attributes on the block-form invocation are
 * dropped, since nothing is rendered to carry them; put them on `shortcut.Kbd`.
 */
export default class DShortcut extends Component<DShortcutSignature> {
  /** Both forms of the shortcut, recomputed only when `@keys` changes. */
  @cached
  get formatted(): FormattedShortcut {
    return formatShortcut(this.args.keys);
  }

  /**
   * The yielded forms plus the bound `Kbd`. Cached so a rerender hands the
   * block the same component class rather than a freshly curried one, which
   * would tear the keycaps down and rebuild them.
   */
  @cached
  get parts(): DShortcutParts {
    const formatted = this.formatted;

    return {
      ...formatted,
      Kbd: curryComponent(
        Kbd,
        { keys: formatted.keys, hidden: true },
        getOwner(this)!
      ),
    };
  }

  <template>
    {{#if (has-block)}}
      {{yield this.parts}}
    {{else}}
      <Kbd @keys={{this.formatted.keys}} ...attributes />
    {{/if}}
  </template>
}
