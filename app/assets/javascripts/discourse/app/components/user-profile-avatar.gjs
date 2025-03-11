<PluginOutlet
  @name="user-profile-avatar-wrapper"
  @outletArgs={{hash user=@user}}
>
  <div class="user-profile-avatar">
    <PluginOutlet
      @name="user-profile-avatar-img-wrapper"
      @outletArgs={{hash user=@user}}
    >
      {{bound-avatar @user "huge"}}
    </PluginOutlet>

    <UserAvatarFlair @user={{@user}} />
    <div>
      <PluginOutlet
        @name="user-profile-avatar-flair"
        @outletArgs={{hash model=@user}}
      />
    </div>
  </div>
</PluginOutlet>