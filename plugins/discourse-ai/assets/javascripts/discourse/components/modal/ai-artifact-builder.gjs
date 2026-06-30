import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AiArtifactBuilder extends Component {
  formApi = null;

  constructor() {
    super(...arguments);
    if (this.editingArtifactId) {
      this.loadArtifact();
    }
  }

  get editingArtifactId() {
    return this.args.model.artifactId;
  }

  get title() {
    return this.editingArtifactId
      ? "discourse_ai.ai_artifact.composer.edit_title"
      : "discourse_ai.ai_artifact.composer.insert_title";
  }

  get submitLabel() {
    return this.editingArtifactId
      ? "discourse_ai.ai_artifact.save_label"
      : "discourse_ai.ai_artifact.composer.insert_button";
  }

  @cached
  get formData() {
    return { name: "", html: "", css: "", js: "" };
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  async loadArtifact() {
    try {
      const data = await ajax(
        `/discourse-ai/ai-bot/artifacts/${this.editingArtifactId}/latest.json`
      );
      this.formApi?.set("name", data.name || "");
      this.formApi?.set("html", data.html || "");
      this.formApi?.set("css", data.css || "");
      this.formApi?.set("js", data.js || "");
    } catch (e) {
      popupAjaxError(e);
      this.args.closeModal();
    }
  }

  @action
  async submit(data) {
    try {
      if (this.editingArtifactId) {
        await ajax(
          `/discourse-ai/ai-bot/artifacts/${this.editingArtifactId}.json`,
          {
            type: "PUT",
            data: {
              name: data.name || "Untitled",
              html: data.html,
              css: data.css,
              js: data.js,
            },
          }
        );
        this.args.model.onSaved?.();
      } else {
        const result = await ajax("/discourse-ai/ai-bot/artifacts.json", {
          type: "POST",
          data: {
            name: data.name || "Untitled",
            html: data.html,
            css: data.css,
            js: data.js,
          },
        });
        this.args.model.toolbarEvent.addText(
          `<div class="ai-artifact" data-ai-artifact-id="${result.id}" data-ai-artifact-version="latest"></div>`
        );
      }
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @title={{i18n this.title}}
      @closeModal={{@closeModal}}
      class="ai-artifact-builder-modal"
    >
      <:body>
        <Form
          @data={{this.formData}}
          @onSubmit={{this.submit}}
          @onRegisterApi={{this.registerApi}}
          as |form|
        >
          <form.Field
            @name="name"
            @title={{i18n "discourse_ai.ai_artifact.composer.name_label"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control />
          </form.Field>

          <form.Field
            @name="html"
            @title={{i18n "discourse_ai.ai_artifact.composer.html_label"}}
            @type="textarea"
            @validation="required"
            as |field|
          >
            <field.Control @height={{200}} />
          </form.Field>

          <form.Field
            @name="css"
            @title={{i18n "discourse_ai.ai_artifact.composer.css_label"}}
            @type="textarea"
            as |field|
          >
            <field.Control @height={{200}} />
          </form.Field>

          <form.Field
            @name="js"
            @title={{i18n "discourse_ai.ai_artifact.composer.js_label"}}
            @type="textarea"
            as |field|
          >
            <field.Control @height={{200}} />
          </form.Field>

          <form.Submit @label={{this.submitLabel}} />
        </Form>
      </:body>
    </DModal>
  </template>
}
