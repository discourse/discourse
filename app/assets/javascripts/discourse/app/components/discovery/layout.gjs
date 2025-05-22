import CategoryReadOnlyBanner from "discourse/components/category-read-only-banner";
import DiscourseBanner from "discourse/components/discourse-banner";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";

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

  <div class="container list-container">
    <div class="row">
      <div class="full-width">
        <div id="header-list-area">
          {{yield to="header"}}
          <PluginOutlet
            @name="header-list-container-bottom"
            @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
          />
        </div>
      </div>
    </div>
    <div class="row">
      <div class="full-width">
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
    </div>
  </div>

  <PluginOutlet
    @name="discovery-below"
    @connectorTagName="div"
    @outletArgs={{lazyHash category=@model.category tag=@model.tag}}
  />
</template>;

export default Layout;
