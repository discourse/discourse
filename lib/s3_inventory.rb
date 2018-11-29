require "aws-sdk-s3"

class S3Inventory

  attr_reader :inventory_id, :s3_client, :source_bucket_name, :source_bucket_path, :destination_bucket_name, :destination_bucket_path

  def initialize(s3_client, source_bucket_name, source_bucket_path, inventory_id = "discourse-uploads")
    @s3_client = s3_client
    @source_bucket_name = source_bucket_name
    @source_bucket_path = source_bucket_path
    @inventory_id = inventory_id
  end

  def update!
    if SiteSetting.enable_s3_inventory
      raise Discourse::InvalidParameters.new("s3_upload_bucket_name") if SiteSetting.s3_upload_bucket.blank?
      raise Discourse::InvalidParameters.new("s3_inventory_bucket_name") if SiteSetting.s3_inventory_bucket.blank?
    elsif SiteSetting.s3_upload_bucket.blank? || SiteSetting.s3_inventory_bucket.blank?
      return
    end

    @destination_bucket_name, @destination_bucket_path = begin
      SiteSetting.s3_inventory_bucket.downcase.split("/".freeze, 2)
    end

    update_policy
    update_configuration
  end

  def update_policy
    s3_client.put_bucket_policy(
      bucket: destination_bucket_name,
      policy: {
        "Version" => "2012-10-17",
        "Statement":[
          {
            "Sid": "InventoryAndAnalyticsExamplePolicy",
            "Effect": "Allow",
            "Principal": {"Service": "s3.amazonaws.com"},
            "Action": ["s3:PutObject"],
            "Resource": ["arn:aws:s3:::#{destination_bucket_name}/*"],
            "Condition": {
              "ArnLike": {
                "aws:SourceArn": "arn:aws:s3:::#{source_bucket_name}"
              },
              "StringEquals": {
                "s3:x-amz-acl": "bucket-owner-full-control"
              }
            }
          }
        ]
      }.to_json
    )
  end

  def update_configuration
    s3_client.put_bucket_inventory_configuration({
      bucket: source_bucket_name,
      id: inventory_id,
      inventory_configuration: inventory_configuration,
      use_accelerate_endpoint: false
    })
  end

  def inventory_configuration
    config = {
      destination: {
        s3_bucket_destination: {
          bucket: "arn:aws:s3:::#{destination_bucket_name}",
          format: "CSV"
        }
      },
      is_enabled: SiteSetting.enable_s3_inventory,
      id: inventory_id,
      included_object_versions: "Current",
      optional_fields: ["Size", "LastModifiedDate", "ETag"],
      schedule: {
        frequency: "Daily"
      }
    }
    config[:filter] = { prefix: source_bucket_path } if source_bucket_path.present?
    config[:destination][:s3_bucket_destination][:prefix] = destination_bucket_path if destination_bucket_path.present?
    config
  end

end
