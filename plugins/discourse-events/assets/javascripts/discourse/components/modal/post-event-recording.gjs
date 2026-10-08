import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { extractError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { setEventAttribute } from "../../lib/raw-event-helper";
import { savePostRaw } from "../../lib/save-post-raw";

// Sets just the event's recording link, so adding one after the stream does
// not mean going through (and rewriting) the whole event.
export default class PostEventRecording extends Component {
  @service store;

  @tracked flash = null;

  data = { recordingUrl: this.event.recordingUrl ?? "" };

  get event() {
    return this.args.model.event;
  }

  get title() {
    return this.event.recordingUrl
      ? i18n("discourse_post_event.recording_modal.edit_title")
      : i18n("discourse_post_event.recording_modal.add_title");
  }

  @action
  async save(data) {
    await this.#update(data.recordingUrl);
  }

  @action
  async remove() {
    await this.#update(null);
  }

  async #update(recordingUrl) {
    this.flash = null;

    try {
      const post = await this.store.find("post", this.event.id);
      const raw = setEventAttribute(post.raw, "recording", recordingUrl);
      if (!raw) {
        this.flash = i18n("discourse_post_event.recording_modal.no_event");
        return;
      }

      await savePostRaw(
        post,
        raw,
        i18n("discourse_post_event.recording_modal.edit_reason")
      );
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  <template>
    <DModal
      class="post-event-recording-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @inline={{@inline}}
      @title={{this.title}}
    >
      <:body>
        <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
          <form.Field
            @format="full"
            @name="recordingUrl"
            @title={{i18n "discourse_post_event.recording_modal.label"}}
            @type="input-url"
            @validation="required|url"
            as |field|
          >
            <field.Control autofocus placeholder="https://" />
          </form.Field>

          <form.Actions>
            <form.Submit @label="discourse_post_event.recording_modal.save" />
            {{#if this.event.recordingUrl}}
              <form.Button
                class="btn-transparent --danger"
                @action={{this.remove}}
                @label="discourse_post_event.recording_modal.remove"
              />
            {{/if}}
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
