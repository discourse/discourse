const HEADLINE_BY_SCENARIO = {
  no_data: {
    title: "insufficient_activity",
    summary: "insufficient_activity",
  },
  "resolution_rate=up|first_reply_time=down": {
    title: "resolution_rate_and_first_reply_time_improved",
    summary: "more_answers_and_faster_replies",
  },
  "resolution_rate=up|first_reply_time=up": {
    title: "resolution_rate_improved",
    summary: "more_answers_but_slower_replies",
    cta: "unanswered",
  },
  "resolution_rate=up|first_reply_time=flat": {
    title: "resolution_rate_improved",
    summary: "more_answers_first_reply_time_flat",
    cta: "unanswered",
  },
  "resolution_rate=down|first_reply_time=down": {
    title: "first_reply_time_decreased",
    summary: "faster_replies_but_lower_resolution_rate",
    cta: "in_progress",
  },
  "resolution_rate=flat|first_reply_time=down": {
    title: "first_reply_time_decreased",
    summary: "faster_replies_resolution_rate_steady",
    cta: "in_progress",
  },
  "resolution_rate=down|first_reply_time=up": {
    title: "resolution_rate_and_first_reply_time_declined",
    summary: "fewer_answers_and_slower_replies",
    cta: "in_progress_and_unanswered",
  },
  "resolution_rate=down|first_reply_time=flat": {
    title: "resolution_rate_decreased",
    summary: "fewer_answers_first_reply_time_steady",
    cta: "in_progress",
  },
  "resolution_rate=flat|first_reply_time=up": {
    title: "first_reply_time_increased",
    summary: "slower_replies_resolution_rate_steady",
    cta: "unanswered",
  },
  "resolution_rate=flat|first_reply_time=flat": {
    title: "support_steady",
    summary: "resolution_rate_and_first_reply_time_steady",
  },
  "resolution_rate=up|first_reply_time=unavailable": {
    title: "resolution_rate_improved",
    summary: "more_answers",
  },
  "resolution_rate=down|first_reply_time=unavailable": {
    title: "resolution_rate_decreased",
    summary: "fewer_answers",
    cta: "in_progress",
  },
  "resolution_rate=flat|first_reply_time=unavailable": {
    title: "support_steady",
    summary: "resolution_rate_steady",
  },
  "resolution_rate=unavailable|first_reply_time=down": {
    title: "first_reply_time_decreased",
    summary: "faster_replies",
  },
  "resolution_rate=unavailable|first_reply_time=up": {
    title: "first_reply_time_increased",
    summary: "slower_replies",
    cta: "unanswered",
  },
  "resolution_rate=unavailable|first_reply_time=flat": {
    title: "support_steady",
    summary: "first_reply_time_steady",
  },
};

function scenarioKey({ resolutionRate, firstReplyTime, noData = false }) {
  if (noData) {
    return "no_data";
  }

  return `resolution_rate=${resolutionRate}|first_reply_time=${firstReplyTime}`;
}

export function supportHeadlineKeys(directions) {
  const scenario = scenarioKey(directions);
  return HEADLINE_BY_SCENARIO[scenario];
}
