import { queryParams } from "discourse/controllers/discovery-sortable";
import TagShowController from "discourse/controllers/tag-show";

export default class TagsIntersectionController extends TagShowController {
  constructor() {
    super(...arguments);

    this.set("queryParams", [
      ...Object.keys(queryParams),
      { categoryParam: "category" },
    ]);
  }
}
