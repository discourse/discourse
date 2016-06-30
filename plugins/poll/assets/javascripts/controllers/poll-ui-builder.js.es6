import { default as computed, observes } from 'ember-addons/ember-computed-decorators';
import InputValidation from 'discourse/models/input-validation';

export default Ember.Controller.extend({
  needs: ['modal'],
  numberPollType: 'number',
  multiplePollType: 'multiple',

  init() {
    this._super();
    this._setupPoll();
  },

  @computed("numberPollType", "multiplePollType")
  pollTypes(numberPollType, multiplePollType) {
    let types = [];

    types.push({ name: I18n.t("poll.ui_builder.poll_type.number"), value: numberPollType });
    types.push({ name: I18n.t("poll.ui_builder.poll_type.multiple"), value: multiplePollType });

    return types;
  },

  @computed("pollType", "pollOptionsCount", "multiplePollType")
  isMultiple(pollType, count, multiplePollType) {
    return (pollType === multiplePollType) && count > 0;
  },

  @computed("pollType", "numberPollType")
  isNumber(pollType, numberPollType) {
    return pollType === numberPollType;
  },

  @computed("isNumber", "isMultiple")
  showMinMax(isNumber, isMultiple) {
    return isNumber || isMultiple;
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
    const isMultiple = this.get("isMultiple");
    const isNumber = this.get("isNumber");
    if (!isMultiple && !isNumber) return;

    if (isMultiple) {
      this.set("pollMax", this.get("pollOptionsCount"));
    } else if (isNumber) {
      this.set("pollMax", this.siteSettings.poll_maximum_options);
    }
  },

  @computed("isMultiple", "isNumber", "pollOptionsCount")
  pollMinOptions(isMultiple, isNumber, count) {
    if (!isMultiple && !isNumber) return;

    if (isMultiple) {
      return this._comboboxOptions(1, count + 1);
    } else if (isNumber) {
      return this._comboboxOptions(1, this.siteSettings.poll_maximum_options + 1);
    }
  },

  @computed("isMultiple", "isNumber", "pollOptionsCount", "pollMin", "pollStep")
  pollMaxOptions(isMultiple, isNumber, count, pollMin, pollStep) {
    if (!isMultiple && !isNumber) return;
    const pollMinInt = parseInt(pollMin) || 1;

    if (isMultiple) {
      return this._comboboxOptions(pollMinInt + 1, count + 1);
    } else if (isNumber) {
      const pollStepInt = parseInt(pollStep) || 1;
      return this._comboboxOptions(pollMinInt + 1, pollMinInt + (this.siteSettings.poll_maximum_options * pollStepInt));
    }
  },

  @computed("isNumber", "pollMax")
  pollStepOptions(isNumber, pollMax) {
    if (!isNumber) return;
    return this._comboboxOptions(1, (parseInt(pollMax) || 1) + 1);
  },

  @computed("isNumber", "showMinMax", "pollType", "publicPoll", "pollOptions", "pollMin", "pollMax", "pollStep")
  pollOutput(isNumber, showMinMax, pollType, publicPoll, pollOptions, pollMin, pollMax, pollStep) {
    let pollHeader = '[poll';
    let output = '';

    const match = this.get("toolbarEvent").getText().match(/\[poll(\s+name=[^\s\]]+)*.*\]/igm);

    if (match) {
      pollHeader += ` name=poll${match.length + 1}`;
    };

    if (pollType) pollHeader += ` type=${pollType}`;
    if (pollMin && showMinMax) pollHeader += ` min=${pollMin}`;
    if (pollMax) pollHeader += ` max=${pollMax}`;
    if (isNumber) pollHeader += ` step=${pollStep}`;
    if (publicPoll) pollHeader += ' public=true';
    pollHeader += ']';
    output += `${pollHeader}\n`;

    if (pollOptions.length > 0 && !isNumber) {
      output += `${pollOptions.split("\n").map(option => `* ${option}`).join("\n")}\n`;
    }

    output += '[/poll]';
    return output;
  },

  @computed("pollOptionsCount", "isNumber")
  disableInsert(count, isNumber) {
    return isNumber ? false : (count < 2);
  },

  @computed("disableInsert")
  minNumOfOptionsValidation(disableInsert) {
    let options = { ok: true };

    if (disableInsert) {
      options = { failed: true, reason: I18n.t("poll.ui_builder.help.options_count") };
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
      pollOptions: '',
      pollMin: 1,
      pollMax: null,
      pollStep: 1
    });
  },

  actions: {
    insertPoll() {
      this.get("toolbarEvent").addText(this.get("pollOutput"));
      this.send("closeModal");
      this._setupPoll();
    }
  }
});
