# frozen_string_literal: true

RSpec.describe Admin::ReportsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#index" do
    before { sign_in(admin) }

    it "excludes page view mobile reports" do
      get "/admin/reports.json"
      expect(response.parsed_body["reports"].map { |r| r[:type] }).not_to include(
        "page_view_anon_browser_mobile_reqs",
        "page_view_logged_in_browser_mobile_reqs",
        "page_view_anon_mobile_reqs",
        "page_view_logged_in_mobile_reqs",
      )
    end

    it "excludes about and storage stats reports" do
      get "/admin/reports.json"
      expect(response.parsed_body["reports"].map { |r| r[:type] }).not_to include(
        "report_about",
        "report_storage_stats",
      )
    end

    context "when use_legacy_pageviews is true" do
      before { SiteSetting.use_legacy_pageviews = true }

      it "excludes the site_traffic report and includes legacy pageview reports" do
        get "/admin/reports.json"
        expect(response.parsed_body["reports"].map { |r| r[:type] }).not_to include("site_traffic")
        expect(response.parsed_body["reports"].map { |r| r[:type] }).to include(
          *Admin::ReportsController::HIDDEN_LEGACY_PAGEVIEW_REPORTS,
        )
      end
    end

    context "when use_legacy_pageviews is false" do
      before { SiteSetting.use_legacy_pageviews = false }

      it "includes the site_traffic report and excludes legacy pageview reports" do
        get "/admin/reports.json"
        expect(response.parsed_body["reports"].map { |r| r[:type] }).to include("site_traffic")
        expect(response.parsed_body["reports"].map { |r| r[:type] }).not_to include(
          *Admin::ReportsController::HIDDEN_LEGACY_PAGEVIEW_REPORTS,
        )
      end
    end
  end

  describe "#bulk" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "with valid params" do
        fab!(:topic)

        it "renders the reports as JSON" do
          get "/admin/reports/bulk.json",
              params: {
                reports: {
                  topics: {
                    limit: 10,
                  },
                  likes: {
                    limit: 10,
                  },
                },
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["reports"].count).to eq(2)
        end

        it "uses the user's locale for report names and descriptions" do
          SiteSetting.allow_user_locale = true
          admin.update!(locale: "es")
          get "/admin/reports/bulk.json",
              params: {
                reports: {
                  topics: {
                    limit: 10,
                  },
                  likes: {
                    limit: 10,
                  },
                },
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["reports"].first["title"]).to eq(
            I18n.t("reports.topics.title", locale: "es"),
          )
          expect(response.parsed_body["reports"].first["description"]).to eq(
            I18n.t("reports.topics.description", locale: "es"),
          )
        end
      end

      context "with invalid params" do
        context "when limit param is invalid" do
          include_examples "invalid limit params",
                           "/admin/reports/topics.json",
                           described_class::REPORTS_LIMIT
        end

        context "with nonexistent report" do
          it "returns not found reports" do
            get "/admin/reports/bulk.json",
                params: {
                  reports: {
                    topics: {
                      limit: 10,
                    },
                    not_found: {
                      limit: 10,
                    },
                  },
                }

            expect(response.status).to eq(200)
            expect(response.parsed_body["reports"].count).to eq(2)
            expect(response.parsed_body["reports"][0]["type"]).to eq("topics")
            expect(response.parsed_body["reports"][1]["type"]).to eq("not_found")
          end
        end

        context "with invalid start or end dates" do
          it "doesn't return 500 error" do
            get "/admin/reports/bulk.json",
                params: {
                  reports: {
                    topics: {
                      limit: 10,
                      start_date: "2015-0-1",
                    },
                  },
                }
            expect(response.status).to eq(400)

            get "/admin/reports/bulk.json",
                params: {
                  reports: {
                    topics: {
                      limit: 10,
                      end_date: "2015-0-1",
                    },
                  },
                }
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "returns report" do
        Fabricate(:topic)

        get "/admin/reports/bulk.json",
            params: {
              reports: {
                topics: {
                  limit: 10,
                },
                likes: {
                  limit: 10,
                },
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["reports"].count).to eq(2)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/reports/bulk.json",
            params: {
              reports: {
                topics: {
                  limit: 10,
                },
                not_found: {
                  limit: 10,
                },
              },
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when use_legacy_pageviews is true" do
      before do
        SiteSetting.use_legacy_pageviews = true
        sign_in(admin)
      end

      it "marks the site_traffic report as not_found and does not run it" do
        get "/admin/reports/bulk.json",
            params: {
              reports: {
                site_traffic: {
                  limit: 10,
                },
                consolidated_page_views: {
                  limit: 10,
                },
                consolidated_page_views_browser_detection: {
                  limit: 10,
                },
                page_view_anon_reqs: {
                  limit: 10,
                },
                page_view_logged_in_reqs: {
                  limit: 10,
                },
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["reports"].count).to eq(5)
        expect(response.parsed_body["reports"][0]).to include("error" => "not_found", "data" => nil)
        expect(response.parsed_body["reports"][1]["type"]).to eq("consolidated_page_views")
        expect(response.parsed_body["reports"][2]["type"]).to eq(
          "consolidated_page_views_browser_detection",
        )
        expect(response.parsed_body["reports"][3]["type"]).to eq("page_view_anon_reqs")
        expect(response.parsed_body["reports"][4]["type"]).to eq("page_view_logged_in_reqs")
      end
    end

    context "when use_legacy_pageviews is false" do
      before do
        SiteSetting.use_legacy_pageviews = false
        sign_in(admin)
      end

      it "marks the legacy pageview reports as not_found and does not run them" do
        get "/admin/reports/bulk.json",
            params: {
              reports: {
                site_traffic: {
                  limit: 10,
                },
                consolidated_page_views: {
                  limit: 10,
                },
                consolidated_page_views_browser_detection: {
                  limit: 10,
                },
                page_view_anon_reqs: {
                  limit: 10,
                },
                page_view_logged_in_reqs: {
                  limit: 10,
                },
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["reports"].count).to eq(5)
        expect(response.parsed_body["reports"][0]["type"]).to eq("site_traffic")
        expect(response.parsed_body["reports"][1]["type"]).to eq("consolidated_page_views")
        expect(response.parsed_body["reports"][2]).to include("error" => "not_found", "data" => nil)
        expect(response.parsed_body["reports"][3]).to include("error" => "not_found", "data" => nil)
        expect(response.parsed_body["reports"][4]).to include("error" => "not_found", "data" => nil)
      end
    end
  end

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "with invalid id form" do
        let(:invalid_id) { "!!&asdfasdf" }

        it "returns 404" do
          get "/admin/reports/#{invalid_id}.json"
          expect(response.status).to eq(404)
        end
      end

      context "with valid type form" do
        context "with missing report" do
          it "returns a 404 error" do
            get "/admin/reports/nonexistent.json"
            expect(response.status).to eq(404)
          end
        end

        context "when a report is found" do
          it "renders the report as JSON" do
            Fabricate(:topic)
            get "/admin/reports/topics.json"

            expect(response.status).to eq(200)
            expect(response.parsed_body["report"]["total"]).to eq(1)
          end
        end

        context "when limit param is invalid" do
          include_examples "invalid limit params",
                           "/admin/reports/topics.json",
                           described_class::REPORTS_LIMIT
        end
      end

      describe "when report is scoped to a category" do
        fab!(:category)
        fab!(:topic) { Fabricate(:topic, category: category) }
        fab!(:other_topic) { Fabricate(:topic) }

        it "should render the report as JSON" do
          get "/admin/reports/topics.json", params: { category_id: category.id }

          expect(response.status).to eq(200)

          report = response.parsed_body["report"]

          expect(report["type"]).to eq("topics")
          expect(report["data"].count).to eq(1)
        end
      end

      describe "when report is scoped to a group" do
        fab!(:user)
        fab!(:other_user) { Fabricate(:user) }
        fab!(:group)

        it "should render the report as JSON" do
          group.add(user)

          get "/admin/reports/signups.json", params: { group_id: group.id }

          expect(response.status).to eq(200)

          report = response.parsed_body["report"]

          expect(report["type"]).to eq("signups")
          expect(report["data"].count).to eq(1)
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "returns report" do
        Fabricate(:topic)

        get "/admin/reports/topics.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["report"]["total"]).to eq(1)
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        get "/admin/reports/topics.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when use_legacy_pageviews is true" do
      before do
        SiteSetting.use_legacy_pageviews = true
        sign_in(admin)
      end

      it "does not allow running site_traffic report" do
        Admin::ReportsController::HIDDEN_PAGEVIEW_REPORTS.each do |report_type|
          get "/admin/reports/#{report_type}.json"
          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        end
      end

      it "does not allow running the page_view_legacy_total_reqs report" do
        get "/admin/reports/page_view_legacy_total_reqs.json"
        expect(response.status).to eq(404)
      end
    end

    context "when use_legacy_pageviews is false" do
      before do
        SiteSetting.use_legacy_pageviews = false
        sign_in(admin)
      end

      it "does not allow running legacy pageview reports" do
        Admin::ReportsController::HIDDEN_LEGACY_PAGEVIEW_REPORTS.each do |report_type|
          get "/admin/reports/#{report_type}.json"
          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        end
      end

      it "does allow running the page_view_legacy_total_reqs report" do
        get "/admin/reports/page_view_legacy_total_reqs.json"
        expect(response.status).to eq(200)
      end
    end
  end
end
