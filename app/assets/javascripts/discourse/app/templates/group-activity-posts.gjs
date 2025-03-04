import RouteTemplate from 'ember-route-template'
import PostList from "discourse/components/post-list/index";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template><PostList @posts={{@controller.model}} @titlePath="topic_html_title" @fetchMorePosts={{@controller.fetchMorePosts}} @emptyText={{iN "groups.empty.posts"}} /></template>)