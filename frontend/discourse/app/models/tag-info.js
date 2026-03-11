import { tracked } from "@glimmer/tracking";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";

export default class TagInfo extends RestModel {
  @tracked description;
  @tracked name;
  @tracked slug;

  @autoTrackedArray categories;
  @autoTrackedArray synonyms;
  @autoTrackedArray tag_group_names;
}
