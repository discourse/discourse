ExternalUploadStub
------------

id
created_at
updated_at
key
original_filename
status - (1 created; 2 uploaded; 3 promoted?processed) - maybe there is no 3, just delete after converted to full upload
user_id
unique_identifier (securerandom)

* after 1 day delete upload in uploaded state, after 1 hour delete upload in created state
* this is created every time generate_presigned_put endpoint is called
* also created when multipart upload is created

discourse sha calculation
--------

1. generate presigned put url or create multipart upload also creates external upload stub then complete direct upload
2. when upload is complete call complete-temporary-external-upload endpoint with key and unique identifier of the stub
3. create exclusive job to download the file from s3 to a tempfile and create an upload record with the sha, which also copies
the temporary file on s3 to the real destination based on the sha
4. delete the external upload stub
5. notify the client via message bus with update details (or errors)

lambda sha calculation
--------

0. run through full s3 direct upload same as step 1 above
1. detect new file in s3
2. download file and generate the sha
3. call complete-temporary-external-upload discourse endpoint with the sha and the unique identifier of the stub
4. copy the temp file into the proper location using the sha and create the real upload record
5. delete the external upload stub
6. notify the client via message bus with update details (or errors)
