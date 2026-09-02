import { Input } from "@ember/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedArray, trackedObject } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { removeValueFromArray } from "discourse/lib/array-tools";
import DButton from "discourse/ui-kit/d-button";
import DEditor from "discourse/ui-kit/d-editor";
import { i18n } from "discourse-i18n";
import PlaceholdersList from "../placeholders-list";
import BaseField from "./da-base-field";
import DAFieldLabel from "./da-field-label";

export default class PmsField extends BaseField {
  @service dialog;

  noPmCreatedLabel = i18n("discourse_automation.fields.pms.no_pm_created");

  delayLabel = i18n("discourse_automation.fields.pms.delay.label");

  pmTitleLabel = i18n("discourse_automation.fields.pms.title.label");

  rawLabel = i18n("discourse_automation.fields.pms.raw.label");

  <template>
    <section class="field pms-field">
      {{#if @field.metadata.value.length}}
        <section class="actions header">
          <DAFieldLabel @field={{@field}} @label={{@label}} />
          <DButton
            class="btn-primary insert-pm"
            @action={{this.insertPM}}
            @icon="plus"
          />
        </section>
      {{/if}}

      {{#each @field.metadata.value as |pm|}}
        <div class="pm-field">
          <div class="control-group">
            <DAFieldLabel @field={{@field}} @label={{this.pmTitleLabel}} />
            <div class="controls">
              <div class="field-wrapper">
                <Input
                  class="pm-input pm-title"
                  disabled={{@field.isDisabled}}
                  id={{concat @field.targetType @field.name "title"}}
                  name={{@field.name}}
                  @value={{pm.title}}
                  {{on "input" (fn this.mutPmTitle pm)}}
                />

                {{#if this.displayPlaceholders}}
                  <PlaceholdersList
                    @currentValue={{pm.title}}
                    @onCopy={{fn this.updatePmTitle pm}}
                    @placeholders={{@placeholders}}
                  />
                {{/if}}
              </div>
            </div>
          </div>

          <div class="control-group">
            <DAFieldLabel @field={{@field}} @label={{this.rawLabel}} />
            <div class="controls">
              <div class="field-wrapper">
                <DEditor @value={{pm.raw}} />

                {{#if this.displayPlaceholders}}
                  <PlaceholdersList
                    @currentValue={{pm.raw}}
                    @onCopy={{fn this.updatePmRaw pm}}
                    @placeholders={{@placeholders}}
                  />
                {{/if}}
              </div>
            </div>
          </div>

          <div class="control-group">
            <label class="control-label">
              {{this.delayLabel}}
            </label>

            <div class="controls">
              <Input
                class="input-large pm-input pm-delay"
                disabled={{@field.isDisabled}}
                @value={{pm.delay}}
                {{on "input" (fn this.mutPmDelay pm)}}
              />
            </div>
          </div>

          <section class="actions">
            <DButton
              class="btn-danger"
              @action={{fn this.removePM pm}}
              @disabled={{@field.isDisabled}}
              @icon="trash-can"
            />
          </section>
        </div>
      {{else}}
        <div class="no-pm">
          <p>{{this.noPmCreatedLabel}}</p>
          <DButton
            class="btn-primary insert-pm"
            @action={{this.insertPM}}
            @disabled={{@field.isDisabled}}
            @icon="plus"
            @label="discourse_automation.fields.pms.add_pm"
          />
        </div>
      {{/each}}
    </section>
  </template>

  constructor() {
    super(...arguments);

    // a hack to prevent warnings about modifying multiple times in the same runloop
    next(() => {
      this.args.field.metadata.value = trackedArray(
        (this.args.field.metadata.value || []).map((pm) => {
          return trackedObject(pm);
        })
      );
    });
  }

  @action
  removePM(pm) {
    this.dialog.yesNoConfirm({
      message: i18n("discourse_automation.fields.pms.confirm_remove_pm"),
      didConfirm: () => {
        return removeValueFromArray(this.args.field.metadata.value, pm);
      },
    });
  }

  @action
  insertPM() {
    this.args.field.metadata.value.push(
      trackedObject({
        title: "",
        raw: "",
        delay: 0,
      })
    );
  }

  @action
  mutPmTitle(pm, event) {
    pm.title = event.target.value;
  }

  @action
  mutPmDelay(pm, event) {
    pm.delay = event.target.value;
  }

  @action
  updatePmRaw(pm, newRaw) {
    pm.raw = newRaw;
  }

  @action
  updatePmTitle(pm, newRaw) {
    pm.title = newRaw;
  }
}
