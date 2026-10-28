import EventDate from "../../components/event-date.gjs";

const EventDateContainer = <template>
  <EventDate @topic={{@outletArgs.topic}} />
</template>;

export default EventDateContainer;
