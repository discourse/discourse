import { getRenderDirector } from "discourse/lib/reviewable-types-manager";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";

export function createRenderDirector(reviewable, reviewableType, siteSettings) {
  const director = getRenderDirector(
    reviewableType,
    reviewable,
    User.create(sessionFixtures["/session/current.json"].current_user),
    siteSettings,
    Site.current()
  );
  return director;
}
