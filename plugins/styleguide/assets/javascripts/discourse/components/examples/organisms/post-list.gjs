import PostList from "discourse/components/post-list";

export default <template>
  <PostList
    @posts={{@posts}}
    @additionalItemClasses="styleguide-post-list-item"
  />
</template>
