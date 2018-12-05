require 'rails_helper'

RSpec.describe ApplicationController do
  describe '#redirect_to_login_if_required' do
    let(:admin) { Fabricate(:admin) }

    before do
      admin  # to skip welcome wizard at home page `/`
      SiteSetting.login_required = true
    end

    it "should carry-forward authComplete param to login page redirect" do
      get "/?authComplete=true"
      expect(response).to redirect_to('/login?authComplete=true')
    end

    it "should never cache a login redirect" do
      get "/"
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
    end
  end

  describe 'invalid request params' do
    before do
      @old_logger = Rails.logger
      @logs = StringIO.new
      Rails.logger = Logger.new(@logs)
    end

    after do
      Rails.logger = @old_logger
    end

    it 'should not raise a 500 (nor should it log a warning) for bad params' do
      bad_str = "d\xDE".force_encoding('utf-8')
      expect(bad_str.valid_encoding?).to eq(false)

      get "/latest.json", params: { test: bad_str }

      expect(response.status).to eq(400)

      log = @logs.string

      if (log.include? 'exception app middleware')
        # heisentest diagnostics
        puts
        puts "EXTRA DIAGNOSTICS FOR INTERMITENT TEST FAIL"
        puts log
        puts ">> action_dispatch.exception"
        ex = request.env['action_dispatch.exception']
        puts ">> exception class: #{ex.class} : #{ex}"
      end

      expect(log).not_to include('exception app middleware')

      expect(JSON.parse(response.body)).to eq(
        "status" => 400,
        "error" => "Bad Request"
      )

    end
  end

  describe 'missing required param' do
    it 'should return a 400' do
      get "/search/query.json", params: { trem: "misspelled term" }

      expect(response.status).to eq(400)
      expect(JSON.parse(response.body)).to eq(
        "errors" => ["param is missing or the value is empty: term"]
      )
    end
  end

  describe 'build_not_found_page' do
    describe 'topic not found' do

      it 'should not redirect to permalink if topic/category does not exist' do
        topic = create_post.topic
        Permalink.create!(url: topic.relative_url, topic_id: topic.id + 1)
        topic.trash!
        get topic.relative_url
        expect(response.status).to eq(410)
      end

      it 'should return permalink for deleted topics' do
        topic = create_post.topic
        external_url = 'https://somewhere.over.rainbow'
        Permalink.create!(url: topic.relative_url, external_url: external_url)
        topic.trash!

        get topic.relative_url
        expect(response.status).to eq(301)
        expect(response).to redirect_to(external_url)

        get "/t/#{topic.id}.json"
        expect(response.status).to eq(301)
        expect(response).to redirect_to(external_url)

        get "/t/#{topic.id}.json", xhr: true
        expect(response.status).to eq(200)
        expect(response.body).to eq(external_url)
      end

      it 'supports subfolder with permalinks' do
        GlobalSetting.stubs(:relative_url_root).returns('/forum')
        Discourse.stubs(:base_uri).returns("/forum")

        trashed_topic = create_post.topic
        trashed_topic.trash!
        new_topic = create_post.topic
        permalink = Permalink.create!(url: trashed_topic.relative_url, topic_id: new_topic.id)

        # no subfolder because router doesn't know about subfolder in this test
        get "/t/#{trashed_topic.slug}/#{trashed_topic.id}"
        expect(response.status).to eq(301)
        expect(response).to redirect_to("/forum/t/#{new_topic.slug}/#{new_topic.id}")

        permalink.destroy
        category = Fabricate(:category)
        permalink = Permalink.create!(url: trashed_topic.relative_url, category_id: category.id)
        get "/t/#{trashed_topic.slug}/#{trashed_topic.id}"
        expect(response.status).to eq(301)
        expect(response).to redirect_to("/forum/c/#{category.slug}")

        permalink.destroy
        permalink = Permalink.create!(url: trashed_topic.relative_url, post_id: new_topic.posts.last.id)
        get "/t/#{trashed_topic.slug}/#{trashed_topic.id}"
        expect(response.status).to eq(301)
        expect(response).to redirect_to("/forum/t/#{new_topic.slug}/#{new_topic.id}/#{new_topic.posts.last.post_number}")
      end

      it 'should return 404 and show Google search' do
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to include(I18n.t('page_not_found.search_button'))
      end

      it 'should not include Google search if login_required is enabled' do
        SiteSetting.login_required = true
        sign_in(Fabricate(:user))
        get "/t/nope-nope/99999999"
        expect(response.status).to eq(404)
        expect(response.body).to_not include('google.com/search')
      end
    end
  end

  describe "#handle_theme" do
    let(:theme) { Fabricate(:theme, user_selectable: true) }
    let(:theme2) { Fabricate(:theme, user_selectable: true) }
    let(:non_selectable_theme) { Fabricate(:theme, user_selectable: false) }
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }

    before do
      sign_in(user)
    end

    it "selects the theme the user has selected" do
      user.user_option.update_columns(theme_ids: [theme.id])

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_ids).to eq([theme.id])

      theme.update_attribute(:user_selectable, false)

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_ids).to eq([SiteSetting.default_theme_id])
    end

    it "can be overridden with a cookie" do
      user.user_option.update_columns(theme_ids: [theme.id])

      cookies['theme_ids'] = "#{theme2.id}|#{user.user_option.theme_key_seq}"

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_ids).to eq([theme2.id])

      theme2.update!(user_selectable: false, component: true)
      theme.add_child_theme!(theme2)
      cookies['theme_ids'] = "#{theme.id},#{theme2.id}|#{user.user_option.theme_key_seq}"

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_ids).to eq([theme.id, theme2.id])
    end

    it "falls back to the default theme when the user has no cookies or preferences" do
      user.user_option.update_columns(theme_ids: [])
      cookies["theme_ids"] = nil
      theme2.set_default!

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_ids).to eq([theme2.id])
    end

    it "can be overridden with preview_theme_id param" do
      sign_in(admin)
      cookies['theme_ids'] = "#{theme.id},#{theme2.id}|#{admin.user_option.theme_key_seq}"

      get "/", params: { preview_theme_id: theme2.id }
      expect(response.status).to eq(200)
      expect(controller.theme_ids).to eq([theme2.id])

      get "/", params: { preview_theme_id: non_selectable_theme.id }
      expect(controller.theme_ids).to eq([non_selectable_theme.id])
    end

    it "does not allow non privileged user to preview themes" do
      sign_in(user)
      get "/", params: { preview_theme_id: non_selectable_theme.id }
      expect(controller.theme_ids).to eq([SiteSetting.default_theme_id])
    end

    it "cookie can fail back to user if out of sync" do
      user.user_option.update_columns(theme_ids: [theme.id])
      cookies['theme_ids'] = "#{theme2.id}|#{user.user_option.theme_key_seq - 1}"

      get "/"
      expect(response.status).to eq(200)
      expect(controller.theme_ids).to eq([theme.id])
    end
  end

  describe 'Custom hostname' do

    it 'does not allow arbitrary host injection' do
      get("/latest",
        headers: {
          "X-Forwarded-Host" => "test123.com"
        }
      )

      expect(response.body).not_to include("test123")
    end
  end

  describe 'Content Security Policy' do
    it 'is enabled by SiteSettings' do
      SiteSetting.content_security_policy = false
      SiteSetting.content_security_policy_report_only = false

      get '/'

      expect(response.headers).to_not include('Content-Security-Policy')
      expect(response.headers).to_not include('Content-Security-Policy-Report-Only')

      SiteSetting.content_security_policy = true
      SiteSetting.content_security_policy_report_only = true

      get '/'

      expect(response.headers).to include('Content-Security-Policy')
      expect(response.headers).to include('Content-Security-Policy-Report-Only')
    end

    it 'can be customized with SiteSetting' do
      SiteSetting.content_security_policy = true

      get '/'
      script_src = parse(response.headers['Content-Security-Policy'])['script-src']

      expect(script_src).to_not include('example.com')

      SiteSetting.content_security_policy_script_src = 'example.com'

      get '/'
      script_src = parse(response.headers['Content-Security-Policy'])['script-src']

      expect(script_src).to include('example.com')
      expect(script_src).to include("'unsafe-eval'")
    end

    it 'does not set CSP when responding to non-HTML' do
      SiteSetting.content_security_policy = true
      SiteSetting.content_security_policy_report_only = true

      get '/latest.json'

      expect(response.headers).to_not include('Content-Security-Policy')
      expect(response.headers).to_not include('Content-Security-Policy-Report-Only')
    end

    def parse(csp_string)
      csp_string.split(';').map do |policy|
        directive, *sources = policy.split
        [directive, sources]
      end.to_h
    end
  end
end
