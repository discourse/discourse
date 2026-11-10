/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ALL_TIME_FROM_DATE = "2014-08-26";
const RANGES = {
  last_10_days: { count: 10, type: "days" },
  last_30_days: { count: 30, type: "days" },
  last_90_days: { count: 90, type: "days" },
  last_year: { count: 1, type: "year" },
  all_time: null,
  custom_date_range: null,
};

export default class RecalculateScoresForm extends Component {
  @service messageBus;

  @tracked remaining = this.args.model.recalculate_scores_remaining;
  @tracked status = "initial";

  formData = { range: "last_10_days", from_date: null };

  rangeOptions = Object.keys(RANGES).map((key) => ({
    value: key,
    name: i18n(`gamification.update_range.${key}`),
  }));
  #formApi;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/recalculate_scores", this.onMessage);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe("/recalculate_scores", this.onMessage);
  }

  get remainingText() {
    return i18n("gamification.daily_update_scores_availability", {
      count: this.remaining,
    });
  }

  get applyDisabled() {
    return (
      this.args.model.recalculate_scores_remaining <= 0 ||
      this.status !== "initial"
    );
  }

  get today() {
    return moment().locale("en").utc().endOf("day");
  }

  get maxFromDate() {
    return this.today.format("YYYY-MM-DD");
  }

  @bind
  onMessage(message) {
    if (message.success) {
      this.status = "complete";
      this.args.model.recalculate_scores_remaining = message.remaining;
      this.remaining = message.remaining;
    }
  }

  @bind
  dateRangeText(range) {
    const calculation = RANGES[range];
    if (!calculation) {
      return;
    }

    const format = i18n("dates.long_with_year_no_time");
    const pastDate = this.today
      .clone()
      .subtract(calculation.count, calculation.type);
    return `${pastDate.format(format)} - ${this.today.format(format)}`;
  }

  fromDate(data) {
    if (data.range === "all_time") {
      return ALL_TIME_FROM_DATE;
    }

    if (data.range === "custom_date_range") {
      return data.from_date;
    }

    const calculation = RANGES[data.range];
    return this.today
      .clone()
      .subtract(calculation.count, calculation.type)
      .format("YYYY-MM-DD");
  }

  @action
  registerFormApi(api) {
    this.#formApi = api;
  }

  @action
  submit() {
    this.#formApi.submit();
  }

  @action
  async recalculate(data) {
    this.status = "loading";

    try {
      await ajax(`/admin/plugins/gamification/recalculate-scores.json`, {
        data: { from_date: this.fromDate(data) },
        type: "PUT",
      });
    } catch (error) {
      this.status = "initial";
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="recalculate-scores-form-modal"
      @title={{i18n "gamification.recalculate"}}
    >
      <:body>
        {{#if (eq this.status "loading")}}
          <div class="recalculate-modal__status">
            <em>{{i18n "gamification.recalculating"}}</em>
          </div>
        {{else if (eq this.status "complete")}}
          <div class="recalculate-modal__status is-success">
            {{dIcon "check"}}
            {{i18n "gamification.completed"}}
          </div>
        {{else}}
          <Form
            class="recalculate-scores-form"
            @data={{this.formData}}
            @onRegisterApi={{this.registerFormApi}}
            @onSubmit={{this.recalculate}}
            as |form transientData|
          >
            <form.Field
              @description={{this.dateRangeText transientData.range}}
              @format="full"
              @name="range"
              @title={{i18n "gamification.update_scores_help"}}
              @type="select"
              @validation="required"
              as |field|
            >
              <field.Control as |select|>
                {{#each this.rangeOptions as |option|}}
                  <select.Option @value={{option.value}}>
                    {{option.name}}
                  </select.Option>
                {{/each}}
              </field.Control>
            </form.Field>

            {{#if (eq transientData.range "custom_date_range")}}
              <form.Field
                @format="full"
                @name="from_date"
                @title={{i18n "gamification.custom_range_from"}}
                @type="input-date"
                @validation="required"
                as |field|
              >
                <field.Control max={{this.maxFromDate}} />
              </form.Field>
            {{/if}}
          </Form>
        {{/if}}
      </:body>

      <:footer>
        <DButton
          class="btn-primary recalculate-modal__submit"
          @action={{this.submit}}
          @disabled={{this.applyDisabled}}
          @label="gamification.recalculate"
        />
        <DButton
          class="btn-default"
          @action={{@closeModal}}
          @label={{if
            (eq this.status "complete")
            "gamification.close"
            "gamification.cancel"
          }}
        />

        <div class="recalculate-modal__footer-text">{{this.remainingText}}</div>
      </:footer>
    </DModal>
  </template>
}
