import { hash } from "@ember/helper";
import CategoryReadOnlyBanner from "discourse/components/category-read-only-banner";
import DiscourseBanner from "discourse/components/discourse-banner";
import PluginOutlet from "discourse/components/plugin-outlet";

const Layout = <template>
  <div class="container">
    <DiscourseBanner />
    {{#if @model.category}}
      <CategoryReadOnlyBanner
        @category={{@model.category}}
        @readOnly={{@createTopicDisabled}}
      />
    {{/if}}
  </div>

  <span>
    <PluginOutlet
      @name="discovery-list-controls-above"
      @connectorTagName="div"
      @outletArgs={{hash
        category=@model.category
        tag=@model.tag
        toggleTagInfo=@toggleTagInfo
      }}
    />
  </span>

  <div class="list-controls">
    <PluginOutlet
      @name="discovery-navigation-bar-above"
      @connectorTagName="div"
      @outletArgs={{hash category=@model.category tag=@model.tag}}
    />
    <div class="container">
      {{yield to="navigation"}}
    </div>
  </div>

  <PluginOutlet
    @name="discovery-above"
    @connectorTagName="div"
    @outletArgs={{hash category=@model.category tag=@model.tag}}
  />

  <div class="container list-container">
    <div class="row">
      <div class="full-width">
        <div id="header-list-area">
          {{yield to="header"}}
          <PluginOutlet
            @name="header-list-container-bottom"
            @outletArgs={{hash category=@model.category tag=@model.tag}}
          />
        </div>
      </div>
    </div>
    <div class="row">
      <div class="full-width">
        <PluginOutlet
          @name="before-list-area"
          @outletArgs={{hash category=@model.category tag=@model.tag}}
        />
        <div id="list-area">
          <PluginOutlet
            @name="discovery-list-area"
            @outletArgs={{hash
              category=@model.category
              tag=@model.tag
              model=@model
            }}
            @defaultGlimmer={{true}}
          >
            <PluginOutlet
              @name="discovery-list-container-top"
              @connectorTagName="span"
              @outletArgs={{hash category=@model.category tag=@model.tag}}
            />
            {{yield to="list"}}
          </PluginOutlet>
        </div>
      </div>
    </div>
  </div>

  <span>
    <PluginOutlet
      @name="discovery-below"
      @connectorTagName="div"
      @outletArgs={{hash category=@model.category tag=@model.tag}}
    />
  </span>
</template>;
export default Layout;
