import DButton from "discourse/ui-kit/d-button";

export default <template>
  <div id="topic-footer-buttons">
    <DButton
      @icon="reply"
      @label="topic.reply.title"
      class="btn-primary pull-right"
    />
  </div>
</template>
