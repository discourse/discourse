import Component from "@glimmer/component";
import CategoryReadOnlyBanner from "discourse/components/category-read-only-banner";
import DiscourseBanner from "discourse/components/discourse-banner";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";

export default class Layout extends Component {
  get listClass() {
    if ("filterType" in this.args.model) {
      return "--topic-list";
    } else if (this.args.model.categories) {
      return "--category-list";
    }
  }

  <template>
    <DiscourseBanner />
    {{#if @model.category}}
      <CategoryReadOnlyBanner
        @category={{@model.category}}
        @readOnly={{@createTopicDisabled}}
      />
    {{/if}}

    <PluginOutlet
      @name="discovery-list-controls-above"
      @connectorTagName="div"
      @outletArgs={{lazyHash
        category=@model.category
        tag=@model.tag
        toggleTagInfo=@toggleTagInfo
      }}
    />

    <div class="list-controls">
      <PluginOutlet
        @name="discovery-navigation-bar-above"
        @connectorTagName="div"
        @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
      />
      <div class="container">
        {{yield to="navigation"}}
      </div>
    </div>

    <PluginOutlet
      @name="discovery-above"
      @connectorTagName="div"
      @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
    />

    <div class={{concatClass "container list-container" this.listClass}}>
      <div id="header-list-area">
        {{yield to="header"}}
        <PluginOutlet
          @name="header-list-container-bottom"
          @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
        />
      </div>
      <PluginOutlet
        @name="before-list-area"
        @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
      />
      <div id="list-area">
        <PluginOutlet
          @name="discovery-list-area"
          @outletArgs={{lazyHash
            category=@model.category
            tag=@model.tag
            model=@model
          }}
          @defaultGlimmer={{true}}
        >
          <PluginOutlet
            @name="discovery-list-container-top"
            @connectorTagName="span"
            @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
          />
          {{yield to="list"}}
        </PluginOutlet>
      </div>
    </div>

    <PluginOutlet
      @name="discovery-below"
      @connectorTagName="div"
      @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
    />
  </template>
}
