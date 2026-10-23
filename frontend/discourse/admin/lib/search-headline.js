const HEADLINE_BY_SCENARIO = {
  no_data: {
    title: "insufficient_activity",
    summary: "insufficient_activity",
  },
  "searches=up|no_result_rate=down": {
    title: "searches_increased_no_result_rate_declined",
    summary: "searches_up_results_improved",
  },
  "searches=up|no_result_rate=up": {
    title: "searches_increased",
    summary: "searches_up_no_result_rate_up",
    cta: "content_gaps",
  },
  "searches=up|no_result_rate=flat": {
    title: "searches_increased",
    summary: "searches_up_no_result_rate_flat",
    cta: "content_gaps",
  },
  "searches=down|no_result_rate=down": {
    title: "no_result_rate_decreased",
    summary: "results_improved_searches_down",
  },
  "searches=flat|no_result_rate=down": {
    title: "no_result_rate_decreased",
    summary: "results_improved_searches_steady",
  },
  "searches=down|no_result_rate=up": {
    title: "searches_decreased_no_result_rate_increased",
    summary: "searches_down_results_worsened",
    cta: "content_gaps",
  },
  "searches=down|no_result_rate=flat": {
    title: "searches_decreased",
    summary: "searches_down_no_result_rate_flat",
  },
  "searches=flat|no_result_rate=up": {
    title: "no_result_rate_increased",
    summary: "results_worsened_searches_steady",
    cta: "content_gaps",
  },
  "searches=flat|no_result_rate=flat": {
    title: "search_steady",
    summary: "searches_and_no_result_rate_steady",
  },
  "searches=up|no_result_rate=unavailable": {
    title: "searches_increased",
    summary: "searches_up",
  },
  "searches=down|no_result_rate=unavailable": {
    title: "searches_decreased",
    summary: "searches_down",
  },
  "searches=flat|no_result_rate=unavailable": {
    title: "search_steady",
    summary: "searches_steady",
  },
  "searches=unavailable|no_result_rate=up": {
    title: "no_result_rate_increased",
    summary: "results_worsened",
    cta: "content_gaps",
  },
  "searches=unavailable|no_result_rate=down": {
    title: "no_result_rate_decreased",
    summary: "results_improved",
  },
  "searches=unavailable|no_result_rate=flat": {
    title: "search_steady",
    summary: "no_result_rate_steady",
  },
};

function scenarioKey({ searches, noResultRate, noData = false }) {
  if (noData) {
    return "no_data";
  }

  return `searches=${searches}|no_result_rate=${noResultRate}`;
}

export function searchHeadlineKeys(directions) {
  const scenario = scenarioKey(directions);
  return HEADLINE_BY_SCENARIO[scenario];
}
