import TagShowController from "discourse/controllers/tag-show";
import { queryParams } from "discourse/controllers/discovery-sortable";

export default class TagsIntersectionController extends TagShowController {
  constructor() {
    super(...arguments);

    this.set("queryParams", [
      ...Object.keys(queryParams),
      { categoryParam: "category" },
    ]);
  }
}
