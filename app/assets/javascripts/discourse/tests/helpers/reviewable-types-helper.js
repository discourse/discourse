import { getRenderDirector } from "discourse/lib/reviewable-types-manager";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

export function createRenderDirector(reviewable, reviewableType, siteSettings) {
  const director = getRenderDirector(
    reviewableType,
    reviewable,
    User.create(
      cloneJSON(sessionFixtures["/session/current.json"].current_user)
    ),
    siteSettings,
    Site.current()
  );
  return director;
}
