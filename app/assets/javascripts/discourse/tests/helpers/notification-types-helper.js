import { getRenderDirector } from "discourse/lib/notification-types-manager";
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
    User.create(sessionFixtures["/session/current.json"].current_user),
    siteSettings,
    Site.current()
  );
  return director;
}
