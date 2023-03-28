import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { isEmpty } from "@ember/utils";

export default class extends Controller {
  @tracked status;
  @tracked tags;
  @tracked exclude_tags;
  @tracked match_all_tags;

  queryParams = ["status", "tags", "exclude_tags", "match_all_tags"];
  queryStringKeys = ["status", "tags"];

  constructor() {
    super(...arguments);
    this.#resetQueryParams();
  }

  #resetQueryParams() {
    this.status = "";
    this.tags = [];
    this.exclude_tags = [];
    this.match_all_tags = null;
  }

  get queryString() {
    let querySegments = [];

    this.queryStringKeys.forEach((key) => {
      if (!isEmpty(this[key])) {
        switch (key) {
          case "tags":
            let tagQueryString = "tags:";
            let delimiter;

            if (this.match_all_tags === "true") {
              delimiter = "+";
            } else {
              delimiter = ",";
            }

            if (this.exclude_tags.length) {
              tagQueryString += `-s${this.exclude_tags.join(delimiter)}`;
            } else if (this.tags.length) {
              tagQueryString += this.tags.join(delimiter);
            }

            querySegments.push(tagQueryString);
            break;
          default:
            querySegments.push(`${key}:${this[key]}`);
        }
      }
    });
    return querySegments.join(" ");
  }

  @action
  updateTopicsListQueryParams(queryString) {
    this.#resetQueryParams();

    for (const match of queryString.matchAll(
      /(?<exclude>-)?(?<key>\w+):(?<value>[^:\s]+)/g
    )) {
      const key = match.groups.key;
      const value = match.groups.value;
      const exclude = match.groups.exclude;

      switch (key) {
        case "tags":
          for (const tagMatch of value.matchAll(
            /^(?<tags>([a-zA-Z0-9\-]+)(?<delimiter>[,+])?([a-zA-Z0-9\-]+)?(\k<delimiter>[a-zA-Z0-9\-]+)*)$/g
          )) {
            const delimiter = tagMatch.groups.delimiter;

            if (delimiter === ",") {
              this.match_all_tags = false;
            } else if (delimiter === "+") {
              this.match_all_tags = true;
            }

            const tags = tagMatch.groups.tags.split(delimiter);
            this.set(`${exclude ? "exclude_" : ""}tags`, tags);
          }

          break;
        case "status":
          this.set(key, value);
          break;
      }
    }
  }
}
