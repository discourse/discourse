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
      @toggleMultiSelect={{@controller.toggleMultiSelect}}
      @mergePosts={{@controller.mergePosts}}
      @deleteSelected={{@controller.deleteSelected}}
      @deselectAll={{@controller.deselectAll}}
      @selectAll={{@controller.selectAll}}
    />
  </template>
);
