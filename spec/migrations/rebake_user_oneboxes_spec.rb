# frozen_string_literal: true

require Rails.root.join("db/post_migrate/20261113004509_rebake_user_oneboxes.rb")

RSpec.describe RebakeUserOneboxes do
  fab!(:new_user) { Fabricate(:user, trust_level: TrustLevel[0]) }
  fab!(:member) { Fabricate(:user, trust_level: TrustLevel[1]) }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    SiteSetting.hide_new_user_profiles = false
    [new_user, member].each do |user|
      user.user_stat.update!(post_count: 1)
      user.user_profile.update!(bio_raw: "Bio of #{user.username}")
    end
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  def post_with_baked_user_onebox(user)
    post = Fabricate(:post, raw: "#{Discourse.base_url}/u/#{user.username}")
    post.update_columns(cooked: <<~HTML, baked_version: Post::BAKED_VERSION)
        <aside class="onebox">
          <article class="onebox-body user-onebox">
            <h3><a href="#{Discourse.base_url}/u/#{user.username}">@#{user.username}</a></h3>
            <p>Bio of #{user.username}</p>
          </article>
        </aside>
      HTML
    post
  end

  it "only marks posts with user oneboxes for rebaking" do
    onebox_post = post_with_baked_user_onebox(new_user)
    other_post = Fabricate(:post)
    other_post.update_columns(
      cooked:
        '<aside class="onebox allowlistedgeneric"><article class="onebox-body"></article></aside>',
      baked_version: Post::BAKED_VERSION,
    )

    described_class.new.up

    expect(onebox_post.reload.baked_version).to be_nil
    expect(other_post.reload.baked_version).to eq(Post::BAKED_VERSION)
  end

  it "re-renders the marked user oneboxes with the current profile visibility" do
    Jobs.run_immediately!
    stub_request(:get, /letter_avatar_proxy/).to_return(status: 404)
    new_user_post = post_with_baked_user_onebox(new_user)
    member_post = post_with_baked_user_onebox(member)

    described_class.new.up
    Post.rebake_old(10)

    expect(new_user_post.reload.cooked).not_to include("user-onebox")
    expect(new_user_post.cooked).not_to include("Bio of #{new_user.username}")
    expect(member_post.reload.cooked).to include("user-onebox")
    expect(member_post.cooked).to include("Bio of #{member.username}")
  end
end
