import { trustHTML } from "@ember/template";

const Html = <template>{{trustHTML @ctx.value}}</template>;

export default Html;
