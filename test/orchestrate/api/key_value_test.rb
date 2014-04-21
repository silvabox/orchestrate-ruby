require_relative "../../test_helper"

class KeyValueTest < MiniTest::Unit::TestCase
  def setup
    @collection = 'test'
    @key = 'keyname'
    @client, @stubs, @basic_auth = make_client_and_artifacts
  end

  def test_gets_current_value_for_key_when_exists
    ref = SecureRandom.hex(16)
    ref_url = "/v0/#{@collection}/#{@key}/refs/#{ref}"
    body = '{"key":"value"}' 
    @stubs.get("/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      headers = {
        'Content-Location' => ref_url,
        'ETag' => ref,
      }.merge(chunked_encoding_header)
      [ 200, response_headers(headers), body]
    end

    response = @client.get_key({collection:@collection, key:@key})
    assert_equal 200, response.status
    assert_equal body, response.body

    assert_equal ref, response.headers['ETag']
    assert_equal ref_url, response.headers['Content-Location']
    assert_equal 'chunked', response.headers['transfer-encoding']
  end

  def test_gets_key_value_is_404_when_does_not_exist
    @stubs.get("/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      [ 404, response_headers(), response_not_found({collection:@collection, key:@key}) ]
    end

    response = @client.get_key({collection:@collection, key:@key})
    assert_equal 404, response.status
    assert_match(/items_not_found/, response.body)
  end

  def test_puts_key_value_with_specific_ref
    body = '{"foo":"bar"}'
    ref = '123456'

    @stubs.put("/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-Match', ref, env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body, env.body
      [ 200, response_headers, '' ]
    end

    @client.put_key({ collection:@collection, key:@key, json: body, ref: ref })
  end

  def test_puts_key_value_with_inspecific_ref
    body = '{"foo":"bar"}'

    @stubs.put("/#{@collection}/#{@key}") do |env|
      assert_authorization @basic_auth, env
      assert_header 'If-None-Match', '*', env
      assert_header 'Content-Type', 'application/json', env
      assert_equal body, env.body
      [ 200, response_headers, '' ]
    end

    @client.put_key({ collection:@collection, key:@key, json:body, ref:'*' })
  end

end
