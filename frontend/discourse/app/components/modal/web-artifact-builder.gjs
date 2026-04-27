import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class WebArtifactBuilder extends Component {
  @tracked name = "";
  @tracked html = "";
  @tracked css = "";
  @tracked js = "";
  @tracked loading = false;

  get insertDisabled() {
    return this.loading || (!this.html && !this.css && !this.js);
  }

  @action
  updateName(event) {
    this.name = event.target.value;
  }

  @action
  async insertArtifact() {
    this.loading = true;
    try {
      const result = await ajax("/web-artifacts.json", {
        type: "POST",
        data: {
          name: this.name || "Untitled",
          html: this.html,
          css: this.css,
          js: this.js,
        },
      });

      this.args.model.toolbarEvent.addText(
        `<div class="web-artifact" data-web-artifact-id="${result.id}"></div>`
      );
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "web_artifact.composer_title"}}
      @closeModal={{@closeModal}}
      class="web-artifact-builder-modal"
    >
      <:body>
        <div class="web-artifact-builder__field">
          <label>{{i18n "web_artifact.composer_name_label"}}</label>
          <input
            type="text"
            value={{this.name}}
            {{on "input" this.updateName}}
            class="web-artifact-builder__name-input"
          />
        </div>
        <div class="web-artifact-builder__field">
          <label>{{i18n "web_artifact.composer_html_label"}}</label>
          <Textarea
            @value={{this.html}}
            class="web-artifact-builder__code-input"
          />
        </div>
        <div class="web-artifact-builder__field">
          <label>{{i18n "web_artifact.composer_css_label"}}</label>
          <Textarea
            @value={{this.css}}
            class="web-artifact-builder__code-input"
          />
        </div>
        <div class="web-artifact-builder__field">
          <label>{{i18n "web_artifact.composer_js_label"}}</label>
          <Textarea
            @value={{this.js}}
            class="web-artifact-builder__code-input"
          />
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{this.insertArtifact}}
          @label="web_artifact.composer_insert"
          @disabled={{this.insertDisabled}}
          @isLoading={{this.loading}}
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
