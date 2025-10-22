/* eslint-disable ember/no-classic-components */
import Component, { Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import EmberObject, { action } from "@ember/object";
import { gt, or } from "@ember/object/computed";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import { and, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DateTimeInput from "discourse/components/date-time-input";
import InputTip from "discourse/components/input-tip";
import RadioButton from "discourse/components/radio-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import discourseComputed from "discourse/lib/decorators";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import GroupChooser from "select-kit/components/group-chooser";

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
  @service siteSettings;

  showAdvanced = false;
  pollType = REGULAR_POLL_TYPE;
  pollTitle;
  pollOptions = [EmberObject.create({ value: "" })];
  pollOptionsText = "";
  pollMin = 1;
  pollMax = 2;
  pollStep = 1;
  pollGroups;
  pollAutoClose;
  pollResult = ALWAYS_POLL_RESULT;
  chartType = BAR_CHART_TYPE;
  publicPoll = this.siteSettings.poll_default_public;
  dynamic = false;

  @or("showAdvanced", "isNumber") showNumber;
  @or("showAdvanced", "isRankedChoice") showRankedChoice;
  @gt("pollOptions.length", 1) canRemoveOption;
  @or("isRankedChoice", "isRegular") rankedChoiceOrRegular;
  @or("isRankedChoice", "isNumber") rankedChoiceOrNumber;

  @discourseComputed("currentUser.staff")
  pollResults(staff) {
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

    if (staff) {
      options.push({
        name: i18n("poll.ui_builder.poll_result.staff"),
        value: STAFF_POLL_RESULT,
      });
    }

    return options;
  }

  @discourseComputed("pollType")
  isRegular(pollType) {
    return pollType === REGULAR_POLL_TYPE;
  }

  @discourseComputed("pollType")
  isNumber(pollType) {
    return pollType === NUMBER_POLL_TYPE;
  }

  @discourseComputed("pollType")
  isMultiple(pollType) {
    return pollType === MULTIPLE_POLL_TYPE;
  }

  @discourseComputed("pollType")
  isRankedChoice(pollType) {
    return pollType === RANKED_CHOICE_POLL_TYPE;
  }

  @discourseComputed("pollOptions.@each.value")
  pollOptionsCount(pollOptions) {
    return (pollOptions || []).filter((option) => option.value.length > 0)
      .length;
  }

  @discourseComputed("site.groups")
  siteGroups(groups) {
    // prevents group "everyone" to be listed
    return groups.filter((g) => g.id !== 0);
  }

  @discourseComputed("chartType", "pollType")
  isPie(chartType, pollType) {
    return pollType !== NUMBER_POLL_TYPE && chartType === PIE_CHART_TYPE;
  }

  @observes("pollType", "pollOptionsCount")
  _setPollMinMax() {
    if (this.isMultiple) {
      if (
        this.pollMin <= 0 ||
        this.pollMin >= this.pollMax ||
        this.pollMin >= this.pollOptionsCount
      ) {
        this.set("pollMin", this.pollOptionsCount > 0 ? 1 : 0);
      }

      if (
        this.pollMax <= 0 ||
        this.pollMin >= this.pollMax ||
        this.pollMax > this.pollOptionsCount
      ) {
        this.set("pollMax", this.pollOptionsCount);
      }
    } else if (this.isNumber) {
      this.set("pollMax", this.siteSettings.poll_maximum_options);
    }
  }

  @discourseComputed(
    "pollType",
    "pollResult",
    "publicPoll",
    "dynamic",
    "pollTitle",
    "pollOptions.@each.value",
    "pollMin",
    "pollMax",
    "pollStep",
    "pollGroups",
    "pollAutoClose",
    "chartType"
  )
  pollOutput(
    pollType,
    pollResult,
    publicPoll,
    dynamic,
    pollTitle,
    pollOptions,
    pollMin,
    pollMax,
    pollStep,
    pollGroups,
    pollAutoClose,
    chartType
  ) {
    let pollHeader = "[poll";
    let output = "";

    const match = this.model.toolbarEvent
      .getText()
      .match(/\[poll(\s+name=[^\s\]]+)*.*\]/gim);

    if (match) {
      pollHeader += ` name=poll${match.length + 1}`;
    }

    let step = pollStep;
    if (step < 1) {
      step = 1;
    }

    if (pollType) {
      pollHeader += ` type=${pollType}`;
    }
    if (pollResult) {
      pollHeader += ` results=${pollResult}`;
    }
    if (pollMin && pollType !== REGULAR_POLL_TYPE) {
      pollHeader += ` min=${pollMin}`;
    }
    if (pollMax && pollType !== REGULAR_POLL_TYPE) {
      pollHeader += ` max=${pollMax}`;
    }
    if (pollType === NUMBER_POLL_TYPE) {
      pollHeader += ` step=${step}`;
    }
    pollHeader += ` public=${publicPoll ? "true" : "false"}`;
    if (chartType && pollType !== NUMBER_POLL_TYPE) {
      pollHeader += ` chartType=${chartType}`;
    }
    if (dynamic) {
      pollHeader += ` dynamic=true`;
    }
    if (pollGroups && pollGroups.length > 0) {
      pollHeader += ` groups=${pollGroups}`;
    }
    if (pollAutoClose) {
      pollHeader += ` close=${pollAutoClose.toISOString()}`;
    }

    pollHeader += "]";
    output += `${pollHeader}\n`;

    if (pollTitle) {
      output += `# ${pollTitle.trim()}\n`;
    }

    if (pollOptions.length > 0 && pollType !== NUMBER_POLL_TYPE) {
      pollOptions.forEach((option) => {
        if (option.value.length > 0) {
          output += `* ${option.value.trim()}\n`;
        }
      });
    }

    output += "[/poll]\n";
    return output;
  }

  @discourseComputed("isNumber", "pollOptionsCount")
  minNumOfOptionsValidation(isNumber, pollOptionsCount) {
    let options = { ok: true };

    if (!isNumber) {
      if (pollOptionsCount < 1) {
        return EmberObject.create({
          failed: true,
          reason: i18n("poll.ui_builder.help.options_min_count"),
        });
      }

      if (pollOptionsCount > this.siteSettings.poll_maximum_options) {
        return EmberObject.create({
          failed: true,
          reason: i18n("poll.ui_builder.help.options_max_count", {
            count: this.siteSettings.poll_maximum_options,
          }),
        });
      }
    }

    return EmberObject.create(options);
  }

  @discourseComputed("pollOptions.@each.value")
  showMinNumOfOptionsValidation(pollOptions) {
    return pollOptions.length !== 1 || pollOptions[0].value !== "";
  }

  @discourseComputed(
    "isMultiple",
    "pollOptionsCount",
    "isNumber",
    "pollMin",
    "pollMax",
    "pollStep"
  )
  minMaxValueValidation(
    isMultiple,
    pollOptionsCount,
    isNumber,
    pollMin,
    pollMax,
    pollStep
  ) {
    pollMin = parseInt(pollMin, 10) || 0;
    pollMax = parseInt(pollMax, 10) || 0;
    pollStep = parseInt(pollStep, 10) || 0;

    if (pollMin < 0) {
      return EmberObject.create({
        failed: true,
        reason: i18n("poll.ui_builder.help.invalid_min_value"),
      });
    }

    if (pollMax < 0 || (isMultiple && pollMax > pollOptionsCount)) {
      return EmberObject.create({
        failed: true,
        reason: i18n("poll.ui_builder.help.invalid_max_value"),
      });
    }

    if (pollMin > pollMax) {
      return EmberObject.create({
        failed: true,
        reason: i18n("poll.ui_builder.help.invalid_values"),
      });
    }

    if (isNumber) {
      if (pollStep < 1) {
        return EmberObject.create({
          failed: true,
          reason: i18n("poll.ui_builder.help.min_step_value"),
        });
      }

      const optionsCount = (pollMax - pollMin + 1) / pollStep;

      if (optionsCount < 1) {
        return EmberObject.create({
          failed: true,
          reason: i18n("poll.ui_builder.help.options_min_count"),
        });
      }

      if (optionsCount > this.siteSettings.poll_maximum_options) {
        return EmberObject.create({
          failed: true,
          reason: i18n("poll.ui_builder.help.options_max_count", {
            count: this.siteSettings.poll_maximum_options,
          }),
        });
      }
    }

    return EmberObject.create({ ok: true });
  }

  @discourseComputed("minMaxValueValidation", "minNumOfOptionsValidation")
  disableInsert(minMaxValueValidation, minNumOfOptionsValidation) {
    return !minMaxValueValidation.ok || !minNumOfOptionsValidation.ok;
  }

  _comboboxOptions(startIndex, endIndex) {
    return [...Array(endIndex - startIndex).keys()].map((number) => ({
      value: number + startIndex,
      name: number + startIndex,
    }));
  }

  @action
  onOptionsTextChange(e) {
    this.set(
      "pollOptions",
      e.target.value.split("\n").map((value) => EmberObject.create({ value }))
    );
  }

  @action
  insertPoll() {
    this.model.toolbarEvent.addText(this.pollOutput);
    this.closeModal();
  }

  @action
  toggleAdvanced() {
    this.toggleProperty("showAdvanced");
    if (this.showAdvanced) {
      this.set(
        "pollOptionsText",
        this.pollOptions.map((x) => x.value).join("\n")
      );
    }
  }

  @action
  updateValue(option, event) {
    option.set("value", event.target.value);
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

    const option = EmberObject.create({ value: "" });
    this.pollOptions.insertAt(atIndex, option);
  }

  @action
  removeOption(option) {
    this.pollOptions.removeObject(option);
  }

  @action
  updatePollType(pollType, event) {
    event?.preventDefault();
    this.set("pollType", pollType);
  }

  @action
  togglePublic() {
    this.set("publicPoll", !this.publicPoll);
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
                {{on "input" (withEventValue (fn (mut this.pollMin)))}}
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
                {{on "input" (withEventValue (fn (mut this.pollMax)))}}
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
