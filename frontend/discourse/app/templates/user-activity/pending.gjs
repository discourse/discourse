import { fn } from "@ember/helper";
import PostList from "discourse/components/post-list/index";
import DButton from "discourse/ui-kit/d-button";

export default <template>
  <ul class="user-stream">
    <PostList
      @posts={{@controller.model.content}}
      @urlPath="postUrl"
      @showUserInfo={{false}}
      @additionalItemClasses="user-stream-item"
      class="user-stream"
    >
      <:belowPostItem as |pending|>
        <div class="reviewable-actions">
          <DButton
            @label="review.delete"
            @icon="trash-can"
            @action={{fn @controller.deletePending pending}}
            class="btn-danger"
          />
        </div>
      </:belowPostItem>
    </PostList>
  </ul>
</template>
