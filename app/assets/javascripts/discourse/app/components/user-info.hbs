{{#if this.includeAvatar}}
  <div class="user-image">
    <div class="user-image-inner">
      <a
        href={{this.userPath}}
        data-user-card={{@user.username}}
        aria-hidden="true"
      >{{avatar @user imageSize="large"}}</a>
      <UserAvatarFlair @user={{@user}} />
    </div>
  </div>
{{/if}}
<div class="user-detail">
  <div class="name-line">
    {{#if this.includeLink}}
      <a
        href={{this.userPath}}
        data-user-card={{@user.username}}
        role="heading"
      >
        <span class={{if this.nameFirst "name" "username"}}>
          {{if this.nameFirst @user.name (format-username @user.username)}}
        </span>
        <span class={{if this.nameFirst "username" "name"}}>
          {{if this.nameFirst (format-username @user.username) @user.name}}
        </span>
      </a>
    {{else}}
      <span class={{if this.nameFirst "name" "username"}}>
        {{if this.nameFirst @user.name (format-username @user.username)}}
      </span>
      <span class={{if this.nameFirst "username" "name"}}>
        {{if this.nameFirst (format-username @user.username) @user.name}}
      </span>
    {{/if}}
    {{#if (and @showStatus @user.status)}}
      <UserStatusMessage
        @status={{@user.status}}
        @showDescription={{@showStatusDescription}}
      />
    {{/if}}
    <PluginOutlet
      @name="after-user-name"
      @connectorTagName="span"
      @outletArgs={{hash user=this.user}}
    />
  </div>
  <div class="title">{{@user.title}}</div>
  {{#if (has-block)}}
    <div class="details">
      {{yield}}
    </div>
  {{/if}}
</div>

<PluginOutlet
  @name="after-user-info"
  @connectorTagName="div"
  @outletArgs={{hash user=this.user}}
/>