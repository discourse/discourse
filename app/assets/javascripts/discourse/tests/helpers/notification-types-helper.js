import { getRenderDirector } from "discourse/lib/notification-types-manager";
import sessionFixtures from "discourse/tests/fixtures/session-fixtures";
import User from "discourse/models/user";
import Site from "discourse/models/site";

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
