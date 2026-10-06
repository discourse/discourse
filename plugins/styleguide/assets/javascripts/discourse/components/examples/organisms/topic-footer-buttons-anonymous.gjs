import DButton from "discourse/ui-kit/d-button";

export default <template>
  <div id="topic-footer-buttons">
    <DButton
      class="btn-primary pull-right"
      @icon="reply"
      @label="topic.reply.title"
    />
  </div>
</template>
