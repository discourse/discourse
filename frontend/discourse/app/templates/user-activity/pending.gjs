import { fn } from "@ember/helper";
import PostList from "discourse/components/post-list/index";
import DButton from "discourse/ui-kit/d-button";

export default <template>
  <ul class="user-stream">
    <PostList
      class="user-stream"
      @additionalItemClasses="user-stream-item"
      @posts={{@controller.model.content}}
      @showUserInfo={{false}}
      @urlPath="postUrl"
    >
      <:belowPostItem as |pending|>
        {{#if @controller.canDeletePending}}
          <div class="reviewable-actions">
            <DButton
              class="btn-danger"
              @action={{fn @controller.deletePending pending}}
              @icon="trash-can"
              @label="review.delete"
            />
          </div>
        {{/if}}
      </:belowPostItem>
    </PostList>
  </ul>
</template>
