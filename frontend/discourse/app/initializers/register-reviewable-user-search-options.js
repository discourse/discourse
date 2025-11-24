import { CUSTOM_USER_SEARCH_OPTIONS } from "discourse/select-kit/components/user-chooser";

export default {
  initialize() {
    CUSTOM_USER_SEARCH_OPTIONS.push("canReview");
  },
};
