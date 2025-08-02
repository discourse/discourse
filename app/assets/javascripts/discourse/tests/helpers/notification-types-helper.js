import { getRenderDirector } from "discourse/lib/notification-types-manager";
import { cloneJSON } from "discourse/lib/object";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";

export function createRenderDirector(
  notification,
  notificationType,
  siteSettings
) {
  const director = getRenderDirector(
    notificationType,
    notification,
    User.create(
      cloneJSON(sessionFixtures["/session/current.json"].current_user)
    ),
    siteSettings,
    Site.current()
  );
  return director;
}
