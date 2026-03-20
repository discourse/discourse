import DCookText from "discourse/ui-kit/d-cook-text";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const DiscoursePostEventLocation = <template>
  {{#if @location}}
    <section class="event__section event-location">
      {{dIcon "location-pin"}}

      <DCookText @rawText={{@location}} />
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventLocation;
