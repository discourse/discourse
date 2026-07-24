import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import DockedComposer from "discourse/components/docked-composer";
import PostStream from "discourse/components/post-stream";
import TopicCategory from "discourse/components/topic-category";
import Post from "discourse/models/post";
import DButton from "discourse/ui-kit/d-button";

@block("topic-sidebar-block", {
  description: "Displays the selected topic inside the right sidebar",
})
export default class TopicSidebarBlock extends Component {
  @service topicSidebar;

  get topic() {
    return this.topicSidebar.selectedTopicId ? this.topicSidebar.topic : null;
  }

  @action
  close() {
    this.topicSidebar.clearSelectedTopic();
  }

  @action
  async onComposerSubmit({ raw }) {
    const topic = this.topic;
    if (!topic || !raw?.trim()) {
      return;
    }
    const post = Post.create({ raw, topic_id: topic.id });
    await post.save();
    await topic.postStream.refresh();
  }

  <template>
    {{#if this.topic}}
      <div class="topic-sidebar-block">
        <DButton
          @action={{this.close}}
          @icon="xmark"
          @title="close"
          class="btn-flat topic-sidebar-block__close"
        />
        <div class="topic-sidebar-block__scroll">
          <h2 class="topic-sidebar-block__title fancy-title">
            {{trustHTML this.topic.fancyTitle}}
          </h2>

          <TopicCategory @topic={{this.topic}} class="topic-category" />

          <PostStream
            @postStream={{this.topic.postStream}}
            @topic={{this.topic}}
          />
        </div>

        <DockedComposer
          @topicId={{this.topic.id}}
          @onSubmit={{this.onComposerSubmit}}
        />
      </div>
    {{/if}}
  </template>
}
