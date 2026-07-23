import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import openLinksInNewTab from "discourse/plugins/discourse-calendar/discourse/modifiers/open-links-in-new-tab";

const DiscoursePostEventLocation = <template>
  {{#if @locationHtml}}
    <section class="event__section event-location">
      {{dIcon "location-pin"}}

      <span
        class="event-location__text"
        {{openLinksInNewTab @locationHtml}}
      >{{trustHTML @locationHtml}}</span>
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventLocation;
