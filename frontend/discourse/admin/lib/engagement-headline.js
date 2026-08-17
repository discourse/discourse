const HEADLINE_BY_SCENARIO = {
  "stickiness=improved|daily_engagement=improved|new_signups=improved": {
    title: "engagement_up",
    summary: "all_metrics_improved",
  },
  "stickiness=improved|daily_engagement=improved|new_signups=declined": {
    title: "stickiness_and_daily_engagement_increased",
    summary: "stickiness_and_daily_engagement_up_new_signups_down",
  },
  "stickiness=improved|daily_engagement=improved|new_signups=flat": {
    title: "stickiness_and_daily_engagement_increased",
    summary: "stickiness_and_daily_engagement_up_new_signups_flat",
  },
  "stickiness=improved|daily_engagement=improved|new_signups=unavailable": {
    title: "stickiness_and_daily_engagement_increased",
    summary: "stickiness_and_daily_engagement_up",
  },
  "stickiness=improved|daily_engagement=declined|new_signups=improved": {
    title: "stickiness_and_new_signups_increased",
    summary: "stickiness_and_new_signups_up_daily_engagement_down",
  },
  "stickiness=improved|daily_engagement=declined|new_signups=declined": {
    title: "stickiness_increased",
    summary: "stickiness_up_daily_engagement_and_new_signups_down",
  },
  "stickiness=improved|daily_engagement=declined|new_signups=flat": {
    title: "stickiness_increased",
    summary: "stickiness_up_daily_engagement_down",
  },
  "stickiness=improved|daily_engagement=declined|new_signups=unavailable": {
    title: "stickiness_increased",
    summary: "stickiness_up_daily_engagement_down",
  },
  "stickiness=improved|daily_engagement=flat|new_signups=improved": {
    title: "stickiness_and_new_signups_increased",
    summary: "stickiness_and_new_signups_up_daily_engagement_flat",
  },
  "stickiness=improved|daily_engagement=flat|new_signups=declined": {
    title: "stickiness_increased",
    summary: "stickiness_up_new_signups_down",
  },
  "stickiness=improved|daily_engagement=flat|new_signups=flat": {
    title: "stickiness_increased",
    summary: "stickiness_up_daily_engagement_and_new_signups_flat",
  },
  "stickiness=improved|daily_engagement=flat|new_signups=unavailable": {
    title: "stickiness_increased",
    summary: "stickiness_up_daily_engagement_flat",
  },
  "stickiness=improved|daily_engagement=unavailable|new_signups=improved": {
    title: "stickiness_and_new_signups_increased",
    summary: "stickiness_and_new_signups_up",
  },
  "stickiness=improved|daily_engagement=unavailable|new_signups=declined": {
    title: "stickiness_increased",
    summary: "stickiness_up_new_signups_down",
  },
  "stickiness=improved|daily_engagement=unavailable|new_signups=flat": {
    title: "stickiness_increased",
    summary: "stickiness_up_new_signups_flat",
  },
  "stickiness=improved|daily_engagement=unavailable|new_signups=unavailable": {
    title: "stickiness_increased",
    summary: "stickiness_up",
  },
  "stickiness=declined|daily_engagement=improved|new_signups=improved": {
    title: "daily_engagement_and_new_signups_increased",
    summary: "daily_engagement_and_new_signups_up_stickiness_down",
  },
  "stickiness=declined|daily_engagement=improved|new_signups=declined": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up_stickiness_and_new_signups_down",
  },
  "stickiness=declined|daily_engagement=improved|new_signups=flat": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up_stickiness_down",
  },
  "stickiness=declined|daily_engagement=improved|new_signups=unavailable": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up_stickiness_down",
  },
  "stickiness=declined|daily_engagement=declined|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up_stickiness_and_daily_engagement_down",
  },
  "stickiness=declined|daily_engagement=declined|new_signups=declined": {
    title: "engagement_declined",
    summary: "all_metrics_down",
  },
  "stickiness=declined|daily_engagement=declined|new_signups=flat": {
    title: "some_engagement_declines",
    summary: "stickiness_and_daily_engagement_down_new_signups_steady",
  },
  "stickiness=declined|daily_engagement=declined|new_signups=unavailable": {
    title: "engagement_declined",
    summary: "stickiness_and_daily_engagement_down",
  },
  "stickiness=declined|daily_engagement=flat|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up_stickiness_down",
  },
  "stickiness=declined|daily_engagement=flat|new_signups=declined": {
    title: "some_engagement_declines",
    summary: "stickiness_and_new_signups_down_daily_engagement_steady",
  },
  "stickiness=declined|daily_engagement=flat|new_signups=flat": {
    title: "some_engagement_declines",
    summary: "stickiness_down_daily_engagement_and_new_signups_steady",
  },
  "stickiness=declined|daily_engagement=flat|new_signups=unavailable": {
    title: "some_engagement_declines",
    summary: "stickiness_down_daily_engagement_steady",
  },
  "stickiness=declined|daily_engagement=unavailable|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up_stickiness_down",
  },
  "stickiness=declined|daily_engagement=unavailable|new_signups=declined": {
    title: "engagement_declined",
    summary: "stickiness_and_new_signups_down",
  },
  "stickiness=declined|daily_engagement=unavailable|new_signups=flat": {
    title: "some_engagement_declines",
    summary: "stickiness_down_new_signups_steady",
  },
  "stickiness=declined|daily_engagement=unavailable|new_signups=unavailable": {
    title: "engagement_declined",
    summary: "stickiness_down",
  },
  "stickiness=flat|daily_engagement=improved|new_signups=improved": {
    title: "daily_engagement_and_new_signups_increased",
    summary: "daily_engagement_and_new_signups_up_stickiness_flat",
  },
  "stickiness=flat|daily_engagement=improved|new_signups=declined": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up_new_signups_down",
  },
  "stickiness=flat|daily_engagement=improved|new_signups=flat": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up_stickiness_and_new_signups_flat",
  },
  "stickiness=flat|daily_engagement=improved|new_signups=unavailable": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up_stickiness_flat",
  },
  "stickiness=flat|daily_engagement=declined|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up_daily_engagement_down",
  },
  "stickiness=flat|daily_engagement=declined|new_signups=declined": {
    title: "some_engagement_declines",
    summary: "daily_engagement_and_new_signups_down_stickiness_steady",
  },
  "stickiness=flat|daily_engagement=declined|new_signups=flat": {
    title: "some_engagement_declines",
    summary: "daily_engagement_down_stickiness_and_new_signups_steady",
  },
  "stickiness=flat|daily_engagement=declined|new_signups=unavailable": {
    title: "some_engagement_declines",
    summary: "daily_engagement_down_stickiness_steady",
  },
  "stickiness=flat|daily_engagement=flat|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up_stickiness_and_daily_engagement_flat",
  },
  "stickiness=flat|daily_engagement=flat|new_signups=declined": {
    title: "some_engagement_declines",
    summary: "new_signups_down_stickiness_and_daily_engagement_steady",
  },
  "stickiness=flat|daily_engagement=flat|new_signups=flat": {
    title: "engagement_steady",
    summary: "all_metrics_steady",
  },
  "stickiness=flat|daily_engagement=flat|new_signups=unavailable": {
    title: "engagement_steady",
    summary: "stickiness_and_daily_engagement_steady",
  },
  "stickiness=flat|daily_engagement=unavailable|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up_stickiness_flat",
  },
  "stickiness=flat|daily_engagement=unavailable|new_signups=declined": {
    title: "some_engagement_declines",
    summary: "new_signups_down_stickiness_steady",
  },
  "stickiness=flat|daily_engagement=unavailable|new_signups=flat": {
    title: "engagement_steady",
    summary: "stickiness_and_new_signups_steady",
  },
  "stickiness=flat|daily_engagement=unavailable|new_signups=unavailable": {
    title: "engagement_steady",
    summary: "stickiness_steady",
  },
  "stickiness=unavailable|daily_engagement=improved|new_signups=improved": {
    title: "daily_engagement_and_new_signups_increased",
    summary: "daily_engagement_and_new_signups_up",
  },
  "stickiness=unavailable|daily_engagement=improved|new_signups=declined": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up_new_signups_down",
  },
  "stickiness=unavailable|daily_engagement=improved|new_signups=flat": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up_new_signups_flat",
  },
  "stickiness=unavailable|daily_engagement=improved|new_signups=unavailable": {
    title: "daily_engagement_increased",
    summary: "daily_engagement_up",
  },
  "stickiness=unavailable|daily_engagement=declined|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up_daily_engagement_down",
  },
  "stickiness=unavailable|daily_engagement=declined|new_signups=declined": {
    title: "engagement_declined",
    summary: "daily_engagement_and_new_signups_down",
  },
  "stickiness=unavailable|daily_engagement=declined|new_signups=flat": {
    title: "some_engagement_declines",
    summary: "daily_engagement_down_new_signups_steady",
  },
  "stickiness=unavailable|daily_engagement=declined|new_signups=unavailable": {
    title: "engagement_declined",
    summary: "daily_engagement_down",
  },
  "stickiness=unavailable|daily_engagement=flat|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up_daily_engagement_flat",
  },
  "stickiness=unavailable|daily_engagement=flat|new_signups=declined": {
    title: "some_engagement_declines",
    summary: "new_signups_down_daily_engagement_steady",
  },
  "stickiness=unavailable|daily_engagement=flat|new_signups=flat": {
    title: "engagement_steady",
    summary: "daily_engagement_and_new_signups_steady",
  },
  "stickiness=unavailable|daily_engagement=flat|new_signups=unavailable": {
    title: "engagement_steady",
    summary: "daily_engagement_steady",
  },
  "stickiness=unavailable|daily_engagement=unavailable|new_signups=improved": {
    title: "new_signups_increased",
    summary: "new_signups_up",
  },
  "stickiness=unavailable|daily_engagement=unavailable|new_signups=declined": {
    title: "engagement_declined",
    summary: "new_signups_down",
  },
  "stickiness=unavailable|daily_engagement=unavailable|new_signups=flat": {
    title: "engagement_steady",
    summary: "new_signups_steady",
  },
  "stickiness=unavailable|daily_engagement=unavailable|new_signups=unavailable":
    {
      title: "insufficient_activity",
      summary: "insufficient_activity",
    },
};

function scenarioKey({ stickiness, dailyEngagement, newSignups }) {
  return `stickiness=${stickiness}|daily_engagement=${dailyEngagement}|new_signups=${newSignups}`;
}

export function engagementHeadlineKeys(directions) {
  const scenario = scenarioKey(directions);
  return HEADLINE_BY_SCENARIO[scenario];
}
