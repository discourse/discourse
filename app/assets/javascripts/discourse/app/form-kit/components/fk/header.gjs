import { hash } from "@ember/helper";

const Title = <template>
  <h2 class="form-kit__header-title">{{yield}}</h2>
</template>;

const Subtitle = <template>
  <span class="form-kit__header-subtitle">{{yield}}</span>
</template>;

const FKHeader = <template>
  <div class="form-kit__header" ...attributes>
    {{yield (hash Title=Title Subtitle=Subtitle)}}
    <div class="form-kit__header-separator"></div>
  </div>
</template>;

export default FKHeader;
