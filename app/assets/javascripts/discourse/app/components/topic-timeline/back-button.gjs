import DButton from "discourse/components/d-button";

const BackButton = <template>
  <DButton
    @action={{@onGoBack}}
    @label="topic.timeline.back"
    @title="topic.timeline.back_description"
    class="btn-primary btn-small back-button"
  />
</template>;

export default BackButton;
