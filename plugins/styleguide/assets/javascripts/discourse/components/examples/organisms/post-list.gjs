import PostList from "discourse/components/post-list";

export default <template>
  <PostList
    @additionalItemClasses="styleguide-post-list-item"
    @posts={{@posts}}
  />
</template>
