require 'spec_helper'

describe Jobs::ExportCsvFile do

  context '.execute' do
    it 'raises an error when the entity is missing' do
      expect { Jobs::ExportCsvFile.new.execute(user_id: "1") }.to raise_error(Discourse::InvalidParameters)
    end
  end

  let :user_list_header do
    ['id','name','username','email','title','created_at','last_seen_at','last_posted_at','last_emailed_at','trust_level','approved','suspended_at','suspended_till','blocked','active','admin','moderator','ip_address','topics_entered','posts_read_count','time_read','topic_count','post_count','likes_given','likes_received','external_id','external_email', 'external_username', 'external_name', 'external_avatar_url']
  end

  let :user_list_export do
    Jobs::ExportCsvFile.new.user_list_export
  end

  def to_hash(row)
    Hash[*user_list_header.zip(row).flatten]
  end

  it 'exports sso data' do
    SiteSetting.enable_sso = true
    user = Fabricate(:user)
    user.create_single_sign_on_record(external_id: "123", last_payload: "xxx", external_email: 'test@test.com')

    user = to_hash(user_list_export.find{|u| u[0] == user.id})

    expect(user["external_id"]).to eq("123")
    expect(user["external_email"]).to eq("test@test.com")
  end
end
