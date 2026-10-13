# frozen_string_literal: true

RSpec.describe Admin::Config::FlagsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#move" do
    let(:flag) { Flag.find_by(name_key: "notify_moderators") }

    context "when logged in as an admin" do
      before { sign_in(admin) }

      context "with a position in range" do
        let!(:original_positions) { Flag.unscoped.pluck(:id, :position).to_h }

        # DO NOT REMOVE: saving a flag reloads the cached flag types after
        # commit, so the moved order will leak to other examples otherwise.
        after do
          original_positions.each { |id, position| Flag.unscoped.where(id:).update_all(position:) }
          Flag.reset_flag_settings!
        end

        it "moves the flag and returns 204" do
          put "/admin/config/flags/#{flag.id}/move.json", params: { position: 1 }

          expect(response.status).to eq(204)
          expect(response.body).to be_empty
          expect(Flag.order(:position).map(&:name)).to eq(
            %w[notify_user off_topic notify_moderators inappropriate spam illegal],
          )
        end
      end

      it "returns 404 when the flag does not exist" do
        put "/admin/config/flags/0/move.json", params: { position: 1 }

        expect(response.status).to eq(404)
      end

      it "returns 403 when the flag is notify_user" do
        put "/admin/config/flags/#{Flag.find_by(name_key: "notify_user").id}/move.json",
            params: {
              position: 1,
            }

        expect(response.status).to eq(403)
      end

      it "returns 422 with an explanatory error when the position is out of range" do
        put "/admin/config/flags/#{flag.id}/move.json", params: { position: 5 }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(I18n.t("flags.errors.wrong_move"))
      end

      it "returns 400 when the position is missing or negative" do
        put "/admin/config/flags/#{flag.id}/move.json"
        expect(response.status).to eq(400)

        put "/admin/config/flags/#{flag.id}/move.json", params: { position: -1 }
        expect(response.status).to eq(400)
      end
    end

    it "returns 403 for a moderator" do
      sign_in(moderator)

      put "/admin/config/flags/#{flag.id}/move.json", params: { position: 1 }

      expect(response.status).to eq(403)
    end

    it "returns 404 for a regular user" do
      sign_in(user)

      put "/admin/config/flags/#{flag.id}/move.json", params: { position: 1 }

      expect(response.status).to eq(404)
    end

    it "returns 404 for an anonymous user" do
      put "/admin/config/flags/#{flag.id}/move.json", params: { position: 1 }

      expect(response.status).to eq(404)
    end
  end
end
