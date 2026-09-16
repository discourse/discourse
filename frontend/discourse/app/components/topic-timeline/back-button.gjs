import DButton from "discourse/ui-kit/d-button";

const BackButton = <template>
  <DButton
    class="btn-primary btn-small back-button"
    @action={{@onGoBack}}
    @label="topic.timeline.back"
    @title="topic.timeline.back_description"
  />
</template>;

export default BackButton;
