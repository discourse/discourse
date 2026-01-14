import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { jsonToHtml } from "../../lib/utilities";

export default class AiToolTestModal extends Component {
  @tracked testResult;
  @tracked isLoading = false;
  parameterValues = {};

  @action
  updateParameter(name, event) {
    this.parameterValues[name] = event.target.value;
  }

  @action
  async runTest() {
    this.isLoading = true;
    try {
      const response = await ajax(
        `/admin/plugins/discourse-ai/ai-tools/${this.args.model.tool.id}/test.json`,
        {
          type: "POST",
          data: JSON.stringify({
            ai_tool: this.args.model.tool,
            parameters: this.parameterValues,
          }),
          contentType: "application/json",
        }
      );
      this.testResult = jsonToHtml(response.output);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_ai.tools.test_modal.title"}}
      @closeModal={{@closeModal}}
      @bodyClass="ai-tool-test-modal__body"
      class="ai-tool-test-modal"
    >
      <:body>
        {{#each @model.tool.parameters as |param|}}
          <div class="control-group">
            <label>{{param.name}}</label>
            <input
              {{on "input" (fn this.updateParameter param.name)}}
              name={{param.name}}
              type="text"
            />
          </div>
        {{/each}}

        {{#if this.testResult}}
          <div class="ai-tool-test-modal__test-result">
            <h3>{{i18n "discourse_ai.tools.test_modal.result"}}</h3>
            <div>{{this.testResult}}</div>
          </div>
        {{/if}}
      </:body>

      <:footer>
        <DButton
          @action={{this.runTest}}
          @label="discourse_ai.tools.test_modal.run"
          @disabled={{this.isLoading}}
          class="btn-primary ai-tool-test-modal__run-button"
        />
      </:footer>
    </DModal>
  </template>
}
