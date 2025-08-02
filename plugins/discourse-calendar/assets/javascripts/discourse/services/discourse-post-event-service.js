import Service, { service } from "@ember/service";

export default class DiscoursePostEventService extends Service {
  @service siteSettings;
  @service discoursePostEventApi;

  async fetchEvents(params = {}) {
    if (this.siteSettings.include_expired_events_on_calendar) {
      params.include_expired = true;
    }
    const events = await this.discoursePostEventApi.events(params);
    return await events;
  }
}
