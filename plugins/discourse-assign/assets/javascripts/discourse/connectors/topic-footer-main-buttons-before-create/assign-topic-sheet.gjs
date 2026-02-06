import AssignTopicSheet from "../../components/assign-topic-sheet";

const AssignTopicSheetConnector = <template>
  <AssignTopicSheet @topic={{@outletArgs.topic}} />
</template>;

export default AssignTopicSheetConnector;
