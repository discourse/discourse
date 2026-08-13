const HEADLINE_BY_SCENARIO = {
  no_data: {
    title: "insufficient_activity",
    summary: "insufficient_activity",
  },
  up_down: {
    title: "resolution_rate_and_first_reply_time_improved",
    summary: "more_answers_and_faster_replies",
  },
  up_up: {
    title: "resolution_rate_improved",
    summary: "more_answers_but_slower_replies",
    cta: "unanswered",
  },
  up_flat: {
    title: "resolution_rate_improved",
    summary: "more_answers_first_reply_time_flat",
    cta: "unanswered",
  },
  down_down: {
    title: "first_reply_time_decreased",
    summary: "faster_replies_but_lower_resolution_rate",
    cta: "in_progress",
  },
  flat_down: {
    title: "first_reply_time_decreased",
    summary: "faster_replies_resolution_rate_steady",
    cta: "in_progress",
  },
  down_up: {
    title: "resolution_rate_and_first_reply_time_declined",
    summary: "fewer_answers_and_slower_replies",
    cta: "in_progress_and_unanswered",
  },
  down_flat: {
    title: "resolution_rate_decreased",
    summary: "fewer_answers_first_reply_time_steady",
    cta: "in_progress",
  },
  flat_up: {
    title: "first_reply_time_increased",
    summary: "slower_replies_resolution_rate_steady",
    cta: "unanswered",
  },
  flat_flat: {
    title: "support_steady",
    summary: "resolution_rate_and_first_reply_time_steady",
  },
  up_unavailable: {
    title: "resolution_rate_improved",
    summary: "more_answers",
  },
  down_unavailable: {
    title: "resolution_rate_decreased",
    summary: "fewer_answers",
    cta: "in_progress",
  },
  flat_unavailable: {
    title: "support_steady",
    summary: "resolution_rate_steady",
  },
  unavailable_down: {
    title: "first_reply_time_decreased",
    summary: "faster_replies",
  },
  unavailable_up: {
    title: "first_reply_time_increased",
    summary: "slower_replies",
    cta: "unanswered",
  },
  unavailable_flat: {
    title: "support_steady",
    summary: "first_reply_time_steady",
  },
};

export function supportHeadlineKeys(scenario) {
  return HEADLINE_BY_SCENARIO[scenario];
}
