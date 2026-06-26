// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import { ICON_NAME_PATTERN } from "discourse/lib/blocks";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_VARIANTS = ["primary", "default", "danger"];

/**
 * A button that opens the topic composer pre-filled with a category and tags —
 * an "ask a question" / "start a discussion" call to action. Unlike
 * `button-link` (which navigates to an `href`), this block performs a live
 * action, so it stays inert in an editing/preview context: clicking it while
 * editing must not open the composer over the author's canvas.
 */
@block("new-topic-button", {
  displayName: "New topic button",
  icon: "plus",
  category: "Navigation",
  description:
    "A button that opens the composer to start a new topic in a category.",
  args: {
    label: {
      type: "richInline",
      ui: {
        control: "rich-inline",
        schema: "plain",
        label: i18n("blocks.builtin.new_topic_button.label"),
      },
    },
    categoryId: {
      type: "number",
      ui: {
        control: "category-select",
        label: i18n("blocks.builtin.new_topic_button.category_id"),
      },
    },
    tags: {
      type: "array",
      itemType: "string",
      default: [],
      ui: {
        // No explicit control: an array of strings auto-maps to the tag
        // chooser in the inspector (see schema-to-fields `pickControl`).
        label: i18n("blocks.builtin.new_topic_button.tags"),
      },
    },
    prefillTitle: {
      type: "string",
      ui: {
        label: i18n("blocks.builtin.new_topic_button.prefill_title"),
        helpText: i18n("blocks.builtin.new_topic_button.prefill_title_help"),
      },
    },
    variant: {
      type: "string",
      default: "primary",
      enum: VALID_VARIANTS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.new_topic_button.variant"),
      },
    },
    icon: {
      type: "string",
      pattern: ICON_NAME_PATTERN,
      ui: {
        control: "icon",
        label: i18n("blocks.builtin.new_topic_button.icon"),
      },
    },
  },
  constraints: {
    atLeastOne: ["label", "icon"],
  },
})
export default class NewTopicButton extends Component {
  @service composer;

  /**
   * Composes the DButton class list, mixing the block BEM root with the
   * variant-derived core button class.
   *
   * @returns {string}
   */
  get btnClass() {
    return `d-block-new-topic-button btn-${this.args.variant ?? "primary"}`;
  }

  /**
   * Whether the block is rendered in an editing / preview context. The click
   * is suppressed while this is true so the composer never opens over the
   * editing canvas.
   *
   * @returns {boolean}
   */
  get #isEditing() {
    return debugHooks.isEditPresentation;
  }

  /**
   * The resolved category model for the configured `categoryId`, or `null`
   * when none is set or the id doesn't resolve. `openNewTopic` reads `id` and
   * `canCreateTopic` off the model, so a bare id isn't enough.
   *
   * @returns {import("discourse/models/category").default | null}
   */
  get #category() {
    return this.args.categoryId
      ? Category.findById(this.args.categoryId)
      : null;
  }

  /**
   * Opens the composer pre-filled with the configured category, tags, and
   * title. No-ops in an editing/preview context so authoring the block never
   * launches the composer.
   */
  @action
  openComposer() {
    if (this.#isEditing) {
      return;
    }

    this.composer.openNewTopic({
      category: this.#category,
      tags: this.args.tags ?? [],
      title: this.args.prefillTitle,
    });
  }

  <template>
    <DButton class={{this.btnClass}} @action={{this.openComposer}}>
      <span
        class="d-block-inline-icon
          {{unless @icon 'd-block-inline-icon--empty'}}"
        data-block-arg="icon"
      >
        {{#if @icon}}
          {{dIcon @icon}}
        {{/if}}
      </span>
      <RichTextRenderer
        @arg="label"
        @schema="plain"
        @value={{@label}}
        @placeholder={{i18n
          "blocks.builtin.placeholders.new_topic_button_label"
        }}
        as |R|
      >
        <span class="d-button-label"><R.Content /></span>
      </RichTextRenderer>
    </DButton>
  </template>
}
