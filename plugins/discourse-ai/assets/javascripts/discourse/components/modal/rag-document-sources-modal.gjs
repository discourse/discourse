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
      @title={{i18n "discourse_ai.rag.sources.modal_title"}}
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      class="rag-document-sources-modal"
    >
      <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
        <form.Field
          @name="urls"
          @title={{i18n "discourse_ai.rag.sources.urls"}}
          @description={{i18n "discourse_ai.rag.sources.urls_description"}}
          @type="textarea"
          @validate={{this.validateUrls}}
          @format="large"
          as |field|
        >
          <field.Control
            @height={{220}}
            class="rag-document-sources-modal__urls"
          />
        </form.Field>

        <form.Field
          @name="refresh_interval_hours"
          @title={{i18n "discourse_ai.rag.sources.refresh_interval_hours"}}
          @validation="required"
          @type="input-number"
          as |field|
        >
          <field.Control @min={{1}} @max={{8760}} />
        </form.Field>

        <form.Actions>
          <form.Submit @label="discourse_ai.rag.sources.save" />
        </form.Actions>
      </Form>
    </DModal>
  </template>
}
