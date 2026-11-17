import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type { TrustedHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import bodyClass from "discourse/helpers/body-class";
import DButton from "discourse/ui-kit/d-button";

interface MatchWidthSignature {
  Element: HTMLElement;
  Args: {
    Positional: [source: HTMLElement | null | undefined];
  };
}

/**
 * Copies the source's width onto the element, and keeps copying it for as long
 * as the element lives.
 *
 * The bar is `position: fixed`, so its width cannot come from CSS: a percentage
 * would resolve against the viewport rather than against the column the bar is
 * meant to span.
 *
 * The bar does not take part in the layout, but the element it was rendered
 * into does, so that element is the column to span and is the default source.
 *
 * It observes the source rather than listening for `resize`, because the column
 * changes width without the window doing so: opening the sidebar re-splits the
 * layout grid, and a `resize` listener never hears about it.
 *
 * `offsetWidth` rather than `getBoundingClientRect()`, because the latter
 * reports visual pixels — under a scaled ancestor the width would be read in one
 * coordinate space and written back in another.
 */
const matchWidth = modifier<MatchWidthSignature>((element, [source]) => {
  const target = source ?? element.parentElement;

  if (!target) {
    return;
  }

  const apply = () => {
    element.style.width = `${target.offsetWidth}px`;
  };

  apply();

  const observer = new ResizeObserver(apply);
  observer.observe(target);

  return () => observer.disconnect();
});

interface DFloatingControlBarSignature {
  /** The bar itself. Attributes and modifiers pass through to it. */
  Element: HTMLDivElement;

  Args: {
    /**
     * What the bar is about, already translated.
     *
     * A plain string is escaped. To render markup, pass a value the consumer has
     * already run through `trustHTML` — the bar does not trust a string on the
     * consumer's behalf, because it cannot know where that string came from.
     */
    label: string | TrustedHTML;

    /** The save button's text, already translated. */
    saveLabel: string;

    /** The discard button's text, already translated. */
    discardLabel: string;

    /**
     * Save was pressed. Awaited: while it is pending the save button shows a
     * loading state and discard is disabled, so returning a promise keeps the
     * bar honest about work still in flight.
     */
    onSave: () => unknown;

    /** Discard was pressed. A notification; the return is ignored. */
    onDiscard: () => unknown;

    /**
     * The element the bar matches its width to. Defaults to the element the bar
     * was rendered into, which is normally the column it should span. Pass one
     * only when that parent is not the right box to measure.
     */
    widthSource?: HTMLElement | null;

    /**
     * An `id` for the save button, for consumers that need to address it
     * directly. The bar's own element takes attributes through `...attributes`;
     * this exists only because the button is nested inside it.
     */
    saveButtonId?: string;
  };
}

/**
 * A bar pinned to the bottom of the page, offering to save or discard changes
 * the user has made but not yet committed.
 *
 * It is `position: fixed`, so it takes no part in the layout of the page that
 * renders it and does not push content down. Instead it marks the document with
 * `d-floating-control-bar-visible`, and the stylesheet reserves room at the
 * bottom of the main outlet so the bar never covers the end of the content. A
 * consumer rendering the bar outside that outlet has to reserve the room itself.
 *
 * Being fixed also means its width cannot come from CSS, so it measures the
 * element it was rendered into and matches that.
 *
 * ```gjs
 * <DFloatingControlBar
 *   @label={{i18n "my_feature.unsaved_changes"}}
 *   @saveLabel={{i18n "my_feature.save"}}
 *   @discardLabel={{i18n "my_feature.discard"}}
 *   @onSave={{this.save}}
 *   @onDiscard={{this.discard}}
 * />
 * ```
 */
export default class DFloatingControlBar extends Component<DFloatingControlBarSignature> {
  @tracked isSaving = false;

  @action
  async save() {
    this.isSaving = true;

    try {
      await this.args.onSave();
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    {{bodyClass "d-floating-control-bar-visible"}}
    <div
      class="d-floating-control-bar"
      ...attributes
      {{matchWidth @widthSource}}
    >
      <span class="d-floating-control-bar__label">{{@label}}</span>
      <div class="d-floating-control-bar__controls">
        <DButton
          class="btn-default btn-small"
          @action={{@onDiscard}}
          @disabled={{this.isSaving}}
          @translatedLabel={{@discardLabel}}
        />
        <DButton
          class="btn-primary btn-small"
          @action={{this.save}}
          @id={{@saveButtonId}}
          @isLoading={{this.isSaving}}
          @translatedLabel={{@saveLabel}}
        />
      </div>
    </div>
  </template>
}
