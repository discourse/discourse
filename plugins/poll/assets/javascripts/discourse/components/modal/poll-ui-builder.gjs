import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DateTimeInput from "discourse/components/date-time-input";
import InputTip from "discourse/components/input-tip";
import RadioButton from "discourse/components/radio-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import { trackedArray } from "discourse/lib/tracked-tools";
import autoFocus from "discourse/modifiers/auto-focus";
import ComboBox from "discourse/select-kit/components/combo-box";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { and, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export const BAR_CHART_TYPE = "bar";
export const PIE_CHART_TYPE = "pie";

export const REGULAR_POLL_TYPE = "regular";
export const NUMBER_POLL_TYPE = "number";
export const MULTIPLE_POLL_TYPE = "multiple";
export const RANKED_CHOICE_POLL_TYPE = "ranked_choice";

const ALWAYS_POLL_RESULT = "always";
const VOTE_POLL_RESULT = "on_vote";
const CLOSED_POLL_RESULT = "on_close";
const STAFF_POLL_RESULT = "staff_only";

export default class PollUiBuilderModal extends Component {
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked chartType = BAR_CHART_TYPE;
  @tracked dynamic = false;
  @tracked pollAutoClose;
  @tracked pollGroups;
  @tracked pollMax = 2;
  @tracked pollMin = 1;
  @tracked pollOptionsText = "";
  @tracked pollResult = ALWAYS_POLL_RESULT;
  @tracked pollStep = 1;
  @tracked pollTitle;
  @tracked pollType = REGULAR_POLL_TYPE;
  @tracked publicPoll = this.siteSettings.poll_default_public;
  @tracked showAdvanced = false;
  @trackedArray pollOptions = [new TrackedObject({ value: "" })];

  get showNumber() {
    return this.showAdvanced || this.isNumber;
  }

  get showRankedChoice() {
    return this.showAdvanced || this.isRankedChoice;
  }

  get rankedChoiceOrRegular() {
    return this.isRankedChoice || this.isRegular;
  }

  get rankedChoiceOrNumber() {
    return this.isRankedChoice || this.isNumber;
  }

  get canRemoveOption() {
    return this.pollOptions.length > 1;
  }

  get pollResults() {
    const options = [
      {
        name: i18n("poll.ui_builder.poll_result.always"),
        value: ALWAYS_POLL_RESULT,
      },
      {
        name: i18n("poll.ui_builder.poll_result.vote"),
        value: VOTE_POLL_RESULT,
      },
      {
        name: i18n("poll.ui_builder.poll_result.closed"),
        value: CLOSED_POLL_RESULT,
      },
    ];

    if (this.currentUser.staff) {
      options.push({
        name: i18n("poll.ui_builder.poll_result.staff"),
        value: STAFF_POLL_RESULT,
      });
    }

    return options;
  }

  get isRegular() {
    return this.pollType === REGULAR_POLL_TYPE;
  }

  get isNumber() {
    return this.pollType === NUMBER_POLL_TYPE;
  }

  get isMultiple() {
    return this.pollType === MULTIPLE_POLL_TYPE;
  }

  get isRankedChoice() {
    return this.pollType === RANKED_CHOICE_POLL_TYPE;
  }

  get pollOptionsCount() {
    return (this.pollOptions || []).filter((option) => option.value.length > 0)
      .length;
  }

  get siteGroups() {
    // prevents group "everyone" to be listed
    return this.site.groups.filter((g) => g.id !== 0);
  }

  get isPie() {
    return (
      this.pollType !== NUMBER_POLL_TYPE && this.chartType === PIE_CHART_TYPE
    );
  }

  @bind
  enforceMinMaxValues() {
    if (this.isMultiple) {
      if (
        this.pollMin <= 0 ||
        this.pollMin >= this.pollMax ||
        this.pollMin >= this.pollOptionsCount
      ) {
        this.pollMin = this.pollOptionsCount > 0 ? 1 : 0;
      }

      if (
        this.pollMax <= 0 ||
        this.pollMin >= this.pollMax ||
        this.pollMax > this.pollOptionsCount
      ) {
        this.pollMax = this.pollOptionsCount;
      }
    } else if (this.isNumber) {
      this.pollMax = this.siteSettings.poll_maximum_options;
    }
  }

  get pollOutput() {
    let pollHeader = "[poll";
    let output = "";

    const match = this.args.model.toolbarEvent
      .getText()
      .match(/\[poll(\s+name=[^\s\]]+)*.*\]/gim);

    if (match) {
      pollHeader += ` name=poll${match.length + 1}`;
    }

    let step = this.pollStep;
    if (step < 1) {
      step = 1;
    }

    if (this.pollType) {
      pollHeader += ` type=${this.pollType}`;
    }
    if (this.pollResult) {
      pollHeader += ` results=${this.pollResult}`;
    }
    if (this.pollMin && this.pollType !== REGULAR_POLL_TYPE) {
      pollHeader += ` min=${this.pollMin}`;
    }
    if (this.pollMax && this.pollType !== REGULAR_POLL_TYPE) {
      pollHeader += ` max=${this.pollMax}`;
    }
    if (this.pollType === NUMBER_POLL_TYPE) {
      pollHeader += ` step=${step}`;
    }
    pollHeader += ` public=${this.publicPoll ? "true" : "false"}`;
    if (this.chartType && this.pollType !== NUMBER_POLL_TYPE) {
      pollHeader += ` chartType=${this.chartType}`;
    }
    if (this.dynamic) {
      pollHeader += ` dynamic=true`;
    }
    if (this.pollGroups?.length > 0) {
      pollHeader += ` groups=${this.pollGroups}`;
    }
    if (this.pollAutoClose) {
      pollHeader += ` close=${this.pollAutoClose.toISOString()}`;
    }

    pollHeader += "]";
    output += `${pollHeader}\n`;

    if (this.pollTitle) {
      output += `# ${this.pollTitle.trim()}\n`;
    }

    if (this.pollOptions.length > 0 && this.pollType !== NUMBER_POLL_TYPE) {
      this.pollOptions.forEach((option) => {
        if (option.value.length > 0) {
          output += `* ${option.value.trim()}\n`;
        }
      });
    }

    output += "[/poll]\n";
    return output;
  }

  get minNumOfOptionsValidation() {
    if (!this.isNumber) {
      if (this.pollOptionsCount < 1) {
        return {
          failed: true,
          reason: i18n("poll.ui_builder.help.options_min_count"),
        };
      }

      if (this.pollOptionsCount > this.siteSettings.poll_maximum_options) {
        return {
          failed: true,
          reason: i18n("poll.ui_builder.help.options_max_count", {
            count: this.siteSettings.poll_maximum_options,
          }),
        };
      }
    }

    return { ok: true };
  }

  get showMinNumOfOptionsValidation() {
    return this.pollOptions.length !== 1 || this.pollOptions[0].value !== "";
  }

  get minMaxValueValidation() {
    const pollMin = parseInt(this.pollMin, 10) || 0;
    const pollMax = parseInt(this.pollMax, 10) || 0;
    const pollStep = parseInt(this.pollStep, 10) || 0;

    if (pollMin < 0) {
      return {
        failed: true,
        reason: i18n("poll.ui_builder.help.invalid_min_value"),
      };
    }

    if (pollMax < 0 || (this.isMultiple && pollMax > this.pollOptionsCount)) {
      return {
        failed: true,
        reason: i18n("poll.ui_builder.help.invalid_max_value"),
      };
    }

    if (pollMin > pollMax) {
      return {
        failed: true,
        reason: i18n("poll.ui_builder.help.invalid_values"),
      };
    }

    if (this.isNumber) {
      if (pollStep < 1) {
        return {
          failed: true,
          reason: i18n("poll.ui_builder.help.min_step_value"),
        };
      }

      const optionsCount = (pollMax - pollMin + 1) / pollStep;

      if (optionsCount < 1) {
        return {
          failed: true,
          reason: i18n("poll.ui_builder.help.options_min_count"),
        };
      }

      if (optionsCount > this.siteSettings.poll_maximum_options) {
        return {
          failed: true,
          reason: i18n("poll.ui_builder.help.options_max_count", {
            count: this.siteSettings.poll_maximum_options,
          }),
        };
      }
    }

    return { ok: true };
  }

  get disableInsert() {
    return !this.minMaxValueValidation.ok || !this.minNumOfOptionsValidation.ok;
  }

  _comboboxOptions(startIndex, endIndex) {
    return [...Array(endIndex - startIndex).keys()].map((number) => ({
      value: number + startIndex,
      name: number + startIndex,
    }));
  }

  @action
  onChangePollMin(event) {
    this.pollMin = event.target.value;
    this.enforceMinMaxValues();
  }

  @action
  onChangePollMax(event) {
    this.pollMax = event.target.value;
    this.enforceMinMaxValues();
  }

  @action
  onOptionsTextChange(e) {
    this.pollOptions = e.target.value
      .split("\n")
      .map((value) => new TrackedObject({ value }));
    this.enforceMinMaxValues();
  }

  @action
  insertPoll() {
    this.args.model.toolbarEvent.addText(this.pollOutput);
    this.args.closeModal();
  }

  @action
  toggleAdvanced() {
    this.showAdvanced = !this.showAdvanced;
    if (this.showAdvanced) {
      this.pollOptionsText = this.pollOptions.map((x) => x.value).join("\n");
    }
  }

  @action
  updateValue(option, event) {
    option.value = event.target.value;
    this.enforceMinMaxValues();
  }

  @action
  onInputKeydown(index, event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.stopPropagation();

      if (event.target.value !== "") {
        this.addOption(index + 1);
      }
    }
  }

  @action
  addOption(atIndex) {
    if (atIndex === -1) {
      atIndex = this.pollOptions.length;
    }

    const option = new TrackedObject({ value: "" });
    this.pollOptions.splice(atIndex, 0, option);
    this.enforceMinMaxValues();
  }

  @action
  removeOption(option) {
    removeValueFromArray(this.pollOptions, option);
    this.enforceMinMaxValues();
  }

  @action
  updatePollType(pollType, event) {
    event?.preventDefault();
    this.pollType = pollType;
    this.enforceMinMaxValues();
  }

  @action
  togglePublic() {
    this.publicPoll = !this.publicPoll;
  }

  <template>
    <DModal
      @title={{i18n "poll.ui_builder.title"}}
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      class="poll-ui-builder"
    >
      <:body>
        <ul class="nav nav-pills poll-type">
          <li>
            <DButton
              @action={{fn this.updatePollType "regular"}}
              class={{concatClass
                "poll-type-value poll-type-value-regular"
                (if this.isRegular "active")
              }}
            >
              {{i18n "poll.ui_builder.poll_type.regular"}}
            </DButton>
          </li>
          <li>
            <DButton
              @action={{fn this.updatePollType "multiple"}}
              class={{concatClass
                "poll-type-value poll-type-value-multiple"
                (if this.isMultiple "active")
              }}
            >
              {{i18n "poll.ui_builder.poll_type.multiple"}}
            </DButton>
          </li>
          {{#if this.showNumber}}
            <li>
              <DButton
                @action={{fn this.updatePollType "number"}}
                class={{concatClass
                  "poll-type-value poll-type-value-number"
                  (if this.isNumber "active")
                }}
              >
                {{i18n "poll.ui_builder.poll_type.number"}}
              </DButton>
            </li>
          {{/if}}
          {{#if this.showRankedChoice}}
            <li>
              <DButton
                @action={{fn this.updatePollType "ranked_choice"}}
                class={{concatClass
                  "poll-type-value poll-type-value-ranked-choice"
                  (if this.isRankedChoice "active")
                }}
              >
                {{i18n "poll.ui_builder.poll_type.ranked_choice"}}
              </DButton>
            </li>
          {{/if}}
        </ul>

        {{#if this.showAdvanced}}
          <div class="input-group poll-title">
            <label class="input-group-label">{{i18n
                "poll.ui_builder.poll_title.label"
              }}</label>
            <input
              {{on "input" (withEventValue (fn (mut this.pollTitle)))}}
              type="text"
              value={{this.pollTitle}}
            />
          </div>
        {{/if}}

        {{#unless this.isNumber}}
          <div class="poll-options">
            {{#if this.showAdvanced}}
              <label class="input-group-label">{{i18n
                  "poll.ui_builder.poll_options.label"
                }}</label>
              <Textarea
                @value={{this.pollOptionsText}}
                {{on "input" this.onOptionsTextChange}}
              />
              {{#if this.showMinNumOfOptionsValidation}}
                {{#unless this.minNumOfOptionsValidation.ok}}
                  <InputTip @validation={{this.minNumOfOptionsValidation}} />
                {{/unless}}
              {{/if}}
            {{else}}
              {{#each this.pollOptions as |option index|}}
                <div class="input-group poll-option-value">
                  <input
                    type="text"
                    value={{option.value}}
                    {{autoFocus}}
                    {{on "input" (fn this.updateValue option)}}
                    {{on "keydown" (fn this.onInputKeydown index)}}
                  />
                  {{#if this.canRemoveOption}}
                    <DButton
                      @icon="trash-can"
                      @action={{fn this.removeOption option}}
                    />
                  {{/if}}
                </div>
              {{/each}}

              <div class="poll-option-controls">
                <DButton
                  @icon="plus"
                  @label="poll.ui_builder.poll_options.add"
                  @action={{fn this.addOption -1}}
                  class="btn-default poll-option-add"
                />
                {{#if
                  (and
                    this.showMinNumOfOptionsValidation
                    (not this.minNumOfOptionsValidation.ok)
                  )
                }}
                  <InputTip @validation={{this.minNumOfOptionsValidation}} />
                {{/if}}
              </div>
            {{/if}}
          </div>
        {{/unless}}

        {{#unless this.rankedChoiceOrRegular}}
          <div class="options">
            <div class="input-group poll-number">
              <label class="input-group-label">{{i18n
                  "poll.ui_builder.poll_config.min"
                }}</label>
              <input
                {{on "input" this.onChangePollMin}}
                type="number"
                value={{this.pollMin}}
                class="poll-options-min"
                min="1"
              />
            </div>

            <div class="input-group poll-number">
              <label class="input-group-label">{{i18n
                  "poll.ui_builder.poll_config.max"
                }}</label>
              <input
                {{on "input" this.onChangePollMax}}
                type="number"
                value={{this.pollMax}}
                class="poll-options-max"
                min="1"
              />
            </div>

            {{#if this.isNumber}}
              <div class="input-group poll-number">
                <label class="input-group-label">{{i18n
                    "poll.ui_builder.poll_config.step"
                  }}</label>
                <input
                  {{on "input" (withEventValue (fn (mut this.pollStep)))}}
                  type="number"
                  value={{this.pollStep}}
                  min="1"
                  class="poll-options-step"
                />
              </div>
            {{/if}}
          </div>

          {{#unless this.minMaxValueValidation.ok}}
            <InputTip @validation={{this.minMaxValueValidation}} />
          {{/unless}}
        {{/unless}}

        <div class="input-group poll-public">
          <DToggleSwitch
            @state={{this.publicPoll}}
            @label="poll.ui_builder.poll_public.label"
            class="poll-toggle-public"
            {{on "click" this.togglePublic}}
          />
        </div>

        {{#if this.showAdvanced}}
          <div class="input-group poll-dynamic">
            <DToggleSwitch
              @state={{this.dynamic}}
              @label="poll.ui_builder.poll_dynamic.label"
              class="poll-toggle-dynamic"
              {{on "click" (fn (mut this.dynamic) (not this.dynamic))}}
            />
          </div>
          <div class="input-group poll-allowed-groups">
            <label class="input-group-label">{{i18n
                "poll.ui_builder.poll_groups.label"
              }}</label>
            <GroupChooser
              @content={{this.siteGroups}}
              @value={{this.pollGroups}}
              @onChange={{fn (mut this.pollGroups)}}
              @labelProperty="name"
              @valueProperty="name"
            />
          </div>

          <div class="input-group poll-date">
            <label class="input-group-label">{{i18n
                "poll.ui_builder.automatic_close.label"
              }}</label>
            <DateTimeInput
              @date={{this.pollAutoClose}}
              @onChange={{fn (mut this.pollAutoClose)}}
              @clearable={{true}}
              @useGlobalPickerContainer={{true}}
            />
          </div>

          <div class="input-group poll-select">
            <label class="input-group-label">{{i18n
                "poll.ui_builder.poll_result.label"
              }}</label>
            <ComboBox
              @content={{this.pollResults}}
              @value={{this.pollResult}}
              @valueProperty="value"
              @onChange={{fn (mut this.pollResult)}}
              class="poll-result"
            />
          </div>

          {{#unless this.rankedChoiceOrNumber}}
            <div class="input-group poll-select column">
              <label class="input-group-label">{{i18n
                  "poll.ui_builder.poll_chart_type.label"
                }}</label>

              <div class="radio-group">
                <RadioButton
                  @id="poll-chart-type-bar"
                  @name="poll-chart-type"
                  @value="bar"
                  @selection={{this.chartType}}
                />
                <label for="poll-chart-type-bar">{{icon "chart-bar"}}
                  {{i18n "poll.ui_builder.poll_chart_type.bar"}}</label>
              </div>

              <div class="radio-group">
                <RadioButton
                  @id="poll-chart-type-pie"
                  @name="poll-chart-type"
                  @value="pie"
                  @selection={{this.chartType}}
                />
                <label for="poll-chart-type-pie">{{icon "chart-pie"}}
                  {{i18n "poll.ui_builder.poll_chart_type.pie"}}</label>
              </div>
            </div>
          {{/unless}}
        {{/if}}
      </:body>
      <:footer>
        <DButton
          @action={{this.insertPoll}}
          @icon="chart-bar"
          @label="poll.ui_builder.insert"
          @disabled={{this.disableInsert}}
          class="btn-primary insert-poll"
        />

        <DButton @label="cancel" @action={{@closeModal}} class="btn-flat" />

        <DButton
          @action={{this.toggleAdvanced}}
          @icon="gear"
          @title={{if
            this.showAdvanced
            "poll.ui_builder.hide_advanced"
            "poll.ui_builder.show_advanced"
          }}
          class="btn-default show-advanced"
        />

      </:footer>
    </DModal>
  </template>
}
