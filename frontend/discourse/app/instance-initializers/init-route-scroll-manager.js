import { lookup } from "discourse/lib/service";
import RouteScrollManagerService from "discourse/services/route-scroll-manager";
export default {
  initialize(owner) {
    lookup(owner, RouteScrollManagerService);
  },
};
