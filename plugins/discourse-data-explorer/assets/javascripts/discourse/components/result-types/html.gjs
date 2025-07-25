import htmlSafe from "discourse/helpers/html-safe";

const Html = <template>{{htmlSafe @ctx.value}}</template>;

export default Html;
