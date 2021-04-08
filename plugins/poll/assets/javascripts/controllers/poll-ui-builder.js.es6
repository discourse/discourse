import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { gt, or } from "@ember/object/computed";
import { next } from "@ember/runloop";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";

export const BAR_CHART_TYPE = "bar";
export const PIE_CHART_TYPE = "pie";

export const REGULAR_POLL_TYPE = "regular";
export const NUMBER_POLL_TYPE = "number";
export const MULTIPLE_POLL_TYPE = "multiple";

const ALWAYS_POLL_RESULT = "always";
const VOTE_POLL_RESULT = "on_vote";
const CLOSED_POLL_RESULT = "on_close";
const STAFF_POLL_RESULT = "staff_only";

export default Controller.extend(ModalFunctionality, {
  showAdvanced: false,

  pollType: REGULAR_POLL_TYPE,
  pollTitle: "",
  pollOptions: null,
  pollMin: 1,
  pollMax: 2,
  pollStep: 1,
  pollGroups: null,
  pollAutoClose: null,
  pollResult: ALWAYS_POLL_RESULT,
  chartType: BAR_CHART_TYPE,
  publicPoll: null,

  onShow() {
    this.setProperties({
      showAdvanced: false,
      pollType: REGULAR_POLL_TYPE,
      pollTitle: null,
      pollOptions: [EmberObject.create({ value: "" })],
      pollMin: 1,
      pollMax: 2,
      pollStep: 1,
      pollGroups: null,
      pollAutoClose: null,
      pollResult: ALWAYS_POLL_RESULT,
      chartType: BAR_CHART_TYPE,
      publicPoll: false,
    });
  },

  @discourseComputed
  pollResults() {
    const options = [
      {
        name: I18n.t("poll.ui_builder.poll_result.always"),
        value: ALWAYS_POLL_RESULT,
      },
      {
        name: I18n.t("poll.ui_builder.poll_result.vote"),
        value: VOTE_POLL_RESULT,
      },
      {
        name: I18n.t("poll.ui_builder.poll_result.closed"),
        value: CLOSED_POLL_RESULT,
      },
    ];

    if (this.get("currentUser.staff")) {
      options.push({
        name: I18n.t("poll.ui_builder.poll_result.staff"),
        value: STAFF_POLL_RESULT,
      });
    }

    return options;
  },

  @discourseComputed("pollType")
  isRegular(pollType) {
    return pollType === REGULAR_POLL_TYPE;
  },

  @discourseComputed("pollType")
  isNumber(pollType) {
    return pollType === NUMBER_POLL_TYPE;
  },

  @discourseComputed("pollType")
  isMultiple(pollType) {
    return pollType === MULTIPLE_POLL_TYPE;
  },

  showNumber: or("showAdvanced", "isNumber"),

  @discourseComputed("pollOptions.@each.value")
  pollOptionsCount(pollOptions) {
    return pollOptions.filter((option) => option.value.length > 0).length;
  },

  @discourseComputed("site.groups")
  siteGroups(groups) {
    // prevents group "everyone" to be listed
    return groups.filter((g) => g.id !== 0);
  },

  @discourseComputed("chartType", "pollType")
  isPie(chartType, pollType) {
    return pollType !== NUMBER_POLL_TYPE && chartType === PIE_CHART_TYPE;
  },

  canRemoveOption: gt("pollOptions.length", 1),

  @observes("pollType", "pollOptionsCount")
  _setPollMinMax() {
    if (this.isMultiple) {
      if (
        this.pollMin >= this.pollMax ||
        this.pollMin >= this.pollOptionsCount
      ) {
        this.set("pollMin", this.pollOptionsCount > 0 ? 1 : 0);
      }

      if (
        this.pollMin >= this.pollMax ||
        this.pollMax > this.pollOptionsCount
      ) {
        this.set("pollMax", Math.min(this.pollMin + 1, this.pollOptionsCount));
      }
    } else if (this.isNumber) {
      this.set("pollMax", this.siteSettings.poll_maximum_options);
    }
  },

  @discourseComputed(
    "pollType",
    "pollResult",
    "publicPoll",
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

    const match = this.toolbarEvent
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
    if (publicPoll) {
      pollHeader += ` public=true`;
    }
    if (chartType && pollType !== NUMBER_POLL_TYPE) {
      pollHeader += ` chartType=${chartType}`;
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
  },

  @discourseComputed("isNumber", "pollOptionsCount")
  minNumOfOptionsValidation(isNumber, pollOptionsCount) {
    let options = { ok: true };

    if (!isNumber && pollOptionsCount === 0) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.options_count"),
      };
    }

    return EmberObject.create(options);
  },

  @discourseComputed("pollOptions.@each.value")
  showMinNumOfOptionsValidation(pollOptions) {
    return pollOptions.length !== 1 || pollOptions[0].value !== "";
  },

  @discourseComputed(
    "isMultiple",
    "pollOptionsCount",
    "isNumber",
    "pollMin",
    "pollMax"
  )
  minMaxValueValidation(
    isMultiple,
    pollOptionsCount,
    isNumber,
    pollMin,
    pollMax
  ) {
    pollMin = parseInt(pollMin, 10) || 0;
    pollMax = parseInt(pollMax, 10) || 0;

    const fail = {
      failed: true,
      reason: I18n.t("poll.ui_builder.help.invalid_values"),
    };

    if (isMultiple) {
      if (
        pollMin > pollMax ||
        pollMin < 0 ||
        (pollOptionsCount > 0 && pollMax > pollOptionsCount)
      ) {
        return EmberObject.create(fail);
      }
    } else if (isNumber) {
      if (pollMin >= pollMax) {
        return EmberObject.create(fail);
      }
    }

    return EmberObject.create({ ok: true });
  },

  @discourseComputed("isNumber", "pollStep")
  minStepValueValidation(isNumber, pollStep) {
    let options = { ok: true };

    if (isNumber && pollStep < 1) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.min_step_value"),
      };
    }

    return EmberObject.create(options);
  },

  @discourseComputed(
    "minMaxValueValidation",
    "minStepValueValidation",
    "minNumOfOptionsValidation"
  )
  disableInsert(
    minMaxValueValidation,
    minStepValueValidation,
    minNumOfOptionsValidation
  ) {
    return (
      !minMaxValueValidation.ok ||
      !minStepValueValidation.ok ||
      !minNumOfOptionsValidation.ok
    );
  },

  _comboboxOptions(startIndex, endIndex) {
    return [...Array(endIndex - startIndex).keys()].map((number) => ({
      value: number + startIndex,
      name: number + startIndex,
    }));
  },

  @action
  insertPoll() {
    this.toolbarEvent.addText(this.pollOutput);
    this.send("closeModal");
  },

  @action
  toggleAdvanced() {
    this.toggleProperty("showAdvanced");
  },

  @action
  addOption(beforeOption, value, e) {
    if (value !== "") {
      const idx = this.pollOptions.indexOf(beforeOption) + 1;
      const option = EmberObject.create({ value: "" });
      this.pollOptions.insertAt(idx, option);

      let lastOptionIdx = 0;
      this.pollOptions.forEach((o) => o.set("idx", lastOptionIdx++));

      next(() => {
        const pollOptions = document.getElementsByClassName("poll-options");
        if (pollOptions) {
          const inputs = pollOptions[0].getElementsByTagName("input");
          if (option.idx < inputs.length) {
            inputs[option.idx].focus();
          }
        }
      });
    }

    if (e) {
      e.preventDefault();
    }
  },

  @action
  removeOption(option) {
    this.pollOptions.removeObject(option);
  },
});
