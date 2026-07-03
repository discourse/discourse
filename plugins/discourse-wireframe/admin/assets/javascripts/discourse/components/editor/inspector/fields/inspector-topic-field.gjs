import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { isPresent } from "@ember/utils";
import Topic from "discourse/models/topic";
import TopicChooser from "discourse/select-kit/components/topic-chooser";

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
export default class InspectorTopicField extends Component {
  @tracked _selectedTopic;

  constructor() {
    super(...arguments);

    // Resolve the saved id to its topic so the chooser can render the title
    // rather than the bare id on first paint.
    if (isPresent(this.args.custom.value)) {
      this.#loadSelectedTopic(this.args.custom.value);
    }
  }

  /**
   * The chooser's content: the resolved topic (if any) so it can display the
   * title for the current value. Search results are merged in by the chooser.
   *
   * @returns {Array} A single-element array with the resolved topic, or empty.
   */
  get selectedTopicContent() {
    return this._selectedTopic ? [this._selectedTopic] : [];
  }

  /**
   * Commits the chosen topic id back to the field and keeps the resolved topic
   * around so the chooser keeps showing its title. The chooser is clearable, so
   * both arguments are null when the author clears the selection.
   *
   * @param {number|null} topicId - The selected topic id, or null when cleared.
   * @param {Object|null} topic - The selected topic, or null when cleared.
   */
  @action
  onChange(topicId, topic) {
    this._selectedTopic = topic;
    this.args.custom.set(topicId);
  }

  /**
   * Resolves a topic id to its topic and seeds it into the chooser content.
   *
   * @param {number} topicId - The saved topic id to resolve.
   */
  async #loadSelectedTopic(topicId) {
    try {
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
