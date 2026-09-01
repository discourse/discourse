import SelectedPosts from "discourse/components/selected-posts";

export default <template>
  <SelectedPosts
    @canChangeOwner={{@controller.canChangeOwner}}
    @canDeleteSelected={{@controller.canDeleteSelected}}
    @canDeselectAll={{@controller.canDeselectAll}}
    @canMergePosts={{@controller.canMergePosts}}
    @canMergeTopic={{@controller.canMergeTopic}}
    @canSelectAll={{@controller.canSelectAll}}
    @deleteSelected={{@controller.deleteSelected}}
    @deselectAll={{@controller.deselectAll}}
    @mergePosts={{@controller.mergePosts}}
    @selectAll={{@controller.selectAll}}
    @selectedPostsCount={{@controller.selectedPostsCount}}
    @toggleMultiSelect={{@controller.toggleMultiSelect}}
  />
</template>
