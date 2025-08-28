import Service, { service } from "@ember/service";

export default class DiscoursePostEventService extends Service {
  @service siteSettings;
  @service discoursePostEventApi;

  async fetchEvents(params = {}) {
    const events = await this.discoursePostEventApi.events(params);
    return await events;
  }
}
