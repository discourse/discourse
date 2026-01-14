import { htmlSafe } from "@ember/template";

const Html = <template>{{htmlSafe @ctx.value}}</template>;

export default Html;
