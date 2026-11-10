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
    search: { replace: true },
    unattributed: { replace: true },
    details: { replace: false },
  };

  async model(params) {
    const period = ["hour", "day", "week", "custom"].includes(params.period)
      ? params.period
      : null;
    const outcome = ["successful", "failed"].includes(params.outcome)
      ? params.outcome
      : null;
    const hasRetries = String(params.has_retries) === "true" ? "true" : null;
    const unattributed = String(params.unattributed) === "true" ? "true" : null;
    const selectedModel = /^-?[1-9]\d*$/.test(params.selectedModel || "")
      ? params.selectedModel
      : null;
    const search = (params.search || "").trim().slice(0, 200);
    const filterQueryParams = {
      ...params,
      period,
      outcome,
      has_retries: hasRetries,
      unattributed,
      search,
      model: selectedModel,
    };
    delete filterQueryParams.selectedModel;

    const requestParams = { ...filterQueryParams };
    delete requestParams.details;
    delete requestParams.period;
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

    return {
      data: await ajax("/admin/plugins/discourse-ai/ai-logs.json", {
        data: requestParams,
      }),
      queryParams: filterQueryParams,
    };
  }
}
