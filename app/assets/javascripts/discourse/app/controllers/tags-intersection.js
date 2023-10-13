import DiscoveryListController, {
  queryParams,
} from "discourse/controllers/discovery/list";

export default class TagsIntersectionController extends DiscoveryListController {
  constructor() {
    super(...arguments);
    this.queryParams = [
      ...Object.keys(queryParams),
      { categoryParam: "category" },
    ];
  }
}
