import Controller from "@ember/controller";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";

export const BAR_CHART_TYPE = "bar";
export const PIE_CHART_TYPE = "pie";

export default Controller.extend({
  regularPollType: "regular",
  numberPollType: "number",
  multiplePollType: "multiple",

  alwaysPollResult: "always",
  votePollResult: "on_vote",
  closedPollResult: "on_close",
  staffPollResult: "staff_only",
  pollChartTypes: [
    { name: BAR_CHART_TYPE.capitalize(), value: BAR_CHART_TYPE },
    { name: PIE_CHART_TYPE.capitalize(), value: PIE_CHART_TYPE }
  ],

  pollType: null,
  pollResult: null,

  init() {
    this._super(...arguments);
    this._setupPoll();
  },

  @discourseComputed("regularPollType", "numberPollType", "multiplePollType")
  pollTypes(regularPollType, numberPollType, multiplePollType) {
    return [
      {
        name: I18n.t("poll.ui_builder.poll_type.regular"),
        value: regularPollType
      },
      {
        name: I18n.t("poll.ui_builder.poll_type.number"),
        value: numberPollType
      },
      {
        name: I18n.t("poll.ui_builder.poll_type.multiple"),
        value: multiplePollType
      }
    ];
  },

  @discourseComputed("chartType", "pollType", "numberPollType")
  isPie(chartType, pollType, numberPollType) {
    return pollType !== numberPollType && chartType === PIE_CHART_TYPE;
  },

  @discourseComputed(
    "alwaysPollResult",
    "votePollResult",
    "closedPollResult",
    "staffPollResult"
  )
  pollResults(
    alwaysPollResult,
    votePollResult,
    closedPollResult,
    staffPollResult
  ) {
    let options = [
      {
        name: I18n.t("poll.ui_builder.poll_result.always"),
        value: alwaysPollResult
      },
      {
        name: I18n.t("poll.ui_builder.poll_result.vote"),
        value: votePollResult
      },
      {
        name: I18n.t("poll.ui_builder.poll_result.closed"),
        value: closedPollResult
      }
    ];
    if (this.get("currentUser.staff")) {
      options.push({
        name: I18n.t("poll.ui_builder.poll_result.staff"),
        value: staffPollResult
      });
    }
    return options;
  },

  @discourseComputed("site.groups")
  siteGroups(groups) {
    return groups.map(g => {
      return { name: g.name, value: g.name };
    });
  },

  @discourseComputed("pollType", "regularPollType")
  isRegular(pollType, regularPollType) {
    return pollType === regularPollType;
  },

  @discourseComputed("pollType", "pollOptionsCount", "multiplePollType")
  isMultiple(pollType, count, multiplePollType) {
    return pollType === multiplePollType && count > 0;
  },

  @discourseComputed("pollType", "numberPollType")
  isNumber(pollType, numberPollType) {
    return pollType === numberPollType;
  },

  @discourseComputed("isRegular")
  showMinMax(isRegular) {
    return !isRegular;
  },

  @discourseComputed("pollOptions")
  pollOptionsCount(pollOptions) {
    if (pollOptions.length === 0) return 0;

    let length = 0;

    pollOptions.split("\n").forEach(option => {
      if (option.length !== 0) length += 1;
    });

    return length;
  },

  @observes("pollType", "pollOptionsCount")
  _setPollMax() {
    const isMultiple = this.isMultiple;
    const isNumber = this.isNumber;
    if (!isMultiple && !isNumber) return;

    if (isMultiple) {
      this.set("pollMax", this.pollOptionsCount);
    } else if (isNumber) {
      this.set("pollMax", this.siteSettings.poll_maximum_options);
    }
  },

  @discourseComputed("isRegular", "isMultiple", "isNumber", "pollOptionsCount")
  pollMinOptions(isRegular, isMultiple, isNumber, count) {
    if (isRegular) return;

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
    if (isRegular) return;
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
    if (!isNumber) return;
    return this._comboboxOptions(1, (parseInt(pollMax, 10) || 1) + 1);
  },

  @discourseComputed(
    "isNumber",
    "showMinMax",
    "pollType",
    "pollResult",
    "publicPoll",
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

    if (pollType) pollHeader += ` type=${pollType}`;
    if (pollResult) pollHeader += ` results=${pollResult}`;
    if (pollMin && showMinMax) pollHeader += ` min=${pollMin}`;
    if (pollMax) pollHeader += ` max=${pollMax}`;
    if (isNumber) pollHeader += ` step=${step}`;
    if (publicPoll) pollHeader += ` public=true`;
    if (chartType && pollType !== "number")
      pollHeader += ` chartType=${chartType}`;
    if (pollGroups) pollHeader += ` groups=${pollGroups}`;
    if (autoClose) {
      let closeDate = moment(
        date + " " + time,
        "YYYY-MM-DD HH:mm"
      ).toISOString();
      if (closeDate) pollHeader += ` close=${closeDate}`;
    }

    pollHeader += "]";
    output += `${pollHeader}\n`;

    if (pollOptions.length > 0 && !isNumber) {
      pollOptions.split("\n").forEach(option => {
        if (option.length !== 0) output += `* ${option}\n`;
      });
    }

    output += "[/poll]\n";
    return output;
  },

  @discourseComputed(
    "pollOptionsCount",
    "isRegular",
    "isMultiple",
    "isNumber",
    "pollMin",
    "pollMax"
  )
  disableInsert(count, isRegular, isMultiple, isNumber, pollMin, pollMax) {
    return (
      (isRegular && count < 1) ||
      (isMultiple && count < pollMin && pollMin >= pollMax) ||
      (isNumber ? false : count < 1)
    );
  },

  @discourseComputed("pollMin", "pollMax")
  minMaxValueValidation(pollMin, pollMax) {
    let options = { ok: true };

    if (pollMin >= pollMax) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.invalid_values")
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
        reason: I18n.t("poll.ui_builder.help.min_step_value")
      };
    }

    return EmberObject.create(options);
  },

  @discourseComputed("disableInsert")
  minNumOfOptionsValidation(disableInsert) {
    let options = { ok: true };

    if (disableInsert) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.options_count")
      };
    }

    return EmberObject.create(options);
  },

  _comboboxOptions(start_index, end_index) {
    return _.range(start_index, end_index).map(number => {
      return { value: number, name: number };
    });
  },

  _setupPoll() {
    this.setProperties({
      pollType: this.get("pollTypes.firstObject.value"),
      publicPoll: false,
      pollOptions: "",
      pollMin: 1,
      pollMax: null,
      pollStep: 1,
      autoClose: false,
      chartType: BAR_CHART_TYPE,
      pollGroups: null,
      date: moment()
        .add(1, "day")
        .format("YYYY-MM-DD"),
      time: moment()
        .add(1, "hour")
        .format("HH:mm")
    });
  },

  actions: {
    insertPoll() {
      this.toolbarEvent.addText(this.pollOutput);
      this.send("closeModal");
      this._setupPoll();
    }
  }
});
