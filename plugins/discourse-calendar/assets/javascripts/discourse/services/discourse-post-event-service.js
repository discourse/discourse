import Service, { service } from "@ember/service";

export default class DiscoursePostEventService extends Service {
  @service discoursePostEventApi;

  async fetchEvents(params = {}) {
    return await this.discoursePostEventApi.events(params);
  }
}
