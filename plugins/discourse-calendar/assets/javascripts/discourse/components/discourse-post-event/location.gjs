import CookText from "discourse/components/cook-text";
import icon from "discourse/helpers/d-icon";

const DiscoursePostEventLocation = <template>
  {{#if @location}}
    <section class="event__section event-location">
      {{icon "location-pin"}}

      <CookText @rawText={{@location}} />
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventLocation;
