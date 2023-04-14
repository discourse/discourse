import { avatarImg } from "discourse/lib/utilities";
import { htmlHelper } from "discourse-common/lib/helpers";
import { isEmpty } from "@ember/utils";

export default htmlHelper((avatarTemplate, size) => {
  if (isEmpty(avatarTemplate)) {
    return "<div class='avatar-placeholder'></div>";
  } else {
    return avatarImg({ size, avatarTemplate });
  }
});
