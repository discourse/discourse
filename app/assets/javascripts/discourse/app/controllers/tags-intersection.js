import DiscoveryListController, {
  queryParams,
} from "discourse/controllers/discovery/list";

export default class TagsIntersectionController extends DiscoveryListController {
  queryParams = [...Object.keys(queryParams), { categoryParam: "category" }];
}
