import CookText from "discourse/ui-kit/d-cook-text";
import icon from "discourse/ui-kit/helpers/d-icon";

const DiscoursePostEventLocation = <template>
  {{#if @location}}
    <section class="event__section event-location">
      {{icon "location-pin"}}

      <CookText @rawText={{@location}} />
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventLocation;
