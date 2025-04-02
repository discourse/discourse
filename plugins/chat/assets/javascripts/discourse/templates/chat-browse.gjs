<div class="c-routes --browse">
  <Chat::Navbar as |navbar|>
    <navbar.BackButton />
    <navbar.Title @title={{i18n "chat.browse.title"}} />

    <navbar.Actions as |a|>
      <a.NewChannelButton />
      <a.OpenDrawerButton />
    </navbar.Actions>
  </Chat::Navbar>

  {{outlet}}
</div>