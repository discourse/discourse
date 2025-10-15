import UpcomingEventsCalendar from "../../components/upcoming-events-calendar";

<template>
  <div class="discourse-post-event-upcoming-events">
    <UpcomingEventsCalendar
      @mine={{true}}
      @initialView={{@controller.initialView}}
      @initialDate={{@controller.initialDate}}
    />
  </div>
</template>
