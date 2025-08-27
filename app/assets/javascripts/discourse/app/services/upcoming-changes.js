import Service from "@ember/service";
import PreloadStore from "discourse/lib/preload-store";

export default class UpcomingChanges extends Service {
  changeStore = null;

  constructor() {
    super(...arguments);

    // eslint-disable-next-line no-console
    console.log(PreloadStore.get("upcomingChanges"));

    // TODO (martin) Link up MessageBus to get live updates from admins changing experiments
    Object.entries(PreloadStore.get("upcomingChanges")).forEach(
      ([identifier, change]) => {
        this[identifier] = change;
      }
    );

    // this.changeStore = new TrackedObject();
  }
}
