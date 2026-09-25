import { CUSTOM_USER_SEARCH_OPTIONS } from "discourse/lib/plugin-registries/user-search-options";

export default {
  initialize() {
    CUSTOM_USER_SEARCH_OPTIONS.push("canReview");
  },
};
