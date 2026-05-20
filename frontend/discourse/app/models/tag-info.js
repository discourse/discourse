import { tracked } from "@glimmer/tracking";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";

export default class TagInfo extends RestModel {
  @tracked category_restricted;
  @tracked description;
  @tracked id;
  @tracked name;
  @tracked slug;
  @tracked staff;
  @tracked topic_count;

  @autoTrackedArray categories;
  @autoTrackedArray localizations;
  @autoTrackedArray synonyms;
  @autoTrackedArray tag_group_names;
}
