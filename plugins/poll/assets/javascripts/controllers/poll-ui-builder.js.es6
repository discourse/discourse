import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import InputValidation from "discourse/models/input-validation";

export default Ember.Controller.extend({
  regularPollType: "regular",
  numberPollType: "number",
  multiplePollType: "multiple",

  alwaysPollResult: "always",
  votePollResult: "on_vote",
  closedPollResult: "on_close",
  staffPollResult: "staff_only",

  init() {
    this._super(...arguments);
    this._setupPoll();
  },

  @computed("regularPollType", "numberPollType", "multiplePollType")
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

  @computed(
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
    return [
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
      },
      {
        name: I18n.t("poll.ui_builder.poll_result.staff"),
        value: staffPollResult
      }
    ];
  },

  @computed("pollType", "regularPollType")
  isRegular(pollType, regularPollType) {
    return pollType === regularPollType;
  },

  @computed("pollType", "pollOptionsCount", "multiplePollType")
  isMultiple(pollType, count, multiplePollType) {
    return pollType === multiplePollType && count > 0;
  },

  @computed("pollType", "numberPollType")
  isNumber(pollType, numberPollType) {
    return pollType === numberPollType;
  },

  @computed("isRegular")
  showMinMax(isRegular) {
    return !isRegular;
  },

  @computed("pollOptions")
  pollOptionsCount(pollOptions) {
    if (pollOptions.length === 0) return 0;

    let length = 0;

    pollOptions.split("\n").forEach(option => {
      if (option.length !== 0) length += 1;
    });

    return length;
  },

  @observes("isMultiple", "isNumber", "pollOptionsCount")
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

  @computed("isRegular", "isMultiple", "isNumber", "pollOptionsCount")
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

  @computed(
    "isRegular",
    "isMultiple",
    "isNumber",
    "pollOptionsCount",
    "pollMin",
    "pollStep"
  )
  pollMaxOptions(isRegular, isMultiple, isNumber, count, pollMin, pollStep) {
    if (isRegular) return;
    const pollMinInt = parseInt(pollMin) || 1;

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

  @computed("isNumber", "pollMax")
  pollStepOptions(isNumber, pollMax) {
    if (!isNumber) return;
    return this._comboboxOptions(1, (parseInt(pollMax) || 1) + 1);
  },

  @computed(
    "isNumber",
    "showMinMax",
    "pollType",
    "pollResult",
    "publicPoll",
    "pollOptions",
    "pollMin",
    "pollMax",
    "pollStep",
    "autoClose",
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
    autoClose,
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

    output += "[/poll]";
    return output;
  },

  @computed(
    "pollOptionsCount",
    "isRegular",
    "isMultiple",
    "isNumber",
    "pollMin",
    "pollMax"
  )
  disableInsert(count, isRegular, isMultiple, isNumber, pollMin, pollMax) {
    return (
      (isRegular && count < 2) ||
      (isMultiple && count < pollMin && pollMin >= pollMax) ||
      (isNumber ? false : count < 2)
    );
  },

  @computed("pollMin", "pollMax")
  minMaxValueValidation(pollMin, pollMax) {
    let options = { ok: true };

    if (pollMin >= pollMax) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.invalid_values")
      };
    }

    return InputValidation.create(options);
  },

  @computed("pollStep")
  minStepValueValidation(pollStep) {
    let options = { ok: true };

    if (pollStep < 1) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.min_step_value")
      };
    }

    return InputValidation.create(options);
  },

  @computed("disableInsert")
  minNumOfOptionsValidation(disableInsert) {
    let options = { ok: true };

    if (disableInsert) {
      options = {
        failed: true,
        reason: I18n.t("poll.ui_builder.help.options_count")
      };
    }

    return InputValidation.create(options);
  },

  _comboboxOptions(start_index, end_index) {
    return _.range(start_index, end_index).map(number => {
      return { value: number, name: number };
    });
  },

  _setupPoll() {
    this.setProperties({
      pollType: null,
      publicPoll: false,
      pollOptions: "",
      pollMin: 1,
      pollMax: null,
      pollStep: 1,
      autoClose: false,
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
