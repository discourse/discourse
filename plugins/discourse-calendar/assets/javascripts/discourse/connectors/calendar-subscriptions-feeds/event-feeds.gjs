import CalendarSubscriptionUrl from "discourse/components/calendar-subscription-url";
import { i18n } from "discourse-i18n";

<template>
  {{#if @outletArgs.urls.all_events}}
    <CalendarSubscriptionUrl
      @label={{i18n "discourse_calendar.preferences.all_events"}}
      @description={{i18n
        "discourse_calendar.preferences.all_events_description"
      }}
      @url={{@outletArgs.urls.all_events}}
    />
  {{/if}}

  {{#if @outletArgs.urls.my_events}}
    <CalendarSubscriptionUrl
      @label={{i18n "discourse_calendar.preferences.my_events"}}
      @description={{i18n
        "discourse_calendar.preferences.my_events_description"
      }}
      @url={{@outletArgs.urls.my_events}}
    />
  {{/if}}
</template>
