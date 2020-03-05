# frozen_string_literal: true

require 'rails_helper'

describe PermalinksController do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:permalink) { Fabricate(:permalink, url: "deadroutee/topic/546") }

  describe 'show' do
    it "should redirect to a permalink's target_url with status 301" do
      permalink.update!(topic_id: topic.id)

      get "/#{permalink.url}"

      expect(response).to redirect_to(topic.relative_url)
      expect(response.status).to eq(301)
    end

    it "should work for subfolder installs too" do
      permalink.update!(topic_id: topic.id)
      set_subfolder "/forum"

      get "/#{permalink.url}"

      expect(response).to redirect_to(topic.relative_url)
      expect(response.status).to eq(301)
    end

    it "should apply normalizations" do
      permalink.update!(external_url: '/topic/100')
      SiteSetting.permalink_normalizations = "/(.*)\\?.*/\\1"

      get "/#{permalink.url}", params: { test: "hello" }

      expect(response).to redirect_to('/topic/100')
      expect(response.status).to eq(301)

      SiteSetting.permalink_normalizations = "/(.*)\\?.*/\\1X"

      get "/#{permalink.url}", params: { test: "hello" }

      expect(response.status).to eq(404)
    end

    it 'return 404 if permalink record does not exist' do
      get '/not/a/valid/url'
      expect(response.status).to eq(404)
    end
  end

  describe 'show go' do
    fab!(:go_link) { Fabricate(:permalink, url: 'go/meta', external_url: 'https://meta.discourse.org/') }
    fab!(:go_topic) { Fabricate(:permalink, url: 'go/important', topic_id: topic.id) }
    fab!(:go_tricky) { Fabricate(:permalink, url: 'go/tricky', external_url: 'https://example.com/folder?tricky=true') }
    fab!(:go_slashes) { Fabricate(:permalink, url: 'go/meta/codinghorror', external_url: 'https://meta.discourse.org/u/codinghorror/') }

    it 'redirects to the link target with a non-permanent redirect' do
      get '/go/meta'
      expect(response.status).to eq(302)
      expect(response).to redirect_to('https://meta.discourse.org/')
    end

    it 'works with a trailing slash' do
      get '/go/meta/'
      expect(response.status).to eq(302)
      expect(response).to redirect_to('https://meta.discourse.org/')
    end

    it 'works with topic targets' do
      get '/go/important'
      expect(response.status).to eq(302)
      expect(response).to redirect_to(topic.relative_url)
    end

    it 'works for subfolder installs too' do
      set_subfolder "/forum"

      get '/go/meta/'
      expect(response.status).to eq(302)
      expect(response).to redirect_to('https://meta.discourse.org/')
      get '/go/important'
      expect(response.status).to eq(302)
      expect(response).to redirect_to(topic.relative_url)
    end

    it 'accepts and forwards query parameters' do
      get '/go/meta?safe_mode=no_custom'
      expect(response.status).to eq(302)
      expect(response).to redirect_to('https://meta.discourse.org/?safe_mode=no_custom')
    end

    it 'accepts and forwards extraneous path elements with or without a slash in the target' do
      ['https://meta.discourse.org', 'https://meta.discourse.org/'].each do |target|
        go_link.update!(external_url: target)

        get '/go/meta/c/praise'
        expect(response.status).to eq(302)
        expect(response).to redirect_to('https://meta.discourse.org/c/praise')
      end
    end

    it 'accepts and forwards extraneous path elements with query parameters' do
      get '/go/meta/c/praise?order=views'
      expect(response.status).to eq(302)
      expect(response).to redirect_to('https://meta.discourse.org/c/praise?order=views')
    end

    it 'preserves query parameters in the target with extraneous path elements and query parameters' do
      get '/go/tricky/item?view=full'
      expect(response.status).to eq(302)
      expect(response).to redirect_to('https://example.com/folder/item?tricky=true&view=full')
    end

    it 'works with slashes inside the link definition' do
      get '/go/meta/codinghorror'
      expect(response).to redirect_to('https://meta.discourse.org/u/codinghorror/')
      expect(response.status).to eq(302)

      get '/go/meta/codinghorror/summary'
      expect(response).to redirect_to('https://meta.discourse.org/u/codinghorror/summary')
      expect(response.status).to eq(302)
    end

    it 'overwrites query parameters using those in the request' do
      get '/go/tricky?tricky=override'
      expect(response.status).to eq(302)
      expect(response).to redirect_to('https://example.com/folder?tricky=override')
    end

    describe 'preservation of trailing slashes' do
      [
        # When request has no suffix: match target_url
        { e: 'https://meta.discourse.org', t: 'https://meta.discourse.org', r: '/go/meta' },
        { e: 'https://meta.discourse.org/', t: 'https://meta.discourse.org/', r: '/go/meta' },
        { e: 'https://meta.discourse.org/faq', t: 'https://meta.discourse.org/faq', r: '/go/meta' },
        { e: 'https://meta.discourse.org/faq/', t: 'https://meta.discourse.org/faq/', r: '/go/meta' },
        # When request has a suffix: override with rails behavior (no trailing slash)
        { e: 'https://meta.discourse.org/', t: 'https://meta.discourse.org/faq', r: '/go/meta/faq' },
        { e: 'https://meta.discourse.org/faq', t: 'https://meta.discourse.org/faq/faq', r: '/go/meta/faq' },
        { e: 'https://meta.discourse.org/faq/', t: 'https://meta.discourse.org/faq/faq', r: '/go/meta/faq' },
      ].each do |testcase|
        it "external_url: #{testcase[:e].inspect} destination: #{testcase[:t].inspect} request: #{testcase[:r].inspect}" do
          go_link.update!(external_url: testcase[:e])

          get testcase[:r]
          expect(response.status).to eq(302)
          expect(response).to redirect_to(testcase[:t])
        end
      end
    end

  end
end
