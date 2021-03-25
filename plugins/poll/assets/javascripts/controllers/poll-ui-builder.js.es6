import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
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
  pollType: null,
  pollResult: null,
  pollGroups: null,
  pollTitle: null,
  date: null,
  time: null,
  publicPoll: null,
  autoClose: null,
  chartType: null,
  pollMin: null,
  pollMax: null,
  pollStep: null,
  pollOptions: null,

  onShow() {
    this.setProperties({
      pollType: REGULAR_POLL_TYPE,
      publicPoll: false,
      pollOptions: "",
      pollMin: 1,
      pollMax: null,
      pollStep: 1,
      autoClose: false,
      chartType: BAR_CHART_TYPE,
      pollResult: ALWAYS_POLL_RESULT,
      pollGroups: null,
      pollTitle: null,
      date: moment().add(1, "day").format("YYYY-MM-DD"),
      time: moment().add(1, "hour").format("HH:mm"),
    });
  },

  @discourseComputed
  pollTypes() {
    return [
      {
        name: I18n.t("poll.ui_builder.poll_type.regular"),
        value: REGULAR_POLL_TYPE,
      },
      {
        name: I18n.t("poll.ui_builder.poll_type.number"),
        value: NUMBER_POLL_TYPE,
      },
      {
        name: I18n.t("poll.ui_builder.poll_type.multiple"),
        value: MULTIPLE_POLL_TYPE,
      },
    ];
  },

  @discourseComputed
  pollResults() {
    let options = [
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

  @discourseComputed
  pollChartTypes() {
    return [
      {
        name: I18n.t("poll.ui_builder.poll_chart_type.bar"),
        value: BAR_CHART_TYPE,
      },
      {
        name: I18n.t("poll.ui_builder.poll_chart_type.pie"),
        value: PIE_CHART_TYPE,
      },
    ];
  },

  @discourseComputed("chartType", "pollType")
  isPie(chartType, pollType) {
    return pollType !== NUMBER_POLL_TYPE && chartType === PIE_CHART_TYPE;
  },

  @discourseComputed("site.groups")
  siteGroups(groups) {
    // prevents group "everyone" to be listed
    return groups.filter((g) => g.id !== 0);
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

  @discourseComputed("isRegular")
  showMinMax(isRegular) {
    return !isRegular;
  },

  @discourseComputed("pollOptions")
  pollOptionsCount(pollOptions) {
    if (pollOptions.length === 0) {
      return 0;
    }

    let length = 0;

    pollOptions.split("\n").forEach((option) => {
      if (option.length !== 0) {
        length += 1;
      }
    });

    return length;
  },

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

  @discourseComputed("isRegular", "isMultiple", "isNumber", "pollOptionsCount")
  pollMinOptions(isRegular, isMultiple, isNumber, count) {
    if (isRegular) {
      return;
    }

    if (isMultiple) {
      return this._comboboxOptions(1, count + 1);
    } else if (isNumber) {
      return this._comboboxOptions(
        1,
        this.siteSettings.poll_maximum_options + 1
      );
    }
  },

  @discourseComputed(
    "isRegular",
    "isMultiple",
    "isNumber",
    "pollOptionsCount",
    "pollMin",
    "pollStep"
  )
  pollMaxOptions(isRegular, isMultiple, isNumber, count, pollMin, pollStep) {
    if (isRegular) {
      return;
    }
    const pollMinInt = parseInt(pollMin, 10) || 1;

    if (isMultiple) {
      return this._comboboxOptions(pollMinInt + 1, count + 1);
    } else if (isNumber) {
      let pollStepInt = parseInt(pollStep, 10);
      if (pollStepInt < 1) {
        pollStepInt = 1;
      }
      return this._comboboxOptions(
        pollMinInt + 1,
        pollMinInt + this.siteSettings.poll_maximum_options * pollStepInt
      );
    }
  },

  @discourseComputed("isNumber", "pollMax")
  pollStepOptions(isNumber, pollMax) {
    if (!isNumber) {
      return;
    }
    return this._comboboxOptions(1, (parseInt(pollMax, 10) || 1) + 1);
  },

  @discourseComputed(
    "isNumber",
    "showMinMax",
    "pollType",
    "pollResult",
    "publicPoll",
    "pollTitle",
    "pollOptions",
    "pollMin",
    "pollMax",
    "pollStep",
    "pollGroups",
    "autoClose",
    "chartType",
    "date",
    "time"
  )
  pollOutput(
    isNumber,
    showMinMax,
    pollType,
    pollResult,
    publicPoll,
    pollTitle,
    pollOptions,
    pollMin,
    pollMax,
    pollStep,
    pollGroups,
    autoClose,
    chartType,
    date,
    time
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
    if (pollMin && showMinMax) {
      pollHeader += ` min=${pollMin}`;
    }
    if (pollMax) {
      pollHeader += ` max=${pollMax}`;
    }
    if (isNumber) {
      pollHeader += ` step=${step}`;
    }
    if (publicPoll) {
      pollHeader += ` public=true`;
    }
    if (chartType && pollType !== "number") {
      pollHeader += ` chartType=${chartType}`;
    }
    if (pollGroups && pollGroups.length > 0) {
      pollHeader += ` groups=${pollGroups}`;
    }
    if (autoClose) {
      let closeDate = moment(
        date + " " + time,
        "YYYY-MM-DD HH:mm"
      ).toISOString();
      if (closeDate) {
        pollHeader += ` close=${closeDate}`;
      }
    }

    pollHeader += "]";
    output += `${pollHeader}\n`;

    if (pollTitle) {
      output += `# ${pollTitle.trim()}\n`;
    }

    if (pollOptions.length > 0 && !isNumber) {
      pollOptions.split("\n").forEach((option) => {
        if (option.length !== 0) {
          output += `* ${option}\n`;
        }
      });
    }

    output += "[/poll]\n";
    return output;
  },

  @discourseComputed("pollOptionsCount")
  minNumOfOptionsValidation(pollOptionsCount) {
    let options = { ok: true };

    if (pollOptionsCount < 1) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.options_count"),
      };
    }

    return EmberObject.create(options);
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
    let options = { ok: true };

    if (
      ((isMultiple && pollOptionsCount >= 2) || isNumber) &&
      pollMin >= pollMax
    ) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.invalid_values"),
      };
    }

    return EmberObject.create(options);
  },

  @discourseComputed("pollStep")
  minStepValueValidation(pollStep) {
    let options = { ok: true };

    if (pollStep < 1) {
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
});
