import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiLogsRoute extends DiscourseRoute {
  @service currentUser;

  queryParams = {
    period: { replace: true },
    start_date: { replace: true },
    end_date: { replace: true },
    outcome: { replace: true },
    has_retries: { replace: true },
    selectedModel: { replace: true },
    feature: { replace: true },
    username: { replace: true },
    unattributed: { replace: true },
    id_type: { replace: true },
    id_value: { replace: true },
    details: { replace: false },
  };

  async model(params) {
    const period = ["hour", "day", "week", "custom"].includes(params.period)
      ? params.period
      : null;
    const idType = ["id", "topic_id", "post_id"].includes(params.id_type)
      ? params.id_type
      : "id";
    const outcome = ["successful", "failed"].includes(params.outcome)
      ? params.outcome
      : null;
    const hasRetries = String(params.has_retries) === "true" ? "true" : null;
    const unattributed = String(params.unattributed) === "true" ? "true" : null;
    const selectedModel = /^[1-9]\d*$/.test(params.selectedModel || "")
      ? params.selectedModel
      : null;
    const idValue = /^[1-9]\d*$/.test(params.id_value || "")
      ? params.id_value
      : null;
    const filterQueryParams = {
      ...params,
      period,
      outcome,
      has_retries: hasRetries,
      unattributed,
      id_type: idType,
      id_value: idValue,
      model: selectedModel,
    };
    delete filterQueryParams.selectedModel;

    const requestParams = { ...filterQueryParams };
    delete requestParams.details;
    delete requestParams.period;
    delete requestParams.id_type;
    delete requestParams.id_value;
    requestParams.llm_id = requestParams.model;
    delete requestParams.model;
    requestParams.include_meta = true;

    if (period === "custom") {
      requestParams.timezone =
        this.currentUser?.user_option?.timezone || moment.tz.guess();
    } else if (period) {
      const hours = { hour: 1, day: 24, week: 24 * 7 }[period];
      if (hours) {
        requestParams.start_date = moment()
          .subtract(hours, "hours")
          .toISOString();
        requestParams.end_date = moment().toISOString();
      }
    }

    if (idValue) {
      requestParams[idType] = idValue;
    }

    return {
      data: await ajax("/admin/plugins/discourse-ai/ai-logs.json", {
        data: requestParams,
      }),
      queryParams: filterQueryParams,
    };
  }
}
