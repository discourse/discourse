import { tracked } from "@glimmer/tracking";
import { i18n } from "discourse-i18n";
import { LEADERBOARD_PERIODS } from "discourse/plugins/discourse-gamification/discourse/components/gamification-leaderboard";

export default class GamificationLeaderboard {
  static create(args = {}) {
    return new GamificationLeaderboard(args);
  }

  @tracked id;
  @tracked createdAt;
  @tracked updatedAt;
  @tracked createdById;
  @tracked excludedGroupsIds;
  @tracked includedGroupsIds;
  @tracked visibleToGroupsIds;
  @tracked forCategoryId;
  @tracked fromDate;
  @tracked toDate;
  @tracked name;
  @tracked period;
  @tracked periodFilterDisabled;

  constructor(args = {}) {
    this.id = args.id;
    this.createdAt = args.created_at;
    this.updatedAt = args.updated_at;
    this.createdById = args.created_by_id;
    this.excludedGroupsIds = args.excluded_groups_ids;
    this.includedGroupsIds = args.included_groups_ids;
    this.visibleToGroupsIds = args.visible_to_groups_ids;
    this.forCategoryId = args.for_category_id;
    this.fromDate = args.from_date;
    this.toDate = args.to_date;
    this.name = args.name;
    this.period = args.period;
    this.periodFilterDisabled = args.period_filter_disabled;

    if (Number.isInteger(args.default_period)) {
      this.defaultPeriod = i18n(
        `gamification.leaderboard.period.${
          LEADERBOARD_PERIODS[args.default_period]
        }`
      );
    }
  }
}
