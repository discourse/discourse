import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const DEFAULT_REFRESH_INTERVAL_HOURS = 24;
const MAX_URLS = 100;

function parseUrls(value) {
  return [
    ...new Set(
      value
        .split("\n")
        .map((url) => url.trim())
        .filter(Boolean)
    ),
  ];
}

function validUrl(value) {
  try {
    const url = new URL(value);
    return (
      ["http:", "https:"].includes(url.protocol) &&
      !url.username &&
      !url.password
    );
  } catch {
    return false;
  }
}

export default class RagDocumentSourcesModal extends Component {
  @cached
  get formData() {
    const sources = this.args.model.sources || [];

    return {
      urls: sources.map((source) => source.url).join("\n"),
      refresh_interval_hours:
        sources[0]?.refresh_interval_hours ?? DEFAULT_REFRESH_INTERVAL_HOURS,
    };
  }

  @action
  validateUrls(name, value, { addError }) {
    const urls = parseUrls(value);
    if (urls.length > MAX_URLS) {
      addError(name, {
        title: i18n("discourse_ai.rag.sources.urls"),
        message: i18n("discourse_ai.rag.sources.too_many", {
          count: MAX_URLS,
        }),
      });
      return;
    }

    const invalidUrl = urls.find((url) => !validUrl(url));
    if (invalidUrl) {
      addError(name, {
        title: i18n("discourse_ai.rag.sources.urls"),
        message: i18n("discourse_ai.rag.sources.invalid_url", {
          url: invalidUrl,
        }),
      });
    }
  }

  @action
  save(data) {
    this.args.model.onSave({
      urls: parseUrls(data.urls),
      refreshIntervalHours: data.refresh_interval_hours,
    });
    this.args.closeModal();
  }

  <template>
    <DModal
      class="rag-document-sources-modal"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n "discourse_ai.rag.sources.modal_title"}}
    >
      <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
        <form.Field
          @description={{i18n "discourse_ai.rag.sources.urls_description"}}
          @format="large"
          @name="urls"
          @title={{i18n "discourse_ai.rag.sources.urls"}}
          @type="textarea"
          @validate={{this.validateUrls}}
          as |field|
        >
          <field.Control
            class="rag-document-sources-modal__urls"
            @height={{220}}
          />
        </form.Field>

        <form.Field
          @name="refresh_interval_hours"
          @title={{i18n "discourse_ai.rag.sources.refresh_interval_hours"}}
          @type="input-number"
          @validation="required"
          as |field|
        >
          <field.Control @max={{8760}} @min={{1}} />
        </form.Field>

        <form.Actions>
          <form.Submit @label="discourse_ai.rag.sources.save" />
        </form.Actions>
      </Form>
    </DModal>
  </template>
}
