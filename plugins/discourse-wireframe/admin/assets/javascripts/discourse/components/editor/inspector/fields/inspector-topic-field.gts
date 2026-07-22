import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { isPresent } from "@ember/utils";
import { type ComponentLike } from "@glint/template";
import Topic from "discourse/models/topic";
import TopicChooserUntyped from "discourse/select-kit/components/topic-chooser";

type TopicFieldData = {
  /** Current FormKit field value. */
  value: unknown;
  /** Writes a replacement FormKit field value. */
  set: (value: unknown) => void | Promise<void>;
};

// TODO(devxp-typescript-pending): replace `TopicFieldData` once FormKit exports
// the type of the field data yielded by a custom control.

interface InspectorTopicFieldSignature {
  /** Topic value supplied by FormKit. */
  Args: {
    /** FormKit field data read and updated by the picker. */
    custom: TopicFieldData;
  };
}

// TODO(devxp-typescript-pending): import TopicChooser directly once its
// select-kit implementation exports a Glint signature.
const TopicChooser = TopicChooserUntyped as unknown as ComponentLike<{
  /** Topic chooser arguments. */
  Args: {
    /** Selected topic id. */
    value: unknown;
    /** Topic models available to display. */
    content: Topic[];
    /** Called with the selected topic. */
    onChange: (
      /** Selected topic id, or `null` when cleared. */
      topicId: number | null,
      /** Selected topic model, or `null` when cleared. */
      topic: Topic | null
    ) => void;
    /** Select-kit configuration. */
    options: {
      /** Whether option values are converted to integers. */
      castInteger: boolean;
    };
  };
}>;

/**
 * Entity picker for `ui.control: "topic-select"`. Wraps the `TopicChooser`
 * combo box so an author can search for and pick a single topic instead of
 * typing its numeric id. The chooser is single-select and its value is the
 * topic id, so it binds directly to the field value.
 *
 * The chooser can only display a topic's title for ids that are in its
 * `content`, and search only populates content for the current query. So when
 * the field mounts with an already-saved id, we resolve that id to its topic
 * and seed it into `content` — otherwise the chooser would show the raw id
 * instead of the topic title. This mirrors the core single-topic site-setting
 * picker (`admin/components/site-settings/topic.gjs`).
 *
 * `@custom` is the FormKit field object yielded from `<formField.Control>`;
 * we read the current id from `@custom.value` and commit changes through
 * `@custom.set`.
 */
export default class InspectorTopicField extends Component<InspectorTopicFieldSignature> {
  /** Resolved model for the selected topic id. */
  @tracked _selectedTopic: Topic | null = null;

  /**
   * Creates the topic field and resolves its initial selected topic.
   *
   * @param owner - Ember owner for the component instance.
   * @param args - Topic value supplied by FormKit.
   */
  constructor(owner: Owner, args: InspectorTopicFieldSignature["Args"]) {
    super(owner, args);

    // Resolve the saved id to its topic so the chooser can render the title
    // rather than the bare id on first paint.
    if (isPresent(this.args.custom.value)) {
      // TODO(devxp-typescript-pending): the FormKit field value is `unknown`;
      // the presence check gates the load and the id is forwarded as-stored to
      // the model lookup.
      void this.#loadSelectedTopic(this.args.custom.value as number | string);
    }
  }

  /**
   * The chooser's content: the resolved topic (if any) so it can display the
   * title for the current value. Search results are merged in by the chooser.
   *
   * @returns A single-element array with the resolved topic, or empty.
   */
  get selectedTopicContent(): Topic[] {
    return this._selectedTopic ? [this._selectedTopic] : [];
  }

  /**
   * Commits the chosen topic id back to the field and keeps the resolved topic
   * around so the chooser keeps showing its title. The chooser is clearable, so
   * both arguments are null when the author clears the selection.
   *
   * @param topicId - The selected topic id, or null when cleared.
   * @param topic - The selected topic, or null when cleared.
   */
  @action
  onChange(topicId: number | null, topic: Topic | null): void {
    this._selectedTopic = topic;
    this.args.custom.set(topicId);
  }

  /**
   * Resolves a topic id to its topic and seeds it into the chooser content.
   *
   * @param topicId - The saved topic id to resolve.
   */
  async #loadSelectedTopic(topicId: number | string): Promise<void> {
    try {
      // TODO(devxp-typescript-pending): remove the explicit result annotation
      // once `Topic.find` declares its resolved model type.
      this._selectedTopic = await Topic.find(topicId, {});
    } catch {
      // The topic may have been deleted; the chooser falls back to the raw id.
    }
  }

  <template>
    <TopicChooser
      @value={{@custom.value}}
      @content={{this.selectedTopicContent}}
      @onChange={{this.onChange}}
      @options={{hash castInteger=true}}
    />
  </template>
}
