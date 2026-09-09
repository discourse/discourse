import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class VoiceDashboardRoute extends Route {
  queryParams = {
    period: { refreshModel: true },
    start_date: { refreshModel: true },
    end_date: { refreshModel: true },
  };

  async model() {
    const controller = this.controllerFor("admin-plugins.show.voice-dashboard");
    const queryString = this.#buildQuery(controller);

    const [overview, rooms, users] = await Promise.all([
      ajax(`/admin/plugins/voice/stats/overview.json?${queryString}`),
      ajax(`/admin/plugins/voice/stats/rooms.json?${queryString}`),
      ajax(`/admin/plugins/voice/stats/users.json?${queryString}`),
    ]);

    return { overview, rooms: rooms.rooms, users: users.users };
  }

  #buildQuery(controller) {
    const params = new URLSearchParams();
    params.set("period", controller.period || "weekly");

    if (controller.start_date) {
      params.set("start_date", controller.start_date);
    }
    if (controller.end_date) {
      params.set("end_date", controller.end_date);
    }

    return params.toString();
  }
}
