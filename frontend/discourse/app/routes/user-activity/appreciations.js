import { trackedArray } from "@ember/reactive/collections";
import { ajax } from "discourse/lib/ajax";
import {
  flattenAppreciation,
  groupAppreciations,
  PAGE_SIZE,
} from "discourse/lib/appreciation-stream";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserActivityAppreciations extends DiscourseRoute {
  queryParams = {
    types: { refreshModel: true },
  };

  get direction() {
    return "given";
  }

  async model(params) {
    const username = this.modelFor("user").username;
    const data = { username };
    if (params.types) {
      data.types = params.types;
    }

    const result = await ajax(
      `/u/${username}/appreciations/${this.direction}.json`,
      { data }
    );

    const appreciations = result.appreciations || [];
    const flat = appreciations.map(flattenAppreciation);
    const lastCursor =
      flat.length > 0 ? flat[flat.length - 1].created_at : null;

    return {
      items: trackedArray(groupAppreciations(flat)),
      canLoadMore: appreciations.length >= PAGE_SIZE,
      lastCursor,
      username,
      direction: this.direction,
      types: params.types,
    };
  }
}
