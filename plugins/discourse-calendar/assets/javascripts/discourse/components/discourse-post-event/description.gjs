import DCookText from "discourse/ui-kit/d-cook-text";

const DiscoursePostEventDescription = <template>
  {{#if @description}}
    <section class="event__section event-description">
      <DCookText @rawText={{@description}} />
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventDescription;
