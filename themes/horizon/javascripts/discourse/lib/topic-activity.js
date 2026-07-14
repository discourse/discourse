const UPDATED_AFTER_LAST_POST_THRESHOLD_DAYS = 1;

export function topicWasUpdatedAfterLastPost(topic) {
  const bumpedAt = moment(topic.bumped_at);
  const lastPostedAt = moment(topic.last_posted_at);
  const bumpedLastPostedDaysDiff = moment
    .duration(bumpedAt.diff(lastPostedAt))
    .asDays();

  return (
    bumpedAt.isAfter(lastPostedAt) &&
    bumpedLastPostedDaysDiff > UPDATED_AFTER_LAST_POST_THRESHOLD_DAYS
  );
}
