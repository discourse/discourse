import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

// glimmer-post-stream: has glimmer version
export default createWidget("post-placeholder", {
  tagName: "article.placeholder",
  template: hbs`
    <div class='row'>
      <div class='topic-avatar'>
        <div class='placeholder-avatar placeholder-animation'></div>
      </div>
      <div class='topic-body'>
        <div class='placeholder-text placeholder-animation'></div>
        <div class='placeholder-text placeholder-animation'></div>
        <div class='placeholder-text placeholder-animation'></div>
      </div>
    </div>
  `,
});
