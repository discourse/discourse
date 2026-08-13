const HEADLINE_BY_SCENARIO = {
  no_data: {
    title: "insufficient_activity",
    summary: "insufficient_activity",
  },
  up_down: {
    title: "searches_increased_no_result_rate_declined",
    summary: "searches_up_results_improved",
  },
  up_up: {
    title: "searches_increased",
    summary: "searches_up_no_result_rate_up",
    cta: "content_gaps",
  },
  up_flat: {
    title: "searches_increased",
    summary: "searches_up_no_result_rate_flat",
    cta: "content_gaps",
  },
  down_down: {
    title: "no_result_rate_decreased",
    summary: "results_improved_searches_down",
  },
  flat_down: {
    title: "no_result_rate_decreased",
    summary: "results_improved_searches_steady",
  },
  down_up: {
    title: "searches_decreased_no_result_rate_increased",
    summary: "searches_down_results_worsened",
    cta: "content_gaps",
  },
  down_flat: {
    title: "searches_decreased",
    summary: "searches_down_no_result_rate_flat",
  },
  flat_up: {
    title: "no_result_rate_increased",
    summary: "results_worsened_searches_steady",
    cta: "content_gaps",
  },
  flat_flat: {
    title: "search_steady",
    summary: "searches_and_no_result_rate_steady",
  },
  up_unavailable: {
    title: "searches_increased",
    summary: "searches_up",
  },
  down_unavailable: {
    title: "searches_decreased",
    summary: "searches_down",
  },
  flat_unavailable: {
    title: "search_steady",
    summary: "searches_steady",
  },
  unavailable_up: {
    title: "no_result_rate_increased",
    summary: "results_worsened",
    cta: "content_gaps",
  },
  unavailable_down: {
    title: "no_result_rate_decreased",
    summary: "results_improved",
  },
  unavailable_flat: {
    title: "search_steady",
    summary: "no_result_rate_steady",
  },
};

export function searchHeadlineKeys(scenario) {
  return HEADLINE_BY_SCENARIO[scenario];
}
