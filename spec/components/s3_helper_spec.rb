require "s3_helper"
require "rails_helper"

describe "S3Helper" do

  it "can correctly set the purge policy" do

    stub_request(:get, "http://169.254.169.254/latest/meta-data/iam/security-credentials/").
      to_return(status: 404, body: "", headers: {})

    lifecycle = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <LifecycleConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
        <Rule>
            <ID>old_rule</ID>
            <Prefix>projectdocs/</Prefix>
            <Status>Enabled</Status>
            <Expiration>
               <Days>3650</Days>
            </Expiration>
        </Rule>
        <Rule>
            <ID>purge-tombstone</ID>
            <Prefix>test/</Prefix>
            <Status>Enabled</Status>
            <Expiration>
               <Days>3650</Days>
            </Expiration>
        </Rule>
      </LifecycleConfiguration>
    XML

    stub_request(:get, "https://bob.s3.amazonaws.com/?lifecycle").
      to_return(status: 200, body: lifecycle, headers: {})

    stub_request(:put, "https://bob.s3.amazonaws.com/?lifecycle").
      with do |req|

      hash = Hash.from_xml(req.body.to_s)
      rules = hash["LifecycleConfiguration"]["Rule"]

      expect(rules.length).to eq(2)

      # fixes the bad filter
      expect(rules[0]["Filter"]["Prefix"]).to eq("projectdocs/")
    end.to_return(status: 200, body: "", headers: {})

    SiteSetting.enable_s3_uploads = true
    SiteSetting.s3_access_key_id = "abc"
    SiteSetting.s3_secret_access_key = "def"

    helper = S3Helper.new('bob', 'tomb')
    helper.update_tombstone_lifecycle(100)
  end

end
