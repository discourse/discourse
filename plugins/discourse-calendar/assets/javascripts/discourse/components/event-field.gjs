import { notEq } from "truth-helpers";
import { i18n } from "discourse-i18n";

const EventField = <template>
  {{#if (notEq @enabled false)}}
    <div class="event-field" ...attributes>
      {{#if @label}}
        <div class="event-field-label">
          <span class="label">{{i18n @label}}</span>
        </div>
      {{/if}}

      <div class="event-field-control">
        {{yield}}
      </div>
    </div>
  {{/if}}
</template>;

export default EventField;
