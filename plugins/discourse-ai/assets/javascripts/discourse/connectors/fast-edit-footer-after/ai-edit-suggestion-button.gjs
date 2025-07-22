import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { showPostAIHelper } from "../../lib/show-ai-helper";

export default class AiEditSuggestionButton extends Component {
  static shouldRender(outletArgs, helper) {
    return showPostAIHelper(outletArgs, helper);
  }

  @service currentUser;

  @tracked loading = false;
  @tracked suggestion = "";
  @tracked _activeAIRequest = null;

  get disabled() {
    return this.loading || this.suggestion?.length > 0;
  }

  get mode() {
    return this.currentUser?.ai_helper_prompts.find(
      (prompt) => prompt.name === "proofread"
    );
  }

  @action
  suggest() {
    this.loading = true;
    this._activeAIRequest = ajax("/discourse-ai/ai-helper/suggest", {
      method: "POST",
      data: {
        mode: this.mode.name,
        text: this.args.outletArgs.initialValue,
        custom_prompt: "",
      },
    });

    this._activeAIRequest
      .then(({ suggestions }) => {
        this.suggestion = suggestions[0].trim();
        this.args.outletArgs.updateValue(this.suggestion);
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.loading = false;
      });

    return this._activeAIRequest;
  }

  <template>
    {{#unless @outletArgs.newValue}}
      <DButton
        class="btn-small btn-ai-suggest-edit"
        @action={{this.suggest}}
        @icon="discourse-sparkles"
        @label="discourse_ai.ai_helper.fast_edit.suggest_button"
        @isLoading={{this.loading}}
        @disabled={{this.disabled}}
      />
    {{/unless}}
  </template>
}
