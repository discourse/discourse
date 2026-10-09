import TopicTimerInfo from "discourse/components/topic-timer-info";

const EXECUTE_AT = moment().add(2, "days");

export default <template>
  <TopicTimerInfo @executeAt={{EXECUTE_AT}} @statusType="reminder" />
</template>
