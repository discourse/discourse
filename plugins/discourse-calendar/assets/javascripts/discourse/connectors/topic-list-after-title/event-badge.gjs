import Component from "@glimmer/component";
import { service } from "@ember/service";
import EventDate from "../../components/event-date";

export default class EventBadge extends Component {
  @service siteSettings;

  <template>
    {{~#if this.siteSettings.discourse_post_event_enabled~}}
      {{~#if @outletArgs.topic.event_starts_at~}}
        <EventDate @topic={{@outletArgs.topic}} />
      {{~/if~}}
    {{~/if~}}
  </template>
}
