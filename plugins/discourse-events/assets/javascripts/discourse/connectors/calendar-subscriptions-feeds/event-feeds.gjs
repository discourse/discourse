import CalendarSubscriptionUrl from "discourse/components/calendar-subscription-url";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @outletArgs.urls.all_events}}
    <CalendarSubscriptionUrl
      @label={{i18n "discourse_events.preferences.all_events"}}
      @description={{i18n
        "discourse_events.preferences.all_events_description"
      }}
      @url={{@outletArgs.urls.all_events}}
    />
  {{/if}}

  {{#if @outletArgs.urls.my_events}}
    <CalendarSubscriptionUrl
      @label={{i18n "discourse_events.preferences.my_events"}}
      @description={{i18n "discourse_events.preferences.my_events_description"}}
      @url={{@outletArgs.urls.my_events}}
    />
  {{/if}}
</template>
