import CookText from "discourse/ui-kit/d-cook-text";

const DiscoursePostEventDescription = <template>
  {{#if @description}}
    <section class="event__section event-description">
      <CookText @rawText={{@description}} />
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventDescription;
