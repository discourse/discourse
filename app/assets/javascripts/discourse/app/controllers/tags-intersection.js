import { queryParams } from "discourse/controllers/discovery-sortable";
import TagShowController from "discourse/controllers/tag-show";

export default class TagsIntersectionController extends TagShowController {
  queryParams = [...Object.keys(queryParams), { categoryParam: "category" }];
}
