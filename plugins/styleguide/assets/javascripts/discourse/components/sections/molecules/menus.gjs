<StyleguideExample @title="<Dmenu />">
  <Styleguide::Component @tag="dmenu component">
    <:sample>
      <DMenu
        @label={{this.label}}
        @offset={{this.offset}}
        @arrow={{this.arrow}}
        @maxWidth={{this.maxWidth}}
        @identifier={{this.identifier}}
        @interactive={{this.interactive}}
        @triggers={{this.triggers}}
        @untriggers={{this.untriggers}}
        @content={{this.content}}
      >
        {{this.content}}
      </DMenu>
    </:sample>
  </Styleguide::Component>

  <Styleguide::Component @tag="dmenu component">
    <:sample>
      <DMenu
        @offset={{this.offset}}
        @arrow={{this.arrow}}
        @maxWidth={{this.maxWidth}}
        @identifier={{this.identifier}}
        @interactive={{this.interactive}}
        @triggers={{this.triggers}}
        @untriggers={{this.untriggers}}
        @content={{this.content}}
      >
        <:trigger>
          {{this.label}}
        </:trigger>
        <:content>
          {{this.content}}
        </:content>
      </DMenu>
    </:sample>
  </Styleguide::Component>

  <Styleguide::Component @tag="menu service">
    <:sample>
      <button
        type="button"
        class="btn btn-default"
        id="menu-instance"
      >{{this.label}}</button>
    </:sample>
    <:actions>
      <DButton @action={{this.registerMenu}}>Register</DButton>
    </:actions>
  </Styleguide::Component>

  <Styleguide::Component @tag="menu service">
    <:sample>
      <button
        type="button"
        class="btn btn-default"
        id="menu-instance-with-component"
      >{{this.label}}</button>
    </:sample>
    <:actions>
      <DButton @action={{this.registerMenuWithComponent}}>Register</DButton>
    </:actions>
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="Example label">
      <Input @value={{this.label}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@content]">
      <Input @value={{this.content}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@identifier]">
      <Input @value={{this.identifier}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@offset]">
      <Input @value={{this.offset}} @type="number" />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@triggers]">
      <Input @value={{this.triggers}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@untriggers]">
      <Input @value={{this.untriggers}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@maxWidth]">
      <Input @value={{this.maxWidth}} @type="number" />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@interactive]">
      <DToggleSwitch
        @state={{this.interactive}}
        {{on "click" this.toggleInteractive}}
      />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@arrow]">
      <DToggleSwitch @state={{this.arrow}} {{on "click" this.toggleArrow}} />
    </Styleguide::Controls::Row>
    <Styleguide::Controls::Row @name="[@inline]">
      <DToggleSwitch @state={{this.inline}} {{on "click" this.toggleInline}} />
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
</StyleguideExample>