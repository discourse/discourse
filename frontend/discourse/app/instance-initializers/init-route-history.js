import { lookup } from "discourse/lib/service";
import RouteHistoryService from "discourse/services/route-history";
export default {
  initialize(owner) {
    lookup(owner, RouteHistoryService);
  },
};
