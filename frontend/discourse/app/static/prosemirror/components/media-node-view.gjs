import { eq } from "discourse/truth-helpers";
import ImageNodeView from "./image-node-view";
import VideoNodeView from "./video-node-view";

export default <template>
  {{#if (eq @node.attrs.extras "video")}}
    <VideoNodeView
      @contentDOM={{@contentDOM}}
      @dom={{@dom}}
      @getPos={{@getPos}}
      @node={{@node}}
      @onSetup={{@onSetup}}
      @options={{@options}}
      @pluginParams={{@pluginParams}}
      @view={{@view}}
    />
  {{else}}
    <ImageNodeView
      @contentDOM={{@contentDOM}}
      @dom={{@dom}}
      @getPos={{@getPos}}
      @node={{@node}}
      @onSetup={{@onSetup}}
      @options={{@options}}
      @pluginParams={{@pluginParams}}
      @view={{@view}}
    />
  {{/if}}
</template>
