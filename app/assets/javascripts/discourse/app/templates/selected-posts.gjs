import RouteTemplate from "ember-route-template";
import SelectedPosts from "discourse/components/selected-posts";

export default RouteTemplate(
  <template>
    <SelectedPosts
      @selectedPostsCount={{@controller.selectedPostsCount}}
      @canSelectAll={{@controller.canSelectAll}}
      @canDeselectAll={{@controller.canDeselectAll}}
      @canDeleteSelected={{@controller.canDeleteSelected}}
      @canMergeTopic={{@controller.canMergeTopic}}
      @canChangeOwner={{@controller.canChangeOwner}}
      @canMergePosts={{@controller.canMergePosts}}
      @toggleMultiSelect={{action "toggleMultiSelect"}}
      @mergePosts={{action "mergePosts"}}
      @deleteSelected={{action "deleteSelected"}}
      @deselectAll={{action "deselectAll"}}
      @selectAll={{action "selectAll"}}
    />
  </template>
);
