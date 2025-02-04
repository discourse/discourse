import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { translateModKey } from "discourse/lib/utilities";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";

export default class FastEdit extends Component {
  @tracked isSaving = false;
  @tracked value = this.args.newValue || this.args.initialValue;

  buttonTitle = i18n("composer.title", {
    modifier: translateModKey("Meta+"),
  });

  get disabled() {
    return this.value === this.args.initialValue;
  }

  @action
  onKeydown(event) {
    if (
      event.key === "Enter" &&
      (event.ctrlKey || event.metaKey) &&
      !this.disabled
    ) {
      this.save();
    }
  }

  @action
  updateValue(event) {
    event.preventDefault();
    this.value = event.target.value;
  }

  @action
  updateValueProperty(value) {
    this.value = value;
  }

  @action
  async save() {
    this.isSaving = true;

    try {
      const result = await ajax(`/posts/${this.args.post.id}`);
      const newRaw = result.raw.replace(this.args.initialValue, this.value);

      // Warn the user if we failed to update the post
      if (newRaw === result.raw) {
        throw new Error(
          "Failed to update the post. Did your fast edit include a special character?"
        );
      }

      await this.args.post.save({ raw: newRaw });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSaving = false;
      this.args.close();
    }
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    {{! template-lint-disable no-invalid-interactive }}
    <div class="fast-edit-container" {{on "keydown" this.onKeydown}}>
      <textarea
        {{on "input" this.updateValue}}
        id="fast-edit-input"
        {{autoFocus}}
      >{{this.value}}</textarea>

      <div class="fast-edit-container__footer">
        <DButton
          class="btn-small btn-primary save-fast-edit"
          @action={{this.save}}
          @icon="pencil"
          @label="composer.save_edit"
          @translatedTitle={{this.buttonTitle}}
          @isLoading={{this.isSaving}}
          @disabled={{this.disabled}}
        />

        <PluginOutlet
          @name="fast-edit-footer-after"
          @defaultGlimmer={{true}}
          @outletArgs={{hash
            initialValue=@initialValue
            newValue=@newValue
            updateValue=this.updateValueProperty
          }}
        />
      </div>
    </div>
  </template>
}
